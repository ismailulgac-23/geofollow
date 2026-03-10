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
        await prisma.locationSnapshot.create({
            data: { userId, latitude, longitude, address, speed, accuracy }
        });

        // 2. Kullanıcının üye olduğu çemberlerdeki yerleri çek
        const memberships = await prisma.circleMember.findMany({
            where: { userId },
            include: { circle: { include: { places: { where: { isActive: true } } } } }
        });

        const allPlaces = memberships.flatMap(m => m.circle.places);
        if (allPlaces.length === 0) {
            // Hiç yer yoksa ve aktif bir hareket varsa kapat (User "temiz" alana çıktı)
            await closeActiveMovement(userId, now);
            return;
        }

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

        // 4. Aktif durumu kontrol et
        const activeMovement = await prisma.movementHistory.findFirst({
            where: { userId, leftAt: null },
            orderBy: { arrivedAt: 'desc' }
        });

        if (bestPlace) {
            // Kullanıcı bir yerin içinde
            if (activeMovement) {
                if (activeMovement.placeId === bestPlace.id) {
                    // ZATEN BURADA: Hiçbir şey yapma (Duplicate engellendi)
                    return;
                } else {
                    // BAŞKA BİR YERE GEÇTİ: Eski yeri kapat, yeniyi aç
                    await closeActiveMovement(userId, now, activeMovement);
                    await createNewMovement(userId, bestPlace, address || bestPlace.address, now);
                }
            } else {
                // YENİ GİRİŞ: Hiçbir yerde değildi, şimdi bir yere girdi
                await createNewMovement(userId, bestPlace, address || bestPlace.address, now);
            }
        } else {
            // Kullanıcı hiçbir yerin (tam) içinde değil
            if (activeMovement) {
                // ÇIKTI MI? %20 toleransı kontrol et (Hysteresis)
                const currentPlace = allPlaces.find(p => p.id === activeMovement.placeId);
                if (currentPlace) {
                    const dist = haversineDistance(latitude, longitude, currentPlace.latitude, currentPlace.longitude);
                    if (dist > (currentPlace.radius * EXIT_THRESHOLD_MULTIPLIER)) {
                        // Tolerans dışına çıktı, gerçekten ayrıldı
                        await closeActiveMovement(userId, now, activeMovement);
                    } else {
                        // Tolerans içinde, hâlâ orada sayılır (Log duplicate etmiyoruz)
                        return;
                    }
                } else {
                    // Yer silinmiş veya pasif, kapat
                    await closeActiveMovement(userId, now, activeMovement);
                }
            }
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

    await prisma.movementHistory.create({
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

                notificationPromises.push(prisma.notification.create({
                    data: {
                        title: type === 'ENTERED' ? 'place_entered' : 'place_exited',
                        message: `${currentUser.name || 'User'} ${type === 'ENTERED' ? 'entered' : 'exited'} ${body.replace('User has left ', '').replace('User has entered ', '')}`,
                        type: 'place',
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

module.exports = { processLocationUpdate, getFrequentPlaces, getTodayMovements };
