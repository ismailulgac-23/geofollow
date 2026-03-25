import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tracker_app/core/providers/auth_provider.dart';
import 'package:tracker_app/core/providers/providers.dart';
import 'package:tracker_app/core/theme/app_theme.dart';
import 'package:tracker_app/l10n/app_localizations.dart';
import 'package:tracker_app/shared/widgets/avatar_widget.dart';
import 'package:tracker_app/shared/widgets/premium_bottom_sheet.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = notifications.where((n) => !n.isRead).length;
    final currentUser = ref.watch(authProvider).user;
    final isPremium = currentUser?.isPremium ?? false;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 56,
              pinned: true,
              backgroundColor: AppTheme.backgroundColor,
              title: Text(
                l10n.notifications,
                style: AppTheme.heading3,
              ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
              actions: [
                TextButton(
                  onPressed: () {
                    ref.read(notificationsProvider.notifier).markAllAsRead();
                  },
                  child: Text(
                    l10n.markAllRead,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
              ],
            ),
            // ── Premium banner (non-premium users) ──────────────────────
            if (!isPremium)
              SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () => PremiumBottomSheet.show(context),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(
                      AppTheme.spacingLG,
                      AppTheme.spacingMD,
                      AppTheme.spacingLG,
                      0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMD,
                      vertical: AppTheme.spacingMD,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2A2000), Color(0xFF1A1400)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: AppTheme.borderRadiusLG,
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFFD700,
                                ).withValues(alpha: 0.3),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.workspace_premium,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingMD),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEn
                                    ? 'Premium required for full alerts'
                                    : 'Tam bildirimler için Premium gerekli',
                                style: AppTheme.bodySmall.copyWith(
                                  color: const Color(0xFFFFD700),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isEn
                                    ? 'Upgrade to get unlimited notifications & SOS alerts'
                                    : 'Sınırsız bildirim ve SOS alarmları için yükseltin',
                                style: AppTheme.caption.copyWith(
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingSM),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isEn ? 'Upgrade' : 'Yükselt',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: -0.1, end: 0),
                ),
              ),
            if (unreadCount > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: AppTheme.spacingLG,
                    right: AppTheme.spacingLG,
                    left: AppTheme.spacingLG,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMD,
                          vertical: AppTheme.spacingSM,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: AppTheme.borderRadiusLG,
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              FontAwesomeIcons.bell,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: AppTheme.spacingSM),
                            Text(
                              '$unreadCount ${l10n.alerts}',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                      const SizedBox(height: AppTheme.spacingXL),
                    ],
                  ),
                ),
              ),
            if (notifications.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingXL),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          FontAwesomeIcons.bellSlash,
                          size: 64,
                          color: AppTheme.primaryColor,
                        ),
                      ).animate().scale(
                        duration: 600.ms,
                        curve: Curves.easeOutBack,
                      ),
                      const SizedBox(height: AppTheme.spacingXL),
                      Text(
                        l10n.noNotificationsYet,
                        style: AppTheme.heading2,
                      ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                      const SizedBox(height: AppTheme.spacingMD),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          l10n.noNotificationsDescription,
                          textAlign: TextAlign.center,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final notification = notifications[index];
                  return _NotificationCard(
                    notification: notification,
                    index: index,
                  );
                }, childCount: notifications.length),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerStatefulWidget {
  final dynamic notification;
  final int index;

  const _NotificationCard({required this.notification, required this.index});

  @override
  ConsumerState<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends ConsumerState<_NotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'battery_low':
        return FontAwesomeIcons.batteryQuarter;
      case 'arrival':
      case 'place_entered':
        return FontAwesomeIcons.locationDot;
      case 'departure':
      case 'place_exited':
        return FontAwesomeIcons.diamondTurnRight;
      case 'geofence':
        return FontAwesomeIcons.circleDot;
      case 'sos':
        return FontAwesomeIcons.triangleExclamation;
      case 'speed':
        return FontAwesomeIcons.gaugeHigh;
      case 'member':
        return FontAwesomeIcons.userPlus;
      case 'movement_started':
        return FontAwesomeIcons.personRunning;
      default:
        return FontAwesomeIcons.bell;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'battery_low':
        return AppTheme.accentRed;
      case 'arrival':
      case 'place_entered':
        return AppTheme.accentGreen;
      case 'departure':
      case 'place_exited':
        return AppTheme.accentOrange;
      case 'movement_started':
        return AppTheme.primaryColor;
      case 'geofence':
        return AppTheme.primaryColor;
      case 'sos':
        return AppTheme.accentRed;
      case 'speed':
        return AppTheme.accentOrange;
      case 'member':
        return AppTheme.primaryColor;
      default:
        return AppTheme.textMuted;
    }
  }

  /// Translates backend code-based notification titles to localized strings
  String _getLocalizedTitle(BuildContext context, String title, String type) {
    final l10n = AppLocalizations.of(context)!;

    // Explicitly check type for place entry/exit
    if (type == 'place_entered' || type == 'arrival') {
      return l10n.notificationPlace;
    }
    if (type == 'place_exited' || type == 'departure') {
      return l10n.notificationPlace;
    }

    switch (title) {
      case 'sos_alert':
        return l10n.notificationSos;
      case 'new_member':
      case 'new_member_joined':
      case 'member_left':
      case 'removed_from_circle':
        return l10n.notificationMember;
      case 'place_added':
        return l10n.notificationPlace;
      case 'message':
        return l10n.notificationMessage;
      case 'movement_started':
        return l10n.notificationMovement;
      default:
        return title;
    }
  }

  /// Reconstructs message if it's a known type to ensure localization
  String _getLocalizedMessage(BuildContext context, dynamic notification) {
    final type = notification.type;

    // Backend doesn't always send placeName separately,
    // but we can try to extract it from the message if it's there
    // Or if the backend sends it in 'data', we'd need to update the model.
    // For now, if we don't have placeName, we'll use the original message.

    if (type == 'place_entered' || type == 'arrival') {
      // If the message is "User entered PlaceName", we can't easily localize
      // unless we have the place name separately.
      // Let's assume for now we want to show the original if we can't translate.
      return notification.message;
    }

    if (type == 'place_exited' || type == 'departure') {
      return notification.message;
    }

    return notification.message;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) {
            _controller.reverse();
            if (!widget.notification.isRead) {
              ref
                  .read(notificationsProvider.notifier)
                  .markAsRead(widget.notification.id);
            }
          },
          onTapCancel: () => _controller.reverse(),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 - (_controller.value * 0.02),
                child: child,
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLG,
                vertical: AppTheme.spacingSM,
              ),
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: AppTheme.borderRadiusXL,
                border: Border.all(
                  color: widget.notification.isRead
                      ? AppTheme.glassBorder
                      : _getColorForType(
                          widget.notification.type,
                        ).withOpacity(0.3),
                  width: widget.notification.isRead ? 1 : 2,
                ),
                boxShadow: widget.notification.isRead
                    ? null
                    : [
                        BoxShadow(
                          color: _getColorForType(
                            widget.notification.type,
                          ).withOpacity(0.1),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getColorForType(
                        widget.notification.type,
                      ).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _getIconForType(widget.notification.type),
                        size: 20,
                        color: _getColorForType(widget.notification.type),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _getLocalizedTitle(
                                  context,
                                  widget.notification.title,
                                  widget.notification.type,
                                ),
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: widget.notification.isRead
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!widget.notification.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          _getLocalizedMessage(context, widget.notification),
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingSM),
                        Row(
                          children: [
                            AvatarWidget(
                              imageUrl: widget.notification.avatarUrl ?? '',
                              size: 20,
                              showRing: false,
                            ),
                            const SizedBox(width: AppTheme.spacingSM),
                            Text(
                              widget.notification.userName ?? l10n.user,
                              style: AppTheme.caption.copyWith(
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              widget.notification.getTimeAgo(l10n),
                              style: AppTheme.caption.copyWith(
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: Duration(milliseconds: 300 + (widget.index * 100)),
        )
        .slideX(begin: 0.1, end: 0);
  }
}
