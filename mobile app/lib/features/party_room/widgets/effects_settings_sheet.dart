import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/live_party_provider.dart';

class EffectsSettingsSheet extends StatelessWidget {
  const EffectsSettingsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const EffectsSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LivePartyProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1A29) : const Color(0xFFFFF7E6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.2),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Title
            Text(
              'Effects',
              style: TextStyle(
                color: isDark ? Colors.amber : const Color(0xFF4A3400),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Toggles matching Reference Image 2
            _buildToggleItem(
              context,
              title: 'Gift effects',
              value: provider.giftEffectsEnabled,
              onChanged: provider.toggleGiftEffects,
              isDark: isDark,
            ),
            _buildToggleItem(
              context,
              title: 'Frame effects',
              value: provider.frameEffectsEnabled,
              onChanged: provider.toggleFrameEffects,
              isDark: isDark,
            ),
            _buildToggleItem(
              context,
              title: 'Entry effects',
              value: provider.entryEffectsEnabled,
              onChanged: provider.toggleEntryEffects,
              isDark: isDark,
            ),
            _buildToggleItem(
              context,
              title: 'Gift banner notification',
              value: provider.giftBannerNotificationEnabled,
              onChanged: provider.toggleGiftBannerNotification,
              isDark: isDark,
            ),
            _buildToggleItem(
              context,
              title: 'Red envelope banner notification',
              value: provider.redEnvelopeBannerNotificationEnabled,
              onChanged: provider.toggleRedEnvelopeBannerNotification,
              isDark: isDark,
            ),
            _buildToggleItem(
              context,
              title: 'Game banner notification',
              value: provider.gameBannerNotificationEnabled,
              onChanged: provider.toggleGameBannerNotification,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF332A15),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.amber,
            activeTrackColor: Colors.amber.withValues(alpha: 0.4),
            inactiveThumbColor: isDark ? Colors.grey[600] : Colors.grey[400],
            inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
