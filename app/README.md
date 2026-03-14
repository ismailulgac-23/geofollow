You are an ELITE Flutter Developer and a WORLD-CLASS UI/UX Designer.

Your task is to build a FULL FRONTEND MVP of a next-generation, visually stunning, ultra-modern Family & Partner Location Tracking application.

This app MUST look like a 2026 flagship startup product.
Absolutely NO boring, standard, template-like UI.
Everything must feel premium, animated, fluid, glassy, and luxurious.

────────────────────────
CORE PRINCIPLES
────────────────────────
• Flutter (latest stable)
• Dart only
• Pixel-perfect UI
• Heavy use of animations & micro-interactions
• Glassmorphism, soft shadows, blur, depth
• Modern typography hierarchy
• Smooth transitions everywhere
• Looks alive even with mock data
• NO empty states
• NO placeholders
• NO TODO comments

────────────────────────
AUTHENTICATION (CRITICAL)
────────────────────────
❗ There is NO email/password login.
❗ ONLY social media login.

Use a VERY MODERN ICON SYSTEM:
• Integrate an Iconify-style icon package (Iconify / Logos / modern SVG icons)
• Google, Apple, Facebook, X (Twitter), Instagram
• Icons must be big, animated, tactile
• Buttons must have hover/press animations
• Login screen must feel PREMIUM and FUTURISTIC

────────────────────────
TECH STACK (MANDATORY)
────────────────────────
• State Management: flutter_riverpod
• Routing: go_router
• Maps: google_maps_flutter
• Animations: flutter_animate (EXTENSIVELY)
• Bottom Sheet: DraggableScrollableSheet (custom styled)
• Blur: BackdropFilter

────────────────────────
ARCHITECTURE
────────────────────────
Use feature-first / clean architecture:

lib/
 ├─ main.dart
 ├─ core/
 │   ├─ theme/
 │   ├─ router/
 │   ├─ constants/
 │   └─ utils/
 ├─ features/
 │   ├─ onboarding/
 │   ├─ auth/
 │   ├─ map/
 │   ├─ places/
 │   ├─ notifications/
 │   ├─ premium/
 │   └─ profile/
 └─ shared/
     ├─ widgets/
     └─ icons/

Use centralized ThemeData.
No inline styling chaos.

────────────────────────
MOCK DATA (VERY IMPORTANT)
────────────────────────
This is a FRONTEND MVP but it must feel REAL.

You MUST generate rich mock data:
• Users (name, avatar, status, battery, last update)
• Locations (lat/lng, address)
• Movement history (timeline)
• Notifications (alerts, arrivals, battery warnings)
• Places (home, school, gym with geofence radius)

Images:
• Avatars → https://i.pravatar.cc/150?u=unique_id
• Backgrounds → https://images.unsplash.com/photo-ID?w=500&q=80

────────────────────────
REQUIRED SCREENS
────────────────────────

1️⃣ ONBOARDING (3 pages)
• Fullscreen background images
• PageView with animated dots
• Smooth transitions
• Persistent animated “Get Started” button
• Looks cinematic

2️⃣ AUTH / INVITE
• Social login only (icon-based)
• Create Circle / Join with Invite Code
• Micro-interactions on inputs & buttons

3️⃣ HOME (CORE EXPERIENCE)
• Fullscreen Google Map
• Custom dark/light JSON map style
• Custom avatar markers with colored status ring
• DraggableScrollableSheet bottom panel:
  – Circle members
  – Avatar
  – Name
  – Address
  – Battery % (color-coded)
  – Last updated time
• Everything animated on enter

4️⃣ MEMBER DETAIL
• Hero animation from avatar
• Map snippet of exact location
• Action buttons: Message / Directions / Call
• Beautiful custom timeline of today’s movements

5️⃣ PLACES (GEOFENCING)
• List of saved places
• Add new place screen:
  – Mini map
  – Drag radius
  – Live preview
• Clean & elegant UI

6️⃣ NOTIFICATIONS
• Animated event cards
• Examples:
  – “Mom’s battery below 10%”
  – “Partner arrived at Work”

7️⃣ PREMIUM PAYWALL
• Dark, dramatic UI
• Glowing accents
• Feature checklist with staggered animations
• Pulsing “Upgrade to Premium” CTA
• Must feel irresistible

8️⃣ PROFILE & SETTINGS
• Polished ListTile layout
• Avatar header
• Ghost Mode toggle (freeze location)
• Subtle animations on toggles

────────────────────────
DELIVERY FORMAT
────────────────────────
1️⃣ Output the FULL FILE STRUCTURE
2️⃣ Then provide:
   • main.dart
   • ThemeData
   • go_router setup
   • Home Map screen with DraggableScrollableSheet
3️⃣ Code must be production-ready
4️⃣ No explanations unless necessary
5️⃣ No placeholders
6️⃣ Everything must compile logically

────────────────────────
FINAL TONE
────────────────────────
This app must feel:
• New-generation
• Experimental
• Luxurious
• Animated
• Ihtişamlı
• NOT generic
• NOT boring

Build it like a startup about to raise Series A.

Start now.



import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tracker_app/core/providers/providers.dart';
import 'package:tracker_app/core/theme/app_theme.dart';
import 'package:tracker_app/shared/widgets/glass_container.dart';
import 'package:tracker_app/core/services/api_client.dart';
import 'package:tracker_app/l10n/app_localizations.dart';

enum NotifyType { info, success, error }

class MemberDetailScreen extends ConsumerStatefulWidget {
  final String memberId;

  const MemberDetailScreen({super.key, required this.memberId});

  @override
  ConsumerState<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends ConsumerState<MemberDetailScreen> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final users = ref.watch(usersProvider);
    final user = users.firstWhere(
      (u) => u.id == widget.memberId,
      orElse: () => users.first,
    );

    final movementHistory = ref.watch(movementHistoryProvider(widget.memberId));

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                stretch: true,
                backgroundColor: AppTheme.cardColor,
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
                actions: [
                  IconButton(
                    onPressed: () {},
                    icon: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingSM),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_horiz,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'avatar_${user.id}',
                        child: CachedNetworkImage(
                          imageUrl: user.avatarUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: AppTheme.surfaceColor),
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
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppTheme.backgroundColor,
                  ),
                  child: Column(
                    children: [
                      _buildUserInfo(user),
                      _buildMapSnippet(user, l10n),
                      _buildActionButtons(user, ref, l10n),
                      _buildMovementHistory(movementHistory, l10n),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(dynamic user) {
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
                        Text(user.name, style: AppTheme.heading1)
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideX(begin: -0.2, end: 0),
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
                        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                          user.status,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 300.ms)
                        .slideX(begin: -0.2, end: 0),
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
              ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
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
                  user.getTimeAgo(AppLocalizations.of(context)!),
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildMapSnippet(dynamic user, AppLocalizations l10n) {
    return Container(
          height: 180,
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
          decoration: BoxDecoration(
            borderRadius: AppTheme.borderRadiusXL,
            boxShadow: AppTheme.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: AppTheme.borderRadiusXL,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: user.location,
                    zoom: 15,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  markers: {
                    Marker(
                      markerId: MarkerId(user.id),
                      position: user.location,
                    ),
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                ),
                Positioned(
                  bottom: AppTheme.spacingSM,
                  right: AppTheme.spacingSM,
                  child: GlassButton(
                    onPressed: () {},
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMD,
                      vertical: AppTheme.spacingSM,
                    ),
                    borderRadius: AppTheme.radiusMD,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          FontAwesomeIcons.diamondTurnRight,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: AppTheme.spacingXS),
                        Text(
                          l10n.directions,
                          style: AppTheme.bodySmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 600.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildActionButtons(
    dynamic user,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final currentUser = ref.watch(currentUserProvider);
    final isMe = currentUser?.id == user.id;

    if (isMe) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _ActionButton(
              icon: FontAwesomeIcons.message,
              label: l10n.message,
              onTap: () => _showMessageSheet(context, user, ref, l10n),
            ).animate().fadeIn(duration: 400.ms, delay: 700.ms),
          ),
          SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: _ActionButton(
              icon: FontAwesomeIcons.handPointer,
              label: l10n.nudge,
              onTap: () async {
                final response = await ApiClient.nudgeUser(user.id);
                if (response['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.userNudged(user.name))),
                  );
                }
              },
              isPrimary: true,
            ).animate().fadeIn(duration: 400.ms, delay: 900.ms),
          ),
        ],
      ),
    );
  }

  void _showMessageSheet(
    BuildContext context,
    dynamic user,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final messageController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _MessageSheet(
          user: user,
          messageController: messageController,
          onCancel: () => Navigator.pop(context),
          onSendMessage: () async {
            final message = messageController.text.trim();
            if (message.isEmpty) return;

            final response = await ApiClient.sendMessageToUser(
              user.id,
              message,
            );
            if (response['success'] == true) {
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.messageSent)));
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildMovementHistory(List movements, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.todaysMovement,
            style: AppTheme.heading3,
          ).animate().fadeIn(duration: 400.ms, delay: 1000.ms),
          const SizedBox(height: AppTheme.spacingMD),
          ...movements.asMap().entries.map((entry) {
            final index = entry.key;
            final movement = entry.value;
            final isLast = index == movements.length - 1;

            return _MovementTimelineItem(
              movement: movement,
              isLast: isLast,
              index: index,
            );
          }),
        ],
      ),
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

class _MovementTimelineItem extends StatelessWidget {
  final dynamic movement;
  final bool isLast;
  final int index;

  const _MovementTimelineItem({
    required this.movement,
    required this.isLast,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == 0
                        ? AppTheme.primaryColor
                        : AppTheme.surfaceLight,
                    border: Border.all(
                      color: index == 0
                          ? AppTheme.primaryColor
                          : AppTheme.glassBorder,
                      width: 2,
                    ),
                  ),
                  child: index == 0
                      ? const Icon(Icons.circle, size: 6, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Container(width: 2, height: 60, color: AppTheme.glassBorder),
              ],
            ),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: AppTheme.borderRadiusLG,
                  border: Border.all(color: AppTheme.glassBorder, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          movement.placeName,
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          movement.getTimeRange(AppLocalizations.of(context)!),
                          style: AppTheme.caption,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(movement.address, style: AppTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: Duration(milliseconds: 1000 + (index * 100)),
        )
        .slideX(begin: 0.1, end: 0);
  }
}

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
