import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_app/core/providers/providers.dart';
import 'package:tracker_app/core/services/notification_service.dart';
import 'package:tracker_app/core/theme/app_theme.dart';
import 'package:tracker_app/features/map/screens/home_screen.dart';
import 'package:tracker_app/features/notifications/screens/notifications_screen.dart';
import 'package:tracker_app/features/places/screens/places_screen.dart';
import 'package:tracker_app/features/profile/screens/profile_screen.dart';
import 'package:tracker_app/l10n/app_localizations.dart';
import 'package:tracker_app/core/services/att_service.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;
  late StreamSubscription _notificationSubscription;

  late final List<Widget> _screens = [
    const HomeScreen(),
    const PlacesScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _notificationSubscription = NotificationService.onNotificationReceived
        .listen((message) {
          if (mounted && _selectedIndex != 2) {
            _showForegroundAlert(message);
          }
        });

    // ATT request check (Fail-safe for skipping Splash)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AttService.checkAndRequest(context);
    });
  }

  @override
  void dispose() {
    _notificationSubscription.cancel();
    super.dispose();
  }

  void _showForegroundAlert(dynamic message) {
    if (!mounted) return;
    final notification = message.notification;
    if (notification == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                FontAwesomeIcons.bell,
                color: AppTheme.primaryColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title ?? 'Yeni Bildirim',
                    style: AppTheme.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    notification.body ?? '',
                    style: AppTheme.caption.copyWith(color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.cardColor.withValues(alpha: 0.95),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Above bottom bar
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Gör',
          textColor: AppTheme.primaryColor,
          onPressed: () {
            setState(() {
              _selectedIndex = 2;
            });
            ref.read(notificationsProvider.notifier).fetchNotifications();
          },
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Uygulama sekmeleri arasında gezerken verileri anlık olarak yenile (Refresh Lifecycle)
    if (index == 0) {
      ref.read(circleProvider.notifier).fetchCircle();
    } else if (index == 1) {
      ref.read(circleProvider.notifier).fetchCircle();
    } else if (index == 2) {
      ref.read(notificationsProvider.notifier).fetchNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🚨 AUTH REDIRECT LOGIC
    ref.listen(authProvider, (previous, next) {
      if (next.status == AuthStatus.unauthenticated) {
        context.go('/splash');
      }
    });

    final circleState = ref.watch(circleProvider);
    final showNavbar = circleState.circle != null && !circleState.isLoading;

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: showNavbar
          ? _BottomNavigationBar(
              selectedIndex: _selectedIndex,
              onTap: _onItemTapped,
            )
          : null,
    );
  }
}

class _BottomNavigationBar extends ConsumerWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const _BottomNavigationBar({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: FontAwesomeIcons.house,
                label: l10n.home,
                isSelected: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: FontAwesomeIcons.locationDot,
                label: l10n.places,
                isSelected: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: FontAwesomeIcons.bell,
                label: l10n.alerts,
                isSelected: selectedIndex == 2,
                badge: (() {
                  final notifications = ref.watch(notificationsProvider);
                  final unreadCount = notifications
                      .where((n) => !n.isRead)
                      .length;
                  return unreadCount > 0 ? unreadCount.toString() : null;
                })(),
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: FontAwesomeIcons.user,
                label: l10n.profile,
                isSelected: selectedIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final String? badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textMuted,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: -2,
                    top: -2,
                    child:
                        Container(
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentRed,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.cardColor,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accentRed.withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Text(
                                badge!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                            .animate(
                              onPlay: (controller) => controller.repeat(),
                            )
                            .shimmer(
                              duration: 1500.ms,
                              color: Colors.white.withOpacity(0.5),
                            )
                            .shake(hz: 2, curve: Curves.easeInOut),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTheme.caption.copyWith(
                color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
