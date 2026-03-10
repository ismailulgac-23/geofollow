const prisma = require('../config/database');
const { sendNotification } = require('../utils/firebase');

// In-memory simulation state
// { userId: { targetIndex, currentLat, currentLng, pathPoints, isMoving } }
const activeSimulations = new Map();

/**
 * Starts or updates a simulation for a mock user.
 * It will make the user move between a list of places.
 */
const startSimulation = async (mockUserId, followerUserId, places) => {
    if (!places || places.length === 0) return;

    // Start slightly offset from the first place
    const startLat = Number(places[0].latitude) + 0.0005;
    const startLng = Number(places[0].longitude) + 0.0005;

    activeSimulations.set(mockUserId, {
        userId: mockUserId,
        followerId: followerUserId,
        places: places,
        targetIndex: 0,
        currentLat: Number(startLat),
        currentLng: Number(startLng),
        dwellTicks: 0,
        isMoving: true,
        isInsidePlace: false,
        currentHistoryId: null
    });

    console.log(`🚀 [Simulation] Sequential loop started for ${mockUserId} (${places.length} places)`);
};

/**
 * Main simulation tick - runs every 10 seconds
 */
const runSimulationTick = async (io) => {
    for (const [userId, sim] of activeSimulations.entries()) {
        try {
            if (!sim.isMoving) continue;

            const targetPlace = sim.places[sim.targetIndex];
            if (!targetPlace) {
                sim.targetIndex = 0;
                continue;
            }

            const radiusInDegrees = (targetPlace.radius || 200) / 111000;
            const stepSize = 0.0022 + (Math.random() * 0.001); // Even faster for demo: ~250-350m per tick

            const distLat = Number(targetPlace.latitude) - Number(sim.currentLat);
            const distLng = Number(targetPlace.longitude) - Number(sim.currentLng);
            const distance = Math.sqrt(distLat * distLat + distLng * distLng);

            // 1. DWELLING (BEKLEME)
            if (sim.dwellTicks > 0) {
                sim.dwellTicks--;
                await updateDBPosition(userId, sim.currentLat, sim.currentLng, io);
                continue;
            }

            // 2. CHECK ARRIVAL (VARDI MI?)
            if (distance < radiusInDegrees) {
                if (!sim.isInsidePlace) {
                    // ARRIVED
                    sim.isInsidePlace = true;

                    // Center the user inside the radius
                    sim.currentLat = Number(targetPlace.latitude) + (Math.random() - 0.5) * (radiusInDegrees * 0.4);
                    sim.currentLng = Number(targetPlace.longitude) + (Math.random() - 0.5) * (radiusInDegrees * 0.4);

                    const hist = await logGeofenceEvent(userId, targetPlace, 'ENTERED');
                    sim.currentHistoryId = hist?.id;
                    await notifyFollower(sim.followerId, `Arkadaşın ${targetPlace.name} konumuna girdi!`, targetPlace.name);

                    // Very short dwell for demo (0 or 1 tick)
                    sim.dwellTicks = Math.floor(Math.random() * 2);

                    await updateDBPosition(userId, sim.currentLat, sim.currentLng, io);
                } else {
                    // DWELL FINISHED -> LEAVE FOR NEXT PLACE
                    sim.isInsidePlace = false;

                    if (sim.currentHistoryId) {
                        await prisma.movementHistory.update({
                            where: { id: sim.currentHistoryId },
                            data: { leftAt: new Date() }
                        }).catch(() => { });
                        sim.currentHistoryId = null;
                    }

                    await notifyFollower(sim.followerId, `Arkadaşın ${targetPlace.name} konumundan ayrıldı.`, targetPlace.name);

                    // GO TO NEXT PLACE SEQUENTIALLY
                    sim.targetIndex = (sim.targetIndex + 1) % sim.places.length;

                    console.log(`🚀 [Simulation] ${userId} heading to ${sim.places[sim.targetIndex].name}`);
                    await moveStep(userId, sim, stepSize, io);
                }
            }
            // 3. TRAVELING (YOLDA)
            else {
                await moveStep(userId, sim, stepSize, io);
            }

        } catch (error) {
            console.error(`❌ [Simulation Error] ${userId}:`, error.message);
        }
    }
};

const moveStep = async (userId, sim, stepSize, io) => {
    try {
        const targetPlace = sim.places[sim.targetIndex];
        if (!targetPlace) return;

        const distLat = Number(targetPlace.latitude) - Number(sim.currentLat);
        const distLng = Number(targetPlace.longitude) - Number(sim.currentLng);
        const distance = Math.sqrt(distLat * distLat + distLng * distLng);

        if (distance > 0) {
            const jitter = 0.95 + (Math.random() * 0.1);
            sim.currentLat += (distLat / distance) * stepSize * jitter;
            sim.currentLng += (distLng / distance) * stepSize * jitter;
        }

        await updateDBPosition(userId, sim.currentLat, sim.currentLng, io);
    } catch (e) {
        console.error("moveStep Error:", e.message);
    }
};

const updateDBPosition = async (userId, lat, lng, io) => {
    if (isNaN(lat) || isNaN(lng)) return;

    const user = await prisma.user.update({
        where: { id: userId },
        data: {
            latitude: Number(lat),
            longitude: Number(lng),
            lastUpdated: new Date(),
            isOnline: true
        }
    });

    // Emit to socket for real-time map updates
    // In the real app, we need to find which "circles" the user is in.
    const memberships = await prisma.circleMember.findMany({ where: { userId } });
    for (const m of memberships) {
        if (io) {
            io.to(`circle-${m.circleId}`).emit('member-location', {
                userId,
                circleId: m.circleId,
                latitude: lat,
                longitude: lng,
                name: user.name,
                avatarUrl: user.avatarUrl,
                status: user.status,
                statusEmoji: user.statusEmoji
            });
        }
    }
};

const logGeofenceEvent = async (userId, place, type) => {
    const history = await prisma.movementHistory.create({
        data: {
            userId,
            placeId: place.id,
            placeName: place.name,
            address: place.address,
            latitude: place.latitude,
            longitude: place.longitude,
            emoji: place.emoji || '📍',
            arrivedAt: new Date(),
        }
    });

    // Create notification record
    await prisma.notification.create({
        data: {
            userId: userId,
            title: type === 'ENTERED' ? 'Yer Bildirimi' : 'Ayrılma Bildirimi',
            message: type === 'ENTERED' ? `${place.name} konumuna varıldı.` : `${place.name} konumundan ayrılındı.`,
            type: 'arrival',
            relatedUserId: userId
        }
    });

    return history;
};

const notifyFollower = async (followerId, message, placeName) => {
    const follower = await prisma.user.findUnique({ where: { id: followerId } });
    if (follower && follower.fcmToken) {
        await sendNotification(follower.fcmToken, {
            title: 'Geofollow Canlı Takip',
            body: message,
            data: { type: 'arrival', placeName: placeName }
        });
    }
};

module.exports = { startSimulation, runSimulationTick };
