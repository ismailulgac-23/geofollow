const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const prisma = require('../config/database');
const { startSimulation, isSimulationRunning } = require('../utils/simulation');

// Helper function to generate JWT
const generateToken = (userId) => {
  return jwt.sign(
    { userId },
    process.env.JWT_SECRET || 'your-secret-key',
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
};

// Helper function to format user response
const formatUserResponse = (user) => ({
  id: user.id,
  email: user.email,
  name: user.name,
  avatarUrl: user.avatarUrl,
  status: user.status,
  statusEmoji: user.statusEmoji,
  batteryLevel: user.batteryLevel,
  isOnline: user.isOnline,
  latitude: user.latitude,
  longitude: user.longitude,
  address: user.address
});


// ----------------------------------------------------------------------
// HELPER: Auto-Setup Apple Review Simulation & Mocks
// ----------------------------------------------------------------------
const setupAppleReviewSimulation = async (user, io) => {
  try {
    const bcrypt = require('bcryptjs');
    const hashPass = await bcrypt.hash('ReviewPass2026', 10);

    const reviewer2 = await prisma.user.upsert({
      where: { email: 'apple_review_2@geofollow.xyz' },
      update: { isOnline: true },
      create: {
        id: 'apple-reviewer-2',
        email: 'apple_review_2@geofollow.xyz',
        name: 'Review Test Partner',
        password: hashPass,
        provider: 'email',
        avatarUrl: 'https://i.pravatar.cc/150?u=apple2',
        status: 'Hareket Halinde',
        batteryLevel: 85,
        isOnline: true,
        latitude: 41.0082,
        longitude: 28.9784,
        isPremium: true
      }
    });

    const reviewCircle = await prisma.circle.upsert({
      where: { id: 'circle-apple-review' },
      update: {},
      create: {
        id: 'circle-apple-review',
        name: 'Review Family',
        inviteCode: 'APPLE-TEST-00',
        emoji: '👨‍👩‍👧‍👦',
        color: '#4ADE80'
      }
    });

    await prisma.circleMember.upsert({
      where: { circleId_userId: { circleId: reviewCircle.id, userId: reviewer2.id } },
      update: {},
      create: { circleId: reviewCircle.id, userId: reviewer2.id, role: 'member' }
    });
    await prisma.circleMember.upsert({
      where: { circleId_userId: { circleId: reviewCircle.id, userId: user.id } },
      update: {},
      create: { circleId: reviewCircle.id, userId: user.id, role: 'admin' }
    });

    if (reviewer2 && reviewCircle) {
      await prisma.movementHistory.deleteMany({ where: { userId: reviewer2.id } });
      await prisma.place.deleteMany({ where: { circleId: reviewCircle.id } });

      const mockPlacesData = [
        { name: 'Reviewer Home', lat: 41.0082 + 0.002, lng: 28.9784 + 0.002, emoji: '🏠' },
        { name: 'Reviewer Office', lat: 41.0082 - 0.008, lng: 28.9784 + 0.006, emoji: '🏢' },
        { name: 'Reviewer Gym', lat: 41.0082 - 0.005, lng: 28.9784 - 0.010, emoji: '💪' },
        { name: 'Reviewer Cafe', lat: 41.0082 + 0.007, lng: 28.9784 - 0.008, emoji: '☕' }
      ];

      const createdPlaces = [];
      for (const p of mockPlacesData) {
        const place = await prisma.place.create({
          data: {
            name: p.name,
            latitude: p.lat,
            longitude: p.lng,
            radius: 120 + Math.random() * 200,
            emoji: p.emoji,
            circleId: reviewCircle.id,
            createdById: user.id
          }
        });
        createdPlaces.push(place);
        await prisma.placeMember.upsert({
          where: { placeId_userId: { placeId: place.id, userId: reviewer2.id } },
          update: {},
          create: { placeId: place.id, userId: reviewer2.id }
        });
      }

      await prisma.user.update({
        where: { id: reviewer2.id },
        data: {
          latitude: createdPlaces[0].latitude,
          longitude: createdPlaces[0].longitude,
          status: 'Yolda',
          statusEmoji: '🚗',
          lastUpdated: new Date()
        }
      });

      startSimulation(reviewer2.id, user.id, createdPlaces, io);
      console.log(`🍎 [Apple Review] Simulation started for ${reviewer2.id}`);
    }
  } catch (err) {
    console.error("Apple Review setup error:", err);
  }
};
// ----------------------------------------------------------------------

// POST /auth/login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const loginEmail = email || 'demo@demo.com';

    const [user, testModeSetting] = await Promise.all([
      prisma.user.findUnique({
        where: { email: loginEmail },
        include: {
          circles: {
            include: {
              circle: {
                include: {
                  members: {
                    include: { user: true }
                  }
                }
              }
            }
          }
        }
      }),
      prisma.systemSetting.findUnique({ where: { key: 'testMode' } })
    ]);

    if (!user) {
      return res.status(404).json({
        success: false,
        code: 'USER_NOT_FOUND'
      });
    }

    // Password check for review accounts (if password is provided)
    if (password && user.password) {
      const bcrypt = require('bcryptjs');
      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch) {
        return res.status(401).json({
          success: false,
          code: 'INVALID_CREDENTIALS'
        });
      }
    }

    await prisma.user.update({
      where: { id: user.id },
      data: { isOnline: true, isPremium: true, lastUpdated: new Date() }
    });

    const token = generateToken(user.id);
    let testMode = testModeSetting?.value === '1';

    // Force testMode for Apple Reviewer
    if (loginEmail === 'apple_review_1@geofollow.xyz') {
      testMode = true;
    }

    // Proximity Simulation for Apple Review (Hyper-Realistic Mode)
    if (testMode && loginEmail === 'apple_review_1@geofollow.xyz') {
      await setupAppleReviewSimulation(user, req.io);
      console.log(`🍎 [Apple Review] Simulation started for apple_review_2 (during Login)`);
    }

    res.json({
      success: true,
      code: 'LOGIN_SUCCESS',
      data: {
        user: formatUserResponse(user),
        token,
        testMode
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

// POST /auth/register
router.post('/register', async (req, res) => {
  try {
    const { email, name, avatarUrl, provider, providerId } = req.body;

    const existingUser = await prisma.user.findUnique({ where: { email } });

    if (existingUser) {
      // If user exists, update name if provided and return success with token
      const user = await prisma.user.update({
        where: { id: existingUser.id },
        data: {
          name: name || existingUser.name,
          avatarUrl: avatarUrl || existingUser.avatarUrl,
          lastUpdated: new Date()
        }
      });
      const token = generateToken(user.id);
      if (existingUser.email === 'apple_review_1@geofollow.xyz') {
        await setupAppleReviewSimulation(user, req.io);
      }

      return res.json({
        success: true,
        code: 'UPDATED',
        data: { user: formatUserResponse(user), token }
      });
    }

    const user = await prisma.user.create({
      data: {
        email,
        name: name || email.split('@')[0],
        avatarUrl: avatarUrl || '',
        provider: provider || 'email',
        providerId: providerId || '',
        status: 'Online',
        batteryLevel: 100,
        isOnline: true,
        isPremium: true,
        lastUpdated: new Date()
      }
    });

    const token = generateToken(user.id);

    if (email === 'apple_review_1@geofollow.xyz') {
      await setupAppleReviewSimulation(user, req.io);
    }

    res.status(201).json({
      success: true,
      code: 'REGISTERED',
      data: { user: formatUserResponse(user), token }
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

// GET /auth/me
router.get('/me', async (req, res) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');

    if (!token) {
      return res.status(401).json({ success: false, code: 'NO_TOKEN_PROVIDED' });
    }

    let decoded;
    try {
      decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key');
    } catch (err) {
      return res.status(401).json({ success: false, code: 'INVALID_OR_EXPIRED_TOKEN' });
    }

    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      select: {
        id: true,
        email: true,
        name: true,
        avatarUrl: true,
        status: true,
        statusEmoji: true,
        batteryLevel: true,
        isOnline: true,
        isPremium: true,
        latitude: true,
        longitude: true,
        address: true,
        lastUpdated: true,
        createdAt: true
      }
    });

    if (!user) {
      return res.status(401).json({ success: false, code: 'USER_NOT_FOUND' });
    }

    // Special Trigger for Reviewer to start simulation if not active
    if (user.email === 'apple_review_1@geofollow.xyz') {
      const reviewer2 = await prisma.user.findUnique({ where: { email: 'apple_review_2@geofollow.xyz' } });
      const reviewCircle = await prisma.circle.findUnique({ where: { id: 'circle-apple-review' } });
      const places = await prisma.place.findMany({ where: { circleId: 'circle-apple-review' } });

      if (reviewer2 && places.length > 0) {
        if (!isSimulationRunning(reviewer2.id)) {
          startSimulation(reviewer2.id, user.id, places, req.io);
          console.log(`🍎 [Apple Review] Simulation auto-started for ${reviewer2.id} (during GetMe)`);
        }
      } else {
        await setupAppleReviewSimulation(user, req.io);
      }
    }

    res.json({ success: true, code: 'SUCCESS', data: user });
  } catch (error) {
    console.error('Get me error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

// POST /auth/logout
router.post('/logout', async (req, res) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');

    if (token) {
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key');
        await prisma.user.update({
          where: { id: decoded.userId },
          data: { isOnline: false, lastUpdated: new Date() }
        });
      } catch (err) {
        // Token invalid, still return success
      }
    }

    res.json({ success: true, code: 'LOGGED_OUT' });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

module.exports = router;