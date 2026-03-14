import 'package:flutter/material.dart';
import 'package:tracker_app/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tracker_app/core/theme/app_theme.dart';

void showInviteBottomSheet(BuildContext context, String inviteCode) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXL),
          ),
        ),
        padding: EdgeInsets.only(
          left: AppTheme.spacingLG,
          right: AppTheme.spacingLG,
          top: AppTheme.spacingMD,
          bottom: MediaQuery.of(context).padding.bottom + AppTheme.spacingLG,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: AppTheme.borderRadiusSM,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_add,
                color: AppTheme.primaryColor,
                size: 32,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Text(
              l10n.inviteMembers,
              style: AppTheme.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              l10n.inviteDescriptionFull,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingXL),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingXL,
                vertical: AppTheme.spacingMD,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: AppTheme.borderRadiusLG,
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                inviteCode,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.inviteCodeCopied)),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: Text(l10n.copy),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceLight,
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.borderRadiusLG,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Share.share(l10n.shareMessage(inviteCode));
                    },
                    icon: const Icon(Icons.share),
                    label: Text(l10n.share),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.borderRadiusLG,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
