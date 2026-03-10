const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function main() {
  console.log("🌱 Starting seed...");

  // ============================================
  // 1. CLEAN EXISTING DATA
  // ============================================
  console.log("🧹 Cleaning existing data...");

  await prisma.notification.deleteMany();
  await prisma.movementHistory.deleteMany();
  await prisma.placeMember.deleteMany();
  await prisma.place.deleteMany();
  await prisma.circleMember.deleteMany();
  await prisma.circle.deleteMany();
  await prisma.user.deleteMany();

  console.log("✅ Data cleaned");

  // ============================================
  // 2. CREATE USERS
  // ============================================
  console.log("👥 Creating users...");

  const users = await Promise.all([
    // Main demo user (login will use this)
    prisma.user.create({
      data: {
        id: "user-demo",
        email: "demo@demo.com",
        name: "Demo User",
        avatarUrl: "https://i.pravatar.cc/150?u=demo",
        status: "Evde",
        statusEmoji: "🏠",
        batteryLevel: 85,
        isOnline: true,
        latitude: 41.0082,
        longitude: 28.9784,
        address: "Taksim, İstanbul",
      },
    }),
    // Family members
    prisma.user.create({
      data: {
        id: "user-ayse",
        email: "ayse@family.com",
        name: "Ayşe Yılmaz",
        avatarUrl: "https://i.pravatar.cc/150?u=ayse",
        status: "İşte",
        statusEmoji: "💼",
        batteryLevel: 92,
        isOnline: true,
        latitude: 41.0124,
        longitude: 28.9768,
        address: "Şişli, İstanbul",
      },
    }),
    prisma.user.create({
      data: {
        id: "user-mehmet",
        email: "mehmet@family.com",
        name: "Mehmet Yılmaz",
        avatarUrl: "https://i.pravatar.cc/150?u=mehmet",
        status: "Spor yapıyor",
        statusEmoji: "🏃",
        batteryLevel: 45,
        isOnline: true,
        latitude: 41.0567,
        longitude: 29.0012,
        address: "Kadıköy, İstanbul",
      },
    }),
    prisma.user.create({
      data: {
        id: "user-elife",
        email: "elif@family.com",
        name: "Elif Yılmaz",
        avatarUrl: "https://i.pravatar.cc/150?u=elif",
        status: "Okulda",
        statusEmoji: "📚",
        batteryLevel: 78,
        isOnline: true,
        latitude: 41.0234,
        longitude: 28.989,
        address: "Beşiktaş, İstanbul",
      },
    }),
    prisma.user.create({
      data: {
        id: "user-ahmet",
        email: "ahmet@family.com",
        name: "Ahmet Yılmaz",
        avatarUrl: "https://i.pravatar.cc/150?u=ahmet",
        status: "Molada",
        statusEmoji: "☕",
        batteryLevel: 23,
        isOnline: true,
        latitude: 41.0456,
        longitude: 28.9923,
        address: "Üsküdar, İstanbul",
      },
    }),
    // Friends
    prisma.user.create({
      data: {
        id: "user-can",
        email: "can@friends.com",
        name: "Can Demir",
        avatarUrl: "https://i.pravatar.cc/150?u=can",
        status: "Müzik dinliyor",
        statusEmoji: "🎵",
        batteryLevel: 67,
        isOnline: true,
        latitude: 41.0345,
        longitude: 28.9789,
        address: "Beyoğlu, İstanbul",
      },
    }),
    prisma.user.create({
      data: {
        id: "user-zeynep",
        email: "zeynep@friends.com",
        name: "Zeynep Kaya",
        avatarUrl: "https://i.pravatar.cc/150?u=zeynep",
        status: "Alışverişte",
        statusEmoji: "🛍️",
        batteryLevel: 55,
        isOnline: true,
        latitude: 41.0789,
        longitude: 29.0234,
        address: "Bağdat Caddesi, İstanbul",
      },
    }),
    prisma.user.create({
      data: {
        id: "user-ali",
        email: "ali@work.com",
        name: "Ali Öztürk",
        avatarUrl: "https://i.pravatar.cc/150?u=ali",
        status: "Toplantıda",
        statusEmoji: "📊",
        batteryLevel: 89,
        isOnline: true,
        latitude: 41.0012,
        longitude: 29.0123,
        address: "Ataşehir, İstanbul",
      },
    }),
    // Offline users
    prisma.user.create({
      data: {
        id: "user-fatma",
        email: "fatma@family.com",
        name: "Fatma Yılmaz",
        avatarUrl: "https://i.pravatar.cc/150?u=fatma",
        status: null,
        statusEmoji: null,
        batteryLevel: 12,
        isOnline: false,
        latitude: 41.0123,
        longitude: 28.9654,
        address: "Bakırköy, İstanbul",
      },
    }),
    prisma.user.create({
      data: {
        id: "user-omer",
        email: "omer@friends.com",
        name: "Ömer Çelik",
        avatarUrl: "https://i.pravatar.cc/150?u=omer",
        status: null,
        statusEmoji: null,
        batteryLevel: 0,
        isOnline: false,
        latitude: 40.9987,
        longitude: 28.8765,
        address: "Zeytinburnu, İstanbul",
      },
    }),
  ]);

  console.log(`✅ Created ${users.length} users`);

  // ============================================
  // 3. CREATE CIRCLES
  // ============================================
  console.log("⭕ Creating circles...");

  const circles = await Promise.all([
    prisma.circle.create({
      data: {
        id: "circle-family",
        name: "Aile",
        emoji: "👨‍👩‍👧‍👦",
        color: "#6C5CE7",
        inviteCode: "AILE2024",
      },
    }),
    prisma.circle.create({
      data: {
        id: "circle-work",
        name: "İş Arkadaşları",
        emoji: "💼",
        color: "#00B894",
        inviteCode: "IS2024",
      },
    }),
    prisma.circle.create({
      data: {
        id: "circle-friends",
        name: "Arkadaşlar",
        emoji: "🎉",
        color: "#E17055",
        inviteCode: "ARKADAS2024",
      },
    }),
  ]);

  console.log(`✅ Created ${circles.length} circles`);

  // ============================================
  // 4. ADD CIRCLE MEMBERS
  // ============================================
  console.log("👨‍👩‍👧‍👦 Adding circle members...");

  // Family circle members
  await Promise.all([
    prisma.circleMember.create({
      data: { circleId: "circle-family", userId: "user-demo", role: "admin" },
    }),
    prisma.circleMember.create({
      data: { circleId: "circle-family", userId: "user-ayse", role: "member" },
    }),
    prisma.circleMember.create({
      data: {
        circleId: "circle-family",
        userId: "user-mehmet",
        role: "member",
      },
    }),
    prisma.circleMember.create({
      data: { circleId: "circle-family", userId: "user-elife", role: "member" },
    }),
    prisma.circleMember.create({
      data: { circleId: "circle-family", userId: "user-ahmet", role: "member" },
    }),
    prisma.circleMember.create({
      data: { circleId: "circle-family", userId: "user-fatma", role: "member" },
    }),
  ]);

  // Work circle members
  await Promise.all([
    prisma.circleMember.create({
      data: { circleId: "circle-work", userId: "user-ali", role: "admin" },
    }),
  ]);

  // Friends circle members
  await Promise.all([
    prisma.circleMember.create({
      data: { circleId: "circle-friends", userId: "user-can", role: "admin" },
    }),
    prisma.circleMember.create({
      data: {
        circleId: "circle-friends",
        userId: "user-zeynep",
        role: "member",
      },
    }),
    prisma.circleMember.create({
      data: { circleId: "circle-friends", userId: "user-omer", role: "member" },
    }),
  ]);

  console.log("✅ Circle members added");

  // ============================================
  // 5. CREATE PLACES
  // ============================================
  console.log("📍 Creating places...");

  const places = await Promise.all([
    prisma.place.create({
      data: {
        id: "place-home",
        name: "Ev",
        address: "Taksim Mahallesi, İstanbul",
        latitude: 41.0082,
        longitude: 28.9784,
        radius: 150,
        emoji: "🏠",
        circleId: "circle-family",
        createdById: "user-demo",
      },
    }),
    prisma.place.create({
      data: {
        id: "place-school",
        name: "Okul",
        address: "Beşiktaş, İstanbul",
        latitude: 41.0234,
        longitude: 28.989,
        radius: 200,
        emoji: "🏫",
        circleId: "circle-family",
        createdById: "user-demo",
      },
    }),
    prisma.place.create({
      data: {
        id: "place-work",
        name: "İş",
        address: "Ataşehir, İstanbul",
        latitude: 41.0012,
        longitude: 29.0123,
        radius: 300,
        emoji: "🏢",
        circleId: "circle-work",
        createdById: "user-demo",
      },
    }),
    prisma.place.create({
      data: {
        id: "place-gym",
        name: "Spor Salonu",
        address: "Kadıköy, İstanbul",
        latitude: 41.0567,
        longitude: 29.0012,
        radius: 100,
        emoji: "💪",
        circleId: "circle-family",
        createdById: "user-ayse",
      },
    }),
    prisma.place.create({
      data: {
        id: "place-mall",
        name: "AVM",
        address: "Bağdat Caddesi, İstanbul",
        latitude: 41.0789,
        longitude: 29.0234,
        radius: 250,
        emoji: "🛒",
        circleId: "circle-friends",
        createdById: "user-demo",
      },
    }),
    prisma.place.create({
      data: {
        id: "place-cafe",
        name: "Favori Cafe",
        address: "Beyoğlu, İstanbul",
        latitude: 41.0345,
        longitude: 28.9789,
        radius: 50,
        emoji: "☕",
        circleId: "circle-friends",
        createdById: "user-can",
      },
    }),
    prisma.place.create({
      data: {
        id: "place-park",
        name: "Park",
        address: "Üsküdar, İstanbul",
        latitude: 41.0456,
        longitude: 28.9923,
        radius: 180,
        emoji: "🌳",
        circleId: "circle-family",
        createdById: "user-demo",
      },
    }),
  ]);

  console.log(`✅ Created ${places.length} places`);

  // ============================================
  // 6. ADD PLACE MEMBERS
  // ============================================
  console.log("📍 Adding place members...");

  // Home members
  await Promise.all([
    prisma.placeMember.create({
      data: { placeId: "place-home", userId: "user-demo" },
    }),
    prisma.placeMember.create({
      data: { placeId: "place-home", userId: "user-ayse" },
    }),
    prisma.placeMember.create({
      data: { placeId: "place-home", userId: "user-mehmet" },
    }),
    prisma.placeMember.create({
      data: { placeId: "place-home", userId: "user-elife" },
    }),
    prisma.placeMember.create({
      data: { placeId: "place-home", userId: "user-ahmet" },
    }),
    prisma.placeMember.create({
      data: { placeId: "place-home", userId: "user-fatma" },
    }),
  ]);

  // School members
  await Promise.all([
    prisma.placeMember.create({
      data: { placeId: "place-school", userId: "user-elife" },
    }),
  ]);

  // Work members
  await Promise.all([
    prisma.placeMember.create({
      data: { placeId: "place-work", userId: "user-ali" },
    }),
  ]);

  // Gym members
  await Promise.all([
    prisma.placeMember.create({
      data: { placeId: "place-gym", userId: "user-mehmet" },
    }),
  ]);

  // Mall members
  await Promise.all([
    prisma.placeMember.create({
      data: { placeId: "place-mall", userId: "user-zeynep" },
    }),
  ]);

  // Cafe members
  await Promise.all([
    prisma.placeMember.create({
      data: { placeId: "place-cafe", userId: "user-can" },
    }),
  ]);

  // Park members
  await Promise.all([
    prisma.placeMember.create({
      data: { placeId: "place-park", userId: "user-ahmet" },
    }),
  ]);

  console.log("✅ Place members added");

  // ============================================
  // 7. CREATE NOTIFICATIONS
  // ============================================
  console.log("🔔 Creating notifications...");

  const notifications = await Promise.all([
    prisma.notification.create({
      data: {
        title: "Düşük Batarya",
        message: "Ahmet'in telefonu %23 şarj kaldı",
        type: "battery_low",
        userId: "user-demo",
        avatarUrl: "https://i.pravatar.cc/150?u=ahmet",
        relatedUserId: "user-ahmet",
      },
    }),
    prisma.notification.create({
      data: {
        title: "Düşük Batarya",
        message: "Fatma'nın telefonu %12 şarj kaldı",
        type: "battery_low",
        userId: "user-demo",
        avatarUrl: "https://i.pravatar.cc/150?u=fatma",
        relatedUserId: "user-fatma",
      },
    }),
    prisma.notification.create({
      data: {
        title: "Ev'e vardı",
        message: "Ayşe Ev'e vardı",
        type: "arrival",
        userId: "user-demo",
        avatarUrl: "https://i.pravatar.cc/150?u=ayse",
        relatedUserId: "user-ayse",
      },
    }),
    prisma.notification.create({
      data: {
        title: "SOS Alerti",
        message: "Mehmet SOS gönderdi!",
        type: "sos",
        userId: "user-demo",
        avatarUrl: "https://i.pravatar.cc/150?u=mehmet",
        relatedUserId: "user-mehmet",
      },
    }),
    prisma.notification.create({
      data: {
        title: "Ev'den ayrıldı",
        message: "Elif Ev'den ayrıldı",
        type: "departure",
        userId: "user-demo",
        avatarUrl: "https://i.pravatar.cc/150?u=elif",
        relatedUserId: "user-elife",
        isRead: true,
      },
    }),
    prisma.notification.create({
      data: {
        title: "Hız Uyarısı",
        message: "Mehmet hız limitini aştı",
        type: "speed",
        userId: "user-demo",
        avatarUrl: "https://i.pravatar.cc/150?u=mehmet",
        relatedUserId: "user-mehmet",
      },
    }),
    // Notifications for other users
    prisma.notification.create({
      data: {
        title: "Ev'e vardı",
        message: "Demo Ev'e vardı",
        type: "arrival",
        userId: "user-ayse",
        avatarUrl: "https://i.pravatar.cc/150?u=demo",
        relatedUserId: "user-demo",
      },
    }),
  ]);

  console.log(`✅ Created ${notifications.length} notifications`);

  // ============================================
  // 8. CREATE MOVEMENT HISTORY
  // ============================================
  console.log("📜 Creating movement history...");

  const movements = await Promise.all([
    prisma.movementHistory.create({
      data: {
        userId: "user-ayse",
        placeId: "place-home",
        placeName: "Ev",
        address: "Taksim, İstanbul",
        latitude: 41.0082,
        longitude: 28.9784,
        arrivedAt: new Date(Date.now() - 2 * 60 * 60 * 1000), // 2 hours ago
        leftAt: new Date(Date.now() - 30 * 60 * 1000), // 30 min ago
      },
    }),
    prisma.movementHistory.create({
      data: {
        userId: "user-mehmet",
        placeId: "place-gym",
        placeName: "Spor Salonu",
        address: "Kadıköy, İstanbul",
        latitude: 41.0567,
        longitude: 29.0012,
        arrivedAt: new Date(Date.now() - 1 * 60 * 60 * 1000), // 1 hour ago
        leftAt: null, // Still there
      },
    }),
    prisma.movementHistory.create({
      data: {
        userId: "user-elife",
        placeId: "place-school",
        placeName: "Okul",
        address: "Beşiktaş, İstanbul",
        latitude: 41.0234,
        longitude: 28.989,
        arrivedAt: new Date(Date.now() - 4 * 60 * 60 * 1000), // 4 hours ago
        leftAt: null,
      },
    }),
    prisma.movementHistory.create({
      data: {
        userId: "user-ali",
        placeId: "place-work",
        placeName: "İş",
        address: "Ataşehir, İstanbul",
        latitude: 41.0012,
        longitude: 29.0123,
        arrivedAt: new Date(Date.now() - 6 * 60 * 60 * 1000), // 6 hours ago
        leftAt: null,
      },
    }),
    prisma.movementHistory.create({
      data: {
        userId: "user-zeynep",
        placeId: "place-mall",
        placeName: "AVM",
        address: "Bağdat Caddesi, İstanbul",
        latitude: 41.0789,
        longitude: 29.0234,
        arrivedAt: new Date(Date.now() - 3 * 60 * 60 * 1000), // 3 hours ago
        leftAt: null,
      },
    }),
  ]);

  console.log(`✅ Created ${movements.length} movement records`);

  // ============================================
  // 9. CREATE SYSTEM SETTINGS
  // ============================================
  console.log("⚙️ Creating system settings...");

  await prisma.systemSetting.upsert({
    where: { key: 'testMode' },
    update: { value: '1' },
    create: { key: 'testMode', value: '1' }
  });

  // ============================================
  // 10. CREATE APPLE REVIEW ACCOUNTS
  // ============================================
  console.log("🍎 Creating Apple Review accounts...");

  const bcrypt = require('bcryptjs');
  const reviewPassword = await bcrypt.hash('ReviewTest2026!', 10);

  // Reviewer account
  const reviewer = await prisma.user.upsert({
    where: { email: 'apple_review_1@geofollow.xyz' },
    update: { password: reviewPassword },
    create: {
      id: "apple-reviewer-1",
      email: "apple_review_1@geofollow.xyz",
      name: "Apple Reviewer",
      password: reviewPassword,
      provider: "email",
      avatarUrl: "https://i.pravatar.cc/150?u=apple1",
      status: "Haritada",
      batteryLevel: 98,
      isOnline: true,
      latitude: 41.0082,
      longitude: 28.9784,
      isPremium: true
    }
  });

  // Partner for reviewer to follow
  const mockPartner = await prisma.user.upsert({
    where: { email: 'apple_review_2@geofollow.xyz' },
    update: { password: reviewPassword },
    create: {
      id: "apple-reviewer-2",
      email: "apple_review_2@geofollow.xyz",
      name: "Review Test Partner",
      password: reviewPassword,
      provider: "email",
      avatarUrl: "https://i.pravatar.cc/150?u=apple2",
      status: "Yolda",
      statusEmoji: "🚗",
      batteryLevel: 75,
      isOnline: true,
      latitude: 41.0124,
      longitude: 28.9856,
      isPremium: true
    }
  });

  // Specialized Review Circle
  const reviewCircle = await prisma.circle.upsert({
    where: { inviteCode: 'TEST-8492' },
    update: {},
    create: {
      id: "circle-apple-review",
      name: "İnceleme Grubu",
      emoji: "🛡️",
      inviteCode: "TEST-8492"
    }
  });

  // Link them
  await prisma.circleMember.upsert({
    where: { circleId_userId: { circleId: reviewCircle.id, userId: reviewer.id } },
    update: {},
    create: { circleId: reviewCircle.id, userId: reviewer.id, role: "admin" }
  });

  await prisma.circleMember.upsert({
    where: { circleId_userId: { circleId: reviewCircle.id, userId: mockPartner.id } },
    update: {},
    create: { circleId: reviewCircle.id, userId: mockPartner.id, role: "member" }
  });

  console.log("✅ Apple review setup completed");

  // ============================================
  // SUMMARY
  // ============================================
  console.log("\n🎉 Seed completed successfully!");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log(`👥 Users: ${users.length}`);
  console.log(`⭕ Circles: ${circles.length}`);
  console.log(`📍 Places: ${places.length}`);
  console.log(`🔔 Notifications: ${notifications.length}`);
  console.log(`📜 Movement Records: ${movements.length}`);

  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log('\n🔑 Login with: POST /auth/login { "email": "demo@demo.com" }');
}

main()
  .catch((e) => {
    console.error("❌ Seed error:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
