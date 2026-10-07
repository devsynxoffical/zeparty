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

  static String? getBadgeAsset(String? title) {
    if (title == null || title.isEmpty) return null;
    final lower = title.toLowerCase().trim();

    // Noble Badges
    if (lower.contains('emperor')) return 'assets/nobles/emperor_badge.png';
    if (lower.contains('king') || lower.contains('prince')) return 'assets/nobles/king_badge.png';
    if (lower.contains('duke')) return 'assets/nobles/duke_badge.png';
    if (lower.contains('marquis')) return 'assets/nobles/marquis_badge.png';
    if (lower.contains('count') || lower.contains('earl')) return 'assets/nobles/count_badge.png';
    if (lower.contains('viscount')) return 'assets/nobles/viscount_card.png';
    if (lower.contains('baron') || lower.contains('knight')) return 'assets/nobles/baron_badge.png';

    // SVIP Badges (Accurate existing asset mapping for all 1-16 tiers)
    if (lower.contains('svip')) {
      if (lower.contains('15') || lower.contains('16')) return 'assets/svip/svip15_badge.png';
      if (lower.contains('14')) return 'assets/svip/svip14_badge.png';
      if (lower.contains('13')) return 'assets/svip/svip13_badge.png';
      if (lower.contains('12')) return 'assets/svip/svip12_badge.png';
      if (lower.contains('11')) return 'assets/svip/svip11_badge.png';
      if (lower.contains('10')) return 'assets/svip/svip10_badge.png';
      if (lower.contains('9')) return 'assets/svip/svip9_badge.png';
      if (lower.contains('8')) return 'assets/svip/svip8_badge.png';
      if (lower.contains('7')) return 'assets/svip/svip7_badge.png';
      if (lower.contains('6')) return 'assets/svip/svip6_badge.png';
      if (lower.contains('5')) return 'assets/svip/svip5_tag.png';
      if (lower.contains('4')) return 'assets/svip/svip4_badge.png';
      if (lower.contains('3')) return 'assets/svip/svip3_badge.png';
      if (lower.contains('2')) return 'assets/svip/svip1_badge.png';
      if (lower.contains('1')) return 'assets/svip/svip1_badge.png';
      return 'assets/svip/svip10_badge.png';
    }

    // Role Badges
    if (lower.contains('admin') && lower.contains('super')) return 'assets/roles/super_admin_tag.png';
    if (lower.contains('admin')) return 'assets/roles/admin_badge.png';
    if (lower.contains('agency')) return 'assets/roles/agency_badge.png';
    if (lower.contains('assistant')) return 'assets/roles/assistant_badge.png';
    if (lower == 'bd' || lower.contains('bd ')) return 'assets/roles/bd_badge.png';
    if (lower.contains('boss')) return 'assets/roles/boss_badge.png';
    if (lower.contains('ceo')) return 'assets/roles/ceo_badge.png';
    if (lower.contains('cs') || lower.contains('support')) return 'assets/roles/cs_badge.png';
    if (lower.contains('master') || lower.contains('game master')) return 'assets/roles/game_master_badge.png';
    if (lower.contains('live host')) return 'assets/roles/host_badge.png';
    if (lower.contains('host')) return 'assets/roles/host_badge.png';
    if (lower.contains('merchant') || lower.contains('marchent')) return 'assets/roles/marchent_badge.png';
    if (lower.contains('top fan')) return 'assets/roles/top_fan_badge.png';
    if (lower.contains('mystery')) return 'assets/animations/mystery_badge.png';

    return null;
  }

  static String? getFrameAsset(String? title) {
    if (title == null || title.isEmpty) return null;
    final lower = title.toLowerCase().trim();

    // Noble Frames
    if (lower.contains('emperor')) return 'assets/nobles/emperor_frame.png';
    if (lower.contains('king')) return 'assets/nobles/king_frame.png';
    if (lower.contains('duke')) return 'assets/nobles/duke_frame.png';
    if (lower.contains('marquis')) return 'assets/nobles/marquis_frame.png';
    if (lower.contains('count') || lower.contains('earl')) return 'assets/nobles/count_frame.png';
    if (lower.contains('viscount')) return 'assets/nobles/viscount_frame.png';
    if (lower.contains('baron')) return 'assets/nobles/baron_frame.png';

    // SVIP Frames
    if (lower.contains('svip')) {
      for (int i = 15; i >= 6; i--) {
        if (lower.contains('svip $i') || lower.contains('svip$i')) {
          return 'assets/svip/svip${i}_frame.png';
        }
      }
    }

    // Role Frames
    if (lower.contains('admin')) return 'assets/roles/admin_frame.png';
    if (lower.contains('agency')) return 'assets/roles/agency_frame.png';
    if (lower.contains('assistant')) return 'assets/roles/assistant_frame.png';
    if (lower.contains('bd')) return 'assets/roles/bd_frame.png';
    if (lower.contains('boss')) return 'assets/roles/boss_frame.png';
    if (lower.contains('ceo')) return 'assets/roles/ceo_frame.png';
    if (lower.contains('cs')) return 'assets/roles/cs_frame.png';
    if (lower.contains('game master')) return 'assets/roles/game_master_frame.png';
    if (lower.contains('live host')) return 'assets/roles/live_host_frame.png';
    if (lower.contains('host')) return 'assets/roles/host_frame.png';
    if (lower.contains('lover')) return 'assets/roles/lover_frame.png';
    if (lower.contains('manager')) return 'assets/roles/manager_frame.png';
    if (lower.contains('merchant') || lower.contains('marchent')) return 'assets/roles/marchent_frame.png';
    if (lower.contains('official')) return 'assets/roles/official_frame.png';
    if (lower.contains('top fan')) return 'assets/roles/top_fan_frame.png';
    if (lower.contains('mystery')) return 'assets/animations/mystery_frame.png';

    return null;
  }

  static String? getTagAsset(String? title) {
    if (title == null || title.isEmpty) return null;
    final lower = title.toLowerCase().trim();

    // SVIP Tags
    if (lower.contains('svip')) {
      if (lower.contains('15') || lower.contains('16')) return 'assets/svip/svip15_tag.png';
      if (lower.contains('14')) return 'assets/svip/svip14_tag.png';
      if (lower.contains('13')) return 'assets/svip/svip13_tag.png';
      if (lower.contains('12')) return 'assets/svip/svip12_tag.png';
      if (lower.contains('11')) return 'assets/svip/svip11_tag.png';
      if (lower.contains('10')) return 'assets/svip/svip10_tag.png';
      if (lower.contains('9')) return 'assets/svip/svip9_tag.png';
      if (lower.contains('8')) return 'assets/svip/svip8_tag.png';
      if (lower.contains('7')) return 'assets/svip/svip7_tag.png';
      if (lower.contains('6')) return 'assets/svip/svip6_tag.png';
      if (lower.contains('5')) return 'assets/svip/svip5_tag.png';
      if (lower.contains('4')) return 'assets/svip/svip4_tag.png';
      if (lower.contains('3')) return 'assets/svip/svip3_tag.png';
      if (lower.contains('2')) return 'assets/svip/svip1_tag.png';
      if (lower.contains('1')) return 'assets/svip/svip1_tag.png';
      return 'assets/svip/svip10_tag.png';
    }

    // Role Tags
    if (lower.contains('super') && lower.contains('admin')) return 'assets/roles/super_admin_tag.png';
    if (lower.contains('admin')) return 'assets/roles/admin_tag.png';
    if (lower.contains('agency')) return 'assets/roles/agency_tag.png';
    if (lower.contains('assistant')) return 'assets/roles/assistant_tag.png';
    if (lower == 'bd' || lower.contains('bd ')) return 'assets/roles/bd_tag.png';
    if (lower.contains('boss')) return 'assets/roles/boss_tag.png';
    if (lower.contains('ceo')) return 'assets/roles/ceo_tag.png';
    if (lower.contains('coin') || lower.contains('seller')) return 'assets/roles/coins_saller_tag.png';
    if (lower.contains('cs') || lower.contains('support')) return 'assets/roles/cs_tag.png';
    if (lower.contains('game master') || lower.contains('master')) return 'assets/roles/game_master_tag.png';
    if (lower.contains('host')) return 'assets/roles/host_tag.png';
    if (lower.contains('lover')) return 'assets/roles/lover_tag.png';
    if (lower.contains('manager')) return 'assets/roles/manager_tag.png';
    if (lower.contains('merchant') || lower.contains('marchent')) return 'assets/roles/marchent_tag.png';
    if (lower.contains('official')) return 'assets/roles/official_tag.png';
    if (lower.contains('top fan')) return 'assets/roles/top_fan_tag.png';

    // Nobles tag fallback using badge
    return getBadgeAsset(title);
  }

  static String? getChatBubbleAsset(String? title) {
    if (title == null || title.isEmpty) return null;
    final lower = title.toLowerCase().trim();

    // Noble Chat Bubbles
    if (lower.contains('emperor')) return 'assets/nobles/emperor_chat_bubble.png';
    if (lower.contains('duke')) return 'assets/nobles/duke_chat_bubble.png';
    if (lower.contains('marquis')) return 'assets/nobles/marquis_chat_bubble.png';
    if (lower.contains('count') || lower.contains('earl')) return 'assets/nobles/count_chat_bubble.png';

    // SVIP Chat Bubbles
    if (lower.contains('svip')) {
      for (int i = 15; i >= 6; i--) {
        if (lower.contains('svip $i') || lower.contains('svip$i')) {
          return 'assets/svip/svip${i}_chat_bubble.png';
        }
      }
      return 'assets/svip/svip10_chat_bubble.png';
    }

    return null;
  }

  static String? getCardAsset(String? title) {
    if (title == null || title.isEmpty) return null;
    final lower = title.toLowerCase().trim();

    // Noble Cards
    if (lower.contains('king') || lower.contains('emperor')) return 'assets/nobles/king_card.png';
    if (lower.contains('viscount') || lower.contains('baron') || lower.contains('knight')) return 'assets/nobles/viscount_card.png';

    // SVIP Cards
    if (lower.contains('svip')) {
      for (int i = 15; i >= 3; i--) {
        if (lower.contains('svip $i') || lower.contains('svip$i')) {
          return 'assets/svip/svip${i}_card.png';
        }
      }
      return 'assets/svip/svip10_card.png';
    }

    return null;
  }

  static String? getEntranceAsset(String? title) {
    if (title == null || title.isEmpty) return null;
    final lower = title.toLowerCase().trim();

    // Noble Entrances
    if (lower.contains('emperor') || lower.contains('king')) return 'assets/nobles/emperor_entrance.png';
    if (lower.contains('marquis') || lower.contains('duke') || lower.contains('count')) return 'assets/nobles/marquis_entrance.png';

    // SVIP Entrances
    if (lower.contains('svip')) {
      for (int i = 15; i >= 6; i--) {
        if (lower.contains('svip $i') || lower.contains('svip$i')) {
          return 'assets/svip/svip${i}_entry.png';
        }
      }
      return 'assets/svip/svip10_entry.png';
    }

    return null;
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

    String? title = nobleTitleOverride ?? user.nobleTitle;
    if (title == null || title.isEmpty) {
      if (user.svipLevel > 0) {
        title = 'SVIP ${user.svipLevel}';
      } else if (user.role != UserRole.user) {
        title = user.role.name;
      } else if (user.isVip) {
        title = 'Baron';
      }
    }

    final assetPath = NobleBadgeHelper.getBadgeAsset(title);

    if (assetPath != null) {
      return Container(
        margin: const EdgeInsets.only(left: 4),
        child: Image.asset(
          assetPath,
          height: fontSize * 2.4,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildFallbackChip(context, title),
        ),
      );
    }

    return _buildFallbackChip(context, title);
  }

  Widget _buildFallbackChip(BuildContext context, String? title) {
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

class NobleTagChip extends StatelessWidget {
  final UserModel user;
  final String? tagTitleOverride;
  final double height;

  const NobleTagChip({
    super.key,
    required this.user,
    this.tagTitleOverride,
    this.height = 18,
  });

  @override
  Widget build(BuildContext context) {
    String? title = tagTitleOverride ?? user.nobleTitle;
    if (title == null || title.isEmpty) {
      if (user.svipLevel > 0) {
        title = 'SVIP ${user.svipLevel}';
      } else if (user.role != UserRole.user) {
        title = user.role.name;
      } else if (user.isVip) {
        title = 'SVIP 1';
      }
    }

    final tagAsset = NobleBadgeHelper.getTagAsset(title);
    if (tagAsset != null) {
      return Container(
        margin: const EdgeInsets.only(left: 4),
        child: Image.asset(
          tagAsset,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class NobleBadgeAndTagRow extends StatelessWidget {
  final UserModel user;
  final double badgeSize;
  final double tagHeight;

  const NobleBadgeAndTagRow({
    super.key,
    required this.user,
    this.badgeSize = 11,
    this.tagHeight = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        NobleBadgeChip(user: user, fontSize: badgeSize),
        NobleTagChip(user: user, height: tagHeight),
      ],
    );
  }
}

