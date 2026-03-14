import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tracker_app/core/providers/providers.dart';
import 'package:tracker_app/core/providers/auth_provider.dart';
import 'package:tracker_app/core/services/api_client.dart';
import 'package:tracker_app/core/theme/app_theme.dart';
import 'package:tracker_app/l10n/app_localizations.dart';
import 'package:tracker_app/shared/widgets/premium_bottom_sheet.dart';

class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({super.key});

  @override
  ConsumerState<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final places = ref.watch(placesProvider);

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
                l10n.places,
                style: AppTheme.heading3,
              ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
              actions: [
                IconButton(
                  onPressed: () {
                    final user = ref.read(authProvider).user;
                    final isPremium = user?.isPremium ?? false;

                    if (!isPremium && places.isNotEmpty) {
                      PremiumBottomSheet.show(context);
                    } else {
                      context.push('/places/add');
                    }
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingSM),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, size: 18, color: Colors.white),
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLG),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.safeZones,
                      style: AppTheme.heading4.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      l10n.safeZonesSubtitle,
                      style: AppTheme.bodySmall,
                    ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                    const SizedBox(height: AppTheme.spacingLG),
                  ],
                ),
              ),
            ),
            if (places.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight.withValues(
                                alpha: 0.5,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_off_outlined,
                              size: 64,
                              color: AppTheme.textMuted,
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 200.ms)
                          .scale(
                            begin: const Offset(0.8, 0.8),
                            curve: Curves.elasticOut,
                          ),
                      const SizedBox(height: AppTheme.spacingLG),
                      Text(
                        l10n.noSafeZones,
                        style: AppTheme.heading3.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                      const SizedBox(height: AppTheme.spacingSM),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          l10n.noSafeZonesDescription,
                          textAlign: TextAlign.center,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                      const SizedBox(height: AppTheme.spacingXL),
                      ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 8,
                              shadowColor: AppTheme.primaryColor.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            onPressed: () => context.push('/places/add'),
                            icon: const Icon(Icons.add_location_alt),
                            label: Text(
                              l10n.addFirstPlace,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 500.ms)
                          .slideY(begin: 0.2, end: 0),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final place = places[index];
                  return _PlaceCard(place: place, index: index);
                }, childCount: places.length),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _PlaceCard extends ConsumerStatefulWidget {
  final dynamic place;
  final int index;

  const _PlaceCard({required this.place, required this.index});

  @override
  ConsumerState<_PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends ConsumerState<_PlaceCard> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
          onTap: () {
            context.push(
              '/places/add',
              extra: {
                'id': widget.place.id,
                'name': widget.place.name,
                'address': widget.place.address,
                'radius': widget.place.radius,
                'emoji': widget.place.emoji,
                'location': {
                  'coordinates': [
                    widget.place.location.longitude,
                    widget.place.location.latitude,
                  ],
                },
              },
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLG,
              vertical: AppTheme.spacingSM,
            ),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: AppTheme.borderRadiusXL,
              border: Border.all(color: AppTheme.glassBorder, width: 1),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radiusXL),
                  ),
                  child: SizedBox(
                    height: 120,
                    child: Stack(
                      children: [
                        IgnorePointer(
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: widget.place.location,
                              zoom: 14,
                            ),
                            onMapCreated: (controller) =>
                                _mapController = controller,
                            circles: {
                              Circle(
                                circleId: CircleId(widget.place.id),
                                center: widget.place.location,
                                radius: widget.place.radius,
                                strokeColor: AppTheme.primaryColor,
                                strokeWidth: 2,
                                fillColor: AppTheme.primaryColor.withOpacity(
                                  0.15,
                                ),
                              ),
                            },
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            compassEnabled: false,
                            mapToolbarEnabled: false,
                            scrollGesturesEnabled: false,
                            rotateGesturesEnabled: false,
                            tiltGesturesEnabled: false,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.backgroundColor.withOpacity(0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: AppTheme.borderRadiusMD,
                        ),
                        child: Center(
                          child: Text(
                            widget.place.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.place.name,
                              style: AppTheme.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.place.address,
                              style: AppTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSM,
                          vertical: AppTheme.spacingXS,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${(widget.place.radius / 1000).toStringAsFixed(1)} km',
                          style: AppTheme.caption,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingMD),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.accentRed,
                        ),
                        onPressed: () => _deletePlace(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: Duration(milliseconds: 300 + (widget.index * 100)),
        )
        .slideY(begin: 0.1, end: 0);
  }

  Future<void> _deletePlace(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text(l10n.deletePlace, style: AppTheme.heading4),
        content: Text(
          l10n.deletePlaceConfirm(widget.place.name),
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.delete,
              style: TextStyle(color: AppTheme.accentRed),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiClient.deletePlace(widget.place.id);
      await ref.read(circleProvider.notifier).fetchCircle();
      if (mounted) {
        ref
            .read(toastControllerProvider)
            .showSuccess(context, l10n.placeDeleted);
      }
    } catch (e) {
      if (mounted) {
        ref
            .read(toastControllerProvider)
            .showError(context, l10n.failedToDeletePlace);
      }
    }
  }
}
