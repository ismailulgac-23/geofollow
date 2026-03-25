import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tracker_app/core/theme/app_theme.dart';
import 'package:tracker_app/l10n/app_localizations.dart';
import 'package:tracker_app/core/services/facebook_analytics_service.dart';

class AttService {
  AttService._();

  static Future<void> checkAndRequest(BuildContext context) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      if (!context.mounted) return;
      final agreed = await showDisclosure(context);
      if (agreed) {
        final newStatus =
            await AppTrackingTransparency.requestTrackingAuthorization();
        if (newStatus == TrackingStatus.authorized) {
          FacebookAnalyticsService.setAdvertiserTracking(true);
        } else {
          FacebookAnalyticsService.setAdvertiserTracking(false);
        }
      }
    } else if (status == TrackingStatus.authorized) {
      FacebookAnalyticsService.setAdvertiserTracking(true);
    } else {
      FacebookAnalyticsService.setAdvertiserTracking(false);
    }
  }

  static Future<bool> showDisclosure(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => PopScope(
            canPop: false,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: AppTheme.primaryColor,
                        size: 32,
                      ),
                    ).animate().scale(
                          duration: 600.ms,
                          curve: Curves.elasticOut,
                        ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.appTracking,
                      style: AppTheme.heading3.copyWith(
                        color: Colors.white,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.trackingStepText,
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        height: 1.5,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(
                        l10n.continueBtn,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ) ??
        false;
  }
}
