import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tracker_app/core/providers/auth_provider.dart';
import 'package:tracker_app/core/services/revenue_cat_service.dart';
import 'package:tracker_app/core/theme/app_theme.dart';
import 'package:tracker_app/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PremiumBottomSheet
//
// Tek bir bottom sheet — hem upsell hem de abonelik yönetimi.
// Premium değilse: Plan seçici + satın alma akışı
// Premium ise    : Abonelik bilgileri + RevenueCat'tan çekilen detaylar
// ─────────────────────────────────────────────────────────────────────────────

class PremiumBottomSheet extends ConsumerStatefulWidget {
  const PremiumBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PremiumBottomSheet(),
    );
  }

  @override
  ConsumerState<PremiumBottomSheet> createState() => _PremiumBottomSheetState();
}

class _PremiumBottomSheetState extends ConsumerState<PremiumBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _haloCtrl;

  int _selectedPlan = 1; // 0=1 week, 1=1 month (default)
  bool _loading = true;
  bool _purchasing = false;
  bool _restoring = false;

  Offerings? _offerings;
  SubscriptionInfo? _subInfo;

  // Colors — primary-based (purple/violet)
  static const _c1 = Color(0xFF6C5CE7); // primaryColor
  static const _c2 = Color(0xFFA29BFE); // primaryLight
  static const _c3 = Color(0xFF8B7CF6);

  static const _features = [
    {
      'icon': Icons.sos,
      'en': 'SOS Emergency Button',
      'tr': 'SOS Acil Durum Butonu',
    },
    {
      'icon': Icons.notifications_active,
      'en': 'Unlimited Notifications',
      'tr': 'Sınırsız Bildirimler',
    },
    {
      'icon': Icons.my_location,
      'en': 'Precise Location Tracking',
      'tr': 'Hassas Konum Takibi',
    },
    {
      'icon': Icons.history,
      'en': '30-Day Location History',
      'tr': '30 Günlük Geçmiş',
    },
    {
      'icon': Icons.group,
      'en': 'Unlimited Group Members',
      'tr': 'Sınırsız Grup Üyesi',
    },
    {
      'icon': Icons.place_outlined,
      'en': 'Unlimited Safe Zones',
      'tr': 'Sınırsız Güvenli Bölge',
    },
  ];

  @override
  void initState() {
    super.initState();
    _haloCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _fetchData();
  }

  @override
  void dispose() {
    _haloCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final user = ref.read(authProvider).user;
      final isPremium = user?.isPremium ?? false;

      // Paralel ama timeout ile — RevenueCat yavaş olursa 8 sn'de pes et
      final results = await Future.wait([
        RevenueCatService.getOfferings().timeout(
          const Duration(seconds: 8),
          onTimeout: () => null,
        ),
        if (isPremium)
          RevenueCatService.getSubscriptionInfo().timeout(
            const Duration(seconds: 8),
            onTimeout: () => null,
          )
        else
          Future<SubscriptionInfo?>.value(null),
      ]);

      if (!mounted) return;
      setState(() {
        _offerings = results[0] as Offerings?;
        _subInfo = results.length > 1 ? results[1] as SubscriptionInfo? : null;
      });
    } catch (e) {
      debugPrint('[PremiumSheet] _fetchData error: $e');
      // Hata olsa bile fallback fiyatlarla sheet gösterilir
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Package? _selectedPackage() {
    final offering = _offerings?.current;
    if (offering == null) return null;
    if (_selectedPlan == 0) return RevenueCatService.weeklyPackage(offering);
    return RevenueCatService.monthlyPackage(offering);
  }

  Future<void> _purchase() async {
    final isEn = AppLocalizations.of(context)!.localeName == 'en';
    final pkg = _selectedPackage();
    if (pkg == null) {
      _showErrorSnackbar(
        isEn
            ? 'Purchase options are currently being updated by Apple. Please try again in a few moments or use the "Restore" button if you already purchased.'
            : 'Satın alma seçenekleri Apple tarafından güncelleniyor. Lütfen biraz sonra tekrar deneyin veya daha önce satın aldıysanız "Geri Yükle" butonunu kullanın.',
      );
      return;
    }

    setState(() => _purchasing = true);
    HapticFeedback.heavyImpact();

    try {
      final result = await RevenueCatService.purchasePackage(pkg);
      if (!mounted) return;

      setState(() => _purchasing = false);

      if (result.success) {
        // Kullanıcı durumunu hem yerel hem backend tarafında güncelle
        await ref.read(authProvider.notifier).checkAuthStatus();
        if (!mounted) return;

        Navigator.of(context).pop();
        _showSuccessSnackbar();

        // Uygulamayı en baştan başlat (/auth/me tetiklemesi için)
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) context.go('/splash');
        });
      } else if (result.cancelled) {
        // İptal edildiğinde hata gösterme (sessiz)
        debugPrint('[PremiumSheet] Purchase cancelled by user');
      } else {
        _showErrorSnackbar(result.error ?? 'Purchase failed');
      }
    } catch (e) {
      setState(() => _purchasing = false);
      _showErrorSnackbar(e.toString());
    }
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    HapticFeedback.lightImpact();

    final result = await RevenueCatService.restorePurchases();
    if (!mounted) return;
    setState(() => _restoring = false);

    if (result.success) {
      await ref.read(authProvider.notifier).checkAuthStatus();
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSuccessSnackbar(restored: true);

      // Uygulamayı en baştan başlat (/auth/me tetiklemesi için)
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) context.go('/splash');
      });
    } else {
      _showErrorSnackbar('No active subscription found to restore.');
    }
  }

  void _showSuccessSnackbar({bool restored = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.workspace_premium, color: _c2),
            const SizedBox(width: 10),
            Text(
              restored ? 'Subscription restored! 🎉' : 'Welcome to Premium! 🎉',
            ),
          ],
        ),
        backgroundColor: AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isPremium = user?.isPremium ?? false;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle + Close row ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(
              children: [
                // Handle centered
                Expanded(
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                // Close button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable body ─────────────────────────────────────────────
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.87,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: _loading
                  ? _buildLoading()
                  : isPremium
                  ? _buildManageView(isEn)
                  : _buildUpsellView(isEn),
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading ─────────────────────────────────────────────────────────────────
  Widget _buildLoading() {
    return const SizedBox(
      height: 200,
      child: Center(child: CircularProgressIndicator(color: _c1)),
    );
  }

  // ── Subscription management (premium users) ─────────────────────────────────
  Widget _buildManageView(bool isEn) {
    return Column(
      children: [
        // Crown hero
        _buildHero(isPremium: true),

        const SizedBox(height: 16),

        // Title
        Text(
          isEn ? 'You are Premium ✨' : 'Premium Üyesiniz ✨',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _c2,
            letterSpacing: -0.5,
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 150.ms),

        const SizedBox(height: 6),
        Text(
          isEn
              ? 'All features are unlocked for you'
              : 'Tüm özellikler sizin için aktif',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

        const SizedBox(height: 24),

        // Subscription info card
        if (_subInfo != null)
          _buildSubInfoCard(isEn, _subInfo!)
        else
          _buildSubInfoFallback(isEn),

        const SizedBox(height: 20),

        // Feature list (greyed-out check, already active)
        _buildFeatureList(isEn, allActive: true),

        const SizedBox(height: 24),

        // Restore link
        _buildTextLink(
          label: isEn ? 'Restore purchases' : 'Satın alımları geri yükle',
          onTap: _restoring ? null : _restore,
          loading: _restoring,
        ),
      ],
    );
  }

  Widget _buildSubInfoCard(bool isEn, SubscriptionInfo info) {
    final items = [
      {
        'label': isEn ? 'Plan' : 'Plan',
        'value': isEn ? info.planLabel : info.planLabelTr,
        'icon': Icons.workspace_premium,
      },
      if (info.expirationFormatted != null)
        {
          'label': isEn
              ? (info.willRenew ? 'Renews on' : 'Expires on')
              : (info.willRenew ? 'Yenileme tarihi' : 'Bitiş tarihi'),
          'value': info.expirationFormatted!,
          'icon': Icons.event_rounded,
        },
      {
        'label': isEn ? 'Store' : 'Mağaza',
        'value': info.storeLabel,
        'icon': Icons.storefront_rounded,
      },
      {
        'label': isEn ? 'Auto-Renew' : 'Otomatik Yenileme',
        'value': info.willRenew
            ? (isEn ? 'Active' : 'Aktif')
            : (isEn ? 'Cancelled' : 'İptal Edildi'),
        'icon': info.willRenew ? Icons.autorenew_rounded : Icons.cancel_rounded,
      },
    ];

    return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _c1.withValues(alpha: 0.15),
                _c2.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _c1.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              final item = e.value;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                ),
                child: Row(
                  children: [
                    Icon(item['icon'] as IconData, size: 16, color: _c2),
                    const SizedBox(width: 10),
                    Text(
                      item['label'] as String,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item['value'] as String,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(
                duration: 400.ms,
                delay: Duration(milliseconds: 200 + e.key * 60),
              );
            }).toList(),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 250.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildSubInfoFallback(bool isEn) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _c1.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _c1.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium, color: _c2, size: 20),
          const SizedBox(width: 12),
          Text(
            isEn ? 'Active premium subscription' : 'Aktif premium abonelik',
            style: AppTheme.bodyMedium.copyWith(
              color: _c2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Upsell view (non-premium) ───────────────────────────────────────────────
  Widget _buildUpsellView(bool isEn) {
    final offering = _offerings?.current;

    // RevenueCat helper'larından gerçek paketleri al
    final weeklyPkg = RevenueCatService.weeklyPackage(offering);
    final monthlyPkg = RevenueCatService.monthlyPackage(offering);

    // Gerçek fiyatlar — offering yoksa fallback
    final weeklyPrice = weeklyPkg?.storeProduct.priceString ?? '\$2.99';
    final monthlyPrice = monthlyPkg?.storeProduct.priceString ?? '\$9.99';

    return Column(
      children: [
        // Hero
        _buildHero(isPremium: false),

        const SizedBox(height: 14),

        // Title
        ShaderMask(
              shaderCallback: (b) =>
                  const LinearGradient(colors: [_c2, _c1]).createShader(b),
              child: const Text(
                'GeoFollow Premium',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            )
            .animate()
            .fadeIn(duration: 400.ms, delay: 150.ms)
            .slideY(begin: 0.2, end: 0),

        const SizedBox(height: 6),

        Text(
          isEn
              ? 'Unlock the full power of family safety'
              : 'Aile güvenliğinin tüm gücünü keşfet',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

        const SizedBox(height: 24),

        // ── Plan selector ─────────────────────────────────────────────────
        Row(
          children: [
            _planTile(
              index: 0,
              label: isEn ? 'PRO (1 Week)' : 'PRO (1 Hafta)',
              price: weeklyPrice,
              period: isEn ? '/wk' : '/hafta',
              badge: null,
              isEn: isEn,
            ),
            const SizedBox(width: 10),
            _planTile(
              index: 1,
              label: isEn ? 'PRO (1 Month)' : 'PRO (1 Ay)',
              price: monthlyPrice,
              period: isEn ? '/mo' : '/ay',
              badge: isEn ? 'BEST VALUE' : 'EN İYİ',
              isEn: isEn,
            ),
          ],
        ).animate().fadeIn(duration: 500.ms, delay: 280.ms),

        const SizedBox(height: 22),

        // ── Feature list ─────────────────────────────────────────────────
        _buildFeatureList(isEn, allActive: false),

        const SizedBox(height: 24),

        // ── CTA button ───────────────────────────────────────────────────
        _buildPrimaryButton(
              label: _purchasing
                  ? ''
                  : (isEn ? 'Unlock Premium' : 'Premiuma Geç'),
              loading: _purchasing,
              onTap: _purchasing ? null : _purchase,
            )
            .animate()
            .fadeIn(duration: 500.ms, delay: 700.ms)
            .slideY(begin: 0.2, end: 0),

        const SizedBox(height: 12),

        // Restore link
        _buildTextLink(
          label: isEn ? 'Restore purchases' : 'Satın alımları geri yükle',
          onTap: _restoring ? null : _restore,
          loading: _restoring,
        ),

        const SizedBox(height: 16),

        // Legal Links (App Store Requirements)
        _buildLegalLinks(isEn),

        const SizedBox(height: 4),

        Text(
          isEn
              ? 'Cancel anytime · Full access will remain until expiration'
              : 'İstediğiniz zaman iptal edin · Süreniz bitene kadar haklarınız kalır',
          style: AppTheme.caption.copyWith(
            color: AppTheme.textMuted.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLegalLinks(bool isEn) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legalLink(
          isEn ? 'Terms of Use' : 'Kullanım Koşulları',
          'https://geofollow.xyz/terms-of-service.html',
        ),
        Text(
          '  •  ',
          style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.3)),
        ),
        _legalLink(
          isEn ? 'Privacy Policy' : 'Gizlilik Politikası',
          'https://geofollow.xyz/privacy-policy.html',
        ),
      ],
    );
  }

  Widget _legalLink(String label, String url) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      child: Text(
        label,
        style: AppTheme.caption.copyWith(
          color: AppTheme.textMuted,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  // ── Shared widgets ──────────────────────────────────────────────────────────

  Widget _buildHero({required bool isPremium}) {
    return SizedBox(
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _haloCtrl,
                builder: (_, __) => Transform.rotate(
                  angle: _haloCtrl.value * 2 * pi,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.transparent,
                          _c1.withValues(alpha: 0.7),
                          _c2.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_c3, _c1],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _c1.withValues(alpha: 0.45),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  isPremium ? Icons.verified_rounded : Icons.workspace_premium,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ],
          ),
        )
        .animate()
        .scale(
          begin: const Offset(0.7, 0.7),
          duration: 600.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 400.ms);
  }

  Widget _planTile({
    required int index,
    required String label,
    required String price,
    required String period,
    required String? badge,
    required bool isEn,
  }) {
    final selected = _selectedPlan == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPlan = index),
        child: AnimatedContainer(
          duration: 250.ms,
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? LinearGradient(
                    colors: [_c1, _c3],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : AppTheme.surfaceLight,
            border: Border.all(
              color: selected ? _c1 : AppTheme.glassBorder,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _c1.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: price,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: selected
                                ? Colors.white
                                : AppTheme.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: period,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected
                                ? Colors.white.withValues(alpha: 0.65)
                                : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: -22,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              if (selected)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureList(bool isEn, {required bool allActive}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        children: _features.asMap().entries.map((e) {
          final isLast = e.key == _features.length - 1;
          final feature = e.value;
          return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(bottom: BorderSide(color: AppTheme.glassBorder)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _c1.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        feature['icon'] as IconData,
                        size: 16,
                        color: _c2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEn ? feature['en'] as String : feature['tr'] as String,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.check_circle_rounded,
                      color: allActive ? _c2 : AppTheme.accentGreen,
                      size: 17,
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(
                duration: 400.ms,
                delay: Duration(milliseconds: 320 + e.key * 55),
              )
              .slideX(begin: 0.08, end: 0);
        }).toList(),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    IconData? icon,
    bool loading = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 250.ms,
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: onTap == null
                ? [Colors.grey.shade700, Colors.grey.shade600]
                : const [_c1, _c3],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: onTap == null
              ? null
              : [
                  BoxShadow(
                    color: _c1.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(icon, size: 16, color: Colors.white),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTextLink({
    required String label,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return TextButton(
      onPressed: onTap,
      child: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: _c2, strokeWidth: 2),
            )
          : Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textMuted,
                decoration: TextDecoration.underline,
                decorationColor: AppTheme.textMuted,
              ),
            ),
    );
  }
}
