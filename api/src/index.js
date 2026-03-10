const express = require('express');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();
const { initializeFirebase } = require('./utils/firebase');

// Initialize Firebase Admin
initializeFirebase();

const prisma = require('./config/database');
const authRoutes = require('./routes/auth.routes');
const userRoutes = require('./routes/user.routes');
const circleRoutes = require('./routes/circle.routes');
const placeRoutes = require('./routes/place.routes');
const notificationRoutes = require('./routes/notification.routes');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE']
  }
});

// Middleware
app.use(cors());
app.use(express.json());

// Make io accessible to routes
app.use((req, res, next) => {
  req.io = io;
  next();
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/circles', circleRoutes);
app.use('/api/places', placeRoutes);
app.use('/api/notifications', notificationRoutes);

// Health check
app.get('/api/health', async (req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json({
      status: 'ok',
      database: 'connected',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      database: 'disconnected',
      message: error.message
    });
  }
});

// Socket.IO for real-time location updates
io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  socket.on('join-circle', (circleId) => {
    socket.join(`circle-${circleId}`);
    console.log(`User ${socket.id} joined circle ${circleId}`);
  });

  socket.on('leave-circle', (circleId) => {
    socket.leave(`circle-${circleId}`);
    console.log(`User ${socket.id} left circle ${circleId}`);
  });

  socket.on('location-update', async (data) => {
    try {
      // Update user location in database
      await prisma.user.update({
        where: { id: data.userId },
        data: {
          latitude: data.latitude,
          longitude: data.longitude,
          address: data.address,
          lastUpdated: new Date(),
          isOnline: true
        }
      });

      // Broadcast location to all circle members
      socket.to(`circle-${data.circleId}`).emit('member-location', data);
    } catch (error) {
      console.error('Location update error:', error);
    }
  });

  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    success: false,
    code: 'INTERNAL_SERVER_ERROR'
  });
});

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n🛑 Shutting down gracefully...');
  await prisma.$disconnect();
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});

const { runSimulationTick } = require('./utils/simulation');

// ... existing code ...

// Start server
const PORT = process.env.PORT || 3000;

const startServer = async () => {
  try {
    await prisma.$connect();
    console.log('✅ PostgreSQL connected (Prisma)');

    server.listen(PORT, () => {
      console.log(`🚀 Server running on port ${PORT}`);
      console.log(`📡 Socket.IO enabled`);

      // Start Simulation Engine (Ticks every 10 seconds)
      setInterval(() => {
        runSimulationTick(io);
      }, 10000);
    });
  } catch (error) {
    console.error('❌ Database connection error:', error.message);
    process.exit(1);
  }
};

startServer();

module.exports = { app, io };
