const express = require('express');
const router = express.Router();
const prisma = require('../config/database');
const auth = require('../middleware/auth');
const { sendNotification, sendMulticastNotification } = require('../utils/firebase');
const { processLocationUpdate, getFrequentPlaces, getTodayMovements } = require('../utils/movementTracker');

router.get('/circle/:circleId', auth, async (req, res) => {
  try {
    const { circleId } = req.params;

    const members = await prisma.circleMember.findMany({
      where: { circleId },
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
    });

    const users = members.map(m => ({
      ...m.user,
      location: m.user.latitude && m.user.longitude
        ? { latitude: m.user.latitude, longitude: m.user.longitude }
        : null
    }));

    res.json({ success: true, code: 'SUCCESS', data: users });
  } catch (error) {
    console.error('Get users error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.get('/:id', auth, async (req, res) => {
  try {
    const { id } = req.params;

    const user = await prisma.user.findUnique({
      where: { id },
      select: {
        id: true, name: true, avatarUrl: true, status: true,
        statusEmoji: true, batteryLevel: true, isOnline: true,
        isPremium: true, latitude: true, longitude: true,
        address: true, lastUpdated: true
      }
    });

    if (!user) {
      return res.status(404).json({ success: false, code: 'USER_NOT_FOUND' });
    }

    res.json({
      success: true,
      code: 'SUCCESS',
      data: {
        ...user,
        location: user.latitude && user.longitude
          ? { latitude: user.latitude, longitude: user.longitude }
          : null
      }
    });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

// Arka planda native plugin'in gönderdiği (Killed / Terminated state) ham konumlar için
router.post('/me/location', auth, async (req, res) => {
  try {
    const userId = req.userId;
    const { latitude, longitude, address, speed, accuracy, batteryLevel } = req.body;

    // Flutter native plugin battery level genelde 0.x (ör: 0.85) döner.
    // Bizim DB ise int (85) bekliyor. Bunu düzeltelim.
    let processedBattery = batteryLevel;
    if (batteryLevel !== undefined && batteryLevel <= 1.0) {
      processedBattery = Math.round(batteryLevel * 100);
    }

    const user = await prisma.user.update({
      where: { id: userId },
      data: {
        latitude,
        longitude,
        ...(address && { address }),
        ...(processedBattery !== undefined && { batteryLevel: processedBattery }),
        lastUpdated: new Date(),
        isOnline: true,
        isPremium: true
      }
    });

    // Hareket takip algoritmasını çalıştır (async, ana akışı bloke etmez)
    console.log(`[Native Sync] Received for user: ${userId} -> Body:`, req.body);
    processLocationUpdate(userId, latitude, longitude, address, speed || 0, accuracy || 0)
      .catch(err => console.error('[LocationUpdate] tracker error:', err.message));

    const circleMembers = await prisma.circleMember.findMany({ where: { userId } });

    if (req.io) {
      circleMembers.forEach(cm => {
        req.io.to(`circle-${cm.circleId}`).emit('member-location', {
          userId, latitude, longitude, address, batteryLevel: processedBattery
        });
      });
    }

    console.log(`[Native Sync] KILLED STATE LOCATION UPDATED -> user: ${userId} (${processedBattery}%)`);
    res.json({ success: true, code: 'LOCATION_UPDATED_NATIVE', data: user });
  } catch (error) {
    console.error('Update location native error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.put('/:id/location', auth, async (req, res) => {
  try {
    const { id } = req.params;
    const { latitude, longitude, address, batteryLevel, speed, accuracy } = req.body;

    const user = await prisma.user.update({
      where: { id },
      data: { latitude, longitude, address, batteryLevel, lastUpdated: new Date(), isOnline: true, isPremium: true }
    });

    // Hareket takip algoritmasını çalıştır (async, ana akışı bloke etmez)
    processLocationUpdate(id, latitude, longitude, address, speed || 0, accuracy || 0)
      .catch(err => console.error('[LocationUpdate] tracker error:', err.message));

    const circleMembers = await prisma.circleMember.findMany({ where: { userId: id } });

    if (req.io) {
      circleMembers.forEach(cm => {
        req.io.to(`circle-${cm.circleId}`).emit('member-location', { userId: id, latitude, longitude, address, batteryLevel });
      });
    }

    res.json({ success: true, code: 'LOCATION_UPDATED', data: user });
  } catch (error) {
    console.error('Update location error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.put('/:id/status', auth, async (req, res) => {
  try {
    const { id } = req.params;
    const { status, statusEmoji } = req.body;

    const user = await prisma.user.update({ where: { id }, data: { status, statusEmoji } });
    res.json({ success: true, code: 'STATUS_UPDATED', data: user });
  } catch (error) {
    console.error('Update status error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.get('/:id/history', auth, async (req, res) => {
  try {
    const { id } = req.params;
    const limit = parseInt(req.query.limit) || 30;
    const type = req.query.type || 'today'; // today | all | frequent

    let data;

    if (type === 'frequent') {
      // En sık gidilen yerleri getir
      data = await getFrequentPlaces(id, limit);
    } else if (type === 'today') {
      // Bugünkü hareketler
      data = await getTodayMovements(id);
    } else {
      // Tüm geçmiş
      data = await prisma.movementHistory.findMany({
        where: { userId: id },
        orderBy: { arrivedAt: 'desc' },
        take: limit
      });
    }

    res.json({ success: true, code: 'SUCCESS', data });
  } catch (error) {
    console.error('Get history error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

// Kullanıcının kendi hareket geçmişi
router.get('/me/history', auth, async (req, res) => {
  try {
    const type = req.query.type || 'today';
    const limit = parseInt(req.query.limit) || 30;
    let data;

    if (type === 'frequent') {
      data = await getFrequentPlaces(req.userId, limit);
    } else if (type === 'today') {
      data = await getTodayMovements(req.userId);
    } else {
      data = await prisma.movementHistory.findMany({
        where: { userId: req.userId },
        orderBy: { arrivedAt: 'desc' },
        take: limit
      });
    }

    res.json({ success: true, code: 'SUCCESS', data });
  } catch (error) {
    console.error('Get my history error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

// ── Geofence Event (Flutter tarafından gönderilir) ────────────────────────────
router.post('/me/geofence-event', auth, async (req, res) => {
  try {
    const { placeId, placeName, eventType, latitude, longitude, address, timestamp } = req.body;
    const userId = req.userId;
    const now = timestamp ? new Date(timestamp) : new Date();

    console.log(`[GeofenceEvent] ${eventType} → ${placeName} (user:${userId}) at ${now.toISOString()}`);

    if (eventType === 'ENTERED') {
      // 30 dk debounce kontrolü - aynı yere art arda fake log atılmasını engeller
      const recentLog = await prisma.movementHistory.findFirst({
        where: { userId, placeId: placeId || null },
        orderBy: { arrivedAt: 'desc' }
      });

      if (recentLog) {
        const diffMins = (now - new Date(recentLog.arrivedAt)) / 60000;
        if (diffMins < 30) {
          console.log(`[GeofenceEvent] SKIP duplicate ENTERED for ${placeName} - Diff: ${diffMins.toFixed(1)} mins`);
          return res.json({ success: true, message: 'Skipped - already entered recently' });
        }
      }

      // Giriş kaydı — açık bir MovementHistory oluştur
      await prisma.movementHistory.create({
        data: {
          userId,
          placeId: placeId || null,
          placeName,
          address: address || '',
          latitude,
          longitude,
          arrivedAt: now,
          leftAt: null,
          visitCount: 1,
          durationMins: 0,
          emoji: '📍',
        }
      });

    } else if (eventType === 'EXITED') {
      // Çıkış kaydı — en son açık kaydı kapat
      const openRecord = await prisma.movementHistory.findFirst({
        where: {
          userId,
          placeName,
          leftAt: null,
        },
        orderBy: { arrivedAt: 'desc' }
      });

      if (openRecord) {
        const durationMins = Math.round((now - new Date(openRecord.arrivedAt)) / 60000);
        await prisma.movementHistory.update({
          where: { id: openRecord.id },
          data: {
            leftAt: now,
            durationMins,
          }
        });
        console.log(`[GeofenceEvent] EXITED ${placeName} — dwell: ${durationMins}min`);
      }
    }

    // LocationSnapshot da kaydet
    await prisma.locationSnapshot.create({
      data: {
        userId,
        latitude,
        longitude,
        address: address || null,
        geofenceEvent: eventType,
        geofencePlaceName: placeName,
        timestamp: now,
      }
    }).catch(() => {/* LocationSnapshot opsiyonel */ });

    res.json({ success: true, code: 'GEOFENCE_EVENT_RECORDED' });
  } catch (error) {
    console.error('[GeofenceEvent] Error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.get('/me/settings', auth, async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.userId },
      select: { id: true, name: true, avatarUrl: true, status: true, statusEmoji: true, isOnline: true, isPremium: true }
    });

    if (!user) {
      return res.status(404).json({ success: false, code: 'USER_NOT_FOUND' });
    }

    res.json({
      success: true,
      code: 'SUCCESS',
      data: { ...user, ghostMode: false, notificationsEnabled: true }
    });
  } catch (error) {
    console.error('Get settings error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.put('/me/settings', auth, async (req, res) => {
  try {
    const { name, status, statusEmoji, ghostMode, notificationsEnabled } = req.body;
    const updateData = {};
    if (name) updateData.name = name;
    if (status !== undefined) updateData.status = status;
    if (statusEmoji !== undefined) updateData.statusEmoji = statusEmoji;
    if (ghostMode !== undefined) updateData.isOnline = !ghostMode;

    const user = await prisma.user.update({ where: { id: req.userId }, data: updateData });

    res.json({
      success: true,
      code: 'SETTINGS_UPDATED',
      data: {
        id: user.id, name: user.name, avatarUrl: user.avatarUrl,
        status: user.status, statusEmoji: user.statusEmoji,
        isOnline: user.isOnline, ghostMode: ghostMode || false,
        notificationsEnabled: notificationsEnabled !== undefined ? notificationsEnabled : true
      }
    });
  } catch (error) {
    console.error('Update settings error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.put('/me', auth, async (req, res) => {
  try {
    const { name, avatarUrl, status, statusEmoji, batteryLevel, fcmToken, latitude, longitude, address } = req.body;
    const updateData = {};
    if (name) updateData.name = name;
    if (avatarUrl) updateData.avatarUrl = avatarUrl;
    if (status !== undefined) updateData.status = status;
    if (statusEmoji !== undefined) updateData.statusEmoji = statusEmoji;
    if (batteryLevel !== undefined) updateData.batteryLevel = batteryLevel;
    if (fcmToken !== undefined) updateData.fcmToken = fcmToken;
    if (latitude !== undefined) updateData.latitude = latitude;
    if (longitude !== undefined) updateData.longitude = longitude;
    if (address !== undefined) updateData.address = address;
    updateData.lastUpdated = new Date();

    const user = await prisma.user.update({ where: { id: req.userId }, data: updateData });
    res.json({ success: true, code: 'PROFILE_UPDATED', data: user });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.post('/sos', auth, async (req, res) => {
  try {
    const sender = await prisma.user.findUnique({
      where: { id: req.userId },
      include: {
        circles: {
          include: {
            circle: {
              include: { members: { include: { user: true } } }
            }
          }
        }
      }
    });

    if (!sender) {
      return res.status(404).json({ success: false, code: 'USER_NOT_FOUND' });
    }

    const recipientTokens = [];
    const notificationPromises = [];

    for (const circleMember of sender.circles) {
      const circle = circleMember.circle;
      for (const member of circle.members) {
        if (member.userId === req.userId) continue;
        if (member.user.fcmToken) recipientTokens.push(member.user.fcmToken);

        notificationPromises.push(
          prisma.notification.create({
            data: {
              title: 'sos_alert',
              message: sender.name,
              type: 'sos',
              userId: member.userId,
              avatarUrl: sender.avatarUrl,
              relatedUserId: sender.id
            }
          })
        );

        if (req.io) {
          req.io.to(`user-${member.userId}`).emit('notification', {
            title: 'sos_alert',
            message: sender.name,
            type: 'sos',
            senderName: sender.name,
            senderAvatar: sender.avatarUrl,
            timestamp: new Date()
          });
        }
      }
    }

    await Promise.all(notificationPromises);

    if (recipientTokens.length > 0) {
      await sendMulticastNotification(recipientTokens, {
        title: '🆘 SOS ALERT',
        body: `${sender.name} needs help immediately!`,
        data: { type: 'sos', userId: sender.id, userName: sender.name }
      });
    }

    res.json({ success: true, code: 'SOS_SENT' });
  } catch (error) {
    console.error('SOS alert error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.post('/premium', auth, async (req, res) => {
  try {
    const { isPremium } = req.body;
    // Deger gonderilmezse varsayilan true (eski davranis)
    const premiumStatus = isPremium !== undefined ? isPremium : true;

    const user = await prisma.user.update({
      where: { id: req.userId },
      data: { isPremium: premiumStatus }
    });

    res.json({
      success: true,
      code: premiumStatus ? 'PREMIUM_ACTIVATED' : 'PREMIUM_DEACTIVATED',
      data: user
    });
  } catch (error) {
    console.error('Sync premium status error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.delete('/me', auth, async (req, res) => {
  try {
    await prisma.user.delete({ where: { id: req.userId } });
    res.json({ success: true, code: 'ACCOUNT_DELETED' });
  } catch (error) {
    console.error('Delete account error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.post('/:id/nudge', auth, async (req, res) => {
  try {
    const targetUserId = req.params.id;
    const senderId = req.userId;

    const targetUser = await prisma.user.findUnique({ where: { id: targetUserId } });
    const sender = await prisma.user.findUnique({ where: { id: senderId } });

    if (!targetUser) return res.status(404).json({ success: false, code: 'USER_NOT_FOUND' });

    if (targetUser.fcmToken) {
      await sendNotification(targetUser.fcmToken, {
        title: 'You got nudged! 👉',
        body: `${sender.name} just nudged you.`,
        data: { type: 'nudge', senderId, click_action: 'FLUTTER_NOTIFICATION_CLICK' }
      });
    }

    res.json({ success: true, code: 'NUDGE_SENT' });
  } catch (error) {
    console.error('Nudge error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

router.post('/:id/message', auth, async (req, res) => {
  try {
    const targetUserId = req.params.id;
    const senderId = req.userId;
    const { message } = req.body;

    const targetUser = await prisma.user.findUnique({ where: { id: targetUserId } });
    const sender = await prisma.user.findUnique({ where: { id: senderId } });

    if (!targetUser) return res.status(404).json({ success: false, code: 'USER_NOT_FOUND' });

    if (targetUser.fcmToken) {
      await sendNotification(targetUser.fcmToken, {
        title: `New message from ${sender.name} 💬`,
        body: message,
        data: { type: 'message', senderId, message, click_action: 'FLUTTER_NOTIFICATION_CLICK' }
      });
    }

    res.json({ success: true, code: 'MESSAGE_SENT' });
  } catch (error) {
    console.error('Message error:', error);
    res.status(500).json({ success: false, code: 'INTERNAL_SERVER_ERROR' });
  }
});

module.exports = router;
