const { GoogleAuth } = require('google-auth-library');
const fs = require('fs');
const path = require('path');
const https = require('https');

const serviceAccountPath = path.join(__dirname, 'src', 'config', 'service-account.json');

async function testTokenGeneration() {
    console.log('--- Token Generation Test ---');
    try {
        const auth = new GoogleAuth({
            keyFile: serviceAccountPath,
            scopes: ['https://www.googleapis.com/auth/cloud-platform'],
        });

        const client = await auth.getClient();
        const tokenResponse = await client.getAccessToken();

        console.log('✅ Access Token generated!');
        return tokenResponse.token;

    } catch (error) {
        console.error('❌ Failed to generate Access Token:', error.message);
    }
}

async function testFCMManual(token) {
    if (!token) return;
    console.log('\n--- Manual HTTP Post Test ---');

    const projectId = 'geofollow-bffa2';
    const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    const fcmToken = 'fY8TmWSJsk6hnDUUwvRcPP:APA91bG-SjQHNk3S7blEvR6zsTi6nqIvQ3vvpxYhcX7uebqmphQbbmCpDTrHDls6X5Ea0CBVMoQUfLN0GKiwsVpVaaMIi9IXE2Cp5olL_q9sowNGW86qzUc';

    const postData = JSON.stringify({
        message: {
            token: fcmToken,
            notification: {
                title: 'Manual Debug',
                body: 'Bu manuel deneme!'
            }
        }
    });

    const options = {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
            'Content-Length': postData.length
        }
    };

    const req = https.request(url, options, (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
            console.log('Status Code:', res.statusCode);
            console.log('Response Body:', data);
            if (res.statusCode === 200) {
                console.log('✅ BİLDİRİM MANUEL OLARAK DÜŞTÜ!');
            } else {
                console.log('❌ HATA:', res.statusCode);
                if (data.includes('ACCESS_TOKEN_SCOPE_INSUFFICIENT')) {
                    console.log('HATA: Scope yetersiz.');
                } else if (data.includes('PERMISSION_DENIED')) {
                    console.log('HATA: FCM API Kapalı veya Yetki Yok.');
                }
            }
        });
    });

    req.on('error', (e) => {
        console.error('Network Error:', e.message);
    });

    req.write(postData);
    req.end();
}

testTokenGeneration().then(testFCMManual);
