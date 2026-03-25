import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tracker_app/core/services/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GeofenceEvent — Bir alana girme/çıkma olayı
// ─────────────────────────────────────────────────────────────────────────────

enum GeofenceEventType { entered, exited, dwelling }

class GeofenceEvent {
  final String placeId;
  final String placeName;
  final GeofenceEventType type;
  final LatLng userLocation;
  final double distanceMeters;
  final DateTime timestamp;

  const GeofenceEvent({
    required this.placeId,
    required this.placeName,
    required this.type,
    required this.userLocation,
    required this.distanceMeters,
    required this.timestamp,
  });

  @override
  String toString() {
    final typeStr = type == GeofenceEventType.entered
        ? 'ENTERED'
        : type == GeofenceEventType.exited
        ? 'EXITED'
        : 'DWELLING';
    return '[Geofence] $typeStr → $placeName '
        '(dist: ${distanceMeters.toStringAsFixed(1)}m) '
        'at ${timestamp.toIso8601String()}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LocationLog — Geçmiş kayıtları için log modeli
// ─────────────────────────────────────────────────────────────────────────────

class LocationLog {
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String? address;
  final double speed;
  final double accuracy;
  final List<String> nearbyPlaces; // O an yakın olan yer isimleri
  final GeofenceEvent? event; // Geofence olayı varsa

  const LocationLog({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.speed,
    required this.accuracy,
    this.nearbyPlaces = const [],
    this.event,
  });

  @override
  String toString() {
    return '[LocationLog] ${timestamp.toIso8601String()} '
        '(${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}) '
        'speed:${speed.toStringAsFixed(1)}m/s acc:${accuracy.toStringAsFixed(1)}m '
        '${nearbyPlaces.isNotEmpty ? "near:[${nearbyPlaces.join(', ')}]" : ""} '
        '${event != null ? "EVENT:${event!}" : ""}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PlaceGeofence — Bir yerin geofence durumu
// ─────────────────────────────────────────────────────────────────────────────

class PlaceGeofence {
  final String placeId;
  final String placeName;
  final double latitude;
  final double longitude;
  final double radius; // Metre cinsinden yarıçap
  bool isInsideNow;
  DateTime? enteredAt;
  int visitCount;

  PlaceGeofence({
    required this.placeId,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.isInsideNow = false,
    this.enteredAt,
    this.visitCount = 0,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// LocationService — Ana konum ve geofence yöneticisi
// ─────────────────────────────────────────────────────────────────────────────

class LocationService {
  // Singleton
  static final LocationService instance = LocationService._internal();
  LocationService._internal();

  // Aktif geofence'lar (API'den yüklenen yerler)
  final List<PlaceGeofence> _geofences = [];

  // Event stream — UI bu stream'i dinleyebilir
  final StreamController<GeofenceEvent> _eventStream =
      StreamController<GeofenceEvent>.broadcast();
  Stream<GeofenceEvent> get geofenceEvents => _eventStream.stream;

  // In-memory log (Debug / geliştirme için)
  final List<LocationLog> _logs = [];
  List<LocationLog> get logs => List.unmodifiable(_logs);

  // Son bilinen konum
  Position? _lastPosition;
  Position? get lastPosition => _lastPosition;

  // Periyodik konum güncelleme timer'ı
  Timer? _locationTimer;
  bool _isRunning = false;

  static const int _updateIntervalSeconds =
      3; // 3 saniyede bir güncellenerek "anlık" hissi verir

  // Real-time position stream
  final StreamController<Position> _positionStreamController =
      StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionStreamController.stream;

  StreamSubscription<Position>? _positionSubscription;

  // ── Başlat ──────────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_isRunning) return;

    final hasPermission = await _requestPermission();
    if (!hasPermission) {
      _log('[LocationService] Permission denied, cannot start.');
      return;
    }

    _isRunning = true;
    _log('[LocationService] ▶ Started (interval: ${_updateIntervalSeconds}s)');

    // 1. Initial immediate tick
    await _tick();

    // 2. Periodic tick for API and geofences (consistency)
    _locationTimer = Timer.periodic(
      Duration(seconds: _updateIntervalSeconds),
      (_) => _tick(),
    );

    // 3. REAL-TIME STREAM for "Shak" (instant) local UI updates
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 2, // 2 meters change triggers a stream update
          ),
        ).listen((Position position) {
          _lastPosition = position;
          _positionStreamController.add(position);
        });
  }

  /// Background location plugin koordinat verdiğinde tetiklenir.
  /// Artık tüm analiz API tarafında yapıldığı için sadece konumu merkeze bildirir.
  Future<void> triggerManualTick({
    required double latitude,
    required double longitude,
    double speed = 0,
    double accuracy = 0,
  }) async {
    try {
      final now = DateTime.now();

      // Adres çözümle
      String? address;
      try {
        final placemarks = await placemarkFromCoordinates(latitude, longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [
            if (p.street != null && p.street!.isNotEmpty) p.street,
            if (p.subLocality != null && p.subLocality!.isNotEmpty)
              p.subLocality,
            if (p.locality != null && p.locality!.isNotEmpty) p.locality,
          ];
          address = parts.join(', ');
        }
      } catch (_) {}

      final logEntry = LocationLog(
        timestamp: now,
        latitude: latitude,
        longitude: longitude,
        address: address,
        speed: speed,
        accuracy: accuracy,
      );
      _logs.add(logEntry);
      if (_logs.length > 500) _logs.removeRange(0, _logs.length - 500);

      _log(
        '[LocationService] 📡 ManualTick (${latitude.toStringAsFixed(5)}, '
        '${longitude.toStringAsFixed(5)}) -> Server handles geofencing.',
      );

      // API'ye konum güncelle (Backend geofence kontrolünü kendisi yapacak)
      await ApiClient.updateLocation(
        latitude: latitude,
        longitude: longitude,
        address: address,
        speed: speed,
        accuracy: accuracy,
      );
    } catch (e) {
      _log('[LocationService] ❌ ManualTick error: $e');
    }
  }

  Future<void> stop() async {
    _locationTimer?.cancel();
    _locationTimer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isRunning = false;
    _log('[LocationService] ⏹ Stopped');
  }

  bool get isRunning => _isRunning;

  // ── Geofence Yükleme (Deprecated - API Handle Ediyor) ────────────────

  void loadGeofences(List<Map<String, dynamic>> places) {
    // Mobil tarafta geofence kontrolü kaldırıldı, her şey API tarafında.
    _log('[LocationService] Geofence monitoring is now handled by the API.');
  }

  // ── Ana Tick ────────────────────────────────────────────────────────────

  Future<void> _tick() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final lat = position.latitude;
      final lng = position.longitude;
      final speed = position.speed; // m/s
      final accuracy = position.accuracy; // metre
      final now = DateTime.now();

      // Adres çözümle
      String? address;
      try {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [
            if (p.street != null && p.street!.isNotEmpty) p.street,
            if (p.subLocality != null && p.subLocality!.isNotEmpty)
              p.subLocality,
            if (p.locality != null && p.locality!.isNotEmpty) p.locality,
          ];
          address = parts.join(', ');
        }
      } catch (_) {}

      // Konum logu
      final logEntry = LocationLog(
        timestamp: now,
        latitude: lat,
        longitude: lng,
        address: address,
        speed: speed,
        accuracy: accuracy,
      );
      _logs.add(logEntry);

      if (_logs.length > 500) _logs.removeRange(0, _logs.length - 500);

      _log(
        '[LocationService] 📍 (${lat.toStringAsFixed(5)}, '
        '${lng.toStringAsFixed(5)}) | $address',
      );

      // API'ye konum güncelle
      await ApiClient.updateLocation(
        latitude: lat,
        longitude: lng,
        address: address,
        speed: speed,
        accuracy: accuracy,
      );

      _lastPosition = position;
    } catch (e) {
      _log('[LocationService] ❌ Tick error: $e');
    }
  }

  // ── Tek seferlik mevcut konum al ────────────────────────────────────────

  static Future<Position?> getCurrentPosition({
    Duration timeout = const Duration(seconds: 15),
    bool useLastKnownAsFallback = true,
  }) async {
    try {
      // 0. Permission check
      final hasPermission = await _requestPermission();
      if (!hasPermission) return null;

      if (kDebugMode)
        print(
          '[LocationService] Waiting for EXACT device location from stream with ${timeout.inSeconds}s timeout...',
        );

      Position? fresh;
      try {
        fresh = await Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
          ),
        ).first.timeout(timeout);
      } catch (streamError) {
        if (kDebugMode)
          print('[LocationService] Stream timeout/error: $streamError. Trying forced getCurrentPosition...');
        
        // 1. Eğer stream timeout olursa, normal metod ile zorla (kısa bir süre daha tanı)
        try {
          fresh = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: const Duration(seconds: 5), // Maksimum 5 saniye daha ver
          );
        } catch (currentPosError) {
           if (kDebugMode) print('[LocationService] Forced getCurrentPosition failed: $currentPosError');
           rethrow; // Dışarıdaki catch bloğuna (Fallback kısmına) gitsin
        }
      }

      instance._lastPosition = fresh;
      return fresh;
    } catch (e) {
      if (kDebugMode) print('[LocationService] Final fallback triggered due to: $e');

      // 2. Son bilinen konumu dene (Daha gerçekçi olur)
      try {
        Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          instance._lastPosition = lastKnown;
          if (kDebugMode) print('[LocationService] Fallback to lastKnown success.');
          return lastKnown;
        }
      } catch (_) {}

      // 3. O da yoksa 0,0 dön (Kullanıcının kesin isteği)
      if (kDebugMode) print('[LocationService] No location found anywhere. Returning 0.0, 0.0 as requested.');
      return Position(
        latitude: 0.0,
        longitude: 0.0,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }
  }

  /// Backward compat: tek seferlik güncelle (HomeScreen ilk yüklemede çağırır)
  static Future<void> updateCurrentLocation() async {
    await instance._tick();
  }

  // ── İzin ────────────────────────────────────────────────────────────────

  static Future<bool> _requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  // ── Haversine mesafe (metre) ─────────────────────────────────────────────

  // ── Debug log ───────────────────────────────────────────────────────────

  void _log(String message) {
    if (kDebugMode) print(message);
  }
}
