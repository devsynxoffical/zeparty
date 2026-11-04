import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/privacy_settings_provider.dart';
import '../theme/app_colors.dart';

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
    if (lower.contains('emperor') || lower.contains('imperial')) return NobleTier.emperor;
    if (lower.contains('king')) return NobleTier.king;
    if (lower.contains('prince')) return NobleTier.prince;
    if (lower.contains('duke')) return NobleTier.duke;
    if (lower.contains('marquis') || lower.contains('mercurius')) return NobleTier.marquis;
    if (lower.contains('viscount')) return NobleTier.viscount;
    if (lower.contains('count') || lower.contains('earl')) return NobleTier.earl;
    if (lower.contains('baron') || lower.contains('knight')) return NobleTier.knight;
    return NobleTier.none;
  }

  static String? getBadgeAsset(String? title) {
    if (title == null || title.isEmpty) return null;
    final lower = title.toLowerCase().trim();

    // Noble Badges
    if (lower.contains('emperor') || lower.contains('imperial')) return 'assets/nobles/emperor_badge.webp';
    if (lower.contains('king') || lower.contains('prince')) return 'assets/nobles/ZP-034_tier-6-king_badge.webp';
    if (lower.contains('duke')) return 'assets/nobles/duke_badge.webp';
    if (lower.contains('marquis')) return 'assets/nobles/marquis_badge.webp';
    if (lower.contains('viscount')) return 'assets/nobles/viscount_badge.webp';
    if (lower.contains('count') || lower.contains('earl')) return 'assets/nobles/count_badge.webp';
    if (lower.contains('baron') || lower.contains('knight')) return 'assets/nobles/baron_badge.webp';

    // SVIP Badges (Accurate exact mapping for all 1-16 tiers using authentic dedicated animated live webp assets)
    if (lower.contains('svip')) {
      final match = RegExp(r'svip\s*(\d+)', caseSensitive: false).firstMatch(lower);
      if (match != null) {
        final level = int.tryParse(match.group(1)!) ?? 1;
        final clampedLevel = level.clamp(1, 16);
        final pad2 = clampedLevel.toString().padLeft(2, '0');
        return 'assets/svip/SVIP${pad2}_badge_live.webp';
      }
      return 'assets/svip/SVIP01_badge_live.webp';
    }

    // Role Badges
    if (lower.contains('admin') && lower.contains('super')) return 'assets/roles/super_admin_tag.webp';
    if (lower.contains('admin')) return 'assets/roles/admin_badge.webp';
    if (lower.contains('agency')) return 'assets/roles/agency_tag.webp';
    if (lower.contains('assistant')) return 'assets/roles/assistant_tag.webp';
    if (lower == 'bd' || lower.contains('bd ')) return 'assets/roles/bd_tag.webp';
    if (lower.contains('boss')) return 'assets/roles/boss_tag.webp';
    if (lower.contains('ceo')) return 'assets/roles/ceo_tag.webp';
    if (lower.contains('cs') || lower.contains('support') || lower.contains('service')) return 'assets/roles/cs_badge.webp';
    if (lower.contains('master') || lower.contains('game master')) return 'assets/roles/game_master_badge.webp';
    if (lower.contains('live host') || lower.contains('audio host')) return 'assets/roles/host_badge.webp';
    if (lower.contains('host')) return 'assets/roles/host_badge.webp';
    if (lower.contains('coins') || lower.contains('seller')) return 'assets/roles/coins_saller_tag.webp';
    if (lower.contains('recharge') || lower.contains('merchant') || lower.contains('marchent')) return 'assets/roles/marchent_badge.webp';
    if (lower.contains('top fan')) return 'assets/roles/top_fan_badge.webp';
    if (lower.contains('lover')) return 'assets/roles/lover_tag.webp';
    if (lower.contains('official')) return 'assets/roles/official_tag.webp';
    if (lower.contains('manager')) return 'assets/roles/manager_tag.webp';
    if (lower.contains('mystery')) return 'assets/animations/mystery_badge.webp';

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
    if (lower.contains('baron') || lower.contains('knight')) return 'assets/nobles/baron_frame.webp';

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
    if (lower.contains('cs') || lower.contains('support') || lower.contains('service')) return 'assets/roles/cs_frame.webp';
    if (lower.contains('game master')) return 'assets/roles/game_master_frame.webp';
    if (lower.contains('live host') || lower.contains('audio host')) return 'assets/roles/host_frame.webp';
    if (lower.contains('host')) return 'assets/roles/host_frame.webp';
    if (lower.contains('coins') || lower.contains('seller')) return 'assets/roles/coins_saller_frame.webp';
    if (lower.contains('recharge') || lower.contains('merchant') || lower.contains('marchent')) return 'assets/roles/marchent_frame.webp';
    if (lower.contains('lover')) return 'assets/roles/lover_frame.webp';
    if (lower.contains('manager')) return 'assets/roles/manager_frame.webp';
    if (lower.contains('official')) return 'assets/roles/official_frame.webp';
    if (lower.contains('top fan')) return 'assets/roles/top_fan_frame.webp';
    if (lower.contains('mystery')) return 'assets/animations/mystery_frame.webp';

    return null;
  }

  static String? getTagAsset(String? title) {
    if (title == null || title.isEmpty) return null;
    final lower = title.toLowerCase().trim();

    // SVIP Tags
    if (lower.contains('svip')) {
      for (int i = 16; i >= 1; i--) {
        if (lower.contains('svip $i') || lower.contains('svip$i')) {
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
    if (lower.contains('cs') || lower.contains('support') || lower.contains('service')) return 'assets/roles/cs_badge.webp';
    if (lower.contains('game master') || lower.contains('master')) return 'assets/roles/game_master_badge.webp';
    if (lower.contains('live host') || lower.contains('audio host') || lower.contains('host')) return 'assets/roles/host_badge.webp';
    if (lower.contains('lover')) return 'assets/roles/lover_tag.webp';
    if (lower.contains('manager')) return 'assets/roles/manager_tag.webp';
    if (lower.contains('recharge') || lower.contains('merchant') || lower.contains('marchent')) return 'assets/roles/marchent_badge.webp';
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
    if (lower.contains('emperor') || lower.contains('imperial')) return 'assets/nobles/emperor_chat_bubble.webp';
    if (lower.contains('king')) return 'assets/nobles/ZP-036_tier-6-king_badge.webp';
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

    if (lower.contains('mystery')) return 'assets/animations/mystery_bubble.webp';

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
    if (lower.contains('baron') || lower.contains('knight')) return null;

    // SVIP Cards
    if (lower.contains('svip')) {
      for (int i = 16; i >= 1; i--) {
        if (lower.contains('svip $i') || lower.contains('svip$i')) {
          if (i == 1) return 'assets/svip/svip1_badge.webp';
          return 'assets/svip/svip${i}_card.webp';
        }
      }
      return 'assets/svip/svip3_card.webp';
    }

    return null;
  }

  /// Master resolver ensuring real image assets are ALWAYS loaded for any item,
  /// replacing generic dummy icons with authentic artwork from the store catalog,
  /// roles, SVIP, and noble collections.
  static String resolveRealAsset({
    String? name,
    String? assetId,
    String? assetType,
    String? categoryId,
    String? currentImageUrl,
  }) {
    // 1. If currentImageUrl is an existing valid assets/ path or http URL
    if (currentImageUrl != null && currentImageUrl.isNotEmpty) {
      if (currentImageUrl.startsWith('http://') || currentImageUrl.startsWith('https://')) {
        return currentImageUrl;
      }
      if (currentImageUrl.startsWith('assets/')) {
        return currentImageUrl;
      }
    }

    final candidate = '${name ?? ''} ${assetId ?? ''} ${categoryId ?? ''} ${assetType ?? ''}'.trim();
    final lower = candidate.toLowerCase();

    // 2. Profile cards / cards
    if (lower.contains('card') || lower.contains('profile')) {
      final card = getCardAsset(candidate);
      if (card != null && card.isNotEmpty) return card;
    }

    // 3. Avatar Frames
    if (lower.contains('frame')) {
      final frame = getFrameAsset(candidate);
      if (frame != null && frame.isNotEmpty) return frame;
    }

    // 4. Badges / Roles / Special Tags
    final badge = getBadgeAsset(candidate);
    if (badge != null && badge.isNotEmpty) return badge;

    // 5. Chat Bubbles
    if (lower.contains('bubble')) {
      final bubble = getChatBubbleAsset(candidate);
      if (bubble != null && bubble.isNotEmpty) return bubble;
    }

    // 6. Entrance / Rides / Vehicles
    if (lower.contains('car') || lower.contains('mount') || lower.contains('vehicle') || lower.contains('entry') || lower.contains('ride')) {
      final entry = getEntranceAsset(candidate);
      if (entry != null && entry.isNotEmpty) return entry;
    }

    // 7. Tags
    final tag = getTagAsset(candidate);
    if (tag != null && tag.isNotEmpty) return tag;

    // 8. Frames fallback
    final frame = getFrameAsset(candidate);
    if (frame != null && frame.isNotEmpty) return frame;

    // 9. SVIP fallback
    if (lower.contains('svip')) {
      final card = getCardAsset(candidate);
      if (card != null) return card;
      return 'assets/svip/svip3_badge.webp';
    }

    // 10. Default authentic store collection asset fallback
    return 'assets/store/ZP-134_avatar-frames_frame.webp';
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

  static Color getColoredNicknameColor(NobleTier tier, {bool isDark = true}) {
    switch (tier) {
      case NobleTier.emperor:
        return const Color(0xFFFFD700); // Imperial (mixture handled via AnimatedImperialUsername)
      case NobleTier.king:
        return const Color(0xFFFFD700); // King (Yellow / Golden)
      case NobleTier.duke:
        return const Color(0xFFAB47BC); // Duke (Royal Purple)
      case NobleTier.marquis:
        return const Color(0xFFE53935); // Mercurius / Marquis (Red)
      case NobleTier.earl:
        return const Color(0xFF42A5F5); // Count / Earl (Sky Blue)
      case NobleTier.viscount:
        return const Color(0xFF2196F3); // Viscount (Blue)
      case NobleTier.knight:
        return const Color(0xFF29B6F6); // Baron / Knight (Distinct Baron Blue)
      case NobleTier.prince:
        return const Color(0xFFFFB300); // Prince (Amber)
      case NobleTier.none:
        return isDark ? Colors.white : AppColors.darkNavy;
    }
  }

  /// Builds a username widget styled consistently across all surfaces:
  /// - Imperial/Emperor: Animated gradient text (Blue & Golden mixture)
  /// - Other active Noble tiers: Colored nickname based on tier
  /// - Inactive/None: Normal theme text color
  static Widget buildStyledUsername({
    required String text,
    String? nobleTitle,
    TextStyle? style,
    TextOverflow overflow = TextOverflow.ellipsis,
    int maxLines = 1,
    TextAlign textAlign = TextAlign.start,
    bool isDark = true,
  }) {
    final tier = getTierFromTitle(nobleTitle);
    if (tier == NobleTier.emperor) {
      return AnimatedImperialUsername(
        text: text,
        style: style,
        overflow: overflow,
        maxLines: maxLines,
        textAlign: textAlign,
      );
    }
    final color = getColoredNicknameColor(tier, isDark: isDark);
    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(color: color),
      overflow: overflow,
      maxLines: maxLines,
      textAlign: textAlign,
    );
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = NobleBadgeHelper.getColoredNicknameColor(tier, isDark: isDark);
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

/// Lightweight, design-compliant animated blue and golden mixed username for Imperial (Emperor) Nobles
class AnimatedImperialUsername extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextOverflow overflow;
  final int maxLines;
  final TextAlign textAlign;

  const AnimatedImperialUsername({
    super.key,
    required this.text,
    this.style,
    this.overflow = TextOverflow.ellipsis,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
  });

  @override
  State<AnimatedImperialUsername> createState() => _AnimatedImperialUsernameState();
}

class _AnimatedImperialUsernameState extends State<AnimatedImperialUsername>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFF29B6F6), // Royal Blue
                Color(0xFFFFD54F), // Imperial Gold
                Color(0xFF4FC3F7), // Cyan/Sky Blue
                Color(0xFFFFE082), // Radiant Gold
                Color(0xFF29B6F6), // Royal Blue
              ],
              stops: const [0.0, 0.35, 0.55, 0.8, 1.0],
              transform: _GradientRotation(_controller.value * 6.2831853),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Text(
        widget.text,
        style: (widget.style ?? const TextStyle(fontWeight: FontWeight.bold)).copyWith(
          color: Colors.white,
        ),
        overflow: widget.overflow,
        maxLines: widget.maxLines,
        textAlign: widget.textAlign,
      ),
    );
  }
}

class _GradientRotation extends GradientTransform {
  final double radians;
  const _GradientRotation(this.radians);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final sin = math_sin(radians);
    final cos = math_cos(radians);
    final center = bounds.center;
    return Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..multiply(Matrix4(
        cos, -sin, 0, 0,
        sin,  cos, 0, 0,
        0,    0,   1, 0,
        0,    0,   0, 1,
      ))
      ..translate(-center.dx, -center.dy);
  }

  static double math_sin(double x) => (x - (x * x * x) / 6.0).clamp(-1.0, 1.0);
  static double math_cos(double x) => (1.0 - (x * x) / 2.0).clamp(-1.0, 1.0);
}

