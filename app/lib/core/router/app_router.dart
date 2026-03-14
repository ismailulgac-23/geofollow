import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_app/core/screens/splash_screen.dart';
import 'package:tracker_app/features/auth/screens/auth_screen.dart';
import 'package:tracker_app/features/auth/screens/invite_screen.dart';
import 'package:tracker_app/features/map/screens/member_detail_screen.dart';
import 'package:tracker_app/features/map/screens/add_place_screen.dart';
import 'package:tracker_app/features/notifications/screens/notifications_screen.dart';
import 'package:tracker_app/features/onboarding/screens/onboarding_screen.dart';
import 'package:tracker_app/features/onboarding/screens/setup_wizard_screen.dart';
import 'package:tracker_app/features/places/screens/places_screen.dart';
import 'package:tracker_app/features/premium/screens/premium_screen.dart';
import 'package:tracker_app/features/profile/screens/profile_screen.dart';
import 'package:tracker_app/core/router/main_shell.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static GoRouter get router => _router;

  static final GoRouter _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/setup-wizard',
        name: 'setup-wizard',
        builder: (context, state) => const SetupWizardScreen(),
      ),
      GoRoute(
        path: '/invite',
        name: 'invite',
        builder: (context, state) => const InviteScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const MainShell(),
      ),
      GoRoute(
        path: '/member/:id',
        name: 'member',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return MemberDetailScreen(memberId: id);
        },
      ),
      GoRoute(
        path: '/places',
        name: 'places',
        builder: (context, state) => const PlacesScreen(),
      ),
      GoRoute(
        path: '/places/add',
        name: 'places/add',
        builder: (context, state) {
          final place = state.extra as Map<String, dynamic>?;
          return AddPlaceScreen(placeToEdit: place);
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/premium',
        name: 'premium',
        builder: (context, state) => const PremiumScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.error}'))),
  );
}
