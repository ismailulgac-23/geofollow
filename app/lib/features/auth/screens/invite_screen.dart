import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_app/core/theme/app_theme.dart';
import 'package:tracker_app/l10n/app_localizations.dart';
import 'package:tracker_app/shared/widgets/glass_container.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final TextEditingController _inviteCodeController = TextEditingController();
  bool _isValid = false;
  bool _isJoining = false;

  void _validateCode(String value) {
    setState(() {
      _isValid = value.length >= 6;
    });
  }

  void _joinCircle() async {
    if (!_isValid) return;

    setState(() {
      _isJoining = true;
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLG),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => context.go('/auth'),
                  icon: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingSM),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.glassBorder, width: 1),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, size: 20),
                  ),
                ).animate().fadeIn(duration: 300.ms),
                const Spacer(),
                Text(l10n.joinACircle, style: AppTheme.heading1)
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 200.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: AppTheme.spacingSM),
                Text(
                      l10n.enterInviteCodeDescription,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 400.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: AppTheme.spacingXL),
                Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: AppTheme.borderRadiusLG,
                        border: Border.all(
                          color: _isValid
                              ? AppTheme.accentGreen
                              : AppTheme.glassBorder,
                          width: _isValid ? 2 : 1,
                        ),
                      ),
                      child: TextField(
                        controller: _inviteCodeController,
                        onChanged: _validateCode,
                        textAlign: TextAlign.center,
                        style: AppTheme.heading2.copyWith(
                          letterSpacing: 8,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLength: 8,
                        decoration: InputDecoration(
                          hintText: l10n.enterCode,
                          hintStyle: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textMuted,
                            letterSpacing: 4,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: AppTheme.borderRadiusLG,
                          ),
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spacingLG,
                          ),
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 600.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: AppTheme.spacingMD),
                if (_isValid)
                  Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: AppTheme.accentGreen,
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.spacingSM),
                          Text(
                            l10n.validCode,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.accentGreen,
                            ),
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideX(begin: -0.2, end: 0),
                const Spacer(),
                GlassButton(
                      onPressed: _isValid ? _joinCircle : null,
                      width: double.infinity,
                      gradient: _isValid ? AppTheme.primaryGradient : null,
                      color: _isValid ? null : AppTheme.surfaceLight,
                      child: _isJoining
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              l10n.joinCircleBtn,
                              style: AppTheme.button.copyWith(
                                color: _isValid
                                    ? Colors.white
                                    : AppTheme.textMuted,
                              ),
                            ),
                    )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 800.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: AppTheme.spacingLG),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
