import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_app/core/providers/auth_provider.dart';
import 'package:tracker_app/core/services/api_client.dart';
import 'package:tracker_app/core/theme/app_theme.dart';
import 'package:tracker_app/l10n/app_localizations.dart';
import 'package:tracker_app/core/services/att_service.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initApp();
  }

  Future<void> _initApp() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      await AttService.checkAndRequest(context);
    }

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    await ref.read(authProvider.notifier).checkAuthStatus();
    if (!mounted) return;

    final onboardingComplete = await ApiClient.isOnboardingComplete();
    if (!mounted) return;

    if (!onboardingComplete) {
      context.go('/onboarding');
      return;
    }

    final authState = ref.read(authProvider);
    if (authState.status == AuthStatus.authenticated) {
      context.go('/home');
    } else {
      context.go('/auth');
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Animated dark bg ──────────────────────────────────────────────
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) =>
                CustomPaint(painter: _SplashBgPainter(_bgController.value)),
          ),

          // ── Glowing orbs ─────────────────────────────────────────────────
          ..._buildOrbs(),

          // ── Center content ───────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, child) => Transform.scale(
                        scale: 1.0 + (_pulseController.value * 0.04),
                        child: child,
                      ),
                      child: _GoFollowLogo(size: 110),
                    )
                    .animate()
                    .scale(
                      begin: const Offset(0.4, 0.4),
                      duration: 900.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 500.ms),

                const SizedBox(height: 32),

                _GoFollowWordmark(fontSize: 44)
                    .animate()
                    .fadeIn(duration: 700.ms, delay: 400.ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),

                const SizedBox(height: 10),

                // Tagline
                Text(
                      AppLocalizations.of(context)!.splashTagline,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textMuted,
                        letterSpacing: 0.3,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 700.ms, delay: 700.ms)
                    .slideY(begin: 0.3, end: 0),

                const SizedBox(height: 80),

                // Loading indicator
                SizedBox(
                  width: 48,
                  child: LinearProgressIndicator(
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: AppTheme.surfaceLight,
                    valueColor: const AlwaysStoppedAnimation(
                      AppTheme.primaryColor,
                    ),
                    minHeight: 2,
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 1000.ms),
              ],
            ),
          ),

          // ── Version badge ─────────────────────────────────────────────────
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'v2.0',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textMuted.withValues(alpha: 0.5),
                  letterSpacing: 2,
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 1200.ms),
            ),
          ),
        ],
      ),
    );
  }

  // ── Version badge ─────────────────────────────────────────────────

  List<Widget> _buildOrbs() {
    return [
      Positioned(
        top: -80,
        left: -60,
        child: _GlowOrb(
          size: 280,
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          controller: _bgController,
          offset: 0.0,
        ),
      ),
      Positioned(
        bottom: -100,
        right: -80,
        child: _GlowOrb(
          size: 320,
          color: AppTheme.accentColor.withValues(alpha: 0.10),
          controller: _bgController,
          offset: 0.5,
        ),
      ),
      Positioned(
        top: 200,
        right: -100,
        child: _GlowOrb(
          size: 200,
          color: AppTheme.accentPink.withValues(alpha: 0.08),
          controller: _bgController,
          offset: 0.3,
        ),
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

/// The circular logo mark with animated ring
class _GoFollowLogo extends StatelessWidget {
  final double size;
  const _GoFollowLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        Container(
          width: size + 24,
          height: size + 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.0),
                AppTheme.primaryColor.withValues(alpha: 0.4),
                AppTheme.accentColor.withValues(alpha: 0.3),
                AppTheme.primaryColor.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
        // Main circle
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7C6CF0), Color(0xFF6C5CE7), Color(0xFF5649C0)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.5),
                blurRadius: 40,
                spreadRadius: 5,
              ),
              BoxShadow(
                color: AppTheme.accentColor.withValues(alpha: 0.2),
                blurRadius: 60,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: CustomPaint(
              size: Size(size * 0.5, size * 0.5),
              painter: _GoFollowIconPainter(),
            ),
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
            text: 'Geo',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              foreground: Paint()
                ..shader = const LinearGradient(
                  colors: [Color(0xFF8B7CF6), Color(0xFF6C5CE7)],
                ).createShader(Rect.fromLTWH(0, 0, fontSize * 1.5, fontSize)),
            ),
          ),
          TextSpan(
            text: 'Follow',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w300,
              letterSpacing: -1.0,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Painters
// ─────────────────────────────────────────────────────────────────────────────

/// Animated background mesh
class _SplashBgPainter extends CustomPainter {
  final double progress;
  _SplashBgPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0A0A1A), Color(0xFF0D0D1E), Color(0xFF050510)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF6C5CE7).withValues(alpha: 0.03)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_SplashBgPainter old) => old.progress != progress;
}

class _GoFollowIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Pin body
    final pinPath = Path();
    final cx = size.width / 2;
    final cy = size.height * 0.42;
    final pinR = size.width * 0.32;

    pinPath.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: pinR));
    pinPath.moveTo(cx, cy + pinR);
    pinPath.lineTo(cx - pinR * 0.5, cy + pinR * 1.8);
    pinPath.lineTo(cx + pinR * 0.5, cy + pinR * 1.8);
    pinPath.close();
    canvas.drawPath(pinPath, paint);

    // Inner dot
    final dotPaint = Paint()
      ..color = const Color(0xFF6C5CE7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), pinR * 0.4, dotPaint);

    // Arrow chevron (right)
    final arrowPath = Path()
      ..moveTo(cx + size.width * 0.08, size.height * 0.15)
      ..lineTo(cx + size.width * 0.22, size.height * 0.26)
      ..lineTo(cx + size.width * 0.08, size.height * 0.37);
    canvas.drawPath(arrowPath, strokePaint);
  }

  @override
  bool shouldRepaint(_GoFollowIconPainter old) => false;
}

/// Animated glow orb
class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  final AnimationController controller;
  final double offset;

  const _GlowOrb({
    required this.size,
    required this.color,
    required this.controller,
    required this.offset,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = (controller.value + offset) % 1.0;
        final dy = sin(t * 2 * pi) * 20;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}
