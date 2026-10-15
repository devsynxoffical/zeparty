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
    if (lower.contains('viscount')) return NobleTier.viscount;
    if (lower.contains('count') || lower.contains('earl')) return NobleTier.earl;
    if (lower.contains('baron') || lower.contains('knight')) return NobleTier.knight;
    return NobleTier.none;
  }

  static String? getBadgeAsset(String? title) {
    if (title == null || title.isEmpty) return null;
    final lower = title.toLowerCase().trim();

    // Noble Badges
    if (lower.contains('emperor')) return 'assets/nobles/emperor_badge.webp';
    if (lower.contains('king') || lower.contains('prince')) return 'assets/nobles/king_badge.webp';
    if (lower.contains('duke')) return 'assets/nobles/duke_badge.webp';
    if (lower.contains('marquis')) return 'assets/nobles/marquis_badge.webp';
    if (lower.contains('viscount')) return 'assets/nobles/viscount_badge.webp';
    if (lower.contains('count') || lower.contains('earl')) return 'assets/nobles/count_badge.webp';
    if (lower.contains('baron') || lower.contains('knight')) return 'assets/nobles/baron_badge.webp';

    // SVIP Badges (Accurate exact mapping for all 1-16 tiers using authentic dedicated webp assets)
    if (lower.contains('svip')) {
      final match = RegExp(r'svip\s*(\d+)', caseSensitive: false).firstMatch(lower);
      if (match != null) {
        final level = int.tryParse(match.group(1)!) ?? 1;
        final clampedLevel = level.clamp(1, 16);
        if (clampedLevel == 1) return 'assets/svip/svip1_badge.webp';
        if (clampedLevel == 2) return 'assets/svip/svip2_badge.webp';
        if (clampedLevel == 3) return 'assets/svip/svip3_badge.webp';
        if (clampedLevel == 4) return 'assets/svip/svip4_badge.webp';
        if (clampedLevel == 5) return 'assets/svip/svip5_badge.webp';
        if (clampedLevel == 6) return 'assets/svip/svip6_badge.webp';
        final pad2 = clampedLevel.toString().padLeft(2, '0');
        if (clampedLevel <= 15) {
          return 'assets/svip/SVIP${pad2}_badge_live.webp';
        }
        return 'assets/svip/SVIP16_badge_live.webp';
      }
      return 'assets/svip/svip1_badge.webp';
    }

    // Role Badges
    if (lower.contains('admin') && lower.contains('super')) return 'assets/roles/super_admin_tag.webp';
    if (lower.contains('admin')) return 'assets/roles/admin_badge.webp';
    if (lower.contains('agency')) return 'assets/roles/agency_tag.webp';
    if (lower.contains('assistant')) return 'assets/roles/assistant_tag.webp';
    if (lower == 'bd' || lower.contains('bd ')) return 'assets/roles/bd_tag.webp';
    if (lower.contains('boss')) return 'assets/roles/boss_tag.webp';
    if (lower.contains('ceo')) return 'assets/roles/ceo_tag.webp';
    if (lower.contains('cs') || lower.contains('support')) return 'assets/roles/cs_badge.webp';
    if (lower.contains('master') || lower.contains('game master')) return 'assets/roles/game_master_badge.webp';
    if (lower.contains('live host')) return 'assets/roles/host_badge.webp';
    if (lower.contains('host')) return 'assets/roles/host_badge.webp';
    if (lower.contains('coins') || lower.contains('seller')) return 'assets/roles/coins_saller_tag.webp';
    if (lower.contains('merchant') || lower.contains('marchent')) return 'assets/roles/marchent_badge.webp';
    if (lower.contains('top fan')) return 'assets/roles/top_fan_badge.webp';
    if (lower.contains('lover')) return 'assets/roles/lover_tag.webp';
    if (lower.contains('official')) return 'assets/roles/official_tag.webp';
    if (lower.contains('manager')) return 'assets/roles/manager_tag.webp';
    if (lower.contains('mystery')) return 'assets/svip/SVIP16_badge_live.webp';

    return null;
  }

  static String? getFrameAsset(String? title) {
    if (title == null || title.isEmpty) return null;
    final lower = title.toLowerCase().trim();

    // Noble Frames
    if (lower.contains('emperor')) return 'assets/nobles/emperor_frame.webp';
    if (lower.contains('king')) return 'assets/nobles/king_frame.webp';
    if (lower.contains('duke')) return 'assets/nobles/duke_frame.webp';
    if (lower.contains('marquis')) return 'assets/nobles/marquis_frame.webp';
    if (lower.contains('viscount')) return 'assets/nobles/viscount_frame.webp';
    if (lower.contains('count') || lower.contains('earl')) return 'assets/nobles/count_frame.webp';
    if (lower.contains('baron')) return 'assets/nobles/baron_frame.webp';

    // SVIP Frames
    if (lower.contains('svip')) {
      final match = RegExp(r'svip\s*(\d+)', caseSensitive: false).firstMatch(lower);
      if (match != null) {
        final level = int.tryParse(match.group(1)!) ?? 1;
        final clampedLevel = level.clamp(1, 16);
        return 'assets/svip/svip${clampedLevel}_frame.webp';
      }
      return 'assets/nobles/baron_frame.webp';
    }

    // Role Frames
    if (lower.contains('super') && lower.contains('admin')) return 'assets/roles/super_admin_frame.webp';
    if (lower.contains('admin')) return 'assets/roles/admin_frame.webp';
    if (lower.contains('agency')) return 'assets/roles/agency_frame.webp';
    if (lower.contains('assistant')) return 'assets/roles/assistant_frame.webp';
    if (lower.contains('bd')) return 'assets/roles/bd_frame.webp';
    if (lower.contains('boss')) return 'assets/roles/boss_frame.webp';
    if (lower.contains('ceo')) return 'assets/roles/ceo_frame.webp';
    if (lower.contains('cs')) return 'assets/roles/cs_frame.webp';
    if (lower.contains('game master')) return 'assets/roles/game_master_frame.webp';
    if (lower.contains('live host')) return 'assets/roles/host_frame.webp';
    if (lower.contains('host')) return 'assets/roles/host_frame.webp';
    if (lower.contains('coins') || lower.contains('seller')) return 'assets/roles/coins_saller_frame.webp';
    if (lower.contains('lover')) return 'assets/roles/lover_frame.webp';
    if (lower.contains('manager')) return 'assets/roles/manager_frame.webp';
    if (lower.contains('merchant') || lower.contains('marchent')) return 'assets/roles/marchent_frame.webp';
    if (lower.contains('official')) return 'assets/roles/official_frame.webp';
    if (lower.contains('top fan')) return 'assets/roles/top_fan_frame.webp';
    if (lower.contains('mystery')) return 'assets/svip/svip16_frame.webp';

    return null;
  }

  static String? getTagAsset(String? title) {
    if (title == null || title.isEmpty) return null;
    final lower = title.toLowerCase().trim();

    // SVIP Tags
    if (lower.contains('svip')) {
      for (int i = 16; i >= 1; i--) {
        if (lower.contains('svip $i') || lower.contains('svip$i')) {
          if (i == 2) return null; // SVIP 2 does not have an official VIP tag
          return 'assets/svip/svip${i}_tag.png';
        }
      }
      return 'assets/svip/svip1_tag.png';
    }

    // Role Tags
    if (lower.contains('super') && lower.contains('admin')) return 'assets/roles/super_admin_tag.webp';
    if (lower.contains('admin')) return 'assets/roles/admin_badge.webp';
    if (lower.contains('agency')) return 'assets/roles/agency_tag.webp';
    if (lower.contains('assistant')) return 'assets/roles/assistant_tag.webp';
    if (lower == 'bd' || lower.contains('bd ')) return 'assets/roles/bd_tag.webp';
    if (lower.contains('boss')) return 'assets/roles/boss_tag.webp';
    if (lower.contains('ceo')) return 'assets/roles/ceo_tag.webp';
    if (lower.contains('coin') || lower.contains('seller')) return 'assets/roles/coins_saller_tag.webp';
    if (lower.contains('cs') || lower.contains('support')) return 'assets/roles/cs_badge.webp';
    if (lower.contains('game master') || lower.contains('master')) return 'assets/roles/game_master_badge.webp';
    if (lower.contains('host')) return 'assets/roles/host_badge.webp';
    if (lower.contains('lover')) return 'assets/roles/lover_tag.webp';
    if (lower.contains('manager')) return 'assets/roles/manager_tag.webp';
    if (lower.contains('merchant') || lower.contains('marchent')) return 'assets/roles/marchent_badge.webp';
    if (lower.contains('official')) return 'assets/roles/official_tag.webp';
    if (lower.contains('top fan')) return 'assets/roles/top_fan_badge.webp';
    if (lower.contains('mystery')) return 'assets/animations/mystery_tag.webp';
    // Nobles do not have a separate rectangular tag (they use the noble badge)
    return null;
  }

  static String? getChatBubbleAsset(String? title) {
    if (title == null || title.isEmpty) return null;
    final lower = title.toLowerCase().trim();

    // Noble Chat Bubbles for all 7 Aristocracy Tiers
    if (lower.contains('emperor') || lower.contains('king')) return 'assets/nobles/emperor_chat_bubble.webp';
    if (lower.contains('duke')) return 'assets/nobles/duke_chat_bubble.webp';
    if (lower.contains('marquis')) return 'assets/nobles/marquis_chat_bubble.webp';
    if (lower.contains('count') || lower.contains('earl') || lower.contains('viscount') || lower.contains('baron')) return 'assets/nobles/count_chat_bubble.webp';

    // SVIP Chat Bubbles
    if (lower.contains('svip')) {
      for (int i = 16; i >= 1; i--) {
        if (lower.contains('svip $i') || lower.contains('svip$i')) {
          return 'assets/svip/svip${i}_chat_bubble.webp';
        }
      }
      return 'assets/nobles/count_chat_bubble.webp';
    }

    if (lower.contains('mystery')) return 'assets/svip/svip16_chat_bubble.webp';

    return null;
  }

  static String? getCardAsset(String? title) {
    if (title == null || title.isEmpty) return null;
    final lower = title.toLowerCase().trim();

    // Noble Profile Cards for all 7 Aristocracy Tiers
    if (lower.contains('emperor')) return 'assets/nobles/tier-7-emperor_profilecard.webp';
    if (lower.contains('king')) return 'assets/nobles/king_card.webp';
    if (lower.contains('duke')) return 'assets/nobles/tier-5-duke_profilecard.webp';
    if (lower.contains('marquis')) return 'assets/nobles/tier-4-marquis_profilecard.webp';
    if (lower.contains('viscount')) return 'assets/nobles/viscount_card.webp';
    if (lower.contains('count') || lower.contains('earl')) return 'assets/nobles/count_card.webp';
    if (lower.contains('baron') || lower.contains('knight')) return 'assets/nobles/viscount_badge.webp';

    // SVIP Cards
    if (lower.contains('svip')) {
      for (int i = 16; i >= 1; i--) {
        if (lower.contains('svip $i') || lower.contains('svip$i')) {
          if (i == 1 || i == 2) return null; // SVIP 1 and 2 do not have an official profile card / skin
          return 'assets/svip/svip${i}_card.webp';
        }
      }
      return null;
    }

    return null;
  }

  static String? getEntranceAsset(String? title) {
    if (title == null || title.isEmpty) return null;
    final lower = title.toLowerCase().trim();

    // Noble Entrance Animations for all 7 Aristocracy Tiers
    if (lower.contains('emperor') || lower.contains('king')) return 'assets/nobles/emperor_entrance.webp';
    if (lower.contains('duke')) return 'assets/nobles/duke_entrance.webp';
    if (lower.contains('marquis') || lower.contains('count') || lower.contains('viscount') || lower.contains('baron')) return 'assets/nobles/marquis_entrance.webp';

    // SVIP Entrances
    if (lower.contains('svip')) {
      for (int i = 16; i >= 1; i--) {
        if (lower.contains('svip $i') || lower.contains('svip$i')) {
          if (i == 13) return 'assets/svip/ZP-124_svip-14_entry.webp';
          return 'assets/svip/svip${i}_entry.webp';
        }
      }
      return 'assets/nobles/marquis_entrance.webp';
    }

    if (lower.contains('mystery')) return 'assets/animations/mystery_entry.webp';

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
          errorBuilder: (context, error, stackTrace) => _buildFallbackChip(context, title),
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
    String? title = tagTitleOverride;
    if (title == null || title.isEmpty) {
      if (user.role != UserRole.user) {
        title = user.role.name;
      } else if (user.isHost) {
        title = 'host';
      } else if (user.isAgency) {
        title = 'agency';
      } else if (user.isBd) {
        title = 'bd';
      } else if (user.isSeller) {
        title = 'seller';
      } else if (user.svipLevel > 0) {
        title = 'SVIP ${user.svipLevel}';
      } else if (user.nobleTitle != null && user.nobleTitle!.isNotEmpty) {
        title = user.nobleTitle;
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
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
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

/// Module 32 Specification: 7 Noble Tiers & Color Palette
class NobleHelper {
  static const Map<int, Color> nobleColors = {
    0: Color(0xFFFFFFFF), // None
    1: Color(0xFFCD7F32), // 1: Baron (Bronze)
    2: Color(0xFF94A3B8), // 2: Viscount (Silver)
    3: Color(0xFFEAB308), // 3: Earl (Gold)
    4: Color(0xFF38BDF8), // 4: Marquis (Diamond Blue)
    5: Color(0xFFA855F7), // 5: Duke (Royal Purple)
    6: Color(0xFFEC4899), // 6: Prince (Rose Gold)
    7: Color(0xFFFF5A4F), // 7: Emperor (Crimson Red)
  };
}

