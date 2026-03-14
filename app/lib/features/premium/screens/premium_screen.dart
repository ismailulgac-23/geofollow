import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Premium sayfası — tüm içerik PremiumBottomSheet'te.
/// Bu sayfa sadece bottom sheet'i açıp geri döner.
class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sayfa render edilir edilmez sheet aç ve pop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context).pop(); // /premium sayfasını kapat
      }
    });

    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.shrink(),
    );
  }
}
