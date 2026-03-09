const express = require('express');
const router = express.Router();
const prisma = require('../config/database');
const auth = require('../middleware/auth');

router.get('/', auth, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const offset = parseInt(req.query.offset) || 0;

    const notifications = await prisma.notification.findMany({
      where: { userId: req.userId },
      orderBy: { createdAt: 'desc' },
      take: limit,
      skip: offset
    });

    const unreadCount = await prisma.notification.count({
      where: { userId: req.userId, isRead: false }
    });

    res.json({ success: true, code: 'SUCCESS', data: { notifications, unreadCount } });
  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.get('/unread-count', auth, async (req, res) => {
  try {
    const count = await prisma.notification.count({
      where: { userId: req.userId, isRead: false }
    });

    res.json({ success: true, code: 'SUCCESS', data: { count } });
  } catch (error) {
    console.error('Get unread count error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.put('/:id/read', auth, async (req, res) => {
  try {
    const { id } = req.params;

    const notification = await prisma.notification.update({
      where: { id, userId: req.userId },
      data: { isRead: true }
    });

    res.json({ success: true, code: 'NOTIFICATION_READ', data: notification });
  } catch (error) {
    console.error('Mark read error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.put('/read-all', auth, async (req, res) => {
  try {
    await prisma.notification.updateMany({
      where: { userId: req.userId, isRead: false },
      data: { isRead: true }
    });

    res.json({ success: true, code: 'ALL_NOTIFICATIONS_READ' });
  } catch (error) {
    console.error('Mark all read error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.delete('/:id', auth, async (req, res) => {
  try {
    const { id } = req.params;

    await prisma.notification.delete({ where: { id, userId: req.userId } });
    res.json({ success: true, code: 'NOTIFICATION_DELETED' });
  } catch (error) {
    console.error('Delete notification error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.delete('/clear-all', auth, async (req, res) => {
  try {
    await prisma.notification.deleteMany({ where: { userId: req.userId } });
    res.json({ success: true, code: 'ALL_NOTIFICATIONS_CLEARED' });
  } catch (error) {
    console.error('Clear notifications error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.post('/', auth, async (req, res) => {
  try {
    const { title, message, type, userId, avatarUrl, relatedUserId } = req.body;

    if (!title || !message || !type || !userId) {
      return res.status(400).json({ success: false, code: 'MISSING_REQUIRED_FIELDS' });
    }

    const notification = await prisma.notification.create({
      data: { title, message, type, userId, avatarUrl, relatedUserId }
    });

    if (req.io) {
      req.io.emit(`notification-${userId}`, notification);
    }

    res.status(201).json({ success: true, code: 'NOTIFICATION_CREATED', data: notification });
  } catch (error) {
    console.error('Create notification error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

module.exports = router;