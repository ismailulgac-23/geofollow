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
            const targetPlace = sim.places[sim.targetIndex];

            // Calculate step towards target
            const distLat = targetPlace.latitude - sim.currentLat;
            const distLng = targetPlace.longitude - sim.currentLng;
            const stepSize = 0.0003; // ~30 meters per tick

            const distance = Math.sqrt(distLat * distLat + distLng * distLng);

            if (distance < stepSize) {
                // Destination Reached!
                sim.currentLat = targetPlace.latitude;
                sim.currentLng = targetPlace.longitude;

                // 1. Log event in DB
                await logGeofenceEvent(userId, targetPlace, 'ENTERED');

                // 2. Notify Follower via FCM
                await notifyFollower(sim.followerId, `Arkadaşın ${targetPlace.name} konumuna vardı!`, targetPlace.name);

                // 3. Pick next target after a small wait
                sim.targetIndex = (sim.targetIndex + 1) % sim.places.length;

                // Update DB position
                await updateDBPosition(userId, sim.currentLat, sim.currentLng, io);

                console.log(`📍 [Simulation] User ${userId} reached ${targetPlace.name}`);
            } else {
                // Move one step
                sim.currentLat += (distLat / distance) * stepSize;
                sim.currentLng += (distLng / distance) * stepSize;

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
