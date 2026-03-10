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
    if (places.length === 0) return;

    activeSimulations.set(mockUserId, {
        followerId: followerUserId,
        places: places,
        targetIndex: 0,
        currentLat: places[0].latitude,
        currentLng: places[0].longitude,
        dwellTicks: 0,
        isMoving: true,
    });

    console.log(`🚀 [Simulation] Started for user ${mockUserId}, following ${followerUserId}`);

    // Start the tick loop if not already running (or it's fine to just let it run globally)
};

/**
 * Main simulation tick - runs every few seconds
 */
const runSimulationTick = async (io) => {
    for (const [userId, sim] of activeSimulations.entries()) {
        try {
            // 1. Check if user is dwelling (waiting) at a place
            if (sim.dwellTicks > 0) {
                sim.dwellTicks--;
                // Update DB position to keep online status active
                await updateDBPosition(userId, sim.currentLat, sim.currentLng, io);
                continue;
            }

            const targetPlace = sim.places[sim.targetIndex];
            const radiusInDegrees = (targetPlace.radius || 200) / 111000;

            // Calculate current distance to target
            const distLat = targetPlace.latitude - sim.currentLat;
            const distLng = targetPlace.longitude - sim.currentLng;
            const distance = Math.sqrt(distLat * distLat + distLng * distLng);

            // 🚀 ULTRA FAST SIMULATION: High base speed (approx 150-200 meters per tick)
            const stepSize = 0.0012 + (Math.random() * 0.0006);

            // 🎯 ENTERED: Just entered the radius circle
            if (distance < radiusInDegrees && !sim.isInsidePlace) {
                // destination arrived, mark inside
                sim.isInsidePlace = true;

                // Randomize exact coordinate within 40% of the radius for realism
                const angle = Math.random() * 2 * Math.PI;
                const r = Math.random() * radiusInDegrees * 0.4;
                sim.currentLat = targetPlace.latitude + (r * Math.cos(angle));
                sim.currentLng = targetPlace.longitude + (r * Math.sin(angle));

                // 2. Log event in DB (Immediately on entry)
                const hist = await logGeofenceEvent(userId, targetPlace, 'ENTERED');
                sim.currentHistoryId = hist.id; // Track this to set leftAt later

                // 3. Notify Follower
                await notifyFollower(sim.followerId, `Arkadaşın ${targetPlace.name} konumuna girdi!`, targetPlace.name);

                // 4. Set dwell time (wait 2-4 ticks - fast rotation)
                sim.dwellTicks = Math.floor(Math.random() * 3) + 2;

                console.log(`📍 [Simulation] User ${userId} ENTERED ${targetPlace.name}. Next movement after dwell.`);

                await updateDBPosition(userId, sim.currentLat, sim.currentLng, io);
            }
            // 🎯 ALREADY INSIDE, NEED TO PICK NEXT TARGET AFTER DWELL
            else if (distance < radiusInDegrees && sim.isInsidePlace && sim.dwellTicks === 0) {
                // Dwell finished, leave current target
                sim.isInsidePlace = false;

                // Update history with leftAt
                if (sim.currentHistoryId) {
                    await prisma.movementHistory.update({
                        where: { id: sim.currentHistoryId },
                        data: { leftAt: new Date() }
                    });
                    sim.currentHistoryId = null;
                }

                // Log EXIT and notify
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

                console.log(`🚀 [Simulation] User ${userId} LEFT ${targetPlace.name}, heading to ${sim.places[sim.targetIndex].name}`);

                // Move one step immediately towards new target
                await moveStep(userId, sim, stepSize, io);
            }
            // 🎯 TRAVELING: Far from target radius
            else {
                await moveStep(userId, sim, stepSize, io);
            }

        } catch (error) {
            console.error(`❌ [Simulation Error] User ${userId}:`, error);
        }
    }
};

const moveStep = async (userId, sim, stepSize, io) => {
    const targetPlace = sim.places[sim.targetIndex];
    const distLat = targetPlace.latitude - sim.currentLat;
    const distLng = targetPlace.longitude - sim.currentLng;
    const distance = Math.sqrt(distLat * distLat + distLng * distLng);

    if (distance > 0) {
        const jitter = 0.95 + (Math.random() * 0.1);
        sim.currentLat += (distLat / distance) * stepSize * jitter;
        sim.currentLng += (distLng / distance) * stepSize * jitter;
    }

    await updateDBPosition(userId, sim.currentLat, sim.currentLng, io);
};

const updateDBPosition = async (userId, lat, lng, io) => {
    const user = await prisma.user.update({
        where: { id: userId },
        data: {
            latitude: lat,
            longitude: lng,
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
