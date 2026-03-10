const { sendNotification } = require('./src/utils/firebase');

const fcmToken = 'fY8TmWSJsk6hnDUUwvRcPP:APA91bG-SjQHNk3S7blEvR6zsTi6nqIvQ3vvpxYhcX7uebqmphQbbmCpDTrHDls6X5Ea0CBVMoQUfLN0GKiwsVpVaaMIi9IXE2Cp5olL_q9sowNGW86qzUc';

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
