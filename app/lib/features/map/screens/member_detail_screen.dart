import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tracker_app/core/models/user_model.dart';
import 'package:tracker_app/core/providers/providers.dart';
import 'package:tracker_app/core/services/api_client.dart';
import 'dart:ui';
import 'package:tracker_app/core/theme/app_theme.dart';
import 'package:tracker_app/l10n/app_localizations.dart';
import 'package:tracker_app/shared/widgets/premium_bottom_sheet.dart';
import 'package:tracker_app/core/providers/auth_provider.dart';
// MemberDetailScreen
// ─────────────────────────────────────────────────────────────────────────────

class MemberDetailScreen extends ConsumerStatefulWidget {
  final String memberId;
  const MemberDetailScreen({super.key, required this.memberId});

  @override
  ConsumerState<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends ConsumerState<MemberDetailScreen> {
  GoogleMapController? _mapController;
  int _historyTab = 0; // 0 = Bugün, 1 = Sık Gidilen

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Sadece bu üyeye ait veriler değiştiğinde rebuild tetikle (Performans & Animasyon Fix)
    final user = ref.watch(
      usersProvider.select(
        (list) => list.firstWhere(
          (u) => u.id == widget.memberId,
          orElse: () => list.isNotEmpty ? list.first : UserModel.empty(),
        ),
      ),
    );

    final movementAsync = ref.watch(movementHistoryProvider(widget.memberId));
    final frequentAsync = ref.watch(frequentPlacesProvider(widget.memberId));

    if (user.id.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Container(
        color: AppTheme.backgroundColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── AppBar ──────────────────────────────────────────────────
            SliverAppBar(
              key: ValueKey('member_appbar_${user.id}'),
              expandedHeight: 280,
              pinned: true,
              stretch: false,
              backgroundColor: AppTheme.backgroundColor,
              surfaceTintColor: Colors.transparent,
              centerTitle: true,
              title: Text(
                user.name,
                style: AppTheme.heading3.copyWith(color: Colors.white),
              ).animate().fadeIn(duration: 400.ms),
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingSM),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms),
              actions: const [],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'avatar_${user.id}',
                      child:
                          user.avatarUrl.isNotEmpty &&
                              user.avatarUrl.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: user.avatarUrl,
                              fit: BoxFit.cover,
                              placeholder: (ctx, url) =>
                                  Container(color: AppTheme.surfaceColor),
                              errorWidget: (ctx, url, error) => Container(
                                color: AppTheme.surfaceColor,
                                child: const Icon(
                                  FontAwesomeIcons.solidUser,
                                  size: 64,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            )
                          : Container(
                              color: AppTheme.surfaceColor,
                              child: const Icon(
                                FontAwesomeIcons.solidUser,
                                size: 64,
                                color: AppTheme.textMuted,
                              ),
                            ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppTheme.backgroundColor.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Body ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                color: AppTheme.backgroundColor,
                child: Column(
                  children: [
                    _buildUserInfo(user, l10n),
                    _buildMapSnippet(user, l10n),
                    _buildActionButtons(user, l10n),
                    const SizedBox(height: AppTheme.spacingLG),
                    _buildHistorySection(l10n, movementAsync, frequentAsync),
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

  // Animasyonların sürekli tekrarlanmasını engellemek için yardımcı metod
  Widget _animateOnce(Widget child, {int delayMs = 0}) {
    // ValueKey ekleyerek widget ağacında stabiliteyi koruyoruz
    return child
        .animate(key: ValueKey('anim_${child.hashCode}'))
        .fadeIn(duration: 400.ms, delay: delayMs.ms);
  }

  // ── User Info ─────────────────────────────────────────────────────────────

  Widget _buildUserInfo(UserModel user, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(user.name, style: AppTheme.heading1),
                        ),
                        const SizedBox(width: AppTheme.spacingSM),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: user.isOnline
                                ? AppTheme.accentGreen
                                : AppTheme.textMuted,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (user.isOnline
                                            ? AppTheme.accentGreen
                                            : AppTheme.textMuted)
                                        .withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      user.status,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMD,
                  vertical: AppTheme.spacingSM,
                ),
                decoration: BoxDecoration(
                  color: user.batteryLevel <= 20
                      ? AppTheme.accentRed.withOpacity(0.2)
                      : AppTheme.accentGreen.withOpacity(0.2),
                  borderRadius: AppTheme.borderRadiusLG,
                ),
                child: Row(
                  children: [
                    Icon(
                      user.batteryLevel <= 20
                          ? FontAwesomeIcons.batteryQuarter
                          : FontAwesomeIcons.batteryFull,
                      size: 16,
                      color: user.batteryLevel <= 20
                          ? AppTheme.accentRed
                          : AppTheme.accentGreen,
                    ),
                    const SizedBox(width: AppTheme.spacingSM),
                    Text(
                      '${user.batteryLevel}%',
                      style: AppTheme.bodyMedium.copyWith(
                        color: user.batteryLevel <= 20
                            ? AppTheme.accentRed
                            : AppTheme.accentGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: AppTheme.borderRadiusLG,
            ),
            child: Row(
              children: [
                const Icon(
                  FontAwesomeIcons.locationDot,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(child: Text(user.address, style: AppTheme.bodyMedium)),
                Text(
                  user.getTimeAgo(l10n),
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Map Snippet ───────────────────────────────────────────────────────────

  Widget _buildMapSnippet(UserModel user, AppLocalizations l10n) {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
      decoration: BoxDecoration(
        borderRadius: AppTheme.borderRadiusXL,
        boxShadow: AppTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: AppTheme.borderRadiusXL,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: user.location,
            zoom: 15,
          ),
          onMapCreated: (c) => _mapController = c,
          markers: {
            Marker(markerId: MarkerId(user.id), position: user.location),
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }

  // ── Action Buttons ────────────────────────────────────────────────────────

  Widget _buildActionButtons(UserModel user, AppLocalizations l10n) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser?.id == user.id) return const SizedBox.shrink();

    return _animateOnce(
      Container(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: FontAwesomeIcons.message,
                label: l10n.message,
                onTap: () => _showMessageSheet(user, l10n),
              ),
            ),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: _ActionButton(
                icon: FontAwesomeIcons.handPointer,
                label: l10n.nudge,
                isPrimary: true,
                onTap: () async {
                  final response = await ApiClient.nudgeUser(user.id);
                  if (response['success'] == true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.userNudged(user.name))),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
      delayMs: 800,
    );
  }

  void _showMessageSheet(UserModel user, AppLocalizations l10n) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _MessageSheet(
          user: user,
          messageController: ctrl,
          onCancel: () => Navigator.pop(ctx),
          onSendMessage: () async {
            final msg = ctrl.text.trim();
            if (msg.isEmpty) return;
            final res = await ApiClient.sendMessageToUser(user.id, msg);
            if (res['success'] == true && ctx.mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.messageSent)));
            }
          },
        ),
      ),
    );
  }

  // ── History Section ───────────────────────────────────────────────────────

  Widget _buildHistorySection(
    AppLocalizations l10n,
    AsyncValue<List<MovementHistory>> movementAsync,
    AsyncValue<List<FrequentPlace>> frequentAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLG,
        0,
        AppTheme.spacingLG,
        AppTheme.spacingLG,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Tab Toggle
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.movementHistory,
                  style: AppTheme.heading3,
                ).animate().fadeIn(duration: 400.ms, delay: 800.ms),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TabChip(
                      label: l10n.today,
                      selected: _historyTab == 0,
                      onTap: () => setState(() => _historyTab = 0),
                    ),
                    _TabChip(
                      label: l10n.frequent,
                      selected: _historyTab == 1,
                      onTap: () => setState(() => _historyTab = 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),

          // Content
          AnimatedSwitcher(
            duration: 300.ms,
            child: Builder(
              builder: (ctx) {
                final currentUser = ref.watch(authProvider).user;
                final isPremium = currentUser?.isPremium ?? false;

                final content = _historyTab == 0
                    ? _buildTodayTab(movementAsync, l10n)
                    : _buildFrequentTab(frequentAsync, l10n);

                if (isPremium) {
                  return content;
                }

                return Stack(
                  children: [
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                      child: Opacity(
                        opacity: 0.6,
                        child: AbsorbPointer(child: content),
                      ),
                    ),
                    Positioned(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.workspace_premium,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingMD),
                            Text(
                              l10n.localeName == 'en'
                                  ? 'Premium Feature'
                                  : 'Premium Özellik',
                              style: AppTheme.heading3.copyWith(
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingSM),
                            ElevatedButton(
                              onPressed: () => PremiumBottomSheet.show(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppTheme.borderRadiusLG,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingLG,
                                  vertical: AppTheme.spacingMD,
                                ),
                              ),
                              child: Text(
                                l10n.localeName == 'en'
                                    ? 'Unlock Premium'
                                    : 'Premiuma Geç',
                                style: AppTheme.button,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTab(
    AsyncValue<List<MovementHistory>> async,
    AppLocalizations l10n,
  ) {
    return async.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => _EmptyHistory(message: l10n.noMovementData),
      data: (list) {
        if (list.isEmpty) return _EmptyHistory(message: l10n.noMovementData);

        // İki konum arasındaki yolculuk süresini hesaplayarak araya ekliyoruz
        final items = <Widget>[];
        for (int i = 0; i < list.length; i++) {
          final movement = list[i];

          // Konum kartı
          items.add(
            _MovementTimelineItem(
              movement: movement,
              isLast: i == list.length - 1,
              index: i,
            ),
          );

          // Yolculuk kartı (Eğer bir önceki (zaman olarak daha eski) kayıt varsa)
          if (i < list.length - 1) {
            final prevMovement =
                list[i + 1]; // Liste desc olduğu için i+1 daha eskidir
            if (prevMovement.leftAt != null) {
              final travelDuration = movement.arrivedAt.difference(
                prevMovement.leftAt!,
              );
              // Sadece 2 dakikadan uzun yolculukları göster
              if (travelDuration.inMinutes >= 2) {
                items.add(
                  _TravelTimelineItem(
                    duration: travelDuration,
                    fromPlace: prevMovement.placeName,
                    toPlace: movement.placeName,
                  ),
                );
              }
            }
          }
        }

        return Column(children: items);
      },
    );
  }

  Widget _buildFrequentTab(
    AsyncValue<List<FrequentPlace>> async,
    AppLocalizations l10n,
  ) {
    return async.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => _EmptyHistory(message: l10n.noMovementData),
      data: (list) {
        if (list.isEmpty) return _EmptyHistory(message: l10n.noMovementData);
        return Column(
          children: list.asMap().entries.map((e) {
            return _FrequentPlaceCard(place: e.value, index: e.key, l10n: l10n);
          }).toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TabChip
// ─────────────────────────────────────────────────────────────────────────────

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyHistory
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  final String message;
  const _EmptyHistory({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: AppTheme.borderRadiusXL,
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        children: [
          const Icon(
            FontAwesomeIcons.mapPin,
            size: 32,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Text(
            message,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MovementTimelineItem
// ─────────────────────────────────────────────────────────────────────────────

class _MovementTimelineItem extends StatelessWidget {
  final MovementHistory movement;
  final bool isLast;
  final int index;

  const _MovementTimelineItem({
    required this.movement,
    required this.isLast,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline indicator
            Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == 0
                        ? AppTheme.primaryColor.withOpacity(0.15)
                        : AppTheme.surfaceLight,
                    border: Border.all(
                      color: index == 0
                          ? AppTheme.primaryColor
                          : AppTheme.glassBorder,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      movement.emoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 20, // Daha kısa yaptık çünkü araya Travel gelecek
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppTheme.glassBorder,
                  ),
              ],
            ),
            const SizedBox(width: AppTheme.spacingMD),
            // Content card
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: AppTheme.borderRadiusLG,
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            movement.placeName == 'Stationary'
                                ? (l10n.localeName == 'tr'
                                      ? 'Sabit Nokta'
                                      : 'Stationary Spot')
                                : movement.placeName,
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          movement.getTimeRange(l10n),
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(movement.address, style: AppTheme.bodySmall),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            movement.duration,
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              height: 1.1,
                            ),
                          ),
                        ),
                        if (movement.visitCount > 1) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${movement.visitCount}×',
                              style: AppTheme.caption.copyWith(
                                color: AppTheme.accentGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: Duration(milliseconds: 900 + (index * 80)),
        )
        .slideX(begin: 0.1, end: 0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TravelTimelineItem
// ─────────────────────────────────────────────────────────────────────────────

class _TravelTimelineItem extends StatelessWidget {
  final Duration duration;
  final String fromPlace;
  final String toPlace;

  const _TravelTimelineItem({
    required this.duration,
    required this.fromPlace,
    required this.toPlace,
  });

  @override
  Widget build(BuildContext context) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';

    String durationStr = duration.inHours >= 1
        ? '${duration.inHours}${isTr ? 'sa' : 'h'} ${duration.inMinutes % 60}m'
        : '${duration.inMinutes}m';

    return Padding(
      padding: const EdgeInsets.only(left: 17, bottom: 12, top: 2),
      child: Row(
        children: [
          Column(
            children: [
              Container(width: 2, height: 15, color: AppTheme.glassBorder),
              const SizedBox(height: 2),
              Icon(
                FontAwesomeIcons.carSide,
                size: 12,
                color: AppTheme.primaryColor.withOpacity(0.5),
              ),
              const SizedBox(height: 2),
              Container(width: 2, height: 15, color: AppTheme.glassBorder),
            ],
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Text(
                  isTr ? 'Yolculuk:' : 'Travel:',
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  durationStr,
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.05, end: 0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FrequentPlaceCard
// ─────────────────────────────────────────────────────────────────────────────

class _FrequentPlaceCard extends StatelessWidget {
  final FrequentPlace place;
  final int index;
  final AppLocalizations l10n;

  const _FrequentPlaceCard({
    required this.place,
    required this.index,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final isTop = index == 0;
    return Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          decoration: BoxDecoration(
            color: isTop
                ? AppTheme.primaryColor.withOpacity(0.08)
                : AppTheme.surfaceLight,
            borderRadius: AppTheme.borderRadiusLG,
            border: Border.all(
              color: isTop
                  ? AppTheme.primaryColor.withOpacity(0.3)
                  : AppTheme.glassBorder,
            ),
          ),
          child: Row(
            children: [
              // Rank + Emoji
              Column(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isTop
                          ? AppTheme.primaryColor.withOpacity(0.2)
                          : AppTheme.surfaceColor,
                      border: Border.all(
                        color: isTop
                            ? AppTheme.primaryColor
                            : AppTheme.glassBorder,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        place.emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#${index + 1}',
                    style: AppTheme.caption.copyWith(
                      color: isTop ? AppTheme.primaryColor : AppTheme.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppTheme.spacingMD),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.placeName,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isTop
                            ? AppTheme.primaryColor
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(place.address, style: AppTheme.bodySmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StatBadge(
                          icon: Icons.repeat_rounded,
                          label: l10n.totalVisits(place.totalVisits),
                          color: AppTheme.accentGreen,
                        ),
                        const SizedBox(width: 8),
                        _StatBadge(
                          icon: Icons.timer_outlined,
                          label: l10n.avgTime(place.avgDuration),
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                    if (place.lastVisit != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.lastVisitLabel}: ${_formatDate(place.lastVisit!)}',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: Duration(milliseconds: 900 + (index * 100)),
        )
        .slideY(begin: 0.1, end: 0);
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatBadge
// ─────────────────────────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              height: 1.1, // Better vertical centering
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActionButton
// ─────────────────────────────────────────────────────────────────────────────

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
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
        decoration: BoxDecoration(
          gradient: isPrimary ? AppTheme.primaryGradient : null,
          color: isPrimary ? null : AppTheme.surfaceLight,
          borderRadius: AppTheme.borderRadiusLG,
          border: isPrimary
              ? null
              : Border.all(color: AppTheme.glassBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isPrimary ? Colors.white : AppTheme.textPrimary,
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: isPrimary ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MessageSheet
// ─────────────────────────────────────────────────────────────────────────────

class _MessageSheet extends StatelessWidget {
  final dynamic user;
  final TextEditingController messageController;
  final VoidCallback onSendMessage;
  final VoidCallback onCancel;

  const _MessageSheet({
    required this.user,
    required this.messageController,
    required this.onSendMessage,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.sendMessageTo(user.name), style: AppTheme.heading3),
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingLG),
            TextField(
              controller: messageController,
              maxLines: 4,
              style: AppTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: l10n.typeMessage,
                border: OutlineInputBorder(
                  borderRadius: AppTheme.borderRadiusLG,
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                contentPadding: const EdgeInsets.all(AppTheme.spacingMD),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: const BorderSide(color: AppTheme.glassBorder),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingMD,
                      ),
                    ),
                    child: Text(l10n.cancel, style: AppTheme.button),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSendMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingMD,
                      ),
                    ),
                    child: Text(l10n.send, style: AppTheme.button),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
