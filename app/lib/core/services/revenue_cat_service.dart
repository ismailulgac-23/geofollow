import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RevenueCat Service — GeoFollow
//
// Products (App Store):
//   pro_1month  → PRO (1 Month)
//   pro_1week   → PRO (1 Week)
//
// Entitlement: "premium"
// Offering   : "default" (RevenueCat Dashboard → Offerings)
// ─────────────────────────────────────────────────────────────────────────────

class RevenueCatService {
  RevenueCatService._();

  // ── API Keys ───────────────────────────────────────────────────────────────
  static const String _appleApiKey = 'appl_yJZMlNzbdEMitarBXJbkQsYdYHT';
  static const String _googleApiKey =
      'goog_xxxxxxxxxxxxxxxxxxxxxxxxxx'; // Android için sonra

  // ── Identifiers ────────────────────────────────────────────────────────────
  static const String entitlementId = 'premium';
  static const String weeklyProductId = 'pro_1week';
  static const String monthlyProductId = 'pro_1month';

  // ── State ──────────────────────────────────────────────────────────────────
  static bool _initialized = false;

  // ─────────────────────────────────────────────────────────────────────────
  // Initialization — main() içinde çağrılır
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> init({String? userId}) async {
    if (_initialized) return;

    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);

    final config = PurchasesConfiguration(
      Platform.isIOS ? _appleApiKey : _googleApiKey,
    )..appUserID = userId;

    await Purchases.configure(config);
    _initialized = true;
    debugPrint('[RevenueCat] ✅ Initialized. User: ${userId ?? "anonymous"}');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Customer Info
  // ─────────────────────────────────────────────────────────────────────────

  /// Kullanıcının aktif premium entitlement'ı var mı?
  static Future<bool> isPremium() async {
    try {
      final info = await Purchases.getCustomerInfo();
      final active = info.entitlements.active.containsKey(entitlementId);
      debugPrint('[RevenueCat] isPremium: $active');
      /* TODO */
      return active;
    } catch (e) {
      debugPrint('[RevenueCat] isPremium error: $e');
      return false;
    }
  }

  /// RevenueCat durumunu backend ile senkronize eder.
  static Future<bool> checkAndSyncPremiumStatus() async {
    try {
      final premium = await isPremium();
      /* TODO */
      final result = await ApiClient.syncPremiumStatus(premium);
      final success = result['success'] == true;
      debugPrint(
        '[RevenueCat] Premium status synced to backend: $premium (Success: $success)',
      );
      return success;
    } catch (e) {
      debugPrint('[RevenueCat] checkAndSyncPremiumStatus error: $e');
      return false;
    }
  }

  /// Aktif abonelik detaylarını döner. Premium değilse null.
  static Future<SubscriptionInfo?> getSubscriptionInfo() async {
    try {
      final info = await Purchases.getCustomerInfo();
      final ent = info.entitlements.active[entitlementId];
      if (ent == null) return null;

      debugPrint('[RevenueCat] Active entitlement: ${ent.productIdentifier}');
      return SubscriptionInfo(
        productIdentifier: ent.productIdentifier,
        expirationDate: ent.expirationDate,
        originalPurchaseDate: ent.originalPurchaseDate,
        isActive: ent.isActive,
        willRenew: ent.willRenew,
        periodType: ent.periodType,
        store: ent.store,
      );
    } catch (e) {
      debugPrint('[RevenueCat] getSubscriptionInfo error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Offerings
  // ─────────────────────────────────────────────────────────────────────────

  /// RevenueCat'taki "default" offering'i döner.
  static Future<Offerings?> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      debugPrint(
        '[RevenueCat] Offerings fetched. Current: ${offerings.current?.identifier}',
      );
      return offerings;
    } catch (e) {
      debugPrint('[RevenueCat] getOfferings error: $e');
      return null;
    }
  }

  /// Offering'den weekly paketini bul
  static Package? weeklyPackage(Offering? offering) {
    if (offering == null) return null;
    // Önce weekly'yi dene, yoksa identifier'a göre ara
    if (offering.weekly != null) return offering.weekly;
    return offering.availablePackages.firstWhere(
      (p) => p.storeProduct.identifier == weeklyProductId,
      orElse: () => offering.availablePackages.first,
    );
  }

  /// Offering'den monthly paketini bul
  static Package? monthlyPackage(Offering? offering) {
    if (offering == null) return null;
    if (offering.monthly != null) return offering.monthly;
    return offering.availablePackages.firstWhere(
      (p) => p.storeProduct.identifier == monthlyProductId,
      orElse: () => offering.availablePackages.first,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Purchase
  // ─────────────────────────────────────────────────────────────────────────

  /// Belirtilen PackageType'ı satın al.
  static Future<PurchaseResult> purchasePackage(Package package) async {
    try {
      debugPrint('[RevenueCat] Purchasing: ${package.storeProduct.identifier}');

      final customerInfo = await Purchases.purchasePackage(package);
      final success = customerInfo.entitlements.active.containsKey(
        entitlementId,
      );
      debugPrint('[RevenueCat] Purchase result: success=$success');
      return PurchaseResult(success: success, customerInfo: customerInfo);
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('[RevenueCat] Purchase cancelled by user');
        return const PurchaseResult(success: false, cancelled: true);
      }
      debugPrint('[RevenueCat] Purchase error: $e');
      return PurchaseResult(success: false, error: e.toString());
    } catch (e) {
      debugPrint('[RevenueCat] Purchase exception: $e');
      return PurchaseResult(success: false, error: e.toString());
    }
  }

  /// Önceki satın alımları geri yükle.
  static Future<PurchaseResult> restorePurchases() async {
    try {
      debugPrint('[RevenueCat] Restoring purchases...');
      final info = await Purchases.restorePurchases();
      final success = info.entitlements.active.containsKey(entitlementId);
      debugPrint('[RevenueCat] Restore result: success=$success');
      return PurchaseResult(success: success, customerInfo: info);
    } catch (e) {
      debugPrint('[RevenueCat] Restore error: $e');
      return PurchaseResult(success: false, error: e.toString());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Identity — kullanıcı bazlı subscription yönetimi
  // ─────────────────────────────────────────────────────────────────────────

  /// Kullanıcı giriş yaptığında — kendi satın alımlarını tanısın
  static Future<void> logIn(String userId) async {
    try {
      final result = await Purchases.logIn(userId);
      debugPrint('[RevenueCat] LogIn: $userId | isNew=${result.created}');
    } catch (e) {
      debugPrint('[RevenueCat] logIn error: $e');
    }
  }

  /// Kullanıcı çıkış yaptığında — anonymous moda geç
  static Future<void> logOut() async {
    try {
      await Purchases.logOut();
      debugPrint('[RevenueCat] LogOut: anonymous mode');
    } catch (e) {
      debugPrint('[RevenueCat] logOut error: $e');
    }
  }

  /// RevenueCat'i sıfırla (re-initialize gerektiğinde)
  static void reset() => _initialized = false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionInfo {
  final String productIdentifier;
  final String? expirationDate;
  final String? originalPurchaseDate;
  final bool isActive;
  final bool willRenew;
  final PeriodType periodType;
  final Store store;

  const SubscriptionInfo({
    required this.productIdentifier,
    required this.expirationDate,
    required this.originalPurchaseDate,
    required this.isActive,
    required this.willRenew,
    required this.periodType,
    required this.store,
  });

  bool get isWeekly =>
      productIdentifier == RevenueCatService.weeklyProductId ||
      productIdentifier.contains('week');
  bool get isMonthly =>
      productIdentifier == RevenueCatService.monthlyProductId ||
      productIdentifier.contains('month');

  String get planLabel => isWeekly ? 'PRO (1 Week)' : 'PRO (1 Month)';
  String get planLabelTr => isWeekly ? 'PRO (1 Hafta)' : 'PRO (1 Ay)';

  String? get expirationFormatted {
    if (expirationDate == null) return null;
    try {
      final dt = DateTime.parse(expirationDate!).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return expirationDate;
    }
  }

  String get storeLabel {
    switch (store) {
      case Store.appStore:
        return 'App Store';
      case Store.playStore:
        return 'Google Play';
      default:
        return store.name;
    }
  }
}

class PurchaseResult {
  final bool success;
  final bool cancelled;
  final String? error;
  final CustomerInfo? customerInfo;

  const PurchaseResult({
    required this.success,
    this.cancelled = false,
    this.error,
    this.customerInfo,
  });
}
