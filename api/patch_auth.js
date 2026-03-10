const fs = require('fs');

const authRoutesPath = '/Users/ismailulgac/Documents/tracker_app/gefollow/api/src/routes/auth.routes.js';
let content = fs.readFileSync(authRoutesPath, 'utf8');

// Replace the injected `setupAppleReviewSimulation` block with import
// And `setupAppleReviewSimulation` with `prepareAppleTestSimulations(user.id, user.latitude, user.longitude, req.io)`

const blockStart = content.indexOf('// ---');
const blockEnd = content.indexOf('// ---', blockStart + 10) + ('// ----------------------------------------------------------------------'.length);

if (blockStart !== -1 && blockEnd !== -1) {
    const toRemove = content.substring(blockStart, blockEnd);
    content = content.replace(toRemove, `const { prepareAppleTestSimulations } = require('../utils/appleTestSimulation');`);
}

// Replace setupAppleReviewSimulation(user, req.io)
// Wait, for login, we fall back to req.body.lat / lng since user obj might not have it yet?
content = content.replace(/await setupAppleReviewSimulation\(user, req\.io\);/g, `await prepareAppleTestSimulations(user.id, req.body.lat || user.latitude, req.body.lng || user.longitude, req.io);`);

fs.writeFileSync(authRoutesPath, content, 'utf8');
console.log('Patch complete.');
