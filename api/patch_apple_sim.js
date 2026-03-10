const fs = require('fs');

const authRoutesPath = '/Users/ismailulgac/Documents/tracker_app/gefollow/api/src/routes/auth.routes.js';
let content = fs.readFileSync(authRoutesPath, 'utf8');

// The block to extract
const startIdx = content.indexOf('// If Apple Reviewer registers');
const endIdx = content.indexOf('res.status(201).json({');

if(startIdx !== -1 && endIdx !== -1) {
    // Remove the old block and replace with function call
}
