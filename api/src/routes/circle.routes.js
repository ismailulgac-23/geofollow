const express = require('express');
const router = express.Router();
const prisma = require('../config/database');
const auth = require('../middleware/auth');

const generateInviteCode = () => {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
};

router.get('/', auth, async (req, res) => {
  try {
    const memberships = await prisma.circleMember.findMany({
      where: { userId: req.userId },
      include: {
        circle: {
          include: {
            members: {
              include: {
                user: {
                  select: {
                    id: true, name: true, avatarUrl: true, isOnline: true,
                    isPremium: true, status: true, statusEmoji: true,
                    batteryLevel: true, latitude: true, longitude: true,
                    address: true, lastUpdated: true
                  }
                }
              }
            },
            places: true
          }
        }
      }
    });

    const circles = memberships.map(m => ({
      id: m.circle.id,
      name: m.circle.name,
      emoji: m.circle.emoji,
      color: m.circle.color,
      inviteCode: m.circle.inviteCode,
      members: m.circle.members.map(mem => ({
        id: mem.user.id, name: mem.user.name, avatarUrl: mem.user.avatarUrl,
        isOnline: mem.user.isOnline, status: mem.user.status,
        statusEmoji: mem.user.statusEmoji, batteryLevel: mem.user.batteryLevel,
        latitude: mem.user.latitude, longitude: mem.user.longitude,
        address: mem.user.address, lastUpdated: mem.user.lastUpdated
      })),
      places: m.circle.places || [],
      memberCount: m.circle.members.length,
      role: m.role
    }));

    const responseCircle = circles.length > 0 ? circles[0] : null;
    res.json({ success: true, code: 'SUCCESS', data: responseCircle });
  } catch (error) {
    console.error('Get circles error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.get('/:id', auth, async (req, res) => {
  try {
    const { id } = req.params;
    const circle = await prisma.circle.findUnique({
      where: { id },
      include: {
        members: {
          include: {
            user: {
              select: {
                id: true, name: true, avatarUrl: true, status: true,
                statusEmoji: true, batteryLevel: true, isOnline: true,
                isPremium: true, latitude: true, longitude: true,
                address: true, lastUpdated: true
              }
            }
          }
        }
      }
    });

    if (!circle) {
      return res.status(404).json({ success: false, code: 'CIRCLE_NOT_FOUND' });
    }

    const isMember = circle.members.some(m => m.userId === req.userId);
    if (!isMember) {
      return res.status(403).json({ success: false, code: 'NOT_A_MEMBER' });
    }

    res.json({ success: true, code: 'SUCCESS', data: circle });
  } catch (error) {
    console.error('Get circle error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.post('/', auth, async (req, res) => {
  try {
    const { name, emoji, color } = req.body;

    if (!name) {
      return res.status(400).json({ success: false, code: 'NAME_REQUIRED' });
    }

    const circle = await prisma.circle.create({
      data: {
        name,
        emoji: emoji || '👨‍👩‍👧‍👦',
        color: color || '#6C5CE7',
        inviteCode: generateInviteCode(),
        members: { create: { userId: req.userId, role: 'admin' } }
      },
      include: { members: true }
    });

    res.status(201).json({ success: true, code: 'CIRCLE_CREATED', data: circle });
  } catch (error) {
    console.error('Create circle error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.post('/join', auth, async (req, res) => {
  try {
    const { code } = req.body;

    if (!code) {
      return res.status(400).json({ success: false, code: 'INVITE_CODE_REQUIRED' });
    }

    const circle = await prisma.circle.findUnique({ where: { inviteCode: code } });

    if (!circle) {
      return res.status(404).json({ success: false, code: 'INVALID_INVITE_CODE' });
    }

    const existingMember = await prisma.circleMember.findUnique({
      where: { circleId_userId: { circleId: circle.id, userId: req.userId } }
    });

    if (existingMember) {
      return res.status(400).json({ success: false, code: 'ALREADY_A_MEMBER' });
    }

    const userMemberships = await prisma.circleMember.findMany({ where: { userId: req.userId } });

    for (const membership of userMemberships) {
      const prevMembers = await prisma.circleMember.findMany({
        where: { circleId: membership.circleId, userId: { not: req.userId } }
      });
      if (prevMembers.length > 0) {
        const user = await prisma.user.findUnique({ where: { id: req.userId } });
        const prevCircle = await prisma.circle.findUnique({ where: { id: membership.circleId } });
        await prisma.notification.createMany({
          data: prevMembers.map(m => ({
            title: 'member_left',
            message: `${user.name}|${prevCircle.name}`,
            type: 'member',
            userId: m.userId,
            relatedUserId: user.id
          }))
        });
      }
    }

    await prisma.circleMember.deleteMany({ where: { userId: req.userId } });
    await prisma.circleMember.create({
      data: { circleId: circle.id, userId: req.userId, role: 'member' }
    });

    const user = await prisma.user.findUnique({ where: { id: req.userId } });
    const members = await prisma.circleMember.findMany({
      where: { circleId: circle.id, userId: { not: req.userId } }
    });

    await prisma.notification.createMany({
      data: members.map(m => ({
        title: 'new_member',
        message: `${user.name}|${circle.name}`,
        type: 'member',
        userId: m.userId,
        avatarUrl: user.avatarUrl,
        relatedUserId: user.id
      }))
    });

    res.json({ success: true, code: 'JOINED_CIRCLE', data: circle });
  } catch (error) {
    console.error('Join circle error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.post('/:id/leave', auth, async (req, res) => {
  try {
    const { id } = req.params;

    await prisma.movementHistory.deleteMany({
      where: { userId: req.userId, place: { circleId: id } }
    });
    await prisma.placeMember.deleteMany({
      where: { userId: req.userId, place: { circleId: id } }
    });
    await prisma.circleMember.delete({
      where: { circleId_userId: { circleId: id, userId: req.userId } }
    });

    res.json({ success: true, code: 'LEFT_CIRCLE' });
  } catch (error) {
    console.error('Leave circle error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.post('/:id/regenerate-code', auth, async (req, res) => {
  try {
    const { id } = req.params;

    const membership = await prisma.circleMember.findUnique({
      where: { circleId_userId: { circleId: id, userId: req.userId } }
    });

    if (!membership || membership.role !== 'admin') {
      return res.status(403).json({ success: false, code: 'ADMIN_ONLY' });
    }

    const circle = await prisma.circle.update({
      where: { id },
      data: { inviteCode: generateInviteCode() }
    });

    res.json({ success: true, code: 'CODE_REGENERATED', data: { inviteCode: circle.inviteCode } });
  } catch (error) {
    console.error('Regenerate code error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.delete('/:circleId/members/:memberId', auth, async (req, res) => {
  try {
    const { circleId, memberId } = req.params;

    const requesterMembership = await prisma.circleMember.findUnique({
      where: { circleId_userId: { circleId, userId: req.userId } }
    });

    if (!requesterMembership || requesterMembership.role !== 'admin') {
      return res.status(403).json({ success: false, code: 'ADMIN_ONLY' });
    }

    if (memberId === req.userId) {
      return res.status(400).json({ success: false, code: 'CANNOT_REMOVE_SELF' });
    }

    const memberToRemove = await prisma.circleMember.findUnique({
      where: { circleId_userId: { circleId, userId: memberId } },
      include: { user: { select: { name: true } } }
    });

    if (!memberToRemove) {
      return res.status(404).json({ success: false, code: 'MEMBER_NOT_FOUND' });
    }

    await prisma.circleMember.delete({
      where: { circleId_userId: { circleId, userId: memberId } }
    });

    const circle = await prisma.circle.findUnique({ where: { id: circleId } });
    await prisma.notification.create({
      data: {
        title: 'removed_from_circle',
        message: circle.name,
        type: 'member',
        userId: memberId
      }
    });

    res.json({ success: true, code: 'MEMBER_REMOVED' });
  } catch (error) {
    console.error('Remove member error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.put('/:id', auth, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, emoji, color } = req.body;

    const membership = await prisma.circleMember.findUnique({
      where: { circleId_userId: { circleId: id, userId: req.userId } }
    });

    if (!membership || membership.role !== 'admin') {
      return res.status(403).json({ success: false, code: 'ADMIN_ONLY' });
    }

    const updateData = {};
    if (name) updateData.name = name;
    if (emoji) updateData.emoji = emoji;
    if (color) updateData.color = color;

    const circle = await prisma.circle.update({ where: { id }, data: updateData });
    res.json({ success: true, code: 'CIRCLE_UPDATED', data: circle });
  } catch (error) {
    console.error('Update circle error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.delete('/:id', auth, async (req, res) => {
  try {
    const { id } = req.params;

    const membership = await prisma.circleMember.findUnique({
      where: { circleId_userId: { circleId: id, userId: req.userId } }
    });

    if (!membership || membership.role !== 'admin') {
      return res.status(403).json({ success: false, code: 'ADMIN_ONLY' });
    }

    await prisma.circle.delete({ where: { id } });
    res.json({ success: true, code: 'CIRCLE_DELETED' });
  } catch (error) {
    console.error('Delete circle error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

module.exports = router;
