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

    // Start slightly offset from the first place so it's not EXACTLY at distance 0
    const startLat = places[0].latitude + (Math.random() - 0.5) * 0.001;
    const startLng = places[0].longitude + (Math.random() - 0.5) * 0.001;

    activeSimulations.set(mockUserId, {
        userId: mockUserId, // Ensure userId is available inside sim object
        followerId: followerUserId,
        places: places,
        targetIndex: (places.length > 1) ? 1 : 0, // Head to the second place immediately if available
        currentLat: Number(startLat),
        currentLng: Number(startLng),
        dwellTicks: 0,
        isMoving: true,
        isInsidePlace: false,
        currentHistoryId: null
    });

    console.log(`🚀 [Simulation] Started for user ${mockUserId}, initially targeting place index ${activeSimulations.get(mockUserId).targetIndex}`);
};

/**
 * Main simulation tick - runs every few seconds
 */
const runSimulationTick = async (io) => {
    for (const [userId, sim] of activeSimulations.entries()) {
        try {
            if (!sim.isMoving) continue;

            // 1. Check if user is dwelling (waiting) at a place
            if (sim.dwellTicks > 0) {
                sim.dwellTicks--;
                // Update DB position to keep online status active and visible
                await updateDBPosition(userId, sim.currentLat, sim.currentLng, io);
                continue;
            }

            const targetPlace = sim.places[sim.targetIndex];
            if (!targetPlace) continue;

            const radiusInDegrees = (targetPlace.radius || 200) / 111000;

            // Calculate current distance to target
            const distLat = Number(targetPlace.latitude) - Number(sim.currentLat);
            const distLng = Number(targetPlace.longitude) - Number(sim.currentLng);
            const distance = Math.sqrt(distLat * distLat + distLng * distLng);

            // 🚀 FAST SIMULATION: High base speed (approx 150-250 meters per tick)
            const stepSize = 0.0015 + (Math.random() * 0.0008);

            // 🎯 ENTERED: Just entered the radius circle
            if (distance < radiusInDegrees && !sim.isInsidePlace) {
                sim.isInsidePlace = true;

                // Deep inside entry
                const angle = Math.random() * 2 * Math.PI;
                const r = Math.random() * radiusInDegrees * 0.3;
                sim.currentLat = Number(targetPlace.latitude) + (r * Math.cos(angle));
                sim.currentLng = Number(targetPlace.longitude) + (r * Math.sin(angle));

                // Log and notify
                const hist = await logGeofenceEvent(userId, targetPlace, 'ENTERED');
                sim.currentHistoryId = hist?.id;

                await notifyFollower(sim.followerId, `Arkadaşın ${targetPlace.name} konumuna girdi!`, targetPlace.name);

                // Short Dwell (1-2 ticks) for faster movement demo
                sim.dwellTicks = Math.floor(Math.random() * 2) + 1;

                console.log(`📍 [Simulation] User ${userId} arrived at ${targetPlace.name}`);
                await updateDBPosition(userId, sim.currentLat, sim.currentLng, io);
            }
            // 🎯 EXITED / PICK NEW TARGET: Was inside, dwell is over
            else if (sim.isInsidePlace && sim.dwellTicks === 0) {
                sim.isInsidePlace = false;

                // Set leftAt time
                if (sim.currentHistoryId) {
                    await prisma.movementHistory.update({
                        where: { id: sim.currentHistoryId },
                        data: { leftAt: new Date() }
                    }).catch(e => console.error("Error updating history leftAt:", e));
                    sim.currentHistoryId = null;
                }

                await notifyFollower(sim.followerId, `Arkadaşın ${targetPlace.name} konumundan ayrıldı.`, targetPlace.name);

                // Pick NEW target
                if (sim.places.length > 1) {
                    let nextIndex = sim.targetIndex;
                    while (nextIndex === sim.targetIndex) {
                        nextIndex = Math.floor(Math.random() * sim.places.length);
                    }
                    sim.targetIndex = nextIndex;
                } else {
                    sim.targetIndex = 0;
                }

                console.log(`🚀 [Simulation] User ${userId} heading to next: ${sim.places[sim.targetIndex].name}`);

                // Move one step immediately towards new target
                await moveStep(userId, sim, stepSize, io);
            }
            // 🎯 TRAVELING
            else {
                await moveStep(userId, sim, stepSize, io);
            }

        } catch (error) {
            console.error(`❌ [Simulation Error] User ${userId}:`, error.message);
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
            const jitter = 0.9 + (Math.random() * 0.2);
            sim.currentLat += (distLat / distance) * stepSize * jitter;
            sim.currentLng += (distLng / distance) * stepSize * jitter;
        }

        await updateDBPosition(userId, sim.currentLat, sim.currentLng, io);
    } catch (e) {
        console.error("Error in moveStep:", e.message);
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
