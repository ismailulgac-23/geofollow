const express = require('express');
const router = express.Router();
const prisma = require('../config/database');
const auth = require('../middleware/auth');

router.get('/circle/:circleId', auth, async (req, res) => {
  try {
    const { circleId } = req.params;

    const membership = await prisma.circleMember.findUnique({
      where: { circleId_userId: { circleId, userId: req.userId } }
    });

    if (!membership) {
      return res.status(403).json({ success: false, code: 'NOT_A_MEMBER' });
    }

    const places = await prisma.place.findMany({
      where: { circleId },
      include: {
        members: {
          include: { user: { select: { id: true, name: true, avatarUrl: true } } }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    const formattedPlaces = places.map(place => ({
      id: place.id, name: place.name, address: place.address,
      location: { latitude: place.latitude, longitude: place.longitude },
      radius: place.radius, emoji: place.emoji, isActive: place.isActive,
      members: place.members.map(m => m.user)
    }));

    res.json({ success: true, code: 'SUCCESS', data: formattedPlaces });
  } catch (error) {
    console.error('Get places error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.get('/:id', auth, async (req, res) => {
  try {
    const { id } = req.params;

    const place = await prisma.place.findUnique({
      where: { id },
      include: {
        members: {
          include: {
            user: { select: { id: true, name: true, avatarUrl: true, isOnline: true, isPremium: true } }
          }
        }
      }
    });

    if (!place) {
      return res.status(404).json({ success: false, code: 'PLACE_NOT_FOUND' });
    }

    const membership = await prisma.circleMember.findUnique({
      where: { circleId_userId: { circleId: place.circleId, userId: req.userId } }
    });

    if (!membership) {
      return res.status(403).json({ success: false, code: 'NOT_AUTHORIZED' });
    }

    res.json({ success: true, code: 'SUCCESS', data: place });
  } catch (error) {
    console.error('Get place error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.post('/', auth, async (req, res) => {
  try {
    const { name, address, latitude, longitude, radius, emoji, circleId, memberIds } = req.body;

    if (!name || !latitude || !longitude || !circleId) {
      return res.status(400).json({ success: false, code: 'MISSING_REQUIRED_FIELDS' });
    }

    const membership = await prisma.circleMember.findUnique({
      where: { circleId_userId: { circleId, userId: req.userId } }
    });

    if (!membership) {
      return res.status(403).json({ success: false, code: 'NOT_A_MEMBER' });
    }

    const place = await prisma.place.create({
      data: {
        name, address, latitude, longitude,
        radius: radius || 150,
        emoji: emoji || '📍',
        circleId,
        createdById: req.userId,
        members: memberIds && memberIds.length > 0 ? {
          create: memberIds.map(userId => ({ userId }))
        } : undefined
      },
      include: { members: true }
    });

    if (memberIds && memberIds.length > 0) {
      await prisma.notification.createMany({
        data: memberIds.map(userId => ({
          title: 'place_added',
          message: name,
          type: 'place',
          userId
        }))
      });
    }

    res.status(201).json({ success: true, code: 'PLACE_CREATED', data: place });
  } catch (error) {
    console.error('Create place error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.put('/:id', auth, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, address, latitude, longitude, radius, emoji, isActive } = req.body;

    const existingPlace = await prisma.place.findUnique({ where: { id } });
    if (!existingPlace) {
      return res.status(404).json({ success: false, code: 'PLACE_NOT_FOUND' });
    }

    const membership = await prisma.circleMember.findUnique({
      where: { circleId_userId: { circleId: existingPlace.circleId, userId: req.userId } }
    });

    if (!membership) {
      return res.status(403).json({ success: false, code: 'NOT_AUTHORIZED' });
    }

    const place = await prisma.place.update({
      where: { id },
      data: { name, address, latitude, longitude, radius, emoji, isActive }
    });

    res.json({ success: true, code: 'PLACE_UPDATED', data: place });
  } catch (error) {
    console.error('Update place error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.delete('/:id', auth, async (req, res) => {
  try {
    const { id } = req.params;

    const place = await prisma.place.findUnique({ where: { id } });
    if (!place) {
      return res.status(404).json({ success: false, code: 'PLACE_NOT_FOUND' });
    }

    const membership = await prisma.circleMember.findUnique({
      where: { circleId_userId: { circleId: place.circleId, userId: req.userId } }
    });

    if (!membership || (membership.role !== 'admin' && place.createdById !== req.userId)) {
      return res.status(403).json({ success: false, code: 'NOT_AUTHORIZED' });
    }

    await prisma.place.delete({ where: { id } });
    res.json({ success: true, code: 'PLACE_DELETED' });
  } catch (error) {
    console.error('Delete place error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.post('/:id/members', auth, async (req, res) => {
  try {
    const { id } = req.params;
    const { userId } = req.body;

    const place = await prisma.place.findUnique({ where: { id } });
    if (!place) {
      return res.status(404).json({ success: false, code: 'PLACE_NOT_FOUND' });
    }

    const existingMember = await prisma.placeMember.findUnique({
      where: { placeId_userId: { placeId: id, userId } }
    });

    if (existingMember) {
      return res.status(400).json({ success: false, code: 'ALREADY_A_MEMBER' });
    }

    const placeMember = await prisma.placeMember.create({ data: { placeId: id, userId } });

    await prisma.notification.create({
      data: { title: 'place_added', message: place.name, type: 'place', userId }
    });

    res.status(201).json({ success: true, code: 'MEMBER_ADDED', data: placeMember });
  } catch (error) {
    console.error('Add member error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.delete('/:id/members/:userId', auth, async (req, res) => {
  try {
    const { id, userId } = req.params;

    await prisma.placeMember.delete({
      where: { placeId_userId: { placeId: id, userId } }
    });

    res.json({ success: true, code: 'MEMBER_REMOVED' });
  } catch (error) {
    console.error('Remove member error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

module.exports = router;