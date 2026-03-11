const prisma = require('../config/database');
const { sendNotification } = require('../utils/firebase');
const { createNewMovement } = require('./movementTracker');

// In-memory simulation state
// { userId: { targetIndex, currentLat, currentLng, pathPoints, isMoving } }
const activeSimulations = new Map();

/**
 * Starts or updates a simulation for a mock user.
 * It will make the user move between a list of places.
 */
const startSimulation = async (mockUserId, followerUserId, places, io) => {
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

    // ⚡ INSTANT FIRST UPDATE: Force a position update so UI sees it immediately
    if (io) {
        await updateDBPosition(mockUserId, Number(startLat), Number(startLng), io);
    }
};

/**
 * Main simulation tick - runs every 3 seconds (set in index.js)
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
            // Sakin hareket: saniyede ~5-15 metre ilerleme (Yürüyüş / Yavaş Sürüş)
            const stepSize = 0.0001 + (Math.random() * 0.00005);

            const distLat = Number(targetPlace.latitude) - Number(sim.currentLat);
            const distLng = Number(targetPlace.longitude) - Number(sim.currentLng);
            const distance = Math.sqrt(distLat * distLat + distLng * distLng);

            // 1. DWELLING
            if (sim.dwellTicks > 0) {
                sim.dwellTicks--;
                await updateDBPosition(userId, sim.currentLat, sim.currentLng, io);
                continue;
            }

            // 2. CHECK ARRIVAL
            if (distance < radiusInDegrees) {
                if (!sim.isInsidePlace) {
                    sim.isInsidePlace = true;
                    sim.currentLat = Number(targetPlace.latitude) + (Math.random() - 0.5) * (radiusInDegrees * 0.4);
                    sim.currentLng = Number(targetPlace.longitude) + (Math.random() - 0.5) * (radiusInDegrees * 0.4);

                    const hist = await createNewMovement(userId, targetPlace, targetPlace.address, new Date());
                    sim.currentHistoryId = hist?.id;

                    await notifyFollower(sim.followerId, `Arkadaşın ${targetPlace.name} konumuna girdi!`, targetPlace.name);

                    sim.dwellTicks = Math.floor(Math.random() * 2);
                    await updateDBPosition(userId, sim.currentLat, sim.currentLng, io);
                } else {
                    sim.isInsidePlace = false;
                    if (sim.currentHistoryId) {
                        await prisma.movementHistory.update({
                            where: { id: sim.currentHistoryId },
                            data: { leftAt: new Date() }
                        }).catch(() => { });
                        sim.currentHistoryId = null;
                    }
                    await notifyFollower(sim.followerId, `Arkadaşın ${targetPlace.name} konumundan ayrıldı.`, targetPlace.name);

                    sim.targetIndex = (sim.targetIndex + 1) % sim.places.length;
                    await moveStep(userId, sim, stepSize, io);
                }
            }
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

        if (distance <= stepSize) {
            sim.currentLat = Number(targetPlace.latitude);
            sim.currentLng = Number(targetPlace.longitude);
        } else if (distance > 0) {
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

    try {
        const user = await prisma.user.update({
            where: { id: userId },
            data: {
                latitude: Number(lat),
                longitude: Number(lng),
                lastUpdated: new Date(),
                isOnline: true
            }
        });

        // Broadcast to all circles the user is in
        const memberships = await prisma.circleMember.findMany({ where: { userId } });
        for (const m of memberships) {
            if (io) {
                io.to(`circle-${m.circleId}`).emit('member-location', {
                    userId,
                    circleId: m.circleId,
                    latitude: Number(lat),
                    longitude: Number(lng),
                    name: user.name,
                    avatarUrl: user.avatarUrl,
                    status: user.status,
                    statusEmoji: user.statusEmoji,
                    batteryLevel: user.batteryLevel,
                    isOnline: true,
                    lastUpdated: new Date().toISOString()
                });
            }
        }
    } catch (e) {
        console.error("updateDBPosition Error:", e.message);
    }
};

const notifyFollower = async (followerId, message, placeName) => {
    try {
        const follower = await prisma.user.findUnique({ where: { id: followerId } });
        if (follower && follower.fcmToken) {
            await sendNotification(follower.fcmToken, {
                title: 'Geofollow Canlı Takip',
                body: message,
                data: { type: 'arrival', placeName: placeName }
            });
        }
    } catch (e) {
        console.error("notifyFollower Error:", e.message);
    }
};

const isSimulationRunning = (userId) => {
    return activeSimulations.has(userId);
};

module.exports = { startSimulation, runSimulationTick, isSimulationRunning };
