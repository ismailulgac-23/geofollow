import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tracker_app/core/theme/app_theme.dart';

class AvatarWidget extends StatelessWidget {
  final String imageUrl;
  final double size;
  final Color? ringColor;
  final bool isOnline;
  final bool showRing;
  final double ringWidth;
  final VoidCallback? onTap;

  const AvatarWidget({
    super.key,
    required this.imageUrl,
    this.size = 48,
    this.ringColor,
    this.isOnline = true,
    this.showRing = true,
    this.ringWidth = 3,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size + (ringWidth * 2),
        height: size + (ringWidth * 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: showRing
              ? LinearGradient(
                  colors: ringColor != null
                      ? [ringColor!, ringColor!.withOpacity(0.5)]
                      : isOnline
                      ? [AppTheme.accentGreen, AppTheme.accentColor]
                      : [
                          AppTheme.textMuted,
                          AppTheme.textMuted.withOpacity(0.5),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.backgroundColor,
                width: ringWidth,
              ),
              image: DecorationImage(
                image: CachedNetworkImageProvider(imageUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AvatarWithStatus extends StatelessWidget {
  final String imageUrl;
  final double size;
  final bool isOnline;
  final String? statusEmoji;
  final int? batteryLevel;
  final VoidCallback? onTap;

  const AvatarWithStatus({
    super.key,
    required this.imageUrl,
    this.size = 48,
    this.isOnline = true,
    this.statusEmoji,
    this.batteryLevel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AvatarWidget(
          imageUrl: imageUrl,
          size: size,
          isOnline: isOnline,
          onTap: onTap,
        ),

        if (batteryLevel != null && batteryLevel! <= 20)
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: batteryLevel! <= 10
                    ? AppTheme.accentRed
                    : AppTheme.accentOrange,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.backgroundColor, width: 1),
              ),
              child: Text(
                '$batteryLevel%',
                style: AppTheme.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 8,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AnimatedAvatar extends StatelessWidget {
  final String imageUrl;
  final double size;
  final bool isOnline;
  final String? statusEmoji;
  final int? batteryLevel;
  final VoidCallback? onTap;

  const AnimatedAvatar({
    super.key,
    required this.imageUrl,
    this.size = 48,
    this.isOnline = true,
    this.statusEmoji,
    this.batteryLevel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AvatarWithStatus(
          imageUrl: imageUrl,
          size: size,
          isOnline: isOnline,
          statusEmoji: statusEmoji,
          batteryLevel: batteryLevel,
          onTap: onTap,
        )
        .animate()
        .scale(
          begin: const Offset(0.8, 0.8),
          duration: 400.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 300.ms);
  }
}

class AvatarRow extends StatelessWidget {
  final List<String> imageUrls;
  final double avatarSize;
  final double overlap;
  final int maxVisible;
  final VoidCallback? onTap;

  const AvatarRow({
    super.key,
    required this.imageUrls,
    this.avatarSize = 36,
    this.overlap = 0.3,
    this.maxVisible = 5,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visibleUrls = imageUrls.take(maxVisible).toList();
    final remaining = imageUrls.length - maxVisible;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...visibleUrls.asMap().entries.map((entry) {
            return Padding(
              padding: EdgeInsets.only(
                left: entry.key == 0 ? 0 : -avatarSize * overlap,
              ),
              child: AvatarWidget(
                imageUrl: entry.value,
                size: avatarSize,
                showRing: false,
              ),
            );
          }),
          if (remaining > 0)
            Padding(
              padding: EdgeInsets.only(left: -avatarSize * overlap),
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.backgroundColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$remaining',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.2, end: 0),
    );
  }
}
