import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:dio/dio.dart';
import 'package:tracker_app/core/providers/providers.dart';
import 'package:tracker_app/core/services/api_client.dart';
import 'package:tracker_app/core/theme/app_theme.dart';
import 'package:tracker_app/shared/widgets/glass_container.dart';
import 'package:tracker_app/l10n/app_localizations.dart';
import 'package:tracker_app/core/services/location_service.dart';

class AddPlaceScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? placeToEdit;

  const AddPlaceScreen({super.key, this.placeToEdit});

  @override
  ConsumerState<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends ConsumerState<AddPlaceScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  double _radius = 500;
  LatLng _currentCenter = const LatLng(41.0082, 28.9784);
  String _currentAddress = '';
  bool _isSaving = false;
  int _step = 0;
  GoogleMapController? _mapController;

  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  final String _googleApiKey = 'AIzaSyAgoiucP1vJNL9DJmCdZ6JI97-i8QcWmqo';

  @override
  void initState() {
    super.initState();
    if (widget.placeToEdit != null) {
      final place = widget.placeToEdit!;
      _nameController.text = place['name'] ?? '';
      _currentAddress = place['address'] ?? '';
      _radius = (place['radius'] as num).toDouble();

      final location = place['location'];
      if (location != null && location['coordinates'] != null) {
        final coords = location['coordinates'];
        // MongoDB coordinates are [longitude, latitude]
        _currentCenter = LatLng(coords[1], coords[0]);
      }

      // Since we already have the address, no need to geocode immediately
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goToCurrentLocation();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController?.dispose();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _searchPlaces(query);
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    });
  }

  Future<void> _searchPlaces(String query) async {
    setState(() => _isSearching = true);
    try {
      final dio = Dio();
      final l10n = AppLocalizations.of(context)!;
      final url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=$_googleApiKey&language=${l10n.localeName}';
      final response = await dio.get(url);

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        setState(() {
          _searchResults = response.data['predictions'];
        });
      } else {
        debugPrint('Search API Error: ${response.data}');
        setState(() {
          _searchResults = [];
        });
      }
    } catch (e) {
      debugPrint('Exception in _searchPlaces: $e');
      setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _goToPlace(String placeId) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchResults = [];
      _searchController.clear();
    });

    try {
      final dio = Dio();
      final url =
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleApiKey';
      final response = await dio.get(url);

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final location = response.data['result']['geometry']['location'];
        final lat = location['lat'];
        final lng = location['lng'];

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15),
        );
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
    }
  }

  Future<void> _goToCurrentLocation() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _currentAddress = l10n.fetchingAddress);

    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        final latLng = LatLng(position.latitude, position.longitude);
        setState(() => _currentCenter = latLng);
        if (_mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: latLng, zoom: 15.5),
            ),
          );
        }
      }
    } catch (_) {}

    if (mounted) {
      await _getAddress();
    }
  }

  Future<void> _getAddress() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (_currentAddress.isEmpty) {
      setState(() {
        _currentAddress = l10n.fetchingAddress;
      });
    }
    try {
      // First try native geocoding
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentCenter.latitude,
        _currentCenter.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        debugPrint('Placemark data: ${place.toJson()}');

        setState(() {
          // Combine address parts, prioritizing street names
          final street = place.street ?? place.thoroughfare ?? place.name;
          _currentAddress =
              [
                    street,
                    place.subLocality,
                    place.locality,
                    place.administrativeArea,
                  ]
                  .where((part) => part != null && part.isNotEmpty)
                  .toSet()
                  .join(', '); // toSet to remove duplicates

          if (_currentAddress.trim().isEmpty) {
            _currentAddress = l10n.noAddressFound;
          }
        });
        return; // Success, exit
      }
    } catch (e) {
      debugPrint(
        'Native geocoding error: $e, falling back to Google Maps API...',
      );
    }

    // Fallback to Google Maps Geocoding API if native fails
    try {
      const apiKey =
          'AIzaSyAgoiucP1vJNL9DJmCdZ6JI97-i8QcWmqo'; // Maps API key from Manifest
      final dio = Dio();
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${_currentCenter.latitude},${_currentCenter.longitude}&key=$apiKey&language=${l10n.localeName}';
      final response = await dio.get(url);

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        if (results.isNotEmpty) {
          final firstResult = results.first;
          if (mounted) {
            setState(() {
              _currentAddress = firstResult['formatted_address'];
            });
          }
          return; // Success, exit
        }
      } else {
        debugPrint('Geocoding API missing status OK: ${response.data}');
      }
    } catch (e) {
      debugPrint('Google Maps API fallback error: $e');
    }

    // If both fail
    if (mounted) {
      setState(() {
        _currentAddress = l10n.noAddressFound;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMD,
                  vertical: AppTheme.spacingSM, // More minimal padding
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ).animate().fadeIn(duration: 300.ms),
                    const SizedBox(width: AppTheme.spacingMD),
                    Text(
                      widget.placeToEdit != null
                          ? l10n.editPlace
                          : l10n.addPlace,
                      style: AppTheme.heading4, // Slightly smaller header
                    ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _currentCenter,
                        zoom: 14,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      onCameraMove: (position) {
                        setState(() {
                          _currentCenter = position.target;
                        });
                      },
                      onCameraIdle: () {
                        _getAddress();
                      },
                      circles: {
                        Circle(
                          circleId: const CircleId('new_place'),
                          center: _currentCenter,
                          radius: _radius,
                          strokeColor: AppTheme.primaryColor,
                          strokeWidth: 2,
                          fillColor: AppTheme.primaryColor.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      },
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                    ),
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: 30,
                        ), // Padding to point the bottom of the pin to center
                        child: Icon(
                          Icons.location_on,
                          size: 40,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    if (_step == 0)
                      Positioned(
                        right: AppTheme.spacingMD,
                        bottom: AppTheme.spacingMD,
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                shape: BoxShape.circle,
                                boxShadow: AppTheme.cardShadow,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  _mapController?.animateCamera(
                                    CameraUpdate.zoomIn(),
                                  );
                                },
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                shape: BoxShape.circle,
                                boxShadow: AppTheme.cardShadow,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: _goToCurrentLocation,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingSM),
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                shape: BoxShape.circle,
                                boxShadow: AppTheme.cardShadow,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () {
                                  _mapController?.animateCamera(
                                    CameraUpdate.zoomOut(),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    /* TODO_SEARCH if (_step == 0)
                      Positioned(
                        top: AppTheme.spacingMD,
                        left: AppTheme.spacingMD,
                        right: AppTheme.spacingMD,
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusXL,
                                ),
                                boxShadow: AppTheme.cardShadow,
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                style: AppTheme.bodyMedium,
                                decoration: InputDecoration(
                                  hintText: l10n.searchForPlace,
                                  hintStyle: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textMuted,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: AppTheme.textSecondary,
                                  ),
                                  suffixIcon: _isSearching
                                      ? const Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            color: AppTheme.textSecondary,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _searchResults = [];
                                            });
                                          },
                                        )
                                      : null,
                                  contentPadding: const EdgeInsets.all(
                                    AppTheme.spacingMD,
                                  ),
                                ),
                              ),
                            ),
                            if (_searchResults.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(
                                  top: AppTheme.spacingSM,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardColor,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusXL,
                                  ),
                                  boxShadow: AppTheme.cardShadow,
                                ),
                                constraints: const BoxConstraints(
                                  maxHeight: 250,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final place = _searchResults[index];
                                    return ListTile(
                                      leading: const Icon(
                                        Icons.location_on,
                                        color: AppTheme.primaryColor,
                                      ),
                                      title: Text(
                                        place['structured_formatting']['main_text'] ??
                                            place['description'],
                                        style: AppTheme.bodyMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle:
                                          place['structured_formatting']['secondary_text'] !=
                                              null
                                          ? Text(
                                              place['structured_formatting']['secondary_text'],
                                              style: AppTheme.bodySmall
                                                  .copyWith(
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            )
                                          : null,
                                      onTap: () {
                                        _goToPlace(place['place_id']);
                                      },
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ), */
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLG),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_step == 0) ...[
                      Text(
                        l10n.selectedLocation,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ).animate().fadeIn(duration: 400.ms),
                      const SizedBox(height: AppTheme.spacingSM),
                      Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: AppTheme.borderRadiusXL,
                            ),
                            child: Text(
                              _currentAddress,
                              style: AppTheme.bodyMedium,
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 150.ms)
                          .slideY(begin: 0.1, end: 0),
                      const SizedBox(height: AppTheme.spacingLG),
                      Row(
                        children: [
                          Text(
                            l10n.radius,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(_radius / 1000).toStringAsFixed(1)} km',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                      const SizedBox(height: AppTheme.spacingSM),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppTheme.primaryColor,
                          inactiveTrackColor: AppTheme.surfaceLight,
                          thumbColor: AppTheme.primaryColor,
                          overlayColor: AppTheme.primaryColor.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        child: Slider(
                          value: _radius,
                          min: 100,
                          max: 2000,
                          onChanged: (value) {
                            setState(() {
                              _radius = value;
                            });
                          },
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                      const SizedBox(height: AppTheme.spacingLG),
                      GlassButton(
                            onPressed: () {
                              setState(() {
                                _step = 1;
                              });
                            },
                            width: double.infinity,
                            gradient: AppTheme.primaryGradient,
                            child: Text(l10n.continueBtn),
                          )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 400.ms)
                          .slideY(begin: 0.2, end: 0),
                    ] else ...[
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _step = 0;
                              });
                            },
                            icon: const Icon(Icons.arrow_back),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: AppTheme.spacingSM),
                          Text(l10n.placeDetails, style: AppTheme.heading4),
                        ],
                      ).animate().fadeIn(duration: 400.ms),
                      const SizedBox(height: AppTheme.spacingLG),
                      Text(
                        l10n.placeName,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ).animate().fadeIn(duration: 400.ms),
                      const SizedBox(height: AppTheme.spacingSM),
                      Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: AppTheme.borderRadiusXL,
                            ),
                            child: TextField(
                              controller: _nameController,
                              style: AppTheme.bodyLarge,
                              decoration: InputDecoration(
                                hintText: l10n.placeNameHint,
                                hintStyle: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.textMuted,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingMD,
                                ),
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 100.ms)
                          .slideY(begin: 0.1, end: 0),
                      const SizedBox(height: AppTheme.spacingLG),
                      GlassButton(
                            onPressed: _isSaving
                                ? null
                                : () => _savePlace(context),
                            width: double.infinity,
                            gradient: AppTheme.primaryGradient,
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(l10n.savePlaceBtn),
                          )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 400.ms)
                          .slideY(begin: 0.2, end: 0),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePlace(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ref.read(toastControllerProvider).showError(context, l10n.enterPlaceName);
      return;
    }

    final circleState = ref.read(circleProvider);
    if (circleState.circle == null) {
      ref
          .read(toastControllerProvider)
          .showError(context, l10n.noCircleFoundError);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final placeData = {
        'name': name,
        'address': _currentAddress,
        'latitude': _currentCenter.latitude,
        'longitude': _currentCenter.longitude,
        'radius': _radius,
        'emoji': widget.placeToEdit?['emoji'] ?? '📍',
        'circleId': circleState.circle!.id,
      };

      final response = widget.placeToEdit != null
          ? await ApiClient.updatePlace(widget.placeToEdit!['id'], placeData)
          : await ApiClient.createPlace(placeData);

      if (response['success'] == true) {
        // Refresh the circle to get the updated places
        await ref.read(circleProvider.notifier).fetchCircle();

        if (mounted) {
          ref
              .read(toastControllerProvider)
              .showSuccess(
                context,
                widget.placeToEdit != null
                    ? l10n.placeUpdated(name)
                    : l10n.placeSaved(name),
              );
          context.pop();
        }
      } else {
        if (mounted) {
          ref
              .read(toastControllerProvider)
              .showError(context, response['message'] ?? l10n.failedToAddPlace);
        }
      }
    } catch (e) {
      if (mounted) {
        ref
            .read(toastControllerProvider)
            .showError(context, l10n.errorSavingPlace(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
