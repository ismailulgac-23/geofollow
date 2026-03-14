class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Family Tracker';
  static const String appVersion = '1.0.0';

  // Map Configuration
  static const double defaultLatitude = 41.0082;
  static const double defaultLongitude = 28.9784;
  static const double defaultZoom = 14.0;
  static const double defaultRadius = 100.0;

  // Animation Durations
  static const Duration animationDurationFast = Duration(milliseconds: 200);
  static const Duration animationDurationMedium = Duration(milliseconds: 400);
  static const Duration animationDurationSlow = Duration(milliseconds: 600);
  static const Duration animationDurationVerySlow = Duration(milliseconds: 1000);

  // Geofence
  static const double minGeofenceRadius = 50.0;
  static const double maxGeofenceRadius = 1000.0;
  static const double defaultGeofenceRadius = 200.0;

  // Mock Data URLs
  static const String avatarBaseUrl = 'https://i.pravatar.cc/150?u=';
  static const String unsplashBaseUrl = 'https://images.unsplash.com/photo-';

  // Unsplash Image IDs
  static const List<String> onboardingImages = [
    '1506905925346-21bda4d32df4?w=800&q=80',
    '1494500764479-8c8493fd84d4?w=800&q=80',
    '1529156069898-4e53e9c47a62?w=800&q=80',
  ];

  // Routes
  static const List<String> routes = [
    '/onboarding',
    '/auth',
    '/invite',
    '/home',
    '/places',
    '/notifications',
    '/premium',
    '/profile',
  ];
}
