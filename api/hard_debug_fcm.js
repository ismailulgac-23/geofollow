const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccountPath = path.join(__dirname, 'src', 'config', 'service-account.json');
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

console.log('--- Debug Info ---');
console.log('Project ID:', serviceAccount.project_id);
console.log('Client Email:', serviceAccount.client_email);
console.log('Private Key length:', serviceAccount.private_key.length);

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const fcmToken = 'fY8TmWSJsk6hnDUUwvRcPP:APA91bG-SjQHNk3S7blEvR6zsTi6nqIvQ3vvpxYhcX7uebqmphQbbmCpDTrHDls6X5Ea0CBVMoQUfLN0GKiwsVpVaaMIi9IXE2Cp5olL_q9sowNGW86qzUc';

const message = {
    token: fcmToken,
    notification: {
        title: 'GeoFollow Manuel Test',
        body: 'Bu bildirim manuel script ile gönderildi.',
    },
    data: {
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        status: 'hard_debug'
    },
    android: {
        priority: 'high'
    }
};

admin.messaging().send(message)
    .then((response) => {
        console.log('✅ Success:', response);
    })
    .catch((error) => {
        console.error('❌ Error details:');
        console.error(JSON.stringify(error, null, 2));
        if (error.code === 'messaging/third-party-auth-error') {
            console.log('\n--- ÖNEMLİ ANALİZ ---');
            console.log('Bu hata genellikle şunlardan kaynaklanır:');
            console.log('1. Firebase Cloud Messaging API (V1) Google Cloud Console\'da "ENABLED" değil.');
            console.log('2. Kullandığınız Service Account bu proje için "Firebase Admin" yetkisine sahip değil.');
            console.log('3. Token başka bir Firebase projesine ait.');
        }
    });
