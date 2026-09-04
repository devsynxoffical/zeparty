import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/privacy_settings_provider.dart';

enum NobleTier {
  none,
  knight,
  viscount,
  earl,
  marquis,
  duke,
  prince,
  king,
  emperor,
}

class NobleBadgeHelper {
  static NobleTier getTierFromTitle(String? title) {
    if (title == null) return NobleTier.none;
    final lower = title.toLowerCase();
    if (lower.contains('emperor')) return NobleTier.emperor;
    if (lower.contains('king')) return NobleTier.king;
    if (lower.contains('prince')) return NobleTier.prince;
    if (lower.contains('duke')) return NobleTier.duke;
    if (lower.contains('marquis')) return NobleTier.marquis;
    if (lower.contains('earl')) return NobleTier.earl;
    if (lower.contains('viscount')) return NobleTier.viscount;
    if (lower.contains('knight')) return NobleTier.knight;
    return NobleTier.none;
  }

  static Color getColoredNicknameColor(NobleTier tier) {
    switch (tier) {
      case NobleTier.emperor:
      case NobleTier.king:
      case NobleTier.duke:
        return const Color(0xFFFFD700); // Gold / Shiny Amber
      case NobleTier.prince:
      case NobleTier.marquis:
        return const Color(0xFFFF4500); // Crimson Red
      case NobleTier.earl:
      case NobleTier.viscount:
        return const Color(0xFFD500F9); // Luxury Purple / Magenta
      case NobleTier.knight:
        return const Color(0xFF00E5FF); // Cyan / Teal
      case NobleTier.none:
        return Colors.white;
    }
  }

  static String getNobleIcon(NobleTier tier) {
    switch (tier) {
      case NobleTier.emperor:
        return '👑 Imperial';
      case NobleTier.king:
        return '👑 King';
      case NobleTier.prince:
        return '👑 Prince';
      case NobleTier.duke:
        return '👑 Duke';
      case NobleTier.marquis:
        return '🛡️ Marquis';
      case NobleTier.earl:
        return '🛡️ Earl';
      case NobleTier.viscount:
        return '⚔️ Viscount';
      case NobleTier.knight:
        return '⚔️ Knight';
      case NobleTier.none:
        return '';
    }
  }
}

class NobleBadgeChip extends StatelessWidget {
  final UserModel user;
  final String? nobleTitleOverride;
  final double fontSize;

  const NobleBadgeChip({
    super.key,
    required this.user,
    this.nobleTitleOverride,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final privacy = context.watch<PrivacySettingsProvider>();
    if (privacy.hideLevelBadges) {
      return const SizedBox.shrink();
    }

    final title = nobleTitleOverride ?? user.nobleTitle ?? (user.isVip ? 'Noble Knight' : null);
    final tier = NobleBadgeHelper.getTierFromTitle(title);

    if (tier == NobleTier.none && title == null) {
      return const SizedBox.shrink();
    }

    final color = NobleBadgeHelper.getColoredNicknameColor(tier);
    final badgeText = NobleBadgeHelper.getNobleIcon(tier).isNotEmpty
        ? NobleBadgeHelper.getNobleIcon(tier)
        : (title ?? 'Noble');

    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.3), Colors.black54],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
