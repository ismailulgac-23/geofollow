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
 * Ana algoritma: Konum güncellemesini işle
 */
async function processLocationUpdate(userId, latitude, longitude, address, speed = 0, accuracy = 0) {
    try {
        // 1. Ham konumu kaydet
        await prisma.locationSnapshot.create({
            data: {
                userId,
                latitude,
                longitude,
                address,
                speed,
                accuracy,
            }
        });

        // 2. Kullanıcının üye olduğu çemberlerdeki yerleri çek
        const memberships = await prisma.circleMember.findMany({
            where: { userId },
            include: {
                circle: {
                    include: {
                        places: {
                            where: { isActive: true }
                        }
                    }
                }
            }
        });

        const allPlaces = memberships.flatMap(m => m.circle.places);
        if (allPlaces.length === 0) return;

        // 3. Hangi yerlere yakın olduğunu bul
        const ARRIVAL_THRESHOLD = 1.2; // placeRadius * bu katsayı = varış eşiği
        const nearbyPlace = allPlaces.find(place => {
            const dist = haversineDistance(latitude, longitude, place.latitude, place.longitude);
            return dist <= (place.radius * ARRIVAL_THRESHOLD);
        });

        // 4. Aktif açık hareketi bul
        const activeMovement = await prisma.movementHistory.findFirst({
            where: { userId, leftAt: null },
            orderBy: { arrivedAt: 'desc' }
        });

        const now = new Date();

        if (nearbyPlace) {
            // Kullanıcı bir yerin yakınında

            if (activeMovement) {
                if (activeMovement.placeId === nearbyPlace.id) {
                    // Aynı yerde → güncelleme gerekmez
                    return;
                } else {
                    // Farklı bir yere geçti → eskiyi kapat
                    const durationMins = Math.round((now - activeMovement.arrivedAt) / 60000);
                    await prisma.movementHistory.update({
                        where: { id: activeMovement.id },
                        data: { leftAt: now, durationMins }
                    });

                    // Exit notification
                    notifyCircles(userId, '📍 Place Exited', `User has left ${activeMovement.placeName || 'a place'}`, 'EXITED', { placeId: activeMovement.placeId });
                }

            }

            // Bu yere daha önce gidilmiş mi kontrol et (bugün veya toplam)
            const existingHistory = await prisma.movementHistory.findFirst({
                where: {
                    userId,
                    placeId: nearbyPlace.id,
                    leftAt: { not: null }
                },
                orderBy: { arrivedAt: 'desc' }
            });

            // Yeni varış kaydı oluştur
            await prisma.movementHistory.create({
                data: {
                    userId,
                    placeId: nearbyPlace.id,
                    placeName: nearbyPlace.name,
                    address: nearbyPlace.address || address,
                    emoji: nearbyPlace.emoji || '📍',
                    latitude: nearbyPlace.latitude,
                    longitude: nearbyPlace.longitude,
                    arrivedAt: now,
                    visitCount: existingHistory ? existingHistory.visitCount + 1 : 1
                }
            });

            // Entry notification
            notifyCircles(userId, '📍 Place Entered', `User has entered ${nearbyPlace.name || 'a place'}`, 'ENTERED', { placeId: nearbyPlace.id });


            // LocationSnapshot'ı yakın yerle güncelle
            await prisma.locationSnapshot.updateMany({
                where: {
                    userId,
                    placeId: null,
                    createdAt: { gte: new Date(now.getTime() - 5000) } // son 5 sn
                },
                data: {
                    placeId: nearbyPlace.id,
                    placeName: nearbyPlace.name
                }
            });

        } else {
            // Kullanıcı herhangi bir yerin yakınında değil
            if (activeMovement) {
                // Yeri terk etti → kaydı kapat
                const durationMins = Math.round((now - activeMovement.arrivedAt) / 60000);
                await prisma.movementHistory.update({
                    where: { id: activeMovement.id },
                    data: { leftAt: now, durationMins }
                });

                // Exit Notification
                notifyCircles(userId, '📍 Place Exited', `User has left ${activeMovement.placeName || 'a place'}`, 'EXITED', { placeId: activeMovement.placeId });
            }
        }
    } catch (error) {
        console.error('[MovementTracker] Error:', error.message);
        // Algoritma hatası ana akışı bloke etmez
    }
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
