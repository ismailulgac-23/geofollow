import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracker_app/core/services/api_client.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // API Client başlat (Top-level olduğu için burada tekrar init gerekir)
  await ApiClient.init();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // ── Periyodik Takip Başlat ──────────────────────────────────────────────

  final appleSettings = AppleSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 10,
    pauseLocationUpdatesAutomatically: false,
    showBackgroundLocationIndicator: true,
    allowBackgroundLocationUpdates: true,
    activityType: ActivityType.otherNavigation,
  );

  final androidSettings = AndroidSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 10,
    forceLocationManager: false,
    intervalDuration: const Duration(seconds: 3),
    foregroundNotificationConfig: const ForegroundNotificationConfig(
      notificationText: "Konumunuz paylaşılıyor",
      notificationTitle: "Alveron",
      enableWakeLock: true,
    ),
  );

  StreamSubscription<Position>? positionStream;

  positionStream =
      Geolocator.getPositionStream(
        locationSettings: kIsWeb
            ? const LocationSettings()
            : (defaultTargetPlatform == TargetPlatform.android
                  ? androidSettings
                  : appleSettings),
      ).listen((Position position) async {
        try {
          // Guard: Ensure we have a valid user ID before updating
          final prefs = await SharedPreferences.getInstance();
          final userId = prefs.getString('user_id');
          final token = prefs.getString('auth_token');
          
          if (userId == null || userId.isEmpty || token == null || token.isEmpty) {
            if (kDebugMode) print('[BG-SERVICE] Skip update: No valid user yet');
            return;
          }

          await ApiClient.updateLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            speed: position.speed,
            accuracy: position.accuracy,
          );

          if (service is AndroidServiceInstance) {
            if (await service.isForegroundService()) {
              service.setForegroundNotificationInfo(
                title: "Alveron Aktif",
                content:
                    "Son güncelleme: ${DateTime.now().hour}:${DateTime.now().minute}",
              );
            }
          }
        } catch (e) {
          if (kDebugMode) print('[BG-SERVICE] Update Error: $e');
        }
      });

  service.on('stopService').listen((event) {
    positionStream?.cancel();
  });
}

/// 100% ÜCRETSİZ ve GÜNCEL Arka Plan Konum Servisi
/// flutter_background_service + geolocator kullanır.
class BackgroundLocationService {
  static const String notificationChannelId = 'location_foreground_service';
  static const int notificationId = 888;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Alveron Aktif',
        initialNotificationContent: 'Konum takibi devam ediyor...',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    await service.startService();
  }

  // --- Yardımcı Metodlar ---

  static Future<void> start() async {
    final service = FlutterBackgroundService();
    await service.startService();
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  static Future<bool> requestPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    // After getting base permission, we should ideally check for "Always" if we are in background mode
    // On some platforms, calling requestPermission again might trigger the "Always" prompt if it's "While in use"
    if (permission == LocationPermission.whileInUse) {
      // In some cases, we might need to prompt the user to upgrade to "Always" in settings
      // but let's try requesting again first
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<void> checkAndStart() async {
    final service = FlutterBackgroundService();
    
    // Guard: Only start if user is logged in
    final userId = await ApiClient.getUserId();
    if (userId == null || userId.isEmpty) return;

    if (!await service.isRunning()) {
      await service.startService();
    }
  }

  static Future<void> forceUpdateLocation() async {
    try {
      // Guard: Only update if user is logged in
      final userId = await ApiClient.getUserId();
      if (userId == null || userId.isEmpty) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await ApiClient.updateLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        speed: pos.speed,
        accuracy: pos.accuracy,
      );
    } catch (e) {
      if (kDebugMode) print('Force update error: $e');
    }
  }

  static void updateConfig(dynamic l10n) {}

  static Future<void> updateAuthToken(String token) async {}
}
