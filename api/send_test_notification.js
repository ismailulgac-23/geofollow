const { sendNotification } = require('./src/utils/firebase');

const fcmToken = 'cxIurUCyVk_glK5YobkDIJ:APA91bG84oDekYy3XumA_JUmSD3XXWI6XEv-nc3zyIBBxM0ACGteXwgc4gw7iyMXf0FT5Nn-YMwwTLPd5ld58twFleikqUkzZ0RzaNAhqGpivS7kLnXVw38';

async function testNotification() {
    console.log('--- FCM Test Script ---');
    console.log(`Target Token: ${fcmToken.substring(0, 10)}...${fcmToken.substring(fcmToken.length - 10)}`);

    const payload = {
        title: 'GeoFollow Test',
        body: 'Bu bir test bildirimidir! Arka plan servis kontrolü.',
        data: {
            type: 'TEST',
            time: new Date().toISOString()
        }
    };

    try {
        const result = await sendNotification(fcmToken, payload);
        if (result) {
            console.log('✅ Bildirim başarıyla gönderildi!');
        } else {
            console.log('❌ Bildirim gönderilemedi. Hata için yukarıdaki loglara bakınız.');
        }
    } catch (error) {
        console.error('❌ Betik hatası:', error);
    }
}

testNotification();
