import 'package:flutter/material.dart';

/// Per-bubble configuration and individual content safe area specification.
/// Every equipped bubble has its own independently calculated usable content
/// boundary, aspect ratio, min dimensions, and voice note sizing.
class ChatBubbleSpec {
  final String id;
  final String name;
  final String assetPath;
  final double originalWidth;
  final double originalHeight;

  /// Usable content insets for outgoing (sent by current user, right-aligned) messages
  final EdgeInsets outgoingInsets;

  /// Usable content insets for incoming (received, left-aligned) messages
  final EdgeInsets incomingInsets;

  /// Minimum bubble width for text messages
  final double minWidth;

  /// Minimum bubble height for text messages
  final double minHeight;

  /// Minimum bubble width for voice note messages (ensuring play button, waveform,
  /// microphone icon, label, and duration all fit comfortably inside the artwork)
  final double minVoiceWidth;

  /// Minimum bubble height for voice note messages
  final double minVoiceHeight;

  /// Primary text color on this bubble's interior background
  final Color textColor;

  /// Decorative areas and ornaments that message content must avoid
  final String decorativeDescription;

  const ChatBubbleSpec({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.originalWidth,
    required this.originalHeight,
    required this.outgoingInsets,
    required this.incomingInsets,
    this.minWidth = 135.0,
    this.minHeight = 52.0,
    this.minVoiceWidth = 205.0,
    this.minVoiceHeight = 62.0,
    this.textColor = Colors.white,
    this.decorativeDescription = 'Standard decorative borders',
  });

  /// The true aspect ratio of the underlying artwork image
  double get aspectRatio => originalWidth / originalHeight;

  /// Resolves the individual safe area insets for this bubble based on message direction
  EdgeInsets getInsets({required bool isMe}) => isMe ? outgoingInsets : incomingInsets;
}

/// Authoritative registry of all ZeParty chat bubble artwork configurations.
class ChatBubbleConfig {
  ChatBubbleConfig._();

  // ───────────────────────────────────────────────────────────────────────────
  // 1. NOBLE CHAT BUBBLES
  // ───────────────────────────────────────────────────────────────────────────

  /// Blue Noble Chat Bubble - Duke Tier (512x212, aspect ratio 2.4151)
  /// Features top royal crest and bottom jewel tail.
  static const ChatBubbleSpec dukeNoble = ChatBubbleSpec(
    id: 'noble_duke',
    name: 'Duke Noble Bubble',
    assetPath: 'assets/nobles/duke_chat_bubble.webp',
    originalWidth: 512,
    originalHeight: 212,
    outgoingInsets: EdgeInsets.fromLTRB(26, 18, 28, 14),
    incomingInsets: EdgeInsets.fromLTRB(28, 18, 26, 14),
    minWidth: 140.0,
    minHeight: 56.0,
    minVoiceWidth: 210.0,
    minVoiceHeight: 64.0,
    textColor: Colors.white,
    decorativeDescription: 'Top royal crest and bottom jewel tail with side wing ornaments',
  );

  /// Imperial Gold Noble Chat Bubble - Emperor Tier (512x212, aspect ratio 2.4151)
  /// Features imperial gold winged crown and lower seal.
  static const ChatBubbleSpec emperorNoble = ChatBubbleSpec(
    id: 'noble_emperor',
    name: 'Emperor Noble Bubble',
    assetPath: 'assets/nobles/emperor_chat_bubble.webp',
    originalWidth: 512,
    originalHeight: 212,
    outgoingInsets: EdgeInsets.fromLTRB(28, 18, 28, 16),
    incomingInsets: EdgeInsets.fromLTRB(28, 18, 28, 16),
    minWidth: 140.0,
    minHeight: 56.0,
    minVoiceWidth: 210.0,
    minVoiceHeight: 64.0,
    textColor: Colors.white,
    decorativeDescription: 'Imperial gold winged crown, lower seal, and glowing laurel branches',
  );

  /// Marquis Noble Chat Bubble - Marquis Tier (512x170, aspect ratio 3.0118)
  /// Features purple royal banner with lateral amethyst gemstones.
  static const ChatBubbleSpec marquisNoble = ChatBubbleSpec(
    id: 'noble_marquis',
    name: 'Marquis Noble Bubble',
    assetPath: 'assets/nobles/marquis_chat_bubble.webp',
    originalWidth: 512,
    originalHeight: 170,
    outgoingInsets: EdgeInsets.fromLTRB(26, 15, 26, 13),
    incomingInsets: EdgeInsets.fromLTRB(26, 15, 26, 13),
    minWidth: 135.0,
    minHeight: 50.0,
    minVoiceWidth: 200.0,
    minVoiceHeight: 60.0,
    textColor: Colors.white,
    decorativeDescription: 'Purple royal banner with amethyst gemstones and gold corner trim',
  );

  /// Count / Baron / Viscount Noble Chat Bubble (512x170, aspect ratio 3.0118)
  /// Features classic gold filigree borders and corner ornaments.
  static const ChatBubbleSpec countNoble = ChatBubbleSpec(
    id: 'noble_count',
    name: 'Count Noble Bubble',
    assetPath: 'assets/nobles/count_chat_bubble.webp',
    originalWidth: 512,
    originalHeight: 170,
    outgoingInsets: EdgeInsets.fromLTRB(24, 14, 24, 12),
    incomingInsets: EdgeInsets.fromLTRB(24, 14, 24, 12),
    minWidth: 130.0,
    minHeight: 48.0,
    minVoiceWidth: 195.0,
    minVoiceHeight: 58.0,
    textColor: Colors.white,
    decorativeDescription: 'Classic gold filigree borders and ornamental corner brackets',
  );

  // ───────────────────────────────────────────────────────────────────────────
  // 2. STORE CHAT BUBBLES (Drive Store Collection ZP-144 .. ZP-158, 512x202)
  // ───────────────────────────────────────────────────────────────────────────

  /// Crimson Flame Chat Bubble - ZP-146 (512x202, aspect ratio 2.5347)
  /// Features intense crimson gradient and a distinct right flame jewel ornament.
  static const ChatBubbleSpec crimsonFlameStore = ChatBubbleSpec(
    id: 'bubble_zp146',
    name: 'Crimson Flame Bubble',
    assetPath: 'assets/store/ZP-146_chat-bubbles_bubble.webp',
    originalWidth: 512,
    originalHeight: 202,
    outgoingInsets: EdgeInsets.fromLTRB(24, 15, 28, 13),
    incomingInsets: EdgeInsets.fromLTRB(28, 15, 24, 13),
    minWidth: 135.0,
    minHeight: 52.0,
    minVoiceWidth: 205.0,
    minVoiceHeight: 62.0,
    textColor: Colors.white,
    decorativeDescription: 'Intense crimson gradient with prominent right flame jewel ornament',
  );

  /// Golden Royal Bubble - ZP-144 (512x202, aspect ratio 2.5347)
  static const ChatBubbleSpec goldenRoyalStore = ChatBubbleSpec(
    id: 'bubble_zp144',
    name: 'Golden Royal Bubble',
    assetPath: 'assets/store/ZP-144_chat-bubbles_bubble.webp',
    originalWidth: 512,
    originalHeight: 202,
    outgoingInsets: EdgeInsets.fromLTRB(26, 16, 26, 14),
    incomingInsets: EdgeInsets.fromLTRB(26, 16, 26, 14),
    minWidth: 135.0,
    minHeight: 52.0,
    minVoiceWidth: 205.0,
    minVoiceHeight: 62.0,
    textColor: Colors.white,
    decorativeDescription: 'Gold ornate filigree frame with royal emblems',
  );

  /// Purple Luxe Bubble - ZP-145 (512x202, aspect ratio 2.5347)
  static const ChatBubbleSpec purpleLuxeStore = ChatBubbleSpec(
    id: 'bubble_zp145',
    name: 'Purple Luxe Bubble',
    assetPath: 'assets/store/ZP-145_chat-bubbles_bubble.webp',
    originalWidth: 512,
    originalHeight: 202,
    outgoingInsets: EdgeInsets.fromLTRB(26, 15, 26, 13),
    incomingInsets: EdgeInsets.fromLTRB(26, 15, 26, 13),
    minWidth: 135.0,
    minHeight: 52.0,
    minVoiceWidth: 205.0,
    minVoiceHeight: 62.0,
    textColor: Colors.white,
    decorativeDescription: 'Deep purple velvet background with diamond side embellishments',
  );

  /// Royal Blue Bubble - ZP-147 (512x202, aspect ratio 2.5347)
  static const ChatBubbleSpec royalBlueStore = ChatBubbleSpec(
    id: 'bubble_zp147',
    name: 'Royal Blue Bubble',
    assetPath: 'assets/store/ZP-147_chat-bubbles_bubble.webp',
    originalWidth: 512,
    originalHeight: 202,
    outgoingInsets: EdgeInsets.fromLTRB(25, 15, 25, 13),
    incomingInsets: EdgeInsets.fromLTRB(25, 15, 25, 13),
    minWidth: 135.0,
    minHeight: 52.0,
    minVoiceWidth: 205.0,
    minVoiceHeight: 62.0,
    textColor: Colors.white,
    decorativeDescription: 'Sapphire royal borders with silver flourishes',
  );

  /// Sparkle Gold Bubble - ZP-148 (512x202, aspect ratio 2.5347)
  static const ChatBubbleSpec sparkleGoldStore = ChatBubbleSpec(
    id: 'bubble_zp148',
    name: 'Sparkle Gold Bubble',
    assetPath: 'assets/store/ZP-148_chat-bubbles_bubble.webp',
    originalWidth: 512,
    originalHeight: 202,
    outgoingInsets: EdgeInsets.fromLTRB(26, 16, 26, 14),
    incomingInsets: EdgeInsets.fromLTRB(26, 16, 26, 14),
    minWidth: 135.0,
    minHeight: 52.0,
    minVoiceWidth: 205.0,
    minVoiceHeight: 62.0,
    textColor: Colors.white,
    decorativeDescription: 'Shimmering golden star particles with gold corner ornaments',
  );

  /// Violet Cyber Bubble - ZP-149 (512x202, aspect ratio 2.5347)
  static const ChatBubbleSpec violetCyberStore = ChatBubbleSpec(
    id: 'bubble_zp149',
    name: 'Violet Cyber Bubble',
    assetPath: 'assets/store/ZP-149_chat-bubbles_bubble.webp',
    originalWidth: 512,
    originalHeight: 202,
    outgoingInsets: EdgeInsets.fromLTRB(24, 14, 24, 13),
    incomingInsets: EdgeInsets.fromLTRB(24, 14, 24, 13),
    minWidth: 135.0,
    minHeight: 52.0,
    minVoiceWidth: 205.0,
    minVoiceHeight: 62.0,
    textColor: Colors.white,
    decorativeDescription: 'Cyberpunk neon lines and angular beveled corners',
  );

  /// Amber Glow Bubble - ZP-150 (512x202, aspect ratio 2.5347)
  static const ChatBubbleSpec amberGlowStore = ChatBubbleSpec(
    id: 'bubble_zp150',
    name: 'Amber Glow Bubble',
    assetPath: 'assets/store/ZP-150_chat-bubbles_bubble.webp',
    originalWidth: 512,
    originalHeight: 202,
    outgoingInsets: EdgeInsets.fromLTRB(24, 14, 24, 13),
    incomingInsets: EdgeInsets.fromLTRB(24, 14, 24, 13),
    minWidth: 135.0,
    minHeight: 52.0,
    minVoiceWidth: 205.0,
    minVoiceHeight: 62.0,
    textColor: Colors.white,
    decorativeDescription: 'Warm radiant amber edges with illuminated corners',
  );

  /// Magic Neon Bubble - ZP-151 (512x202, aspect ratio 2.5347)
  static const ChatBubbleSpec magicNeonStore = ChatBubbleSpec(
    id: 'bubble_zp151',
    name: 'Magic Neon Bubble',
    assetPath: 'assets/store/ZP-151_chat-bubbles_bubble.webp',
    originalWidth: 512,
    originalHeight: 202,
    outgoingInsets: EdgeInsets.fromLTRB(25, 15, 25, 13),
    incomingInsets: EdgeInsets.fromLTRB(25, 15, 25, 13),
    minWidth: 135.0,
    minHeight: 52.0,
    minVoiceWidth: 205.0,
    minVoiceHeight: 62.0,
    textColor: Colors.white,
    decorativeDescription: 'Electric cyan and neon magenta glowing edges',
  );

  /// Crystal Wave Bubble - ZP-152 (512x202, aspect ratio 2.5347)
  static const ChatBubbleSpec crystalWaveStore = ChatBubbleSpec(
    id: 'bubble_zp152',
    name: 'Crystal Wave Bubble',
    assetPath: 'assets/store/ZP-152_chat-bubbles_bubble.webp',
    originalWidth: 512,
    originalHeight: 202,
    outgoingInsets: EdgeInsets.fromLTRB(24, 14, 24, 13),
    incomingInsets: EdgeInsets.fromLTRB(24, 14, 24, 13),
    minWidth: 135.0,
    minHeight: 52.0,
    minVoiceWidth: 205.0,
    minVoiceHeight: 62.0,
    textColor: Colors.white,
    decorativeDescription: 'Prismatic crystal refractions and aqua waves',
  );

  /// Emerald Shine Bubble - ZP-153 (512x202, aspect ratio 2.5347)
  static const ChatBubbleSpec emeraldShineStore = ChatBubbleSpec(
    id: 'bubble_zp153',
    name: 'Emerald Shine Bubble',
    assetPath: 'assets/store/ZP-153_chat-bubbles_bubble.webp',
    originalWidth: 512,
    originalHeight: 202,
    outgoingInsets: EdgeInsets.fromLTRB(25, 15, 25, 13),
    incomingInsets: EdgeInsets.fromLTRB(25, 15, 25, 13),
    minWidth: 135.0,
    minHeight: 52.0,
    minVoiceWidth: 205.0,
    minVoiceHeight: 62.0,
    textColor: Colors.white,
    decorativeDescription: 'Deep emerald facets with delicate golden framing',
  );

  /// Solar Flare Bubble - ZP-154 (512x202, aspect ratio 2.5347)
  static const ChatBubbleSpec solarFlareStore = ChatBubbleSpec(
    id: 'bubble_zp154',
    name: 'Solar Flare Bubble',
    assetPath: 'assets/store/ZP-154_chat-bubbles_bubble.webp',
    originalWidth: 512,
    originalHeight: 202,
    outgoingInsets: EdgeInsets.fromLTRB(26, 16, 26, 14),
    incomingInsets: EdgeInsets.fromLTRB(26, 16, 26, 14),
    minWidth: 135.0,
    minHeight: 52.0,
    minVoiceWidth: 205.0,
    minVoiceHeight: 62.0,
    textColor: Colors.white,
    decorativeDescription: 'Intense sunburst flare with fiery outer corona',
  );

  /// Ocean Blue Bubble - ZP-155 (512x202, aspect ratio 2.5347)
  static const ChatBubbleSpec oceanBlueStore = ChatBubbleSpec(
    id: 'bubble_zp155',
    name: 'Ocean Blue Bubble',
    assetPath: 'assets/store/ZP-155_chat-bubbles_bubble.webp',
    originalWidth: 512,
    originalHeight: 202,
    outgoingInsets: EdgeInsets.fromLTRB(25, 15, 25, 13),
    incomingInsets: EdgeInsets.fromLTRB(25, 15, 25, 13),
    minWidth: 135.0,
    minHeight: 52.0,
    minVoiceWidth: 205.0,
    minVoiceHeight: 62.0,
    textColor: Colors.white,
    decorativeDescription: 'Marine deep ocean gradient with oceanic wave borders',
  );

  /// Galaxy Dust Bubble - ZP-156 (512x202, aspect ratio 2.5347)
  static const ChatBubbleSpec galaxyDustStore = ChatBubbleSpec(
    id: 'bubble_zp156',
    name: 'Galaxy Dust Bubble',
    assetPath: 'assets/store/ZP-156_chat-bubbles_bubble.webp',
    originalWidth: 512,
    originalHeight: 202,
    outgoingInsets: EdgeInsets.fromLTRB(25, 15, 25, 13),
    incomingInsets: EdgeInsets.fromLTRB(25, 15, 25, 13),
    minWidth: 135.0,
    minHeight: 52.0,
    minVoiceWidth: 205.0,
    minVoiceHeight: 62.0,
    textColor: Colors.white,
    decorativeDescription: 'Nebula cosmic dust particles and galactic outer haze',
  );

  /// Pink Petal Bubble - ZP-157 (512x202, aspect ratio 2.5347)
  static const ChatBubbleSpec pinkPetalStore = ChatBubbleSpec(
    id: 'bubble_zp157',
    name: 'Pink Petal Bubble',
    assetPath: 'assets/store/ZP-157_chat-bubbles_bubble.webp',
    originalWidth: 512,
    originalHeight: 202,
    outgoingInsets: EdgeInsets.fromLTRB(24, 14, 24, 13),
    incomingInsets: EdgeInsets.fromLTRB(24, 14, 24, 13),
    minWidth: 135.0,
    minHeight: 52.0,
    minVoiceWidth: 205.0,
    minVoiceHeight: 62.0,
    textColor: Colors.white,
    decorativeDescription: 'Soft sakura petals and delicate pastel pink borders',
  );

  /// Dragon Shadow Bubble - ZP-158 (512x202, aspect ratio 2.5347)
  static const ChatBubbleSpec dragonShadowStore = ChatBubbleSpec(
    id: 'bubble_zp158',
    name: 'Dragon Shadow Bubble',
    assetPath: 'assets/store/ZP-158_chat-bubbles_bubble.webp',
    originalWidth: 512,
    originalHeight: 202,
    outgoingInsets: EdgeInsets.fromLTRB(25, 15, 25, 13),
    incomingInsets: EdgeInsets.fromLTRB(25, 15, 25, 13),
    minWidth: 135.0,
    minHeight: 52.0,
    minVoiceWidth: 205.0,
    minVoiceHeight: 62.0,
    textColor: Colors.white,
    decorativeDescription: 'Dark dragon scales and metallic shadow bevels',
  );

  // ───────────────────────────────────────────────────────────────────────────
  // 3. SVIP CHAT BUBBLES (SVIP 1 .. SVIP 16)
  // ───────────────────────────────────────────────────────────────────────────

  /// SVIP 10 Bubble (512x212, aspect ratio 2.4151)
  static const ChatBubbleSpec svip10Bubble = ChatBubbleSpec(
    id: 'svip_10',
    name: 'SVIP 10 Imperial Bubble',
    assetPath: 'assets/svip/svip10_chat_bubble.webp',
    originalWidth: 512,
    originalHeight: 212,
    outgoingInsets: EdgeInsets.fromLTRB(28, 18, 28, 16),
    incomingInsets: EdgeInsets.fromLTRB(28, 18, 28, 16),
    minWidth: 140.0,
    minHeight: 56.0,
    minVoiceWidth: 210.0,
    minVoiceHeight: 64.0,
    textColor: Colors.white,
    decorativeDescription: 'SVIP 10 imperial crown and royal filigree',
  );

  /// SVIP 5 Bubble (512x212, aspect ratio 2.4151)
  static const ChatBubbleSpec svip5Bubble = ChatBubbleSpec(
    id: 'svip_5',
    name: 'SVIP 5 Royal Bubble',
    assetPath: 'assets/svip/svip5_chat_bubble.webp',
    originalWidth: 512,
    originalHeight: 212,
    outgoingInsets: EdgeInsets.fromLTRB(26, 18, 28, 14),
    incomingInsets: EdgeInsets.fromLTRB(28, 18, 26, 14),
    minWidth: 140.0,
    minHeight: 56.0,
    minVoiceWidth: 210.0,
    minVoiceHeight: 64.0,
    textColor: Colors.white,
    decorativeDescription: 'SVIP 5 royal crest and blue side wings',
  );

  /// SVIP 6 Bubble (512x176, aspect ratio 2.9091)
  static const ChatBubbleSpec svip6Bubble = ChatBubbleSpec(
    id: 'svip_6',
    name: 'SVIP 6 Bubble',
    assetPath: 'assets/svip/svip6_chat_bubble.webp',
    originalWidth: 512,
    originalHeight: 176,
    outgoingInsets: EdgeInsets.fromLTRB(25, 15, 25, 13),
    incomingInsets: EdgeInsets.fromLTRB(25, 15, 25, 13),
    minWidth: 135.0,
    minHeight: 50.0,
    minVoiceWidth: 200.0,
    minVoiceHeight: 60.0,
    textColor: Colors.white,
    decorativeDescription: 'SVIP 6 silver bevels and illuminated corners',
  );

  /// SVIP 16 Bubble (512x171, aspect ratio 2.9942)
  static const ChatBubbleSpec svip16Bubble = ChatBubbleSpec(
    id: 'svip_16',
    name: 'SVIP 16 Pinnacle Bubble',
    assetPath: 'assets/svip/svip16_chat_bubble.webp',
    originalWidth: 512,
    originalHeight: 171,
    outgoingInsets: EdgeInsets.fromLTRB(26, 15, 26, 13),
    incomingInsets: EdgeInsets.fromLTRB(26, 15, 26, 13),
    minWidth: 135.0,
    minHeight: 52.0,
    minVoiceWidth: 205.0,
    minVoiceHeight: 62.0,
    textColor: Colors.white,
    decorativeDescription: 'SVIP 16 transcendent pinnacle ornamentation',
  );

  /// SVIP Generic / Level 1-4, 7-9, 11-15 Bubble (512x170, aspect ratio 3.0118)
  static const ChatBubbleSpec svipStandard = ChatBubbleSpec(
    id: 'svip_standard',
    name: 'SVIP Member Bubble',
    assetPath: 'assets/svip/svip1_chat_bubble.webp',
    originalWidth: 512,
    originalHeight: 170,
    outgoingInsets: EdgeInsets.fromLTRB(24, 14, 24, 12),
    incomingInsets: EdgeInsets.fromLTRB(24, 14, 24, 12),
    minWidth: 130.0,
    minHeight: 48.0,
    minVoiceWidth: 195.0,
    minVoiceHeight: 58.0,
    textColor: Colors.white,
    decorativeDescription: 'SVIP membership gold borders and corner jewels',
  );

  // ───────────────────────────────────────────────────────────────────────────
  // 4. ANIMATION / MYSTERY BUBBLE
  // ───────────────────────────────────────────────────────────────────────────

  static const ChatBubbleSpec mysteryBubble = ChatBubbleSpec(
    id: 'mystery',
    name: 'Mystery Bubble',
    assetPath: 'assets/animations/mystery_bubble.webp',
    originalWidth: 512,
    originalHeight: 212,
    outgoingInsets: EdgeInsets.fromLTRB(26, 16, 26, 14),
    incomingInsets: EdgeInsets.fromLTRB(26, 16, 26, 14),
    minWidth: 135.0,
    minHeight: 52.0,
    minVoiceWidth: 205.0,
    minVoiceHeight: 62.0,
    textColor: Colors.white,
    decorativeDescription: 'Animated mystic aura with glowing particle periphery',
  );

  // ───────────────────────────────────────────────────────────────────────────
  // 5. DEFAULT DYNAMIC FALLBACK
  // ───────────────────────────────────────────────────────────────────────────

  static const ChatBubbleSpec defaultSpec = ChatBubbleSpec(
    id: 'default_custom',
    name: 'Custom Bubble',
    assetPath: '',
    originalWidth: 512,
    originalHeight: 170,
    outgoingInsets: EdgeInsets.fromLTRB(24, 14, 24, 12),
    incomingInsets: EdgeInsets.fromLTRB(24, 14, 24, 12),
    minWidth: 130.0,
    minHeight: 48.0,
    minVoiceWidth: 195.0,
    minVoiceHeight: 58.0,
    textColor: Colors.white,
    decorativeDescription: 'Standard dynamic safe area container',
  );

  // ───────────────────────────────────────────────────────────────────────────
  // AUTHORITATIVE LOOKUP
  // ───────────────────────────────────────────────────────────────────────────

  /// Authoritative lookup method to get the individual safe area configuration
  /// for any equipped bubble URL or asset path.
  static ChatBubbleSpec getSpec(String? bubbleUrl) {
    if (bubbleUrl == null || bubbleUrl.isEmpty || bubbleUrl == 'none') {
      return defaultSpec;
    }

    final lower = bubbleUrl.toLowerCase().trim();

    // 1. Noble Tiers
    if (lower.contains('duke')) return dukeNoble;
    if (lower.contains('emperor') || lower.contains('imperial')) return emperorNoble;
    if (lower.contains('marquis')) return marquisNoble;
    if (lower.contains('count') || lower.contains('baron') || lower.contains('viscount') || lower.contains('earl')) {
      return countNoble;
    }

    // 2. Specific Store Bubbles (ZP-144 .. ZP-158)
    if (lower.contains('zp-146') || lower.contains('crimson')) return crimsonFlameStore;
    if (lower.contains('zp-144')) return goldenRoyalStore;
    if (lower.contains('zp-145')) return purpleLuxeStore;
    if (lower.contains('zp-147')) return royalBlueStore;
    if (lower.contains('zp-148')) return sparkleGoldStore;
    if (lower.contains('zp-149')) return violetCyberStore;
    if (lower.contains('zp-150')) return amberGlowStore;
    if (lower.contains('zp-151')) return magicNeonStore;
    if (lower.contains('zp-152')) return crystalWaveStore;
    if (lower.contains('zp-153')) return emeraldShineStore;
    if (lower.contains('zp-154')) return solarFlareStore;
    if (lower.contains('zp-155')) return oceanBlueStore;
    if (lower.contains('zp-156')) return galaxyDustStore;
    if (lower.contains('zp-157')) return pinkPetalStore;
    if (lower.contains('zp-158')) return dragonShadowStore;
    if (lower.contains('chat-bubbles') || lower.contains('store')) return crimsonFlameStore;

    // 3. SVIP levels
    if (lower.contains('svip10') || lower.contains('svip 10')) return svip10Bubble;
    if (lower.contains('svip5') || lower.contains('svip 5')) return svip5Bubble;
    if (lower.contains('svip4') || lower.contains('svip 4')) return marquisNoble;
    if (lower.contains('svip6') || lower.contains('svip 6')) return svip6Bubble;
    if (lower.contains('svip16') || lower.contains('svip 16')) return svip16Bubble;
    if (lower.contains('svip')) return svipStandard;

    // 4. Mystery bubble
    if (lower.contains('mystery')) return mysteryBubble;

    return defaultSpec;
  }
}
