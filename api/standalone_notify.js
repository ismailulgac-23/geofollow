const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccountPath = path.join(__dirname, 'src', 'config', 'service-account.json');
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const fcmToken = 'fY8TmWSJsk6hnDUUwvRcPP:APA91bG-SjQHNk3S7blEvR6zsTi6nqIvQ3vvpxYhcX7uebqmphQbbmCpDTrHDls6X5Ea0CBVMoQUfLN0GKiwsVpVaaMIi9IXE2Cp5olL_q9sowNGW86qzUc';

const message = {
    token: fcmToken,
    notification: {
        title: 'GeoFollow Manuel Test',
        body: 'Bu bildirim manuel script ile gönderildi.',
    },
    data: {
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        status: 'done'
    }
};

admin.messaging().send(message)
    .then((response) => {
        console.log('✅ Başarıyla gönderildi:', response);
    })
    .catch((error) => {
        console.error('❌ Hata oluştu:', error);
        if (error.code) console.log('Hata Kodu:', error.code);
        if (error.message) console.log('Hata Mesajı:', error.message);
    });
