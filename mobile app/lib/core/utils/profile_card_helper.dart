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
  /// Evaluates whether an equipped profile card has a light background
  /// requiring dark text and dark icons for readability.
  static bool isLightCard(String? path) {
    if (path == null || path.isEmpty) return false;
    final lower = path.toLowerCase();

    // 1. All Noble profile cards feature radiant light backgrounds
    // (King, Count, Viscount, Duke, Emperor, Marquis)
    if (lower.contains('king') ||
        lower.contains('count') ||
        lower.contains('viscount') ||
        lower.contains('duke') ||
        lower.contains('emperor') ||
        lower.contains('marquis')) {
      return true;
    }

    // 2. All SVIP profile cards in ZeParty catalog feature light pearl, cream, or lavender interiors
    if (lower.contains('svip')) {
      return true;
    }

    // 3. Known light keywords
    if (lower.contains('gold') ||
        lower.contains('white') ||
        lower.contains('cream') ||
        lower.contains('pearl') ||
        lower.contains('silver') ||
        lower.contains('platinum')) {
      return true;
    }

    // 4. Known dark keywords
    if (lower.contains('black') ||
        lower.contains('dark') ||
        lower.contains('cyber') ||
        lower.contains('night') ||
        lower.contains('ruby')) {
      return false;
    }

    // Safe default for custom cards: assume light frame unless marked dark
    return true;
  }

  /// Master resolver: Identifies the single authoritative profile card to render,
  /// with safe fallback to the default card if none is equipped or unresolved.
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

    // Step 2: Fallback to active aristocratic noble or SVIP privileges if no card explicitly equipped
    if (rawCard == null || rawCard.isEmpty || rawCard == 'none' || rawCard == 'default') {
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

    // Step 3: Resolve file path or network URL
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

    // Step 4: Determine light/dark color adaptation
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
