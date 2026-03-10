const fs = require('fs');

const authRoutesPath = '/Users/ismailulgac/Documents/tracker_app/gefollow/api/src/routes/auth.routes.js';
let content = fs.readFileSync(authRoutesPath, 'utf8');

const setupFn = `
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
      console.log(\`🍎 [Apple Review] Simulation started for \${reviewer2.id}\`);
    }
  } catch (err) {
    console.error("Apple Review setup error:", err);
  }
};
// ----------------------------------------------------------------------
`;

// Insert helper right before `// POST /auth/login`
content = content.replace('// POST /auth/login', setupFn + '\n// POST /auth/login');

// Now in POST /register, replace the huge apple review block
const registerAppleReviewStartStr = `// If Apple Reviewer registers (fresh start after db clear/app reinstall), setup mock data and start`;
const startIdx = content.indexOf(registerAppleReviewStartStr);
const endIdx = content.indexOf('res.status(201).json({', startIdx);

if (startIdx !== -1 && endIdx !== -1) {
    content = content.substring(0, startIdx) +
        `if (email === 'apple_review_1@geofollow.xyz') {
      await setupAppleReviewSimulation(user, req.io);
    }

    ` + content.substring(endIdx);
}

// Add it to the IF existing user in POST /register
const existingUserReturnStr = `return res.json({
        success: true,
        code: 'UPDATED',
        data: { user: formatUserResponse(user), token }
      });`;

content = content.replace(existingUserReturnStr,
    `if (existingUser.email === 'apple_review_1@geofollow.xyz') {
        await setupAppleReviewSimulation(user, req.io);
      }

      ` + existingUserReturnStr);

// Now clean up POST /login block
const loginAppleReviewStartStr = `// 4. Apple Review Test User Hook`;
const loginEndIdx = content.indexOf('// 5. START REAL-TIME MOVEMENT SIMULATION', content.indexOf(loginAppleReviewStartStr));
const loginFinalEndIdx = content.indexOf('} // End Apple Reviewer Special Check', loginEndIdx);

if (content.includes(loginAppleReviewStartStr) && loginFinalEndIdx !== -1) {
    content = content.substring(0, content.indexOf(loginAppleReviewStartStr)) +
        `if (user.email === 'apple_review_1@geofollow.xyz') {
        await setupAppleReviewSimulation(user, req.io);
      }
      ` + content.substring(loginFinalEndIdx + 38);
}


fs.writeFileSync(authRoutesPath, content, 'utf8');
console.log('Script done');
