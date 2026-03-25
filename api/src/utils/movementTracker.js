/**
 * Movement Tracking Algorithm
 * 
 * Her konum güncellemesinde:
 * 1. Ham konumu LocationSnapshot'a kaydeder
 * 2. Kullanıcının dairesi içindeki yerlere yakın mı kontrol eder (Haversine mesafesi)
 * 3. Yakınsa, MovementHistory'i günceller veya yeni kayıt oluşturur
 * 4. Kullanıcı yoksa (ayrıldıysa) mevcut kaydı kapatır
 * 5. visitCount (toplam ziyaret) arttırır
 */

const prisma = require('../config/database');
const { sendMulticastNotification } = require('./firebase');

const EARTH_RADIUS_KM = 6371;

/**
 * İki koordinat arasındaki mesafeyi metre cinsinden hesaplar (Haversine)
 */
function haversineDistance(lat1, lon1, lat2, lon2) {
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLon = ((lon2 - lon1) * Math.PI) / 180;
    const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return EARTH_RADIUS_KM * c * 1000; // metre
}

/**
 * Ana algoritma: Konum güncellemesini işle (Tamamen API Tarafında)
 */
async function processLocationUpdate(userId, latitude, longitude, address, speed = 0, accuracy = 0) {
    try {
        const now = new Date();

        // 1. Ham konumu kaydet (Snapshot)
        const currentSnapshot = await prisma.locationSnapshot.create({
            data: { userId, latitude, longitude, address, speed, accuracy }
        });

        // 2. Kullanıcının bilgisini al (Son bildirim ne zaman atıldı?)
        const user = await prisma.user.findUnique({
            where: { id: userId }
        });

        if (!user) return;

        // 3. HAREKETE GEÇTİ ANALİZİ (On the Move Detection)
        // Eğer 15 dakikadır konum gelmemişse (veya hareketsizse) ve şimdi mesafe katetmişse bildir
        const lastSnapshot = await prisma.locationSnapshot.findFirst({
            where: { userId, id: { not: currentSnapshot.id } },
            orderBy: { timestamp: 'desc' }
        });

        if (lastSnapshot) {
            const timeDiffMins = (now - new Date(lastSnapshot.timestamp)) / 60000;
            const dist = haversineDistance(latitude, longitude, lastSnapshot.latitude, lastSnapshot.longitude);

            // Uzun süre (15dk+) bekledi ve şimdi 200m+ mesafe katetti
            // Ve son 1 saat içinde "Harekete geçti" bildirimi almamış olmalı (Spam koruması)
            const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
            const canSendNotification = !user.lastMovementNotificationAt || user.lastMovementNotificationAt < oneHourAgo;

            if (timeDiffMins >= 15 && dist >= 200 && canSendNotification) {
                // Eğer bir YER'e (Safe Zone) girdiyse ZATEN bildirim gidecek.
                // Sadece hiçbir yerin içinde değilken "Harekete geçti" demeliyiz.
                // Bu check'i aşağıda yer kontrolünden sonra yapacağız.
                user._shouldNotifyMovement = true; 
            }
        }

        // 4. Kullanıcının üye olduğu çemberlerdeki yerleri çek
        const memberships = await prisma.circleMember.findMany({
            where: { userId },
            include: { circle: { include: { places: { where: { isActive: true } } } } }
        });

        const allPlaces = memberships.flatMap(m => m.circle.places);

        // 3. Aktif durumu kontrol et
        const activeMovement = await prisma.movementHistory.findFirst({
            where: { userId, leftAt: null },
            orderBy: { arrivedAt: 'desc' }
        });

        // 3. Mesafe bazlı analiz
        // Hysteresis (Gecikme/Tolerans): Giriş için tam radius, çıkış için %20 daha geniş alan
        const EXIT_THRESHOLD_MULTIPLIER = 1.2;

        let bestPlace = null;
        let minRatio = 1.0; // ratiosu en küçük olan (merkeze en yakın olan) kazanır

        for (const place of allPlaces) {
            const dist = haversineDistance(latitude, longitude, place.latitude, place.longitude);
            const ratio = dist / place.radius;

            if (ratio <= 1.0) {
                // İçeride
                if (ratio < minRatio) {
                    minRatio = ratio;
                    bestPlace = place;
                }
            }
        }

        // 4. Hareket Durum Yönetimi (Timeline Mantığı)
        if (bestPlace) {
            // 4.1. Kullanıcı tanımlı bir yerin içinde
            if (activeMovement) {
                if (activeMovement.placeId === bestPlace.id) {
                    return; // Zaten burada, işlem yapmaya gerek yok
                }
                // Başka bir yerden (yer veya stationary) buraya geldi, eskiyi kapat
                await closeActiveMovement(userId, now, activeMovement);
            }
            // Yeni girişi başlat
            await createNewMovement(userId, bestPlace, address || bestPlace.address, now);
        } else {
            // 4.2. Tanımlı bir yerin içinde değil
            if (activeMovement) {
                if (activeMovement.placeId) {
                    // Tanımlı bir yerden çıktı mı? (Tolerans / Hysteresis kontrolü)
                    const currentPlace = allPlaces.find(p => p.id === activeMovement.placeId);
                    if (currentPlace) {
                        const dist = haversineDistance(latitude, longitude, currentPlace.latitude, currentPlace.longitude);
                        if (dist > (currentPlace.radius * EXIT_THRESHOLD_MULTIPLIER)) {
                            await closeActiveMovement(userId, now, activeMovement);
                        }
                    } else {
                        // Yer artık mevcut değilse kapat
                        await closeActiveMovement(userId, now, activeMovement);
                    }
                } else {
                    // Zaten "Stationary Point" (bilinmeyen yer) içindeydi, hareket etti mi?
                    const distMovement = haversineDistance(latitude, longitude, activeMovement.latitude, activeMovement.longitude);
                    if (distMovement > 100) { // 100m'den fazla uzaklaşırsa sabitlik bozulur
                        await closeActiveMovement(userId, now, activeMovement);
                    }
                }
            } else {
                // Hiçbir yerde değil ve aktif hareketi yok. 
                // Yeni bir stationary nokta (bilinmeyen yer) tespiti yapalım.
                const lastSnapshot = await prisma.locationSnapshot.findFirst({
                    where: { userId, timestamp: { lt: new Date(now.getTime() - 10 * 60000) } }, // 10 dk önce
                    orderBy: { timestamp: 'desc' }
                });

                if (lastSnapshot) {
                    const distFromLast = haversineDistance(latitude, longitude, lastSnapshot.latitude, lastSnapshot.longitude);
                    if (distFromLast < 80) { // 10 dk boyunca 80m radius içindeyse "sabit" sayılır
                        await createNewMovement(userId, {
                            id: null, 
                            name: address || 'Stationary',
                            address: address || 'Unknown Location',
                            latitude: lastSnapshot.latitude,
                            longitude: lastSnapshot.longitude,
                            emoji: '📍'
                        }, address, now);
                    }
                }
            }
        }

        // 5. Harekete Geçti Bildirimi (Place'e girmediyse at)
        if (user._shouldNotifyMovement && !bestPlace) {
            await prisma.user.update({
                where: { id: userId },
                data: { lastMovementNotificationAt: now }
            });

            console.log(`[MovementTracker] ON THE MOVE: ${user.name} (User: ${userId})`);
            notifyCircles(userId, '🏃 Harekete Geçti', `${user.name} uzun süre sonra harekete geçti.`, 'MOVEMENT_STARTED', { speed: speed });
        }
    } catch (error) {
        console.error('[MovementTracker] Error:', error.message);
    }
}

async function closeActiveMovement(userId, now, activeMovement = null) {
    if (!activeMovement) {
        activeMovement = await prisma.movementHistory.findFirst({
            where: { userId, leftAt: null }
        });
    }
    if (!activeMovement) return;

    const durationMins = Math.round((now - new Date(activeMovement.arrivedAt)) / 60000);

    await prisma.movementHistory.update({
        where: { id: activeMovement.id },
        data: { leftAt: now, durationMins }
    });

    console.log(`[MovementTracker] EXITED: ${activeMovement.placeName} (User: ${userId})`);
    notifyCircles(userId, '📍 Place Exited', `User has left ${activeMovement.placeName}`, 'EXITED', { placeId: activeMovement.placeId });
}

async function createNewMovement(userId, place, address, now) {
    // Aynı yeri bugün ziyaret edip etmediğini kontrol et (visitCount için) ve 30 dk debounce uygula
    const lastHistory = await prisma.movementHistory.findFirst({
        where: { userId, placeId: place.id },
        orderBy: { arrivedAt: 'desc' }
    });

    if (lastHistory) {
        const diffMins = (now - new Date(lastHistory.arrivedAt)) / 60000;
        if (diffMins < 30) {
            console.log(`[MovementTracker] SKIP duplicate ENTERED log for ${place.name} (User: ${userId}) - Diff: ${diffMins.toFixed(1)} mins`);
            return;
        }
    }

    const history = await prisma.movementHistory.create({
        data: {
            userId,
            placeId: place.id,
            placeName: place.name,
            address: address || place.address || '',
            emoji: place.emoji || '📍',
            latitude: place.latitude,
            longitude: place.longitude,
            arrivedAt: now,
            visitCount: lastHistory ? lastHistory.visitCount + 1 : 1
        }
    });

    console.log(`[MovementTracker] ENTERED: ${place.name} (User: ${userId})`);
    notifyCircles(userId, '📍 Place Entered', `User has entered ${place.name}`, 'ENTERED', { placeId: place.id });

    return history;
}

/**
 * Bir kullanıcının hareket özeti: En sık gittiği yerler
 */
async function getFrequentPlaces(userId, limit = 5) {
    try {
        // Tüm yerlere göre grupla ve ziyaret sayısını topla
        const histories = await prisma.movementHistory.findMany({
            where: {
                userId,
                placeId: { not: null },
                leftAt: { not: null }
            },
            orderBy: { arrivedAt: 'desc' },
            take: 200 // son 200 hareket içinden analiz yap
        });

        // Yer bazlı istatistikler
        const placeStats = {};
        for (const h of histories) {
            if (!h.placeId) continue;
            if (!placeStats[h.placeId]) {
                placeStats[h.placeId] = {
                    placeId: h.placeId,
                    placeName: h.placeName,
                    address: h.address,
                    emoji: h.emoji || '📍',
                    latitude: h.latitude,
                    longitude: h.longitude,
                    totalVisits: 0,
                    totalMinutes: 0,
                    lastVisit: null
                };
            }
            placeStats[h.placeId].totalVisits += 1;
            placeStats[h.placeId].totalMinutes += h.durationMins || 0;
            if (!placeStats[h.placeId].lastVisit || h.arrivedAt > placeStats[h.placeId].lastVisit) {
                placeStats[h.placeId].lastVisit = h.arrivedAt;
            }
        }

        // Ziyaret sayısına göre sırala
        const sorted = Object.values(placeStats)
            .sort((a, b) => b.totalVisits - a.totalVisits)
            .slice(0, limit);

        return sorted;
    } catch (error) {
        console.error('[MovementTracker] getFrequentPlaces error:', error.message);
        return [];
    }
}

/**
 * Bugünkü hareketleri getir
 */
async function getTodayMovements(userId) {
    try {
        const startOfDay = new Date();
        startOfDay.setHours(0, 0, 0, 0);

        const movements = await prisma.movementHistory.findMany({
            where: {
                userId,
                arrivedAt: { gte: startOfDay }
            },
            orderBy: { arrivedAt: 'desc' }
        });

        return movements;
    } catch (error) {
        console.error('[MovementTracker] getTodayMovements error:', error.message);
        return [];
    }
}

/**
 * Circle üyelerine place giriş/çıkış bildirimlerini atar
 */
async function notifyCircles(userId, title, body, type, data) {
    try {
        const currentUser = await prisma.user.findUnique({
            where: { id: userId },
            include: {
                circles: { include: { circle: { include: { members: { include: { user: true } } } } } }
            }
        });
        if (!currentUser) return;

        const recipientTokens = [];
        const notificationPromises = [];

        for (const circleMember of currentUser.circles) {
            for (const member of circleMember.circle.members) {
                if (member.userId === userId) continue;
                if (member.user.fcmToken && !recipientTokens.includes(member.user.fcmToken)) {
                    recipientTokens.push(member.user.fcmToken);
                }

                let dbTitle = 'notification';
                if (type === 'ENTERED') dbTitle = 'place_entered';
                else if (type === 'EXITED') dbTitle = 'place_exited';
                else if (type === 'MOVEMENT_STARTED') dbTitle = 'movement_started';

                notificationPromises.push(prisma.notification.create({
                    data: {
                        title: dbTitle,
                        message: `${currentUser.name || 'User'} ${body.split(' ').slice(1).join(' ')}`,
                        type: type.toLowerCase(),
                        userId: member.userId,
                        avatarUrl: currentUser.avatarUrl,
                        relatedUserId: currentUser.id
                    }
                }));
            }
        }

        await Promise.all(notificationPromises);

        if (recipientTokens.length > 0) {
            await sendMulticastNotification(recipientTokens, {
                title,
                body: `${currentUser.name || 'User'} ${type === 'ENTERED' ? 'entered' : 'left'} ${body.split(' ').slice(3).join(' ')}`,
                data: { ...data, type: 'place', relatedUserId: currentUser.id }
            });
        }
    } catch (err) {
        console.error("[MovementTracker] notifyCircles error", err);
    }
}

module.exports = { processLocationUpdate, getFrequentPlaces, getTodayMovements, createNewMovement, notifyCircles, closeActiveMovement };
