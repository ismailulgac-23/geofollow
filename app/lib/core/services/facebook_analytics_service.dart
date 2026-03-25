import 'package:facebook_app_events/facebook_app_events.dart';

class FacebookAnalyticsService {
  static final facebookAppEvents = FacebookAppEvents();

  /// 1. App Activation (Standard: fb_mobile_activate_app)
  static Future<void> logAppActivated() async {
    try {
      await facebookAppEvents.activateApp();
      print("[FACEBOOK] App Activated");
    } catch (e) {
      print("[FACEBOOK ERROR] App Activation: $e");
    }
  }

  /// 2. Advanced Matching (Critically important for ad attribution)
  static Future<void> setUserData({
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    String? city,
  }) async {
    try {
      await facebookAppEvents.setUserData(
        email: email,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        city: city,
      );
      print("[FACEBOOK] User Data Set (Advanced Matching)");
    } catch (e) {
      print("[FACEBOOK ERROR] Set User Data: $e");
    }
  }

  /// 3. Clear User Data
  static Future<void> clearUserData() async {
    try {
      await facebookAppEvents.clearUserData();
      print("[FACEBOOK] User Data Cleared");
    } catch (e) {
      print("[FACEBOOK ERROR] Clear User Data: $e");
    }
  }

  /// 4. Complete Registration (Standard: fb_mobile_complete_registration)
  static Future<void> logCompleteRegistration({
    String? registrationMethod,
  }) async {
    try {
      await facebookAppEvents.logCompletedRegistration(
        registrationMethod: registrationMethod ?? "Email",
      );
      print("[FACEBOOK] Event: Complete Registration ($registrationMethod)");
    } catch (e) {
      print("[FACEBOOK ERROR] Complete Registration: $e");
    }
  }

  /// 5. Subscribe (Helper: logSubscribe)
  static Future<void> logSubscribe({
    required double amount,
    required String currency,
    required String orderId,
  }) async {
    try {
      await facebookAppEvents.logSubscribe(
        price: amount,
        currency: currency,
        orderId: orderId,
      );
      print("[FACEBOOK] Event: Subscribe ($amount $currency, Order: $orderId)");
    } catch (e) {
      print("[FACEBOOK ERROR] Subscribe: $e");
    }
  }

  /// 6. Start Trial (Helper: logStartTrial)
  static Future<void> logStartTrial({
    required double amount,
    required String currency,
    required String orderId,
  }) async {
    try {
      await facebookAppEvents.logStartTrial(
        price: amount,
        currency: currency,
        orderId: orderId,
      );
      print(
        "[FACEBOOK] Event: Start Trial ($amount $currency, Order: $orderId)",
      );
    } catch (e) {
      print("[FACEBOOK ERROR] Start Trial: $e");
    }
  }

  /// 7. Purchase (Helper: logPurchase)
  static Future<void> logPurchase({
    required double amount,
    required String currency,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await facebookAppEvents.logPurchase(
        amount: amount,
        currency: currency,
        parameters: parameters,
      );
      print("[FACEBOOK] Event: Purchase ($amount $currency)");
    } catch (e) {
      print("[FACEBOOK ERROR] Purchase: $e");
    }
  }

  /// 8. Initiate Checkout (Helper: logInitiatedCheckout)
  static Future<void> logInitiatedCheckout({
    double? amount,
    String? currency,
    String? contentId,
    String? contentType,
  }) async {
    try {
      await facebookAppEvents.logInitiatedCheckout(
        totalPrice: amount,
        currency: currency,
        contentId: contentId,
        contentType: contentType,
      );
      print("[FACEBOOK] Event: Initiate Checkout ($amount $currency)");
    } catch (e) {
      print("[FACEBOOK ERROR] Initiate Checkout: $e");
    }
  }

  /// 9. Custom Event: Account Deleted
  static Future<void> logAccountDeleted() async {
    try {
      await facebookAppEvents.logEvent(
        name: "account_deleted",
        parameters: {"deletion_date": DateTime.now().toIso8601String()},
      );
      print("[FACEBOOK] Event: Account Deleted");
    } catch (e) {
      print("[FACEBOOK ERROR] Account Deleted: $e");
    }
  }
  /// 10. Set Advertiser Tracking (iOS 14.5+)
  static Future<void> setAdvertiserTracking(bool enabled) async {
    try {
      await facebookAppEvents.setAdvertiserTracking(enabled: enabled);
      print("[FACEBOOK] Advertiser Tracking Enabled: $enabled");
    } catch (e) {
      print("[FACEBOOK ERROR] Set Advertiser Tracking: $e");
    }
  }
}
