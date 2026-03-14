import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:tracker_app/core/services/api_client.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tracker_app/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Arka plan izole alanında Firebase'i tekrar başlatmak zorunluyuz
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode) {
    print("🌙 Arka Plan Bildirimi: ${message.messageId}");
    print("Başlık: ${message.notification?.title}");
  }
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final StreamController<RemoteMessage> _notificationStreamController =
      StreamController<RemoteMessage>.broadcast();

  static Stream<RemoteMessage> get onNotificationReceived =>
      _notificationStreamController.stream;

  // Android için yüksek öncelikli kanal tanımı
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'Yüksek Öncelikli Bildirimler', // title
    description: 'Önemli takip bildirimleri için kullanılır.', // description
    importance: Importance.max,
  );

  static Future<void> initialize() async {
    try {
      // 1. İzinleri İste (iOS & Android 13+)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        print('🔔 Bildirim Durumu: ${settings.authorizationStatus}');
      }

      // 2. iOS İçin Ön Planda Bildirim Ayarları
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Android Kanalını Oluştur
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(_channel);
      }

      // 4. Local Notifications Başlat (Ön planda banner göstermek için)
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _localNotifications.initialize(initializationSettings);

      // 5. Arka Plan Handler Kaydet
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // 6. Token Al ve Sunucuya Gönder
      String? token = await _messaging.getToken();
      if (token != null) {
        await _updateTokenOnServer(token);
      }

      // 7. Token Yenilenmesini Dinle
      _messaging.onTokenRefresh.listen((newToken) {
        _updateTokenOnServer(newToken);
      });

      // 8. ÖN PLAN (Foreground) - Bildirim Uygulama Açıkken Gelirse
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        // Bildirim varsa ve Android ise manuel banner gösteriyoruz
        if (notification != null && android != null && !kIsWeb) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                icon: '@mipmap/ic_launcher',
                priority: Priority.high,
                importance: Importance.max,
              ),
            ),
          );
        }

        _notificationStreamController.add(message);
      });

      // 9. ARKA PLAN (Background) - Bildirime Tıklayıp Açınca
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('📂 Bildirime tıklandı (Background -> Foreground)');
        }
        // Gerekirse navigasyon burada yapılabilir
      });

      // 10. KAPALI DURUM (Terminated) - Uygulama Tamamen Kapalıyken Tıklanırsa
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        if (kDebugMode) {
          print('🚀 Uygulama kapalıyken bildirime tıklandı!');
        }
        // Gerekirse navigasyon burada yapılabilir
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Bildirim Servisi Hatası: $e');
      }
    }
  }

  static Future<void> _updateTokenOnServer(String token) async {
    try {
      if (kDebugMode) {
        print('🔑 FCM Token: $token');
      }
      // Sunucuya gönder
      await ApiClient.updateProfile({'fcmToken': token});
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Token sunucuya iletilemedi: $e');
      }
    }
  }
}
