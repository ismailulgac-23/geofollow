import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracker_app/core/services/background_location_service.dart';

class ApiClient {
  static late final Dio _dio;
  static const String baseUrl = 'https://api.geofollow.xyz/api';

  static Future<void> init() async {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token to requests
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          final locale = prefs.getString('selected_locale') ?? 'en';
          options.headers['Accept-Language'] = locale;

          if (kDebugMode) {
            print('REQUEST[${options.method}] => PATH: ${options.path}');
            print('DATA: ${options.data}');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            print(
              'RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}',
            );
            print('DATA: ${response.data}');
          }
          return handler.next(response);
        },
        onError: (error, handler) {
          if (kDebugMode) {
            print(
              'ERROR[${error.response?.statusCode}] => PATH: ${error.requestOptions.path}',
            );
            print('MESSAGE: ${error.message}');
            print('DATA: ${error.response?.data}');
          }
          return handler.next(error);
        },
      ),
    );
  }

  static Dio get dio => _dio;

  // Auth endpoints - Login with email (after Firebase auth)
  static Future<Map<String, dynamic>> loginWithEmail(
    String email, {
    String? password,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
          'lat': latitude,
          'lng': longitude,
        },
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  // Register endpoint
  static Future<Map<String, dynamic>> register({
    required String email,
    required String name,
    String? avatarUrl,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'email': email,
          'name': name,
          'avatarUrl': avatarUrl,
          'lat': latitude,
          'lng': longitude,
        },
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/auth/me');
    return response.data;
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put('/users/me', data: data);
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateLocation({
    required double latitude,
    required double longitude,
    String? address,
    double? speed,
    double? accuracy,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return {'success': false, 'code': 'NO_USER'};
      final response = await _dio.put(
        '/users/$userId/location',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          if (address != null) 'address': address,
          if (speed != null) 'speed': speed,
          if (accuracy != null) 'accuracy': accuracy,
          'lastUpdated': DateTime.now().toIso8601String(),
        },
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      return {'success': false, 'code': 'NETWORK_ERROR'};
    }
  }

  static Future<Map<String, dynamic>> reportGeofenceEvent({
    required String placeId,
    required String placeName,
    required String eventType,
    required double latitude,
    required double longitude,
    String? address,
    String? timestamp,
  }) async {
    try {
      final response = await _dio.post(
        '/users/me/geofence-event',
        data: {
          'placeId': placeId,
          'placeName': placeName,
          'eventType': eventType,
          'latitude': latitude,
          'longitude': longitude,
          if (address != null) 'address': address,
          'timestamp': timestamp ?? DateTime.now().toIso8601String(),
        },
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      return {'success': false, 'code': 'NETWORK_ERROR'};
    }
  }

  static Future<Map<String, dynamic>> sendSOS() async {
    try {
      final response = await _dio.post('/users/sos');
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> nudgeUser(String userId) async {
    try {
      final response = await _dio.post('/users/$userId/nudge');
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> sendMessageToUser(
    String userId,
    String message,
  ) async {
    try {
      final response = await _dio.post(
        '/users/$userId/message',
        data: {'message': message},
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  // Circle endpoints
  static Future<Map<String, dynamic>> getCircle() async {
    try {
      final response = await _dio.get('/circles');
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createCircle(String name) async {
    try {
      final response = await _dio.post('/circles', data: {'name': name});
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> joinCircle(String code) async {
    try {
      final response = await _dio.post('/circles/join', data: {'code': code});
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> leaveCircle(String id) async {
    try {
      final response = await _dio.post('/circles/$id/leave');
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  // Place endpoints
  static Future<Map<String, dynamic>> createPlace(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post('/places', data: data);
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updatePlace(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put('/places/$id', data: data);
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateBatteryLevel(int level) async {
    try {
      final response = await _dio.put(
        '/users/me',
        data: {'batteryLevel': level},
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> deletePlace(String id) async {
    try {
      final response = await _dio.delete('/places/$id');
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> syncPremiumStatus(bool isPremium) async {
    try {
      final response = await _dio.post(
        '/users/premium',
        data: {'isPremium': isPremium},
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final response = await _dio.delete('/users/me');
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getMovementHistory(
    String userId, {
    String type = 'today',
    int limit = 30,
  }) async {
    try {
      final response = await _dio.get(
        '/users/$userId/history?type=$type&limit=$limit',
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      return {'success': false, 'code': 'NETWORK_ERROR'};
    }
  }

  static Future<Map<String, dynamic>> getMyMovementHistory({
    String type = 'today',
    int limit = 30,
  }) async {
    try {
      final response = await _dio.get(
        '/users/me/history?type=$type&limit=$limit',
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      return {'success': false, 'code': 'NETWORK_ERROR'};
    }
  }

  static Future<Map<String, dynamic>> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    return {'success': true};
  }

  // Notifications
  static Future<Map<String, dynamic>> getNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/notifications?limit=$limit&offset=$offset',
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> markNotificationAsRead(String id) async {
    try {
      final response = await _dio.put('/notifications/$id/read');
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    try {
      final response = await _dio.put('/notifications/read-all');
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        return e.response!.data;
      }
      rethrow;
    }
  }

  static Future<void> saveToken(String token, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_id', userId);
    await BackgroundLocationService.updateAuthToken(token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  // Onboarding
  static Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
  }

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_complete') ?? false;
  }
}
