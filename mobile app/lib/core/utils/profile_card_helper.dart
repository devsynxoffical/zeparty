import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../providers/backpack_provider.dart';
import 'noble_badge_helper.dart';

/// Resolved appearance specifications for a user's profile card.
class ProfileCardData {
  final bool isDefault;
  final String? assetPath;
  final String? networkUrl;
  final bool isLight;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color iconColor;
  final Color chipBorderColor;
  final Color chipBackgroundColor;

  const ProfileCardData({
    required this.isDefault,
    this.assetPath,
    this.networkUrl,
    required this.isLight,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.iconColor,
    required this.chipBorderColor,
    required this.chipBackgroundColor,
  });

  bool get hasCustomCard => !isDefault && (assetPath != null || networkUrl != null);

  /// Visual container background color matching the card theme.
  /// When a custom card is equipped, it replaces the container itself (transparent background).
  Color get cardBackgroundColor =>
      isDefault ? const Color(0xFF141024) : Colors.transparent;

  /// Visual container border: Default card uses golden/orange border; custom cards are borderless.
  BoxBorder? get cardBorder =>
      isDefault ? Border.all(color: const Color(0xFFFFB300), width: 1.5) : null;

  /// Surface background for inner sub-sections (Medals, Badges, CP, Level pills).
  Color get surfaceColor =>
      isLight ? const Color(0x0C000000) : const Color(0xFF1E1A33);

  /// Surface border for inner sub-sections.
  Color get surfaceBorderColor =>
      isLight ? const Color(0x18000000) : Colors.white12;

  /// Badge container background color.
  Color get badgeSurfaceColor =>
      isLight ? const Color(0x10000000) : const Color(0xFF221A36);

  /// Default fallback card appearance (Black background with golden/orange border).
  static const ProfileCardData defaultCard = ProfileCardData(
    isDefault: true,
    assetPath: null,
    networkUrl: null,
    isLight: false,
    primaryTextColor: Colors.white,
    secondaryTextColor: Colors.white70,
    iconColor: Colors.white70,
    chipBorderColor: Colors.white12,
    chipBackgroundColor: Color(0xFF1E1A33),
  );
}

/// Centralized helper for profile-card resolution and theme adaptation.
class ProfileCardHelper {
  /// Explicit registry mapping card IDs and asset filenames to their verified brightness theme.
  /// True = Light background (requires dark text & dark icons)
  /// False = Dark background (requires light text & light icons)
  static const Map<String, bool> _explicitCardThemes = {
    // Nobles (Empirically measured luminance 189.1 - 226.2 -> Light theme)
    'king': true,
    'king_card.webp': true,
    'assets/nobles/king_card.webp': true,
    'duke': true,
    'tier-5-duke_profilecard.webp': true,
    'assets/nobles/tier-5-duke_profilecard.webp': true,
    'emperor': true,
    'tier-7-emperor_profilecard.webp': true,
    'assets/nobles/tier-7-emperor_profilecard.webp': true,
    'marquis': true,
    'tier-4-marquis_profilecard.webp': true,
    'assets/nobles/tier-4-marquis_profilecard.webp': true,
    'viscount': true,
    'viscount_card.webp': true,
    'assets/nobles/viscount_card.webp': true,
    'count': true,
    'count_card.webp': true,
    'assets/nobles/count_card.webp': true,

    // Store Special Cards ZP-165 through ZP-170 (Luminance 141.6 - 199.9 -> Light theme)
    'zp-165': true,
    'zp-165_special-cards_card.webp': true,
    'assets/store/zp-165_special-cards_card.webp': true,
    'zp-166': true,
    'zp-166_special-cards_card.webp': true,
    'assets/store/zp-166_special-cards_card.webp': true,
    'zp-167': true,
    'zp-167_special-cards_card.webp': true,
    'assets/store/zp-167_special-cards_card.webp': true,
    'zp-168': true,
    'zp-168_special-cards_card.webp': true,
    'assets/store/zp-168_special-cards_card.webp': true,
    'zp-169': true,
    'zp-169_special-cards_card.webp': true,
    'assets/store/zp-169_special-cards_card.webp': true,
    'zp-170': true,
    'zp-170_special-cards_card.webp': true,
    'assets/store/zp-170_special-cards_card.webp': true,

    // SVIP Explicit Cards
    'svip7': true,
    'svip7_card.webp': true,
    'assets/svip/svip7_card.webp': true,
    'svip7_profilecard.webp': true,
    'assets/svip/svip7_profilecard.webp': true,

    // Known Dark Cards
    'card_vip.jpg': false,
    'assets/images/card_vip.jpg': false,
    'default': false,
    'none': false,
  };

  /// Evaluates whether an equipped profile card has a light background
  /// requiring dark text and dark icons for readability.
  /// Uses explicit card registry, with safe fallback to dark theme (false) for unknown cards.
  static bool isLightCard(String? pathOrId) {
    if (pathOrId == null || pathOrId.isEmpty) return false;
    final lower = pathOrId.toLowerCase().trim();

    // 1. Direct match in explicit registry
    if (_explicitCardThemes.containsKey(lower)) {
      return _explicitCardThemes[lower]!;
    }

    // 2. Basename match in explicit registry (stripping query parameters)
    final filename = lower.split('/').last.split('?').first;
    if (_explicitCardThemes.containsKey(filename)) {
      return _explicitCardThemes[filename]!;
    }

    // 3. Noble cards
    if (filename.contains('king') ||
        filename.contains('duke') ||
        filename.contains('emperor') ||
        filename.contains('marquis') ||
        filename.contains('viscount') ||
        filename.contains('count')) {
      return true;
    }

    // 4. Store special cards prefix (ZP-165 to ZP-170)
    if (filename.contains('zp-165') ||
        filename.contains('zp-166') ||
        filename.contains('zp-167') ||
        filename.contains('zp-168') ||
        filename.contains('zp-169') ||
        filename.contains('zp-170') ||
        filename.contains('special-cards')) {
      return true;
    }

    // 5. SVIP cards (All SVIP 2-16 cards feature light pearl, cream, or pastel interiors)
    if (lower.contains('svip')) {
      return true;
    }

    // 6. Explicit dark indicators
    if (filename.contains('card_vip') ||
        filename.contains('black') ||
        filename.contains('dark') ||
        filename.contains('night')) {
      return false;
    }

    // 7. Safe fallback for unknown custom cards: Dark theme (white text/icons)
    return false;
  }

  /// Master resolver: Identifies the single authoritative profile card to render,
  /// with safe fallback to the default card if none is equipped, unequipped, or unresolved.
  static ProfileCardData resolve({
    UserModel? user,
    bool isMe = false,
    BackpackProvider? backpack,
  }) {
    if (user == null) return ProfileCardData.defaultCard;

    // Step 1: Resolve explicit user-equipped card (from backpack for me, or user model)
    String? rawCard;
    if (isMe && backpack != null) {
      rawCard = backpack.equippedCardUrl ?? user.profileCardUrl ?? user.equippedProfileCardId;
    } else {
      rawCard = user.profileCardUrl ?? user.equippedProfileCardId;
    }

    // Explicit sentinel for unequipped / default card
    if (rawCard == 'none' || rawCard == 'default') {
      return ProfileCardData.defaultCard;
    }

    // Step 2: Fallback to active aristocratic noble or SVIP privileges if no card explicitly equipped
    if (rawCard == null || rawCard.isEmpty) {
      if (user.hasActiveNoble && user.nobleTitle != null && user.nobleTitle!.isNotEmpty) {
        rawCard = NobleBadgeHelper.getCardAsset(user.nobleTitle);
      } else if (user.svipLevel >= 3) {
        rawCard = NobleBadgeHelper.getCardAsset('SVIP ${user.svipLevel}');
      }
    }

    // If still null or default -> render default card
    if (rawCard == null || rawCard.isEmpty || rawCard == 'none' || rawCard == 'default') {
      return ProfileCardData.defaultCard;
    }

    // Step 2: Resolve file path or network URL
    String? assetPath;
    String? networkUrl;

    if (rawCard.startsWith('http://') || rawCard.startsWith('https://')) {
      networkUrl = rawCard;
    } else if (rawCard.startsWith('assets/')) {
      assetPath = rawCard;
    } else {
      // Named identifier (e.g. 'king', 'duke', 'svip')
      final resolved = NobleBadgeHelper.getCardAsset(rawCard);
      if (resolved != null && resolved.isNotEmpty) {
        if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
          networkUrl = resolved;
        } else if (resolved.startsWith('assets/')) {
          assetPath = resolved;
        }
      }
    }

    // If neither assetPath nor networkUrl could be resolved, fall back to default
    if (assetPath == null && networkUrl == null) {
      return ProfileCardData.defaultCard;
    }

    // Step 3: Determine light/dark color adaptation
    final isLight = isLightCard(assetPath ?? networkUrl);

    return ProfileCardData(
      isDefault: false,
      assetPath: assetPath,
      networkUrl: networkUrl,
      isLight: isLight,
      primaryTextColor: isLight ? const Color(0xFF1A162B) : Colors.white,
      secondaryTextColor: isLight ? const Color(0xFF534C64) : Colors.white70,
      iconColor: isLight ? const Color(0xFF4A4458) : Colors.white70,
      chipBorderColor: isLight ? const Color(0x33000000) : Colors.white12,
      chipBackgroundColor: isLight ? const Color(0x14000000) : const Color(0xFF1E1A33),
    );
  }
}
