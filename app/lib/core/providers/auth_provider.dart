import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tracker_app/core/models/user_model.dart';
import 'package:tracker_app/core/providers/providers.dart';
import 'package:tracker_app/core/services/api_client.dart';
import 'package:tracker_app/core/services/location_service.dart';
import 'package:tracker_app/core/services/revenue_cat_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

// Auth state
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  needsRegistration,
}

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;
  final String? registrationEmail;
  final String? registrationName;
  final String? registrationAvatarUrl;
  final bool isTestMode;

  AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.registrationEmail,
    this.registrationName,
    this.registrationAvatarUrl,
    this.isTestMode = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? error,
    String? registrationEmail,
    String? registrationName,
    String? registrationAvatarUrl,
    bool? isTestMode,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: clearError ? null : (error ?? this.error),
      registrationEmail: registrationEmail ?? this.registrationEmail,
      registrationName: registrationName ?? this.registrationName,
      registrationAvatarUrl:
          registrationAvatarUrl ?? this.registrationAvatarUrl,
      isTestMode: isTestMode ?? this.isTestMode,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  StreamSubscription<bool>? _premiumSubscription;

  AuthNotifier() : super(AuthState()) {
    _listenToPremiumStatus();
  }

  void _listenToPremiumStatus() {
    _premiumSubscription?.cancel();
    _premiumSubscription = RevenueCatService.premiumStatusStream.listen((
      isPremium,
    ) {
      if (state.user != null && state.user!.isPremium != isPremium) {
        state = state.copyWith(
          user: state.user!.copyWith(isPremium: isPremium),
        );
        debugPrint(
          '[AuthNotifier] 🔄 Premium status updated from RevenueCat Stream: $isPremium',
        );
      }
    });
  }

  @override
  void dispose() {
    _premiumSubscription?.cancel();
    super.dispose();
  }

  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      // Check if we have a valid token from our API
      final token = await ApiClient.getToken();
      if (token == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      final response = await ApiClient.getMe();

      if (response['success'] == true && response['data'] != null) {
        final userData = response['data'];
        final user = UserModel(
          id: userData['id'],
          email: userData['email'] ?? '',
          name: userData['name'],
          avatarUrl: userData['avatarUrl'] ?? '',
          status: userData['status'] ?? '',
          statusEmoji: userData['statusEmoji'],
          batteryLevel: userData['batteryLevel'] ?? 100,
          lastUpdated: DateTime.now(),
          location:
              userData['latitude'] != null && userData['longitude'] != null
              ? LatLng(userData['latitude'], userData['longitude'])
              : const LatLng(41.0082, 28.9784),
          address: userData['address'] ?? '',
          isOnline: userData['isOnline'] ?? true,
          isPremium: userData['isPremium'] ?? false,
        );
        state = AuthState(status: AuthStatus.authenticated, user: user);

        // RevenueCat — kullanıcı ID ile eşleştir ve premium durumunu senkronize et
        await RevenueCatService.logIn(userData['id'].toString());

        // RevenueCat'ten en güncel durumu al ve backend verisinden üstün tut
        final realPremiumStatus = await RevenueCatService.isPremium();
        if (user.isPremium != realPremiumStatus) {
          state = AuthState(
            status: AuthStatus.authenticated,
            user: user.copyWith(isPremium: realPremiumStatus),
          );
        } else {
          state = AuthState(status: AuthStatus.authenticated, user: user);
        }

        // Backend ile senkronize et (arkaplanda)
        RevenueCatService.syncPremiumStatus(realPremiumStatus);

        // Önbelleğe (cache) al ki network koparsa veya terminate olursa çıkış yapmasın!
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_data', jsonEncode(userData));
      } else {
        // Status code 401 is handled via unauthenticated
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          clearError: true,
        );
      }
    } catch (e) {
      // 🚨 401 UNAUTHORIZED CHECK
      if (e is DioException && e.response?.statusCode == 401) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          clearError: true,
        );
        await ApiClient.logout();
        return;
      }

      // 🚨 NETWORK HATASI VEYA TIMEOUT: Kullanıcıyı DÜŞÜRME!
      final token = await ApiClient.getToken();
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getString('cached_user_data');
        if (cachedData != null) {
          try {
            final userData = jsonDecode(cachedData);
            final user = UserModel(
              id: userData['id'],
              email: userData['email'] ?? '',
              name: userData['name'],
              avatarUrl: userData['avatarUrl'] ?? '',
              status: userData['status'] ?? '',
              statusEmoji: userData['statusEmoji'],
              batteryLevel: userData['batteryLevel'] ?? 100,
              lastUpdated: DateTime.now(),
              location:
                  userData['latitude'] != null && userData['longitude'] != null
                  ? LatLng(userData['latitude'], userData['longitude'])
                  : const LatLng(41.0082, 28.9784),
              address: userData['address'] ?? '',
              isOnline: userData['isOnline'] ?? true,
              isPremium: userData['isPremium'] ?? false,
            );
            state = AuthState(status: AuthStatus.authenticated, user: user);
            return;
          } catch (_) {}
        }

        final userId = await ApiClient.getUserId() ?? '';
        final fallbackUser = UserModel(
          id: userId,
          email: 'offline',
          name: 'Offline Mode',
          avatarUrl: '',
          status: 'Offline',
          batteryLevel: 100,
          lastUpdated: DateTime.now(),
          location: const LatLng(41.0082, 28.9784),
          address: 'Offline',
        );
        state = AuthState(status: AuthStatus.authenticated, user: fallbackUser);
        return;
      }

      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearError: true,
      );
    }
  }

  // Google Sign In
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          clearError: true,
        );
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final String? email = userCredential.user?.email;

      if (email == null) {
        throw Exception('Google Auth email bulunamadı.');
      }

      return await _loginWithEmail(
        email,
        userCredential.user?.displayName,
        userCredential.user?.photoURL,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
      return false;
    }
  }

  // Apple Sign In
  Future<bool> signInWithApple() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final AuthCredential authCredential = oAuthProvider.credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(authCredential);

      // Apple email bilgisi gizlenmiş olabilir
      final String email =
          userCredential.user?.email ??
          credential.email ??
          'apple_${userCredential.user?.uid}@apple.com';

      String? displayName = userCredential.user?.displayName;
      if (displayName == null || displayName.isEmpty) {
        if (credential.givenName != null || credential.familyName != null) {
          displayName =
              '${credential.givenName ?? ''} ${credential.familyName ?? ''}'
                  .trim();
        }
      }

      return await _loginWithEmail(
        email,
        displayName,
        userCredential.user?.photoURL,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
      return false;
    }
  }

  // Register user after setup wizard
  Future<bool> register({required String name, String? avatarUrl}) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    final email = state.registrationEmail;
    if (email == null) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Kayıt için email bulunamadı.',
      );
      return false;
    }

    try {
      Position? position;
      try {
        position = await LocationService.getCurrentPosition(
          timeout: const Duration(seconds: 3),
        );
      } catch (_) {}

      final response = await ApiClient.register(
        email: email,
        name: name,
        avatarUrl: avatarUrl ?? state.registrationAvatarUrl,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      if (response['success'] == true) {
        final data = response['data'];
        await ApiClient.saveToken(data['token'], data['user']['id']);

        final user = UserModel(
          id: data['user']['id'],
          email: data['user']['email'] ?? '',
          name: data['user']['name'],
          avatarUrl: data['user']['avatarUrl'] ?? '',
          status: data['user']['status'] ?? '',
          statusEmoji: data['user']['statusEmoji'],
          batteryLevel: data['user']['batteryLevel'] ?? 100,
          lastUpdated: DateTime.now(),
          location:
              data['user']['latitude'] != null &&
                  data['user']['longitude'] != null
              ? LatLng(data['user']['latitude'], data['user']['longitude'])
              : const LatLng(41.0082, 28.9784),
          address: data['user']['address'] ?? '',
          isOnline: data['user']['isOnline'] ?? true,
          isPremium: data['user']['isPremium'] ?? false,
        );

        state = AuthState(status: AuthStatus.authenticated, user: user);
        await RevenueCatService.logIn(data['user']['id'].toString());

        final realPremiumStatus = await RevenueCatService.isPremium();
        if (user.isPremium != realPremiumStatus) {
          state = state.copyWith(
            user: user.copyWith(isPremium: realPremiumStatus),
          );
        }

        RevenueCatService.syncPremiumStatus(realPremiumStatus);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_data', jsonEncode(data['user']));

        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: response['message'] ?? 'Kayıt başarısız oldu.',
          clearError: false,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
        clearError: false,
      );
      return false;
    }
  }

  // Direct login with email (bypasses Firebase)
  Future<bool> loginWithEmail(String email) async {
    return await _loginWithEmail(email);
  }

  // Password-based login for Reviewers
  Future<bool> loginWithReviewCredentials(String email, String password) async {
    return await _loginWithEmail(email, null, null, password);
  }

  Future<bool> _loginWithEmail(
    String email, [
    String? name,
    String? avatarUrl,
    String? password,
  ]) async {
    try {
      // Get location for proximity simulation
      double? lat;
      double? lng;
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          // Try last known position first for speed
          Position? position = await Geolocator.getLastKnownPosition();

          // If no last known, or if we want fresher, try current with timeout
          position ??= await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );

          lat = position.latitude;
          lng = position.longitude;
        }
      } catch (e) {
        print('Location fetch failed or timed out during login: $e');
        // Ignore location errors during login, backend will use fallback or skip simulation
      }

      final responseData = await ApiClient.loginWithEmail(
        email,
        password: password,
        latitude: lat,
        longitude: lng,
      );

      if (responseData['success'] == true) {
        final data = responseData['data'];
        final isTestMode = data['testMode'] ?? false;

        await ApiClient.saveToken(data['token'], data['user']['id']);

        final user = UserModel(
          id: data['user']['id'],
          email: data['user']['email'] ?? '',
          name: data['user']['name'],
          avatarUrl: data['user']['avatarUrl'] ?? '',
          status: data['user']['status'] ?? '',
          statusEmoji: data['user']['statusEmoji'],
          batteryLevel: data['user']['batteryLevel'] ?? 100,
          lastUpdated: DateTime.now(),
          location:
              data['user']['latitude'] != null &&
                  data['user']['longitude'] != null
              ? LatLng(data['user']['latitude'], data['user']['longitude'])
              : const LatLng(41.0082, 28.9784),
          address: data['user']['address'] ?? '',
          isOnline: data['user']['isOnline'] ?? true,
          isPremium: data['user']['isPremium'] ?? false,
        );

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isTestMode: isTestMode,
          registrationEmail: email,
          clearError: true,
        );
        await RevenueCatService.logIn(data['user']['id'].toString());

        final realPremiumStatus = await RevenueCatService.isPremium();
        if (user.isPremium != realPremiumStatus) {
          state = state.copyWith(
            user: user.copyWith(isPremium: realPremiumStatus),
          );
        }

        RevenueCatService.syncPremiumStatus(realPremiumStatus);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_data', jsonEncode(data['user']));

        return true;
      } else {
        if (responseData['code'] == 'USER_NOT_FOUND') {
          // Trigger setup wizard
          state = state.copyWith(
            status: AuthStatus.needsRegistration,
            registrationEmail: email,
            registrationName: name,
            registrationAvatarUrl: avatarUrl,
            clearError: true,
          );
          return false;
        }

        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: responseData['message'] ?? 'Login failed',
          clearError: false,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await ApiClient.logout();
    await RevenueCatService.logOut(); // RevenueCat anonymous moda geçirir
    state = AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

// Convenience providers
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.authenticated;
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});
