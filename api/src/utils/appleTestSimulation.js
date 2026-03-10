const prisma = require('../config/database');
const { createNewMovement } = require('./movementTracker');

// In-memory state for bot simulations
const activeBotSimulations = new Map();

/**
 * Completely autonomous "SQUAD SIMULATION" for App Store Review.
 * Spawns 5 bots and 5 places around the tester.
 */
const prepareAppleTestSimulations = async (appleUserId, actualLat, actualLng, io) => {
    try {
        console.log(`🍎 [Apple Review] Starting ZERO SQUAD build... (Tester: ${appleUserId})`);

        // 1. Base coordinates
        const baseLat = actualLat || 41.0082;
        const baseLng = actualLng || 28.9784;

        // 2. Clear ALL previous review data to ensure "ZERO" state
        await prisma.circle.deleteMany({ where: { id: 'circle-apple-review' } });
        // Prisma cascade deletes should handle members and places if schema is set,
        // but let's be explicit for safety.
        await prisma.place.deleteMany({ where: { circleId: 'circle-apple-review' } });

        const reviewBotIds = ['apple_bot_1', 'apple_bot_2', 'apple_bot_3', 'apple_bot_4', 'apple_bot_5'];
        await prisma.movementHistory.deleteMany({ where: { userId: { in: reviewBotIds } } });
        await prisma.locationSnapshot.deleteMany({ where: { userId: { in: reviewBotIds } } });

        // 3. Re-create the Circle
        const reviewCircle = await prisma.circle.create({
            data: {
                id: 'circle-apple-review',
                name: 'Apple Review Squad',
                inviteCode: 'TEST-SIM-000',
                emoji: '🛡️',
                color: '#6C5CE7'
            }
        });

        // 4. Add the Tester
        await prisma.circleMember.create({
            data: { circleId: reviewCircle.id, userId: appleUserId, role: 'admin' }
        });

        // 5. Create 5 Specialized Bots
        const mockBots = [
            { id: 'apple_bot_1', name: 'James Wilson', emoji: '🧑‍💼', avatar: 'https://i.pravatar.cc/150?u=1', off: 0.004, speed: 1.2 },
            { id: 'apple_bot_2', name: 'Sophia Miller', emoji: '👩‍⚕️', avatar: 'https://i.pravatar.cc/150?u=2', off: -0.003, speed: 0.8 },
            { id: 'apple_bot_3', name: 'Jackson Lee', emoji: '🧑‍🎨', avatar: 'https://i.pravatar.cc/150?u=3', off: 0.005, speed: 1.5 },
            { id: 'apple_bot_4', name: 'Olivia Brown', emoji: '👩‍🏫', avatar: 'https://i.pravatar.cc/150?u=4', off: -0.005, speed: 1.0 },
            { id: 'apple_bot_5', name: 'Liam Davis', emoji: '🧑‍🚒', avatar: 'https://i.pravatar.cc/150?u=5', off: 0.002, speed: 1.3 }
        ];

        for (let bot of mockBots) {
            await prisma.user.upsert({
                where: { id: bot.id },
                update: {
                    latitude: baseLat + bot.off,
                    longitude: baseLng + (bot.off * 0.5),
                    isOnline: true,
                    status: "Exploring",
                    statusEmoji: bot.emoji,
                    lastUpdated: new Date()
                },
                create: {
                    id: bot.id,
                    email: `${bot.id}@geofollow.test`,
                    name: bot.name,
                    password: 'bot-password-2026',
                    avatarUrl: bot.avatar,
                    status: "Exploring",
                    statusEmoji: bot.emoji,
                    batteryLevel: 60 + Math.floor(Math.random() * 30),
                    isOnline: true,
                    latitude: baseLat + bot.off,
                    longitude: baseLng + (bot.off * 0.5),
                    isPremium: true
                }
            });

            await prisma.circleMember.create({
                data: { circleId: reviewCircle.id, userId: bot.id, role: 'member' }
            });
        }

        // 6. Create 5 Target Places
        const placeConfigs = [
            { name: 'Reviewer Office', latOff: 0.005, lngOff: 0.002, emoji: '🏢' },
            { name: 'City Central Park', latOff: -0.006, lngOff: 0.004, emoji: '🌳' },
            { name: 'Fitness Hub', latOff: 0.002, lngOff: -0.004, emoji: '💪' },
            { name: 'Harbor View Cafe', latOff: -0.003, lngOff: -0.003, emoji: '☕' },
            { name: 'Shopping Plaza', latOff: 0.004, lngOff: -0.005, emoji: '🛍️' }
        ];

        const createdPlaces = [];
        for (let pc of placeConfigs) {
            const place = await prisma.place.create({
                data: {
                    name: pc.name,
                    latitude: baseLat + pc.latOff,
                    longitude: baseLng + pc.lngOff,
                    radius: 250,
                    emoji: pc.emoji,
                    circleId: reviewCircle.id,
                    createdById: appleUserId
                }
            });
            createdPlaces.push(place);

            // Add all bots to place members
            for (let botId of reviewBotIds) {
                await prisma.placeMember.create({
                    data: { placeId: place.id, userId: botId }
                });
            }
        }

        // 7. Inject into loop data
        for (let bot of mockBots) {
            const botPlaces = [...createdPlaces].sort(() => 0.5 - Math.random());
            activeBotSimulations.set(bot.id, {
                botId: bot.id,
                name: bot.name,
                currentLat: baseLat + bot.off,
                currentLng: baseLng + (bot.off * 0.5),
                places: botPlaces,
                targetIndex: 0,
                isInsidePlace: false,
                currentHistoryId: null,
                dwellTicks: 0,
                speedMult: bot.speed
            });
        }

        // 8. Start global loop if not alive
        if (!global.isAppleSimLoopRunning) {
            global.isAppleSimLoopRunning = true;
            setInterval(() => runAppleBotTick(io, appleUserId), 2500);
            console.log(`🍎 [Apple Review] Global Bot Ticker is now LIVE.`);
        }

    } catch (err) {
        console.error("🍎 [Apple Review Setup Failed]", err);
    }
};

const runAppleBotTick = async (io, testUserId) => {
    for (const [botId, sim] of activeBotSimulations.entries()) {
        try {
            if (sim.dwellTicks > 0) {
                sim.dwellTicks--;
                broadcastBot(botId, sim, io);
                continue;
            }

            const targetP = sim.places[sim.targetIndex];
            const radiusInDeg = 250 / 111320;
            const step = (0.0006 + (Math.random() * 0.0003)) * sim.speedMult;

            const dLat = targetP.latitude - sim.currentLat;
            const dLng = targetP.longitude - sim.currentLng;
            const dist = Math.sqrt(dLat * dLat + dLng * dLng);

            if (dist <= radiusInDeg) {
                if (!sim.isInsidePlace) {
                    sim.isInsidePlace = true;
                    // Log Arrival
                    const hist = await createNewMovement(botId, targetP, 'Test Sector', new Date());
                    sim.currentHistoryId = hist?.id;
                    sim.dwellTicks = 4 + Math.floor(Math.random() * 6);
                } else {
                    sim.isInsidePlace = false;
                    // Log Departure
                    if (sim.currentHistoryId) {
                        await prisma.movementHistory.update({
                            where: { id: sim.currentHistoryId },
                            data: { leftAt: new Date() }
                        }).catch(() => { });
                        sim.currentHistoryId = null;
                    }
                    sim.targetIndex = (sim.targetIndex + 1) % sim.places.length;
                    moveStep(sim, step);
                }
            } else {
                moveStep(sim, step);
            }

            broadcastBot(botId, sim, io);

        } catch (e) {
            // silent fail for individual bots
        }
    }
};

const moveStep = (sim, step) => {
    const target = sim.places[sim.targetIndex];
    const dLat = target.latitude - sim.currentLat;
    const dLng = target.longitude - sim.currentLng;
    const dist = Math.sqrt(dLat * dLat + dLng * dLng);

    if (dist <= step) {
        sim.currentLat = target.latitude;
        sim.currentLng = target.longitude;
    } else {
        const ratio = step / dist;
        sim.currentLat += dLat * ratio;
        sim.currentLng += dLng * ratio;
    }
};

const broadcastBot = async (botId, sim, io) => {
    if (io) {
        io.to('circle-apple-review').emit('member-location', {
            userId: botId,
            circleId: 'circle-apple-review',
            latitude: sim.currentLat,
            longitude: sim.currentLng,
            name: sim.name,
            isOnline: true,
            status: sim.isInsidePlace ? 'At Location' : 'On the move',
            lastUpdated: new Date().toISOString()
        });
    }
    // Update DB semi-frequently
    if (Math.random() > 0.7) {
        await prisma.user.update({
            where: { id: botId },
            data: { latitude: sim.currentLat, longitude: sim.currentLng, lastUpdated: new Date() }
        }).catch(() => { });
    }
};

module.exports = { prepareAppleTestSimulations };
