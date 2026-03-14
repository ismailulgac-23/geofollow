import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_app/core/services/api_client.dart';
import 'package:tracker_app/core/providers/auth_provider.dart';
import 'package:tracker_app/core/providers/providers.dart';
import 'package:tracker_app/core/theme/app_theme.dart';
import 'package:tracker_app/shared/widgets/invite_bottom_sheet.dart';
import 'package:tracker_app/shared/widgets/premium_bottom_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tracker_app/core/services/background_location_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:tracker_app/l10n/app_localizations.dart';
import 'package:tracker_app/core/providers/locale_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with WidgetsBindingObserver {
  bool _ghostMode = false;
  bool _notifications = true;
  bool _alwaysLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckAndStartTracking();
    }
  }

  Future<void> _recheckAndStartTracking() async {
    final statusAlways = await Permission.locationAlways.status;
    final statusWhenInUse = await Permission.locationWhenInUse.status;

    // Eğer ayarlardan izin verip döndüyse, motoru hemen başlatıyoruz.
    if (statusAlways.isGranted || statusWhenInUse.isGranted) {
      await BackgroundLocationService.checkAndStart();
    }
    await _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final isRunning = await FlutterBackgroundService().isRunning();
    if (mounted) {
      setState(() {
        _alwaysLocation = isRunning;
      });
    }
  }

  Future<void> _toggleAlwaysLocation(bool value) async {
    // ── Premium gate ──
    final currentUser = ref.read(authProvider).user;
    if (!(currentUser?.isPremium ?? false)) {
      PremiumBottomSheet.show(context);
      return; // Switch'i toggle etme
    }

    final l10n = AppLocalizations.of(context)!;
    if (value) {
      // Önce izinleri kontrol et
      var statusAlways = await Permission.locationAlways.request();

      if (statusAlways.isGranted) {
        await BackgroundLocationService.start();
        setState(() => _alwaysLocation = true);
      } else {
        // Eğer Always reddedildiyse ama WhenInUse varsa yine başlatılabilir
        // (ama BackgroundService mavi bar ile uyanık kalır)
        var statusWhenInUse = await Permission.locationWhenInUse.status;
        if (statusWhenInUse.isGranted) {
          await BackgroundLocationService.start();
          setState(() => _alwaysLocation = true);
        } else {
          // İzin yoksa ayarları aç
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: AppTheme.cardColor,
                title: Text(l10n.locationAlwaysRequired),
                content: Text(l10n.locationAlwaysDescription),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      openAppSettings();
                    },
                    child: Text(l10n.openSettings),
                  ),
                ],
              ),
            );
          }
        }
      }
    } else {
      await BackgroundLocationService.stop();
      setState(() => _alwaysLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final circleState = ref.watch(circleProvider);
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppTheme.backgroundColor,
              title: Text(l10n.profile),
              centerTitle: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLG,
                  vertical: AppTheme.spacingMD,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar and User Info
                    Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: Padding(
                                padding: const EdgeInsets.all(
                                  3.0,
                                ), // Ring thickness
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.backgroundColor,
                                  ),
                                  child: ClipOval(
                                    child:
                                        (currentUser?.avatarUrl != null &&
                                            currentUser!.avatarUrl.isNotEmpty)
                                        ? CachedNetworkImage(
                                            imageUrl: currentUser.avatarUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Container(
                                                  color: AppTheme.surfaceColor,
                                                  child: const Icon(
                                                    Icons.person,
                                                    size: 40,
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                                ),
                                            errorWidget:
                                                (
                                                  context,
                                                  url,
                                                  dynamic error,
                                                ) => Container(
                                                  color: AppTheme.surfaceColor,
                                                  child: const Icon(
                                                    Icons.person,
                                                    size: 40,
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                                ),
                                          )
                                        : Container(
                                            color: AppTheme.surfaceColor,
                                            child: const Icon(
                                              Icons.person,
                                              size: 50,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            if (currentUser?.isPremium == true)
                              Positioned(
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFFB75E),
                                        Color(0xFFED8F03),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.backgroundColor,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        FontAwesomeIcons.crown,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'PRO',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .scale(
                          begin: const Offset(0.8, 0.8),
                          curve: Curves.elasticOut,
                        ),
                    const SizedBox(height: AppTheme.spacingMD),
                    Text(
                      currentUser?.name ?? 'Kullanıcı',
                      style: AppTheme.heading2,
                    ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      currentUser?.address ?? l10n.addressUnknown,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                    const SizedBox(height: AppTheme.spacing2XL),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.yourCircle,
                        style: AppTheme.heading4.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    _SettingsTile(
                      icon: FontAwesomeIcons.userPlus,
                      title: l10n.inviteMembers,
                      subtitle: l10n.inviteDescription,
                      onTap: () {
                        if (circleState.circle?.inviteCode != null) {
                          showInviteBottomSheet(
                            context,
                            circleState.circle!.inviteCode,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.noInviteCode)),
                          );
                        }
                      },
                    ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                    const SizedBox(height: AppTheme.spacingMD),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.locationSettings,
                        style: AppTheme.heading4.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 450.ms),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    _SettingsTile(
                      icon: FontAwesomeIcons.locationDot,
                      title: l10n.preciseTracking,
                      subtitle: l10n.allowBackground,
                      trailing: _AnimatedToggle(
                        value: _alwaysLocation,
                        onChanged: _toggleAlwaysLocation,
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
                    const SizedBox(height: AppTheme.spacingMD),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.account,
                        style: AppTheme.heading4.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    _SettingsTile(
                      icon: FontAwesomeIcons.crown,
                      title: l10n.premiumTitle,
                      subtitle: currentUser?.isPremium == true
                          ? l10n
                                .premiumTitle // Place holder for subscribed
                          : l10n.premiumSubtitle,
                      isPremium: true,
                      onTap: () => PremiumBottomSheet.show(context),
                    ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
                    const SizedBox(height: AppTheme.spacingSM),
                    _SettingsTile(
                      icon: Icons.language,
                      title: l10n.language,
                      subtitle: currentLocale.languageCode == 'en'
                          ? l10n.english
                          : l10n.turkish,
                      trailing: Icon(
                        Icons.swap_horiz,
                        size: 18,
                        color: AppTheme.textMuted.withValues(alpha: 0.5),
                      ),
                      onTap: () =>
                          ref.read(localeProvider.notifier).toggleLocale(),
                    ).animate().fadeIn(duration: 400.ms, delay: 650.ms),
                    const SizedBox(height: AppTheme.spacingSM),
                    _SettingsTile(
                      icon: FontAwesomeIcons.fileLines,
                      title: l10n.privacyPolicy,
                      onTap: () => launchUrl(
                        Uri.parse('https://geofollow.xyz/privacy-policy.html'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 700.ms),
                    const SizedBox(height: AppTheme.spacingSM),
                    _SettingsTile(
                      icon: FontAwesomeIcons.fileContract,
                      title: l10n.termsOfService,
                      onTap: () => launchUrl(
                        Uri.parse(
                          'https://geofollow.xyz/terms-of-service.html',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 800.ms),
                    const SizedBox(height: AppTheme.spacingXL),
                    // Logout Button with softer design
                    GestureDetector(
                      onTap: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) {
                          context.go('/auth');
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacingMD,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRed.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXL,
                          ),
                          border: Border.all(
                            color: AppTheme.accentRed.withOpacity(0.12),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              FontAwesomeIcons.rightFromBracket,
                              size: 18,
                              color: AppTheme.accentRed.withOpacity(0.6),
                            ),
                            const SizedBox(width: AppTheme.spacingSM),
                            Text(
                              l10n.logout,
                              style: AppTheme.button.copyWith(
                                color: AppTheme.accentRed.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 1700.ms),
                    const SizedBox(height: AppTheme.spacingMD),
                    // Delete Account Button
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AppTheme.cardColor,
                            title: Text(
                              l10n.deleteAccount,
                              style: const TextStyle(color: AppTheme.accentRed),
                            ),
                            content: Text(l10n.deleteAccountConfirm),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  l10n.cancel,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  try {
                                    await ApiClient.deleteAccount();
                                    await ref
                                        .read(authProvider.notifier)
                                        .logout();
                                    if (context.mounted) {
                                      context.go('/auth');
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to delete account: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: Text(
                                  l10n.delete,
                                  style: const TextStyle(
                                    color: AppTheme.accentRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacingMD,
                        ),
                        decoration: BoxDecoration(color: Colors.transparent),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              FontAwesomeIcons.trash,
                              size: 16,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: AppTheme.spacingSM),
                            Text(
                              l10n.deleteAccount,
                              style: AppTheme.button.copyWith(
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 1800.ms),
                    const SizedBox(height: AppTheme.spacingLG),
                    Center(
                      child: Text(
                        '${l10n.version} 1.0.0',
                        style: AppTheme.caption,
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 1900.ms),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool isPremium;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.isPremium = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: Border.all(
            color: isPremium
                ? AppTheme.accentOrange.withValues(alpha: 0.3)
                : AppTheme.glassBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isPremium
                    ? AppTheme.accentOrange.withValues(alpha: 0.1)
                    : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                border: Border.all(
                  color: isPremium
                      ? AppTheme.accentOrange.withValues(alpha: 0.5)
                      : AppTheme.glassBorder.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isPremium ? AppTheme.accentOrange : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppTheme.bodySmall),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(
                FontAwesomeIcons.chevronRight,
                size: 14,
                color: AppTheme.textMuted.withOpacity(0.5),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedToggle extends StatefulWidget {
  final bool value;
  final Function(bool) onChanged;

  const _AnimatedToggle({required this.value, required this.onChanged});

  @override
  State<_AnimatedToggle> createState() => _AnimatedToggleState();
}

class _AnimatedToggleState extends State<_AnimatedToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: widget.value ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(_AnimatedToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: Container(
        width: 50,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: widget.value ? AppTheme.primaryColor : AppTheme.surfaceLight,
          border: Border.all(
            color: widget.value ? AppTheme.primaryColor : AppTheme.glassBorder,
          ),
        ),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(2 + (_animation.value * 22), 2),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
