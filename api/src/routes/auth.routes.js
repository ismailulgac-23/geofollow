const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const prisma = require('../config/database');

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
    const testMode = testModeSetting?.value === '1';

    // Proximity Simulation for Apple Review
    if (testMode && loginEmail === 'apple_review_1@geofollow.xyz') {
      const { lat, lng } = req.body; // Frontend can send initial lat/lng
      if (lat && lng) {
        await prisma.user.update({
          where: { email: 'apple_review_2@geofollow.xyz' },
          data: {
            latitude: lat + 0.002,
            longitude: lng + 0.002,
            lastUpdated: new Date()
          }
        });
      }
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
      return res.status(400).json({ success: false, code: 'USER_ALREADY_EXISTS' });
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