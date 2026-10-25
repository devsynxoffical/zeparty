import 'package:flutter/painting.dart';

enum GameKind { turnBased, physicsShot, physicsRealtime }

enum GameAvailability { available, comingSoon }

/// Static description of a game as shown in the Game Center. Server config
/// (enabled, featured, player limits) is merged in by the catalog repository.
class GameCatalogEntry {
  const GameCatalogEntry({
    required this.gameId,
    required this.title,
    required this.tagline,
    required this.description,
    required this.theme,
    required this.minPlayers,
    required this.maxPlayers,
    required this.kind,
    required this.availability,
    required this.artwork,
    required this.accent,
    this.featured = false,
    this.onlineRooms = 0,
    this.turnTimeoutSeconds,
    this.rewards = const {},
    this.rules = const {},
  });

  final String gameId;
  final String title;
  final String tagline;
  final String description;
  final String theme;
  final int minPlayers;
  final int maxPlayers;
  final GameKind kind;
  final GameAvailability availability;

  /// Asset path relative to the shared assets root, e.g. games/ludo_royale/ui/card_art.webp
  final String artwork;
  final Color accent;
  final bool featured;
  final int onlineRooms;
  final int? turnTimeoutSeconds;
  final Map<String, int> rewards;
  final Map<String, dynamic> rules;

  bool get isAvailable => availability == GameAvailability.available;

  factory GameCatalogEntry.fromJson(Map<String, dynamic> j) => GameCatalogEntry(
        gameId: j['gameId'] as String,
        title: j['title'] as String,
        tagline: j['tagline'] as String,
        description: j['description'] as String,
        theme: j['theme'] as String,
        minPlayers: j['minPlayers'] as int,
        maxPlayers: j['maxPlayers'] as int,
        kind: switch (j['kind'] as String) {
          'physics_shot' => GameKind.physicsShot,
          'physics_realtime' => GameKind.physicsRealtime,
          _ => GameKind.turnBased,
        },
        availability: j['status'] == 'available' ? GameAvailability.available : GameAvailability.comingSoon,
        artwork: j['artwork'] as String,
        accent: _hex(j['accent'] as String),
        featured: j['featured'] as bool? ?? false,
        onlineRooms: j['onlineRooms'] as int? ?? 0,
        turnTimeoutSeconds: j['turnTimeoutSeconds'] as int?,
        rewards: ((j['rewards'] as Map<String, dynamic>?) ?? const {}).map((k, v) => MapEntry(k, (v as num).toInt())),
        rules: (j['rules'] as Map<String, dynamic>?) ?? const {},
      );

  static Color _hex(String h) {
    final v = int.parse(h.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | v);
  }
}

/// Built-in catalog used when the backend is unreachable. Mirrors backend/src/games/registry.ts.
const List<GameCatalogEntry> kBuiltInCatalog = [
  GameCatalogEntry(
    gameId: 'ludo_royale',
    title: 'Ludo Royale',
    tagline: 'Imperial palace, crystal dice',
    description: 'The classic race in a marble and gold royal chamber. Roll a six to leave the palace gates, capture rivals, race all four tokens home.',
    theme: 'Imperial Palace',
    minPlayers: 2,
    maxPlayers: 4,
    kind: GameKind.turnBased,
    availability: GameAvailability.available,
    artwork: 'games/ludo_royale/ui/card_art.webp',
    accent: Color(0xFFC9A227),
    featured: true,
  ),
  GameCatalogEntry(gameId: 'connect4_galaxy', title: 'Connect 4 Galaxy', tagline: 'Four in a row among the stars', description: 'Drop glowing energy discs into a crystal grid floating in deep space.', theme: 'Galactic Strategy Chamber', minPlayers: 2, maxPlayers: 2, kind: GameKind.turnBased, availability: GameAvailability.available, artwork: 'games/connect4_galaxy/ui/card_art.webp', accent: Color(0xFF5B7CFF)),
  GameCatalogEntry(gameId: 'snake_ladder_kingdom', title: 'Snake & Ladder Kingdom', tagline: 'Climb the floating isles', description: 'A miniature fantasy kingdom where ladders are golden and snakes are friendly dragons.', theme: 'Fantasy Kingdom', minPlayers: 2, maxPlayers: 4, kind: GameKind.turnBased, availability: GameAvailability.available, artwork: 'games/snake_ladder_kingdom/ui/card_art.webp', accent: Color(0xFF3DBE7A)),
  GameCatalogEntry(gameId: 'chess_legends', title: 'Chess Legends', tagline: 'Obsidian and crystal', description: 'Full chess with time controls in the Grandmaster Hall.', theme: 'Royal Grandmaster Hall', minPlayers: 2, maxPlayers: 2, kind: GameKind.turnBased, availability: GameAvailability.available, artwork: 'games/chess_legends/ui/card_art.webp', accent: Color(0xFFB8C4D6)),
  GameCatalogEntry(gameId: 'color_clash', title: 'Color Clash', tagline: 'Holographic card arena', description: 'An original colour and number matching card game with ZeParty action cards.', theme: 'Holographic Card Arena', minPlayers: 2, maxPlayers: 6, kind: GameKind.turnBased, availability: GameAvailability.available, artwork: 'games/color_clash/ui/card_art.webp', accent: Color(0xFFFF4FA3)),
  GameCatalogEntry(gameId: 'carrom_masters', title: 'Carrom Masters', tagline: 'Luxury heritage club', description: 'Photoreal walnut board, precise striker physics.', theme: 'Luxury Heritage Club', minPlayers: 2, maxPlayers: 4, kind: GameKind.physicsShot, availability: GameAvailability.available, artwork: 'games/carrom_masters/ui/card_art.webp', accent: Color(0xFFA86B3C)),
  GameCatalogEntry(gameId: 'pool_elite', title: '8 Ball Pool Elite', tagline: 'Private billiards lounge', description: 'Cinematic 8-ball with authoritative shot resolution.', theme: 'Private Luxury Billiards Lounge', minPlayers: 2, maxPlayers: 2, kind: GameKind.physicsShot, availability: GameAvailability.available, artwork: 'games/pool_elite/ui/card_art.webp', accent: Color(0xFF1F7A4D)),
  GameCatalogEntry(gameId: 'air_hockey', title: 'Neon Air Hockey', tagline: 'Futuristic arena', description: 'Real-time neon air hockey with latency-aware sync.', theme: 'Futuristic Competitive Arena', minPlayers: 2, maxPlayers: 2, kind: GameKind.physicsRealtime, availability: GameAvailability.available, artwork: 'games/air_hockey/ui/card_art.webp', accent: Color(0xFF19E6FF)),
  GameCatalogEntry(gameId: 'darts_arena', title: 'Darts Arena', tagline: 'Premium sports lounge', description: 'Authentic dartboard, skill-based throws.', theme: 'Premium Competitive Sports Lounge', minPlayers: 2, maxPlayers: 4, kind: GameKind.physicsShot, availability: GameAvailability.available, artwork: 'games/darts_arena/ui/card_art.webp', accent: Color(0xFFD9452B)),
  GameCatalogEntry(gameId: 'mini_golf_paradise', title: 'Mini Golf Paradise', tagline: 'Fantasy tropical resort', description: 'Five island courses with moving obstacles and waterfalls.', theme: 'Fantasy Tropical Resort', minPlayers: 2, maxPlayers: 4, kind: GameKind.physicsShot, availability: GameAvailability.available, artwork: 'games/mini_golf_paradise/ui/card_art.webp', accent: Color(0xFF2BC0B4)),
];
