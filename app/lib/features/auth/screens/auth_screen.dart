import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tracker_app/core/providers/auth_provider.dart';
import 'package:tracker_app/core/theme/app_theme.dart';
import 'package:tracker_app/l10n/app_localizations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _floatController;
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final success = await ref.read(authProvider.notifier).signInWithGoogle();
      if (success && mounted) {
        final authState = ref.read(authProvider);
        if (authState.user != null) context.go('/home');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleReviewerLogin() async {
    setState(() => _isLoading = true);
    try {
      final success = await ref
          .read(authProvider.notifier)
          .loginWithReviewCredentials(
            'apple_review_1@geofollow.xyz',
            'ReviewTest2026!',
          );
      if (success && mounted) {
        // Test modunda ise hemen ana sayfaya gitmeyecek, simülasyon animasyonu görecek
        final authState = ref.read(authProvider);
        if (authState.user != null) {
          if (authState.isTestMode) {
            await Future.delayed(const Duration(seconds: 5));
          }
          // Onboarding'den başlasın ki tüm adımları görsün
          context.go('/onboarding');
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final success = await ref.read(authProvider.notifier).signInWithApple();
      if (success && mounted) {
        final authState = ref.read(authProvider);
        if (authState.user != null) context.go('/home');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.needsRegistration) {
        context.go('/setup-wizard');
      } else if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Dark background with grid ────────────────────────────────────
          CustomPaint(painter: _AuthBgPainter()),

          // ── Rotating gradient ring (behind everything) ───────────────────
          Positioned(
            top: -size.width * 0.3,
            left: -size.width * 0.3,
            child: AnimatedBuilder(
              animation: _rotateController,
              builder: (_, __) => Transform.rotate(
                angle: _rotateController.value * 2 * pi,
                child: Container(
                  width: size.width * 1.6,
                  height: size.width * 1.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.0),
                        AppTheme.primaryColor.withValues(alpha: 0.08),
                        AppTheme.accentColor.withValues(alpha: 0.06),
                        AppTheme.accentPink.withValues(alpha: 0.04),
                        AppTheme.primaryColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Floating particles ───────────────────────────────────────────
          ..._buildParticles(size),

          // ── Main content ─────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  _buildBrandSection(l10n),
                  const Spacer(flex: 3),
                  _buildLoginSection(l10n),
                  const SizedBox(height: 24),
                  _buildTermsText(l10n),
                  const Spacer(),
                ],
              ),
            ),
          ),
          _buildSimulationOverlay(),
        ],
      ),
    );
  }

  // ── Brand section ──────────────────────────────────────────────────────────

  Widget _buildBrandSection(AppLocalizations l10n) {
    return Column(
      children: [
        // Logo
        AnimatedBuilder(
              animation: _floatController,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _floatController.value * -6),
                child: GestureDetector(
                  onLongPress: () => _handleReviewerLogin(),
                  child: _AuthLogo(),
                ),
              ),
            )
            .animate()
            .scale(
              begin: const Offset(0.5, 0.5),
              duration: 900.ms,
              curve: Curves.elasticOut,
            )
            .fadeIn(duration: 500.ms),

        const SizedBox(height: 28),

        _GoFollowWordmark(fontSize: 42)
            .animate()
            .fadeIn(duration: 600.ms, delay: 350.ms)
            .slideY(begin: 0.4, end: 0, curve: Curves.easeOutCubic),

        const SizedBox(height: 10),

        // Tagline
        _TaglineChips()
            .animate()
            .fadeIn(duration: 600.ms, delay: 600.ms)
            .slideY(begin: 0.3, end: 0),
      ],
    );
  }

  // ── Login section ──────────────────────────────────────────────────────────

  Widget _buildLoginSection(AppLocalizations l10n) {
    return Column(
      children: [
        // Divider with text
        Row(
          children: [
            Expanded(child: _GlassLine()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.welcome,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Expanded(child: _GlassLine()),
          ],
        ).animate().fadeIn(duration: 500.ms, delay: 800.ms),

        const SizedBox(height: 28),

        // Google button
        _PremiumSocialButton(
              icon: FontAwesomeIcons.google,
              label: l10n.continueWithGoogle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFF5F5F5)],
              ),
              textColor: const Color(0xFF1A1A1A),
              iconColor: const Color(0xFFEA4335),
              onPressed: _isLoading ? null : _handleGoogleSignIn,
              isLoading: _isLoading,
            )
            .animate()
            .fadeIn(duration: 500.ms, delay: 950.ms)
            .slideX(begin: 0.15, end: 0, curve: Curves.easeOutCubic),

        const SizedBox(height: 14),

        // Apple button
        _PremiumSocialButton(
              icon: FontAwesomeIcons.apple,
              label: l10n.continueWithApple,
              gradient: const LinearGradient(
                colors: [Color(0xFF1C1C1E), Color(0xFF000000)],
              ),
              textColor: Colors.white,
              iconColor: Colors.white,
              onPressed: _isLoading ? null : _handleAppleSignIn,
              isLoading: _isLoading,
              hasBorder: true,
            )
            .animate()
            .fadeIn(duration: 500.ms, delay: 1050.ms)
            .slideX(begin: -0.15, end: 0, curve: Curves.easeOutCubic),
      ],
    );
  }

  Widget _buildTermsText(AppLocalizations l10n) {
    return Text.rich(
      TextSpan(
        style: AppTheme.caption.copyWith(
          color: AppTheme.textMuted,
          height: 1.6,
        ),
        children: [
          TextSpan(text: l10n.byContinuing),
          TextSpan(
            text: l10n.termsOfService,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => launchUrl(
                Uri.parse('https://gofollow.xyz/terms'),
                mode: LaunchMode.externalApplication,
              ),
          ),
          TextSpan(text: l10n.and),
          TextSpan(
            text: l10n.privacyPolicy,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => launchUrl(
                Uri.parse('https://gofollow.xyz/privacy'),
                mode: LaunchMode.externalApplication,
              ),
          ),
          TextSpan(text: l10n.agreementSuffix),
        ],
      ),
      textAlign: TextAlign.center,
    ).animate().fadeIn(duration: 500.ms, delay: 1200.ms);
  }

  Widget _buildSimulationOverlay() {
    final authState = ref.watch(authProvider);
    if (!authState.isTestMode || authState.status != AuthStatus.authenticated) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.95),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.memory_rounded,
            size: 64,
            color: AppTheme.primaryColor,
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms),
          const SizedBox(height: 32),
          Text(
            "SIMULATION MODE ACTIVE",
            style: AppTheme.heading3.copyWith(
              color: Colors.white,
              letterSpacing: 2.0,
            ),
          ).animate().fadeIn().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 12),
          Text(
            "Syncing mock environment for review...",
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 48),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
          ).animate().fadeIn(delay: 800.ms),
        ],
      ),
    );
  }

  List<Widget> _buildParticles(Size size) {
    final positions = [
      const Offset(0.1, 0.15),
      const Offset(0.85, 0.1),
      const Offset(0.7, 0.55),
      const Offset(0.15, 0.65),
      const Offset(0.5, 0.85),
    ];

    return positions.asMap().entries.map((e) {
      return Positioned(
        left: e.value.dx * size.width,
        top: e.value.dy * size.height,
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (_, __) => Transform.translate(
            offset: Offset(
              sin((_floatController.value + e.key * 0.2) * pi) * 8,
              cos((_floatController.value + e.key * 0.3) * pi) * 6,
            ),
            child: Container(
              width: 4 + (e.key % 3) * 2.0,
              height: 4 + (e.key % 3) * 2.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: [
                  AppTheme.primaryColor,
                  AppTheme.accentColor,
                  AppTheme.accentPink,
                  AppTheme.primaryLight,
                  AppTheme.accentGreen,
                ][e.key % 5].withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Brand Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AuthLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer ring
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
        ),
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        // Main logo circle
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8B7CF6), Color(0xFF6C5CE7), Color(0xFF5040C0)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.45),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.location_on_rounded,
            size: 38,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _GoFollowWordmark extends StatelessWidget {
  final double fontSize;
  const _GoFollowWordmark({required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Alveron',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
              foreground: Paint()
                ..shader = const LinearGradient(
                  colors: [Color(0xFFA29BFE), Color(0xFF6C5CE7)],
                ).createShader(Rect.fromLTWH(0, 0, fontSize * 2, fontSize)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaglineChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const chips = ['📍 Real-time', '🔒 Secure', '⚡ Instant'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: chips.asMap().entries.map((e) {
        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.glassBorder.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            e.value,
            style: AppTheme.caption.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GlassLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppTheme.glassBorder.withValues(alpha: 0.5),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _PremiumSocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final Color textColor;
  final Color iconColor;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool hasBorder;

  const _PremiumSocialButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.textColor,
    required this.iconColor,
    this.onPressed,
    this.isLoading = false,
    this.hasBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: AnimatedOpacity(
        opacity: onPressed == null ? 0.5 : 1.0,
        duration: 200.ms,
        child: Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            border: hasBorder
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: textColor,
                  ),
                )
              else
                Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background painter
// ─────────────────────────────────────────────────────────────────────────────

class _AuthBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF07071A), Color(0xFF0D0D1E), Color(0xFF050516)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridPaint = Paint()
      ..color = const Color(0xFF6C5CE7).withValues(alpha: 0.025)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_AuthBgPainter old) => false;
}
