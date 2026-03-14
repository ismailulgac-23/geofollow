import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tracker_app/core/providers/auth_provider.dart';
import 'package:tracker_app/core/services/background_location_service.dart';
import 'package:tracker_app/core/services/notification_service.dart';
import 'package:tracker_app/core/theme/app_theme.dart';
import 'package:tracker_app/shared/widgets/glass_container.dart';
import 'package:tracker_app/l10n/app_localizations.dart';

class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  String? _displayName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nameFromSocial = ref.read(authProvider).registrationName;
      if (nameFromSocial != null && nameFromSocial.isNotEmpty) {
        _displayName = nameFromSocial;
      } else {
        _displayName = 'GeoUser#${Random().nextInt(9000) + 1000}';
      }
      setState(() {});
    });
  }

  List<WizardStepData> _getSteps(AppLocalizations l10n) {
    return [
      WizardStepData(
        title: l10n.welcomeName(_displayName ?? ''),
        description: l10n.welcomeDescription,
        icon: FontAwesomeIcons.userAstronaut,
        color: AppTheme.primaryColor,
        contentBuilder: _buildProfileStep,
      ),
      WizardStepData(
        title: l10n.appTracking,
        description: l10n.appTrackingDescription,
        icon: FontAwesomeIcons.shieldHalved,
        color: AppTheme.accentPink,
        contentBuilder: (context, email) =>
            _buildTrackingStep(context, email, l10n),
      ),
      WizardStepData(
        title: l10n.backgroundLocation,
        description: l10n.backgroundLocationDescription,
        icon: FontAwesomeIcons.locationArrow,
        color: AppTheme.accentColor,
        contentBuilder: (context, email) =>
            _buildLocationStep(context, email, l10n),
      ),
      WizardStepData(
        title: l10n.notifications,
        description: l10n.notificationsDescription,
        icon: FontAwesomeIcons.bell,
        color: AppTheme.accentOrange,
        contentBuilder: (context, email) =>
            _buildNotificationStep(context, email, l10n),
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage(int stepsLength) async {
    setState(() => _isLoading = true);

    try {
      if (_currentPage == 1) {
        // Step 1: Data Privacy / Tracking
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          await Permission.appTrackingTransparency.request();
        } else if (defaultTargetPlatform == TargetPlatform.android) {
          // On Android, background apps need battery optimization ignored for stability
          await Permission.ignoreBatteryOptimizations.request();
        }
      } else if (_currentPage == 2) {
        // Step 2: Location
        final granted = await BackgroundLocationService.requestPermissions();
        if (granted) {
          // Optionally start or pre-init service
          await BackgroundLocationService.initialize();
        }
      } else if (_currentPage == 3) {
        // Step 3: Notifications
        if (defaultTargetPlatform == TargetPlatform.android) {
          await Permission.notification.request();
        }
        await NotificationService.initialize();
      }
    } catch (e) {
      debugPrint('Error during permission request: $e');
    } finally {
      setState(() => _isLoading = false);
    }

    if (_currentPage < stepsLength - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishSetup();
    }
  }

  Future<void> _finishSetup() async {
    setState(() => _isLoading = true);
    final success = await ref
        .read(authProvider.notifier)
        .register(name: _displayName ?? '');
    setState(() => _isLoading = false);

    if (success && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final email = ref.watch(authProvider).registrationEmail ?? l10n.user;

    if (_displayName == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final steps = _getSteps(l10n);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildProgressBar(steps.length),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemCount: steps.length,
                  itemBuilder: (context, index) {
                    final step = steps[index];
                    return Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingLG),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: step.color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(step.icon, size: 64, color: step.color),
                          ).animate().scale(
                            duration: 500.ms,
                            curve: Curves.elasticOut,
                          ),
                          const SizedBox(height: AppTheme.spacingXL),
                          Text(
                                step.title,
                                style: AppTheme.heading2.copyWith(
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              )
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideY(begin: 0.2, end: 0),
                          const SizedBox(height: AppTheme.spacingMD),
                          Text(
                                step.description,
                                style: AppTheme.bodyLarge.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              )
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 200.ms)
                              .slideY(begin: 0.2, end: 0),
                          const SizedBox(height: AppTheme.spacingXL),
                          step
                              .contentBuilder(context, email)
                              .animate()
                              .fadeIn(duration: 500.ms, delay: 400.ms)
                              .slideY(begin: 0.2, end: 0),
                          const Spacer(),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : GlassButton(
                                  width: double.infinity,
                                  onPressed: () => _nextPage(steps.length),
                                  gradient: AppTheme.primaryGradient,
                                  child: Text(
                                    _currentPage == steps.length - 1
                                        ? l10n.finishSetup
                                        : l10n.allowAndContinue,
                                    style: AppTheme.button,
                                  ),
                                ).animate().fadeIn(
                                  duration: 500.ms,
                                  delay: 600.ms,
                                ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(int stepsLength) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: Row(
        children: List.generate(stepsLength, (index) {
          final isActive = index <= _currentPage;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: EdgeInsets.only(right: index == stepsLength - 1 ? 0 : 8),
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primaryColor : AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildProfileStep(BuildContext context, String email) {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                FontAwesomeIcons.solidEnvelope,
                color: AppTheme.textMuted,
                size: 16,
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Text(
                l10n.connectedAccount,
                style: AppTheme.caption.copyWith(color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            email,
            style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Row(
            children: [
              const Icon(
                FontAwesomeIcons.idBadge,
                color: AppTheme.textMuted,
                size: 16,
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Text(
                l10n.displayNameLabel,
                style: AppTheme.caption.copyWith(color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            _displayName ?? '',
            style: AppTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingStep(
    BuildContext context,
    String email,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: AppTheme.accentPink.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentPink.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            child: Center(
              child: Icon(
                FontAwesomeIcons.shieldHeart,
                color: AppTheme.accentPink,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Text(
              l10n.trackingStepText,
              style: AppTheme.bodyMedium.copyWith(height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep(
    BuildContext context,
    String email,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            child: Center(
              child: Icon(
                FontAwesomeIcons.mapLocationDot,
                color: AppTheme.accentColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Text(
              l10n.locationStepText,
              style: AppTheme.bodyMedium.copyWith(height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationStep(
    BuildContext context,
    String email,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            child: Center(
              child: Icon(
                FontAwesomeIcons.circleExclamation,
                color: AppTheme.accentOrange,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Text(
              l10n.notificationStepText,
              style: AppTheme.bodyMedium.copyWith(height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class WizardStepData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Widget Function(BuildContext, String) contentBuilder;

  WizardStepData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.contentBuilder,
  });
}
