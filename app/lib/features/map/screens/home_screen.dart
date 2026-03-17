import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tracker_app/core/models/place_model.dart';
import 'package:tracker_app/core/models/user_model.dart';

import 'package:tracker_app/core/providers/providers.dart';
import 'package:tracker_app/core/theme/app_theme.dart';
import 'package:tracker_app/shared/widgets/avatar_widget.dart';
import 'package:tracker_app/shared/widgets/invite_bottom_sheet.dart';
import 'package:tracker_app/shared/widgets/premium_bottom_sheet.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:tracker_app/core/services/api_client.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tracker_app/core/services/location_service.dart';
import 'package:tracker_app/l10n/app_localizations.dart';
import 'package:tracker_app/core/services/background_location_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Circle> _mapCircles = {};
  MapType _currentMapType = MapType.normal;
  final ValueNotifier<double> _sheetExtent = ValueNotifier<double>(0.25);

  // Real-time Polling & Caching
  Timer? _refreshTimer;
  StreamSubscription<Position>? _localMarkerSubscription;
  final Map<String, BitmapDescriptor> _userIconCache = {};

  late LatLng _currentCenter;
  bool _isLocationInitialized = false;

  CameraPosition get _initialCameraPosition =>
      CameraPosition(target: _currentCenter, zoom: 15.0);

  final String _darkMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [{ "color": "#0D0D1E" }]
    },
    {
      "elementType": "labels.icon",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [{ "color": "#6C6C8A" }]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [{ "color": "#0D0D1E" }]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [{ "color": "#1E1E32" }]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [{ "color": "#6C5CE7" }, { "weight": 0.5 }]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [{ "color": "#0A1628" }]
    },
    {
      "featureType": "poi",
      "elementType": "geometry",
      "stylers": [{ "color": "#1A1A2E" }]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _updateBattery();

      // 🚀 FIRST FETCH: Then load markers, ensuring avatar is at the CORRECT spot immediately
      await _fetchRealLocationAndStart();
      _loadMarkers();

      // Premium değilse her açılışta upsell sheet göster
      _maybeShowPremiumSheet();
    });

    // Start Real-time Polling (every 3 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        ref.read(circleProvider.notifier).silentFetch();
      }
    });

    // 🚀 INSTANT LOCAL MOVEMENT: Update current user marker and currentCenter as location changes
    _localMarkerSubscription = LocationService.instance.positionStream.listen((
      pos,
    ) {
      if (!mounted) return;
      final currentUser = ref.read(authProvider).user;
      if (currentUser == null) return;

      final markerId = MarkerId('user_${currentUser.id}');
      final latLng = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _currentCenter =
            latLng; // Keep the 'current center' variable updated for GPS button
        _markers = _markers.map((m) {
          if (m.markerId == markerId) {
            return m.copyWith(positionParam: latLng);
          }
          return m;
        }).toSet();
      });
    });
  }

  void _maybeShowPremiumSheet() {
    if (!mounted) return;
    final user = ref.read(authProvider).user;
    if (user != null && !user.isPremium) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) PremiumBottomSheet.show(context);
      });
    }
  }

  Future<void> _fetchRealLocationAndStart() async {
    Position? position;
    int retryCount = 0;

    // Simülasyon başlarken gercek GPS konumu alınması bikaç saniye sürebilir
    // Maksimum 3 kez dene, eğer konum hiç alınamazsa Apple Review simülasyonu için San Francisco'yu (Amerika) baz al
    while (position == null && retryCount < 3) {
      if (!mounted) return;
      position = await LocationService.getCurrentPosition(
        timeout: const Duration(seconds: 4),
      );

      if (position == null) {
        retryCount++;
        // İzin verilmemiş olabilir ya da stream cevap dönmemiş olabilir
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (!mounted) return;

    // Her şeye rağmen null döndüyse, Apple Tester için Amerika / San Francisco koordinatına atla (Sonsuz loop engeli)
    final latLng = position != null
        ? LatLng(position.latitude, position.longitude)
        : const LatLng(37.7749, -122.4194);
    setState(() => _currentCenter = latLng);

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 15.5),
      ),
    );

    setState(() => _isLocationInitialized = true);

    // 2. Çemberdeki yerleri geofence motoruna yükle
    final places = ref.read(placesProvider);
    if (places.isNotEmpty) {
      LocationService.instance.loadGeofences(
        places
            .map(
              (p) => {
                'id': p.id,
                'name': p.name,
                'latitude': p.location.latitude,
                'longitude': p.location.longitude,
                'radius': p.radius,
              },
            )
            .toList(),
      );
    }

    // 3. Periyodik konum motorunu başlat (15 sn aralık)
    await LocationService.instance.start();

    // 4. Arkaplan konum zorlaması ve arkaplan motorunu başlat (Cold Boot için)
    BackgroundLocationService.forceUpdateLocation();
    BackgroundLocationService.checkAndStart();
  }

  Future<void> _updateBattery() async {
    try {
      final battery = Battery();
      final level = await battery.batteryLevel;
      await ApiClient.updateBatteryLevel(level);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadMarkers() async {
    final users = ref.read(usersProvider);
    final places = ref.read(placesProvider);

    // Create user markers in parallel
    final currentUser = ref.read(authProvider).user;
    final userMarkerFutures = users.map((user) async {
      // 🚀 CACHE LOGIC: Check if we have a valid cached icon for this user's state
      final cacheKey = '${user.id}_${user.isOnline}_${user.avatarUrl}';

      BitmapDescriptor icon;
      if (_userIconCache.containsKey(cacheKey)) {
        icon = _userIconCache[cacheKey]!;
      } else {
        final iconBytes = await _getCustomMarkerIcon(user);
        icon = BitmapDescriptor.bytes(iconBytes);
        _userIconCache[cacheKey] = icon;
      }

      // 🎯 Fix: If this is ME, use the LATEST known local position instead of potentially old API position
      LatLng pos = user.location;
      if (currentUser != null && user.id == currentUser.id) {
        final lastLocal = LocationService.instance.lastPosition;
        if (lastLocal != null) {
          pos = LatLng(lastLocal.latitude, lastLocal.longitude);
        }
      }

      return Marker(
        markerId: MarkerId('user_${user.id}'),
        position: pos,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        onTap: () => _showUserDialog(user),
      );
    });

    // Create place markers in parallel
    final placeMarkerFutures = places.map((place) async {
      final iconBytes = await _getPlaceMarkerIcon(place);
      return Marker(
        markerId: MarkerId('place_${place.id}'),
        position: place.location,
        icon: BitmapDescriptor.bytes(iconBytes),
        anchor: const Offset(0.5, 0.9), // Slightly above the point
        onTap: () => _showPlaceDialog(place),
      );
    });

    final userMarkers = await Future.wait(userMarkerFutures);
    final placeMarkers = await Future.wait(placeMarkerFutures);

    // Create place circles
    final placeCircles = places.map((place) {
      return Circle(
        circleId: CircleId('circle_${place.id}'),
        center: place.location,
        radius: place.radius,
        strokeColor: AppTheme.primaryColor.withOpacity(0.8),
        strokeWidth: 2,
        fillColor: AppTheme.primaryColor.withOpacity(0.1),
      );
    }).toSet();

    if (mounted) {
      setState(() {
        _markers = {...userMarkers, ...placeMarkers};
        _mapCircles = placeCircles;
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _applyMapStyle();
  }

  void _applyMapStyle() {
    if (_mapController == null) return;
    if (_currentMapType == MapType.normal) {
      _mapController!.setMapStyle(_darkMapStyle);
    } else {
      _mapController!.setMapStyle(null);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _localMarkerSubscription?.cancel();
    _mapController?.dispose();
    _sheetExtent.dispose();
    LocationService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final users = ref.watch(usersProvider);
    final circleState = ref.watch(circleProvider);

    ref.listen(usersProvider, (previous, next) {
      _loadMarkers();
    });

    ref.listen(placesProvider, (previous, next) {
      _loadMarkers();
      // Geofence motorını güncelle
      if (next.isNotEmpty) {
        LocationService.instance.loadGeofences(
          next
              .map(
                (p) => {
                  'id': p.id,
                  'name': p.name,
                  'latitude': p.location.latitude,
                  'longitude': p.location.longitude,
                  'radius': p.radius,
                },
              )
              .toList(),
        );
      }
    });

    final isNoCircle = circleState.circle == null && !circleState.isLoading;

    if (isNoCircle) {
      return Scaffold(body: _NoCircleView());
    }

    if (!_isLocationInitialized) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppTheme.primaryColor),
                const SizedBox(height: 24),
                Text(
                  l10n.loadingLocation,
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ).animate().fadeIn().scale(),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: _currentMapType,
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: _onMapCreated,
            markers: _markers,
            circles: _mapCircles,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
          ),
          // Map Type Selector
          ValueListenableBuilder<double>(
            valueListenable: _sheetExtent,
            builder: (context, extent, child) {
              return Positioned(
                left: AppTheme.spacingMD,
                bottom:
                    (MediaQuery.of(context).size.height * extent) +
                    AppTheme.spacingMD,
                child: child!,
              );
            },
            child: _buildMapTypeSelector()
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Row(
                children: [
                  // SOS Button — Premium gate
                  Builder(
                    builder: (ctx) {
                      final user = ref.read(authProvider).user;
                      final isPremium = user?.isPremium ?? false;
                      return GestureDetector(
                            onTap: () {
                              if (isPremium) {
                                _showSOSDialog(context, l10n);
                              } else {
                                PremiumBottomSheet.show(context);
                              }
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: isPremium
                                          ? const [
                                              Color(0xFFEF4444),
                                              Color(0xFFDC2626),
                                            ]
                                          : [
                                              Colors.grey.shade700,
                                              Colors.grey.shade800,
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(26),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (isPremium
                                                    ? const Color(0xFFEF4444)
                                                    : Colors.grey)
                                                .withValues(alpha: 0.45),
                                        blurRadius: 15,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.sos,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                // Crown badge for non-premium
                                if (!isPremium)
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFFFFD700),
                                            Color(0xFFFF8C00),
                                          ],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.workspace_premium,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideX(begin: -0.3, end: 0)
                          .shimmer(
                            duration: 2000.ms,
                            delay: 1000.ms,
                            color: Colors.white.withValues(alpha: 0.3),
                          );
                    },
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  _MapControlButton(
                        icon: Icons.search,
                        onPressed: () => _showSearchDialog(context, l10n),
                        size: 44,
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: -0.3, end: 0),
                  const SizedBox(width: AppTheme.spacingSM),
                  if (circleState.circle?.inviteCode != null)
                    _MapControlButton(
                          icon: Icons.person_add_alt_1,
                          onPressed: () {
                            final user = ref.read(authProvider).user;
                            final isPremium = user?.isPremium ?? false;
                            final membersCount =
                                circleState.circle!.members.length;

                            if (!isPremium && membersCount >= 2) {
                              PremiumBottomSheet.show(context);
                            } else {
                              showInviteBottomSheet(
                                context,
                                circleState.circle!.inviteCode,
                              );
                            }
                          },
                          size: 44,
                          iconColor: AppTheme.primaryColor,
                        )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideX(begin: -0.3, end: 0),
                  const SizedBox(width: AppTheme.spacingSM),
                  // PRO Button for visibility (Apple Review)
                  Builder(
                    builder: (ctx) {
                      final user = ref.watch(authProvider).user;
                      if (user != null && user.isPremium) return const SizedBox();
                      return _MapControlButton(
                            icon: Icons.workspace_premium,
                            onPressed: () => PremiumBottomSheet.show(context),
                            size: 44,
                            iconColor: const Color(0xFFFFD700), // Gold
                          )
                          .animate(onPlay: (controller) => controller.repeat())
                          .shimmer(
                            duration: 2000.ms,
                            color: Colors.white.withValues(alpha: 0.3),
                          )
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideX(begin: -0.3, end: 0);
                    },
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  const Expanded(child: SizedBox()),
                  _MapControlButton(
                        icon: Icons.my_location,
                        onPressed: () {
                          _mapController?.animateCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: _currentCenter,
                                zoom: 15.5,
                              ),
                            ),
                          );
                        },
                        size: 44,
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: 0.3, end: 0),
                ],
              ),
            ),
          ),
          Positioned(
            top: 132.5,
            right: AppTheme.spacingMD,
            child: Column(
              children: [
                _MapControlButton(
                  icon: Icons.add,
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  },
                  size: 40,
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                const SizedBox(height: AppTheme.spacingSM),
                _MapControlButton(
                  icon: Icons.remove,
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomOut());
                  },
                  size: 40,
                ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                const SizedBox(height: AppTheme.spacingMD),
                // Add Place Button
                GestureDetector(
                      onTap: () {
                        final user = ref.read(authProvider).user;
                        final isPremium = user?.isPremium ?? false;
                        final places = ref.read(placesProvider);

                        if (!isPremium && places.isNotEmpty) {
                          PremiumBottomSheet.show(context);
                        } else {
                          context.push('/places/add');
                        }
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryColor,
                              const Color(0xFF5B4ED0),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_location_alt,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 400.ms)
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1, 1),
                      duration: 400.ms,
                      curve: Curves.easeOutBack,
                    ),
              ],
            ),
          ),
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              _sheetExtent.value = notification.extent;
              return true;
            },
            child: DraggableScrollableSheet(
              initialChildSize: 0.25,
              minChildSize: 0.1,
              maxChildSize: 0.7,
              snap: true,
              snapSizes: const [0.1, 0.25, 0.5, 0.7],
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppTheme.radius2XL),
                    ),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppTheme.radius2XL),
                    ),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: CustomScrollView(
                        controller: scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: _buildSheetHeader(users, l10n),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final user = users[index];
                              return _MemberCard(user: user)
                                  .animate()
                                  .fadeIn(
                                    duration: 400.ms,
                                    delay: Duration(milliseconds: 100 * index),
                                  )
                                  .slideX(begin: 0.1, end: 0);
                            }, childCount: users.length),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 100),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapTypeSelector() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.cardColor.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapTypeOption(
                type: MapType.normal,
                icon: Icons.map_rounded,
                isSelected: _currentMapType == MapType.normal,
                onTap: () {
                  setState(() => _currentMapType = MapType.normal);
                  _applyMapStyle();
                },
              ),
              const SizedBox(height: 4),
              _MapTypeOption(
                type: MapType.satellite,
                icon: Icons.satellite_rounded,
                isSelected: _currentMapType == MapType.satellite,
                onTap: () {
                  setState(() => _currentMapType = MapType.satellite);
                  _applyMapStyle();
                },
              ),
              const SizedBox(height: 4),
              _MapTypeOption(
                type: MapType.terrain,
                icon: Icons.terrain_rounded,
                isSelected: _currentMapType == MapType.terrain,
                onTap: () {
                  setState(() => _currentMapType = MapType.terrain);
                  _applyMapStyle();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetHeader(List users, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLG,
        vertical: AppTheme.spacingMD,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Row(
            children: [
              Text(
                l10n.yourCircle,
                style: AppTheme.heading3,
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2, end: 0),
              const Spacer(),
              IconButton(
                onPressed: () => _showLeaveCircleDialog(context, l10n),
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppTheme.accentRed,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: l10n.leaveCircle,
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
              const SizedBox(width: AppTheme.spacingMD),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSM,
                  vertical: AppTheme.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                    Text(
                      '${users.length} ${l10n.online}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.accentGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
            ],
          ),
        ],
      ),
    );
  }

  void _showLeaveCircleDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.leaveCircle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.leaveCircleConfirm,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final circleId = ref.read(circleProvider).circle?.id;
              if (circleId != null) {
                final success = await ref
                    .read(circleProvider.notifier)
                    .leaveCircle(circleId);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.successfullyLeftCircle)),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(l10n.leave),
          ),
        ],
      ),
    );
  }

  void _showSOSDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.sos, color: Color(0xFFEF4444), size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.sosDialogTitle,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sosDialogContent,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.sosLocationSharingNote,
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final response = await ApiClient.sendSOS();
              if (response['success'] == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(l10n.sosAlertSentToAll),
                      ],
                    ),
                    backgroundColor: const Color(0xFFEF4444),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(l10n.sendSOS),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context, AppLocalizations l10n) {
    final TextEditingController _searchController = TextEditingController();
    final List<dynamic> _searchResults = [];
    bool _isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radius2XL),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLG),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(l10n.search, style: AppTheme.heading3),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                  TextField(
                    controller: _searchController,
                    style: AppTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      hintStyle: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textMuted,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setModalState(() {
                                  _searchController.clear();
                                  _searchResults.clear();
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      if (value.isEmpty) {
                        setModalState(() {
                          _searchResults.clear();
                        });
                        return;
                      }
                      _performSearch(value);
                      setModalState(() {
                        _searchResults.clear();
                        _searchResults.addAll(_performSearch(value));
                      });
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                  if (_searchResults.isEmpty && !_isSearching)
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      child: Text(
                        l10n.searchPlaceholder,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_searchResults.isNotEmpty)
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(
                                result['avatarUrl'] ??
                                    'https://i.pravatar.cc/150?u=${result['name']?.toLowerCase() ?? 'unknown'}',
                              ),
                            ),
                            title: Text(result['name']),
                            subtitle: Text(result['address'] ?? result['type']),
                            onTap: () {
                              if (result['type'] == 'user') {
                                context.push('/member/${result['id']}');
                              } else if (result['type'] == 'place') {
                                _mapController?.animateCamera(
                                  CameraUpdate.newLatLng(result['location']),
                                );
                                Navigator.pop(context);
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showUserDialog(UserModel user) {
    final l10n = AppLocalizations.of(context)!;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header with gradient
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: user.isOnline
                                      ? [
                                          const Color(0xFF10B981),
                                          const Color(0xFF059669),
                                        ]
                                      : [
                                          const Color(0xFF6B7280),
                                          const Color(0xFF4B5563),
                                        ],
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: user.avatarUrl.isNotEmpty
                                          ? Image.network(
                                              user.avatarUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  _buildInitialAvatar(
                                                    user.name,
                                                  ),
                                            )
                                          : _buildInitialAvatar(user.name),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              user.name,
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            if (user.statusEmoji != null) ...[
                                              const SizedBox(width: 8),
                                              Text(
                                                user.statusEmoji!,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: user.isOnline
                                                    ? Colors.white
                                                    : Colors.grey.shade300,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              user.isOnline
                                                  ? l10n.online
                                                  : l10n.offline,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white.withOpacity(
                                                  0.9,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Close button
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Content
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  // Location info
                                  _InfoRow(
                                    icon: Icons.location_on,
                                    label: l10n.location,
                                    value: user.address,
                                    iconColor: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(height: 16),
                                  // Battery info
                                  _InfoRow(
                                    icon: user.batteryLevel <= 20
                                        ? Icons.battery_alert
                                        : Icons.battery_full,
                                    label: l10n.battery,
                                    value: '${user.batteryLevel}%',
                                    iconColor: user.batteryLevel <= 20
                                        ? AppTheme.accentRed
                                        : AppTheme.accentGreen,
                                  ),
                                  const SizedBox(height: 16),
                                  // Last seen
                                  _InfoRow(
                                    icon: Icons.access_time,
                                    label: l10n.lastSeen,
                                    value: user.getTimeAgo(l10n),
                                    iconColor: AppTheme.textMuted,
                                  ),
                                  const SizedBox(height: 24),
                                  // Action buttons
                                  Center(
                                    child: SizedBox(
                                      width: 120,
                                      child: _ActionButton(
                                        icon: Icons.person,
                                        label: l10n.profile,
                                        onTap: () {
                                          Navigator.pop(context);
                                          context.push('/member/${user.id}');
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .animate()
            .fadeIn(duration: 300.ms)
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              duration: 300.ms,
              curve: Curves.easeOutBack,
            );
      },
    );
  }

  Widget _buildInitialAvatar(String name) {
    return Container(
      color: AppTheme.primaryColor,
      child: Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  List<dynamic> _performSearch(String query) {
    final users = ref.read(usersProvider);
    final places = ref.read(placesProvider);

    final queryLower = query.toLowerCase();

    final userResults = users
        .where((user) => user.name.toLowerCase().contains(queryLower))
        .map(
          (user) => {
            'id': user.id,
            'name': user.name,
            'avatarUrl': user.avatarUrl,
            'address': user.address,
            'type': 'user',
          },
        )
        .toList();

    final placeResults = places
        .where((place) => place.name.toLowerCase().contains(queryLower))
        .map(
          (place) => {
            'id': place.id,
            'name': place.name,
            'avatarUrl': null,
            'address': place.address,
            'location': place.location,
            'type': 'place',
          },
        )
        .toList();

    return [...userResults, ...placeResults];
  }

  Future<Uint8List> _getCustomMarkerIcon(UserModel user) async {
    // Create a large avatar marker - 220x220 pixels for better visibility
    const int markerSize = 220;
    const double avatarRadius = 80.0;
    const double borderWidth = 8.0;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final center = Offset(markerSize / 2, markerSize / 2);

    final avatarUrl = user.avatarUrl;
    final isOnline = user.isOnline;

    // Draw shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, avatarRadius + borderWidth + 5, shadowPaint);

    // Draw outer border (status color)
    final Paint borderPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx - avatarRadius, center.dy - avatarRadius),
        Offset(center.dx + avatarRadius, center.dy + avatarRadius),
        isOnline
            ? [const Color(0xFF10B981), const Color(0xFF34D399)]
            : [const Color(0xFF6B7280), const Color(0xFF9CA3AF)],
      )
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, avatarRadius + borderWidth, borderPaint);

    // Draw white inner border
    final Paint whiteBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, avatarRadius + 2, whiteBorderPaint);

    // Draw avatar background
    final Paint bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx - avatarRadius, center.dy - avatarRadius),
        Offset(center.dx + avatarRadius, center.dy + avatarRadius),
        [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      );
    canvas.drawCircle(center, avatarRadius, bgPaint);

    // Draw avatar image or initial
    bool avatarDrawn = false;
    if (avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
      try {
        final http.Response response = await http.get(Uri.parse(avatarUrl));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final ui.Codec codec = await ui.instantiateImageCodec(
            response.bodyBytes,
            targetWidth: (avatarRadius * 2).toInt(),
            targetHeight: (avatarRadius * 2).toInt(),
          );
          final ui.FrameInfo frameInfo = await codec.getNextFrame();
          final ui.Image image = frameInfo.image;

          // Clip to circle and draw
          canvas.save();
          final Path clipPath = Path()
            ..addOval(Rect.fromCircle(center: center, radius: avatarRadius));
          canvas.clipPath(clipPath);

          // Center the image
          final double dx = center.dx - image.width / 2;
          final double dy = center.dy - image.height / 2;

          canvas.drawImage(
            image,
            Offset(dx, dy),
            Paint()..filterQuality = FilterQuality.high,
          );
          canvas.restore();
          avatarDrawn = true;
        }
      } catch (e) {
        // Fall through to draw initial
      }
    }

    // Draw initial if no avatar
    if (!avatarDrawn) {
      final String initial = user.name.isNotEmpty
          ? user.name.substring(0, 1).toUpperCase()
          : '?';

      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: initial,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2,
        ),
      );
    }

    // Draw online badge
    if (isOnline) {
      final badgeCenter = Offset(
        center.dx + avatarRadius - 5,
        center.dy - avatarRadius + 5,
      );

      // Badge shadow
      final Paint badgeShadowPaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(badgeCenter, 16, badgeShadowPaint);

      // Badge white background
      final Paint badgeBgPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(badgeCenter, 14, badgeBgPaint);

      // Badge green dot
      final Paint badgeDotPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(badgeCenter, 10, badgeDotPaint);
    }

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(markerSize, markerSize);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _getPlaceMarkerIcon(PlaceModel place) async {
    const int markerSize = 120;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final center = Offset(markerSize / 2, markerSize / 2);
    final radius = 45.0;

    // 1. Draw Shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center + const Offset(0, 4), radius + 2, shadowPaint);

    // 2. Draw Outer Glow/Ring
    final Paint glowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx - radius, center.dy - radius),
        Offset(center.dx + radius, center.dy + radius),
        [
          AppTheme.primaryColor.withOpacity(0.5),
          AppTheme.accentColor.withOpacity(0.5),
        ],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius + 4, glowPaint);

    // 3. Draw Main Pin Body (White Circle)
    final Paint bodyPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius, bodyPaint);

    // 4. Draw Inner Color Ring
    final Paint innerRingPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx - radius, center.dy - radius),
        Offset(center.dx + radius, center.dy + radius),
        [AppTheme.accentOrange, AppTheme.accentColor],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - 4, innerRingPaint);

    // 5. Draw Icon (Minimalist)
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.location_on.codePoint),
        style: TextStyle(
          fontSize: 44,
          fontFamily: Icons.location_on.fontFamily,
          color: AppTheme.accentColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2 + 5),
    );

    // 6. Draw the "Pin" point at the bottom
    final Path pinPath = Path();
    pinPath.moveTo(center.dx - 15, center.dy + radius - 5);
    pinPath.lineTo(center.dx + 15, center.dy + radius - 5);
    pinPath.lineTo(center.dx, center.dy + radius + 15);
    pinPath.close();

    final Paint pinPaint = Paint()..color = Colors.white;
    canvas.drawPath(pinPath, pinPaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(markerSize, markerSize + 20);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  void _showPlaceDialog(PlaceModel place) {
    final l10n = AppLocalizations.of(context)!;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child:
              Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 400),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Header with gradient
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppTheme.primaryColor,
                                        const Color(0xFF5B4ED0),
                                      ],
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Icon
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.location_on,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              place.name,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              l10n.safeZone,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.white.withOpacity(
                                                  0.7,
                                                ),
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Close button
                                      GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Content
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      // Address info
                                      _InfoRow(
                                        icon: Icons.location_on,
                                        label: l10n.address,
                                        value: place.address,
                                        iconColor: AppTheme.primaryColor,
                                      ),
                                      const SizedBox(height: 16),
                                      // Radius info
                                      _InfoRow(
                                        icon: Icons.radar,
                                        label: l10n.radius,
                                        value: '${place.radius.toInt()}m',
                                        iconColor: AppTheme.accentGreen,
                                      ),
                                      const SizedBox(height: 16),

                                      const SizedBox(height: 24),
                                      // Action buttons
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _ActionButton(
                                              icon: Icons.edit,
                                              label: l10n.editPlace,
                                              onTap: () {
                                                Navigator.pop(context);
                                                context.push(
                                                  '/places/add',
                                                  extra: {
                                                    'id': place.id,
                                                    'name': place.name,
                                                    'address': place.address,
                                                    'radius': place.radius,
                                                    'emoji': place.emoji,
                                                    'location': {
                                                      'coordinates': [
                                                        place
                                                            .location
                                                            .longitude,
                                                        place.location.latitude,
                                                      ],
                                                    },
                                                  },
                                                );
                                              },
                                              isPrimary: true,
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
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                    duration: 300.ms,
                    curve: Curves.easeOutBack,
                  ),
        );
      },
    );
  }
}

class _MapControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final Color? iconColor;

  const _MapControlButton({
    required this.icon,
    required this.onPressed,
    this.size = 48,
    this.iconColor,
  });

  @override
  State<_MapControlButton> createState() => _MapControlButtonState();
}

class _MapControlButtonState extends State<_MapControlButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(widget.size / 2),
            boxShadow: AppTheme.cardShadow,
            border: Border.all(color: AppTheme.glassBorder, width: 1),
          ),
          child: Icon(
            widget.icon,
            color: widget.iconColor ?? AppTheme.textPrimary,
            size: widget.size * 0.45,
          ),
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final dynamic user;

  const _MemberCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () => context.push('/member/${user.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLG,
          vertical: AppTheme.spacingSM,
        ),
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: AppTheme.borderRadiusLG,
          border: Border.all(color: AppTheme.glassBorder, width: 1),
        ),
        child: Row(
          children: [
            AvatarWithStatus(
              imageUrl: user.avatarUrl,
              size: 48,
              isOnline: user.isOnline,
              statusEmoji: user.statusEmoji,
              batteryLevel: user.batteryLevel,
            ),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.name,
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(user.address, style: AppTheme.bodySmall),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSM,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: user.batteryLevel <= 20
                        ? AppTheme.accentRed.withOpacity(0.2)
                        : AppTheme.accentGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        user.batteryLevel <= 20
                            ? FontAwesomeIcons.batteryQuarter
                            : FontAwesomeIcons.batteryFull,
                        size: 12,
                        color: user.batteryLevel <= 20
                            ? AppTheme.accentRed
                            : AppTheme.accentGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${user.batteryLevel}%',
                        style: AppTheme.caption.copyWith(
                          color: user.batteryLevel <= 20
                              ? AppTheme.accentRed
                              : AppTheme.accentGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(user.getTimeAgo(l10n), style: AppTheme.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.caption.copyWith(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.primaryColor : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary
                ? Colors.white.withOpacity(0.2)
                : AppTheme.glassBorder,
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isPrimary ? Colors.white : AppTheme.primaryColor,
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTheme.caption.copyWith(
                color: isPrimary ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoCircleView extends ConsumerStatefulWidget {
  @override
  _NoCircleViewState createState() => _NoCircleViewState();
}

class _NoCircleViewState extends ConsumerState<_NoCircleView> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  Future<void> _handleJoin() async {
    final l10n = AppLocalizations.of(context)!;
    if (_codeController.text.trim().isEmpty) return;

    final success = await ref
        .read(circleProvider.notifier)
        .joinCircle(_codeController.text.trim());
    if (success && mounted) {
      LocationService.updateCurrentLocation();
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(circleProvider).error ?? l10n.failedToJoinCircle,
          ),
        ),
      );
    }
  }

  Future<void> _handleCreate() async {
    final l10n = AppLocalizations.of(context)!;
    if (_nameController.text.trim().isEmpty) return;

    final success = await ref
        .read(circleProvider.notifier)
        .createCircle(_nameController.text.trim());
    if (success && mounted) {
      LocationService.updateCurrentLocation();
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(circleProvider).error ?? l10n.failedToCreateCircle,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authProvider).user;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMD,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // Top Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spacingMD,
                          ),
                          child: Row(
                            children: [
                              // User Info
                              GestureDetector(
                                    onTap: () => context.push('/profile'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.08),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          AvatarWidget(
                                            imageUrl: user?.avatarUrl ?? '',
                                            size: 32,
                                            ringColor: AppTheme.primaryColor
                                                .withOpacity(0.5),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                user?.name ?? '',
                                                style: AppTheme.bodyMedium
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                              Text(
                                                l10n.profile,
                                                style: AppTheme.caption
                                                    .copyWith(
                                                      color: AppTheme
                                                          .textSecondary,
                                                      fontSize: 10,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(duration: 400.ms)
                                  .slideX(begin: -0.2),
                              const Spacer(),
                              // Logout Button
                              IconButton(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: AppTheme.cardColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          title: Text(
                                            l10n.logout,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          content: Text(
                                            'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
                                            style: AppTheme.bodyMedium.copyWith(
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: Text(
                                                l10n.cancel,
                                                style: TextStyle(
                                                  color: AppTheme.textMuted,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                ref
                                                    .read(authProvider.notifier)
                                                    .logout();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppTheme.accentRed,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: Text(l10n.logout),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      FontAwesomeIcons.rightFromBracket,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(duration: 400.ms)
                                  .slideX(begin: 0.2),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.group_add_rounded,
                            size: 50,
                            color: AppTheme.primaryColor,
                          ),
                        ).animate().scale(
                          duration: 600.ms,
                          curve: Curves.elasticOut,
                        ),
                        const SizedBox(height: AppTheme.spacingXL),
                        Text(
                          l10n.welcomeToGeoFollow,
                          style: AppTheme.heading1,
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: AppTheme.spacingMD),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            l10n.noCircleDescription,
                            style: AppTheme.bodyLarge.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                        const SizedBox(height: AppTheme.spacing2XL),

                        // Join Section
                        Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacingXL,
                              ),
                              child: _buildInputSection(
                                controller: _codeController,
                                hint: l10n.enterCode,
                                buttonLabel: l10n.joinCircle,
                                onPressed: _handleJoin,
                                icon: Icons.vpn_key_outlined,
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 600.ms, duration: 400.ms)
                            .slideY(begin: 0.1, end: 0),

                        const SizedBox(height: AppTheme.spacingLG),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingXL,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Divider(color: AppTheme.glassBorder),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  l10n.or,
                                  style: AppTheme.caption.copyWith(
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(color: AppTheme.glassBorder),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 700.ms),
                        const SizedBox(height: AppTheme.spacingLG),

                        // Create Section
                        Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacingXL,
                              ),
                              child: _buildInputSection(
                                controller: _nameController,
                                hint: l10n.circleNameExample,
                                buttonLabel: l10n.createCircle,
                                onPressed: _handleCreate,
                                icon: Icons.add_circle_outline,
                                isPrimary: true,
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 800.ms, duration: 400.ms)
                            .slideY(begin: 0.1, end: 0),
                        const SizedBox(height: AppTheme.spacingXL),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection({
    required TextEditingController controller,
    required String hint,
    required String buttonLabel,
    required VoidCallback onPressed,
    required IconData icon,
    bool isPrimary = false,
  }) {
    return Column(
      children: [
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textMuted),
            prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: isPrimary
                  ? AppTheme.primaryColor
                  : AppTheme.surfaceLight,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: isPrimary ? null : BorderSide(color: AppTheme.glassBorder),
              elevation: isPrimary ? 4 : 0,
            ),
            child: Text(
              buttonLabel,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapTypeOption extends StatelessWidget {
  final MapType type;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _MapTypeOption({
    required this.type,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : AppTheme.textSecondary,
        ),
      ),
    );
  }
}
