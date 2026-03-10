const { GoogleAuth } = require('google-auth-library');
const fs = require('fs');
const path = require('path');

const serviceAccountPath = path.join(__dirname, 'src', 'config', 'service-account.json');

async function testTokenGeneration() {
    console.log('--- Token Generation Test ---');
    try {
        const auth = new GoogleAuth({
            keyFile: serviceAccountPath,
            scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
        });

        const client = await auth.getClient();
        const tokenResponse = await client.getAccessToken();

        console.log('✅ Access Token generated successfully!');
        console.log('Token starts with:', tokenResponse.token.substring(0, 10));
        console.log('Expiry:', tokenResponse.res.data.expires_in, 'seconds');
        return tokenResponse.token;

    } catch (error) {
        console.error('❌ Failed to generate Access Token:');
        console.error(error.message);
        if (error.response) {
            console.error('Response Data:', error.response.data);
        }
    }
}

async function testFCMWithToken(token) {
    if (!token) return;
    console.log('\n--- Manual FCM V1 Request Test ---');

    const projectId = 'geofollow-bffa2';
    const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    const fcmToken = 'fY8TmWSJsk6hnDUUwvRcPP:APA91bG-SjQHNk3S7blEvR6zsTi6nqIvQ3vvpxYhcX7uebqmphQbbmCpDTrHDls6X5Ea0CBVMoQUfLN0GKiwsVpVaaMIi9IXE2Cp5olL_q9sowNGW86qzUc';

    const message = {
        message: {
            token: fcmToken,
            notification: {
                title: 'Manual Test',
                body: 'Bu manuel HTTP isteği ile gelen bildirimdir.'
            }
        }
    };

    const response = await fetch(url, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(message)
    });

    const body = await response.json();
    if (response.ok) {
        console.log('✅ FCM Request OK:', body);
    } else {
        console.log('❌ FCM Request Failed (HTTP ', response.status, '):');
        console.log(JSON.stringify(body, null, 2));
    }
}

testTokenGeneration().then(testFCMWithToken);
