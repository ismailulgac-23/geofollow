import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_app/core/providers/auth_provider.dart';
import 'package:tracker_app/core/services/api_client.dart';
import 'package:tracker_app/core/theme/app_theme.dart';
import 'package:tracker_app/core/providers/locale_provider.dart';
import 'package:tracker_app/l10n/app_localizations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _shimmerController;

  List<OnboardingPageData> _getPages(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      OnboardingPageData(
        emoji: '📍',
        title: l10n.stayConnected,
        subtitle: l10n.withLovedOnes,
        description: l10n.trackDescription,
        imageUrl:
            'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&q=80',
        accentColor: const Color(0xFF6C5CE7),
        gradientColors: const [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
        features: [
          l10n.onboardingRealTimeGps,
          l10n.onboardingBatteryStatus,
          l10n.onboardingLiveMap,
        ],
      ),
      OnboardingPageData(
        emoji: '🛡️',
        title: l10n.setSafeZones,
        subtitle: l10n.getInstantAlerts,
        description: l10n.safeZonesDescription,
        imageUrl:
            'https://images.unsplash.com/photo-1494500764479-8c8493fd84d4?w=800&q=80',
        accentColor: const Color(0xFF00CEC9),
        gradientColors: const [Color(0xFF00CEC9), Color(0xFF55EFC4)],
        features: [
          l10n.onboardingCustomGeofences,
          l10n.onboardingInstantAlerts,
          l10n.onboardingSmartHistory,
        ],
      ),
      OnboardingPageData(
        emoji: '⭐',
        title: l10n.premiumFeatures,
        subtitle: l10n.ultimatePeace,
        description: l10n.premiumDescription,
        imageUrl:
            'https://images.unsplash.com/photo-1529156069898-4e53e9c47a62?w=800&q=80',
        accentColor: const Color(0xFFFF6B9D),
        gradientColors: const [Color(0xFFFF6B9D), Color(0xFFFF9F43)],
        features: [
          l10n.unlimitedPlaces,
          l10n.onboarding30DayHistory,
          l10n.onboardingSosEmergency,
        ],
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await ApiClient.setOnboardingComplete();
    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState.status == AuthStatus.authenticated) {
      context.go('/setup-wizard');
    } else {
      context.go('/auth');
    }
  }

  void _nextPage() {
    final pages = _getPages(context);
    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pages = _getPages(context);
    final currentLocale = ref.watch(localeProvider);
    final currentData = pages[_currentPage];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background image with blur ──────────────────────────────────
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: pages.length,
            itemBuilder: (context, index) => _OnboardingPageBackground(
              data: pages[index],
              isActive: index == _currentPage,
            ),
          ),

          // ── Dark overlay ────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // ── Content overlay ─────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar
                  _buildTopBar(l10n, currentLocale),

                  const Spacer(),

                  // Emoji badge
                  _EmojiFeatureBadge(
                    emoji: currentData.emoji,
                    color: currentData.accentColor,
                  ),
                  const SizedBox(height: 16),

                  // Text content
                  _buildTextContent(pages, currentData),
                  const SizedBox(height: 20),

                  // Feature pills
                  _FeaturePills(
                    features: currentData.features,
                    color: currentData.accentColor,
                  ),
                  const SizedBox(height: 32),

                  // Page indicator
                  _buildPageIndicator(pages.length),
                  const SizedBox(height: 20),

                  // CTA button
                  _buildCtaButton(l10n, pages, currentData),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n, Locale currentLocale) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Alveron',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFA29BFE),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2, end: 0),

          // Right side controls
          Row(
                children: [
                  _LanguageToggle(currentLocale: currentLocale),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _completeOnboarding,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l10n.skip,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              )
              .animate()
              .fadeIn(duration: 600.ms, delay: 200.ms)
              .slideX(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildTextContent(
    List<OnboardingPageData> pages,
    OnboardingPageData data,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
              data.title,
              style: AppTheme.heading2.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 18,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
            )
            .animate(key: ValueKey('title_$_currentPage'))
            .fadeIn(duration: 500.ms, delay: 100.ms)
            .slideX(begin: 0.15, end: 0),
        const SizedBox(height: 4),
        ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: pages[_currentPage].gradientColors,
              ).createShader(bounds),
              child: Text(
                data.subtitle,
                style: AppTheme.heading1.copyWith(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
            )
            .animate(key: ValueKey('sub_$_currentPage'))
            .fadeIn(duration: 500.ms, delay: 250.ms)
            .slideX(begin: 0.15, end: 0),
        const SizedBox(height: 14),
        Text(
              data.description,
              style: AppTheme.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.6,
              ),
            )
            .animate(key: ValueKey('desc_$_currentPage'))
            .fadeIn(duration: 500.ms, delay: 400.ms)
            .slideX(begin: 0.15, end: 0),
      ],
    );
  }

  Widget _buildPageIndicator(int count) {
    return Row(
      children: List.generate(count, (i) {
        final isActive = i == _currentPage;
        return AnimatedContainer(
          duration: 350.ms,
          margin: const EdgeInsets.only(right: 6),
          width: isActive ? 28 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? _getPages(context)[_currentPage].accentColor
                : Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildCtaButton(
    AppLocalizations l10n,
    List<OnboardingPageData> pages,
    OnboardingPageData data,
  ) {
    final isLast = _currentPage == pages.length - 1;
    return GestureDetector(
          onTap: _nextPage,
          child: AnimatedContainer(
            duration: 300.ms,
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: data.gradientColors),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: data.accentColor.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isLast ? l10n.getStarted : l10n.continueBtn,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  isLast
                      ? Icons.rocket_launch_rounded
                      : Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 600.ms)
        .slideY(begin: 0.3, end: 0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Model
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingPageData {
  final String emoji;
  final String title;
  final String subtitle;
  final String description;
  final String imageUrl;
  final Color accentColor;
  final List<Color> gradientColors;
  final List<String> features;

  const OnboardingPageData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.imageUrl,
    required this.accentColor,
    required this.gradientColors,
    required this.features,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingPageBackground extends StatelessWidget {
  final OnboardingPageData data;
  final bool isActive;

  const _OnboardingPageBackground({required this.data, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: data.imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: AppTheme.backgroundColor),
          errorWidget: (_, __, ___) => Container(color: AppTheme.surfaceColor),
        ),
      ],
    );
  }
}

class _EmojiFeatureBadge extends StatelessWidget {
  final String emoji;
  final Color color;

  const _EmojiFeatureBadge({required this.emoji, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                'Alveron',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        )
        .animate(key: ValueKey('badge_${emoji}'))
        .fadeIn(duration: 400.ms)
        .slideX(begin: -0.1, end: 0);
  }
}

class _FeaturePills extends StatelessWidget {
  final List<String> features;
  final Color color;

  const _FeaturePills({required this.features, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: features.asMap().entries.map((e) {
        return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    e.value,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(
              duration: 400.ms,
              delay: Duration(milliseconds: 500 + e.key * 80),
            )
            .slideY(begin: 0.2, end: 0);
      }).toList(),
    );
  }
}

class _LanguageToggle extends ConsumerWidget {
  final Locale currentLocale;
  const _LanguageToggle({required this.currentLocale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              currentLocale.languageCode.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
