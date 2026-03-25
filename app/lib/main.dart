import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_app/core/router/app_router.dart';
import 'package:tracker_app/core/services/api_client.dart';
import 'package:tracker_app/core/services/revenue_cat_service.dart';
import 'package:tracker_app/core/theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tracker_app/firebase_options.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tracker_app/core/providers/locale_provider.dart';
import 'package:tracker_app/l10n/app_localizations.dart';

import 'package:tracker_app/core/services/background_location_service.dart';
import 'package:tracker_app/core/services/facebook_analytics_service.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize API client
  await ApiClient.init();

  // Initialize RevenueCat (anonim mod — kullanıcı ID sonra logIn ile set edilir)
  await RevenueCatService.init();

  // 3. Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.backgroundColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Log app activation
  FacebookAnalyticsService.logAppActivated();

  runApp(const ProviderScope(child: TrackerApp()));
}

class TrackerApp extends ConsumerStatefulWidget {
  const TrackerApp({super.key});

  @override
  ConsumerState<TrackerApp> createState() => _TrackerAppState();
}

class _TrackerAppState extends ConsumerState<TrackerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      BackgroundLocationService.forceUpdateLocation();
      BackgroundLocationService.checkAndStart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);

    // Update background location config when locale changes
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final l10n = await AppLocalizations.delegate.load(locale);
      BackgroundLocationService.updateConfig(l10n);
    });

    return MaterialApp.router(
      title: 'Alveron',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('tr')],
    );
  }
}
