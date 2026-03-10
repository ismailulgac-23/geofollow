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

            // Calculate step towards target
            const distLat = targetPlace.latitude - sim.currentLat;
            const distLng = targetPlace.longitude - sim.currentLng;

            // 🚀 FAST SIMULATION: Increased step size (approx 100-150 meters per 10s tick)
            const stepSize = 0.0009 + (Math.random() * 0.0004);

            const distance = Math.sqrt(distLat * distLat + distLng * distLng);

            // 🎯 IMMEDIATE TRIGGER: Trigger ENTERED as soon as entering the radius circle
            if (distance < radiusInDegrees) {
                // Destination Reached (Within Radius)!
                // Randomize exact coordinate within 50% of the radius for realism
                const angle = Math.random() * 2 * Math.PI;
                const r = Math.random() * radiusInDegrees * 0.5; // Deep inside the radius

                sim.currentLat = targetPlace.latitude + (r * Math.cos(angle));
                sim.currentLng = targetPlace.longitude + (r * Math.sin(angle));

                // 2. Log event in DB (Immediately on entry)
                await logGeofenceEvent(userId, targetPlace, 'ENTERED');

                // 3. Notify Follower via FCM (Immediately on entry)
                await notifyFollower(sim.followerId, `Arkadaşın ${targetPlace.name} konumuna girdi!`, targetPlace.name);

                // 4. Set dwell time (wait 2-4 ticks ~ 20-40 seconds - faster rotation)
                sim.dwellTicks = Math.floor(Math.random() * 3) + 2;

                // 5. Pick next target RANDOMLY (mixed movement)
                if (sim.places.length > 1) {
                    let nextIndex = sim.targetIndex;
                    while (nextIndex === sim.targetIndex) {
                        nextIndex = Math.floor(Math.random() * sim.places.length);
                    }
                    sim.targetIndex = nextIndex;
                } else {
                    sim.targetIndex = 0;
                }

                // Update DB position
                await updateDBPosition(userId, sim.currentLat, sim.currentLng, io);

                console.log(`📍 [Simulation] User ${userId} ENTERED ${targetPlace.name} radius, next target: ${sim.places[sim.targetIndex].name}`);
            } else {
                // Move one step (with slight speed jitter for realism)
                const jitter = 0.9 + (Math.random() * 0.2);
                sim.currentLat += (distLat / distance) * stepSize * jitter;
                sim.currentLng += (distLng / distance) * stepSize * jitter;

                // Update DB position
                await updateDBPosition(userId, sim.currentLat, sim.currentLng, io);
            }

        } catch (error) {
            console.error(`❌ [Simulation Error] User ${userId}:`, error);
        }
    }
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
    await prisma.movementHistory.create({
        data: {
            userId,
            placeId: place.id,
            placeName: place.name,
            latitude: place.latitude,
            longitude: place.longitude,
            arrivedAt: new Date(),
        }
    });

    // Create notification record
    await prisma.notification.create({
        data: {
            userId: userId, // This is a bit tricky, usually notification belongs to the receiver.
            title: type === 'ENTERED' ? 'Yer Bildirimi' : 'Ayrılma Bildirimi',
            message: `${place.name} konumuna varıldı.`,
            type: 'arrival',
            relatedUserId: userId
        }
    });
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
