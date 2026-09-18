import 'package:flutter/material.dart';
import '../models/noble_model.dart';
import 'wallet_provider.dart';

class NobleProvider extends ChangeNotifier {
  String? _activeRankId;
  int _eligibleSentCoins = 0;
  DateTime? _expiryDate;
  bool _isLoading = false;
  final List<NobleAuditRecord> _auditHistory = [];

  String? get activeRankId => _activeRankId;
  int get eligibleSentCoins => _eligibleSentCoins;
  DateTime? get expiryDate => _expiryDate;
  bool get isLoading => _isLoading;
  List<NobleAuditRecord> get auditHistory => List.unmodifiable(_auditHistory);

  static const List<NoblePrivilege> _basePrivileges = [
    NoblePrivilege(id: 'np_entry', name: 'Entrance Effect', icon: Icons.flash_on_rounded, description: 'Grand entry wave and broadcast', category: 'display'),
    NoblePrivilege(id: 'np_card', name: 'Profile Card', icon: Icons.badge_rounded, description: 'Exclusive animated VIP profile card', category: 'display'),
    NoblePrivilege(id: 'np_frame', name: 'Frame', icon: Icons.circle_outlined, description: 'Noble crown luxury avatar border', category: 'display'),
    NoblePrivilege(id: 'np_act', name: 'Activate Effect', icon: Icons.auto_awesome_rounded, description: 'Full room activation splash banner', category: 'display'),
    NoblePrivilege(id: 'np_badge', name: 'Identity Badge', icon: Icons.verified_user_rounded, description: 'Distinctive noble title badge', category: 'display'),
    NoblePrivilege(id: 'np_color_name', name: 'Colored Username', icon: Icons.format_paint_rounded, description: 'Glowing golden and gradient username', category: 'display'),
    NoblePrivilege(id: 'np_bubble', name: 'Bubble', icon: Icons.chat_bubble_outline_rounded, description: 'Glowing royal chat bubble', category: 'display'),
    NoblePrivilege(id: 'np_world_notif', name: 'World Notification', icon: Icons.campaign_rounded, description: 'Global app-wide announcement banner', category: 'display'),
  ];

  static const List<NoblePrivilege> _micPrivileges = [
    NoblePrivilege(id: 'np_mic_wave', name: 'Mic Wave', icon: Icons.graphic_eq_rounded, description: 'Dynamic glowing audio wave on mic', category: 'mic'),
    NoblePrivilege(id: 'np_mic_effect', name: 'Mic Effect', icon: Icons.spatial_audio_rounded, description: '3D luxury microphone spotlight halo', category: 'mic'),
  ];

  static const List<NoblePrivilege> _functionalPrivileges = [
    NoblePrivilege(id: 'np_seat', name: 'Privilege Seat', icon: Icons.chair_rounded, description: 'Reserved premium seat on party stage', category: 'functional'),
    NoblePrivilege(id: 'np_return', name: 'Coins Return', icon: Icons.currency_exchange_rounded, description: 'Direct coin rebate on activation', category: 'functional'),
    NoblePrivilege(id: 'np_gift', name: 'Exclusive Gift', icon: Icons.card_giftcard_rounded, description: 'Access to royal noble gifts', category: 'functional'),
    NoblePrivilege(id: 'np_speed', name: 'High-Speed Upgrade', icon: Icons.speed_rounded, description: '2x faster level progression XP', category: 'functional'),
    NoblePrivilege(id: 'np_fly_comment', name: 'Fly Comment', icon: Icons.air_rounded, description: 'Royal flying comments across rooms', category: 'functional'),
    NoblePrivilege(id: 'np_emoji', name: 'Exclusive Emoji', icon: Icons.emoji_events_rounded, description: 'Aristocracy exclusive sticker pack', category: 'functional'),
    NoblePrivilege(id: 'np_send_pic', name: 'Send Picture', icon: Icons.image_rounded, description: 'Send direct pictures in room chat', category: 'functional'),
    NoblePrivilege(id: 'np_lucky_bag', name: 'Lucky Bag Limit', icon: Icons.shopping_bag_rounded, description: 'Higher limits on sending lucky bags', category: 'functional'),
    NoblePrivilege(id: 'np_anti_disturb', name: 'Anti-Disturb', icon: Icons.do_not_disturb_on_rounded, description: 'Block unauthorized private messages', category: 'functional'),
    NoblePrivilege(id: 'np_custom_title', name: 'Customized Title', icon: Icons.edit_note_rounded, description: 'Create personal room honorific title', category: 'functional'),
    NoblePrivilege(id: 'np_home_bg', name: 'Homepage Background', icon: Icons.wallpaper_rounded, description: 'Exclusive aristocracy profile skin', category: 'functional'),
    NoblePrivilege(id: 'np_anti_follow', name: 'Anti-Follow', icon: Icons.person_off_rounded, description: 'Prevent users from force-following stream', category: 'functional'),
    NoblePrivilege(id: 'np_shake', name: 'Shake', icon: Icons.vibration_rounded, description: 'Trigger full-room screen vibration effect', category: 'functional'),
  ];

  final List<NobleRank> _ranks = [
    // 1. Baron (100k sent coins)
    NobleRank(
      id: 'baron',
      name: 'Baron',
      requiredSentCoins: 100000,
      firstMonthCost: 50000,
      returnPercentage: 30,
      durationDays: 30,
      colors: const [Color(0xFF78909C), Color(0xFF37474F)],
      badgeAsset: 'assets/images/rank_baron.png',
      privileges: [
        ..._basePrivileges.take(6),
        _functionalPrivileges[0], // Privilege seat
        _functionalPrivileges[1], // Coins return
      ],
    ),
    // 2. Viscount (150k sent coins)
    NobleRank(
      id: 'viscount',
      name: 'Viscount',
      requiredSentCoins: 150000,
      firstMonthCost: 100000,
      returnPercentage: 10,
      durationDays: 30,
      colors: const [Color(0xFFFB8C00), Color(0xFFE65100)],
      badgeAsset: 'assets/images/rank_viscount.png',
      privileges: [
        ..._basePrivileges.take(6),
        _functionalPrivileges[0],
        _functionalPrivileges[1],
        _functionalPrivileges[2], // Exclusive gift
      ],
    ),
    // 3. Count (250k sent coins)
    NobleRank(
      id: 'count',
      name: 'Count',
      requiredSentCoins: 250000,
      firstMonthCost: 200000,
      returnPercentage: 50,
      durationDays: 30,
      colors: const [Color(0xFF1E88E5), Color(0xFF0D47A1)],
      badgeAsset: 'assets/images/rank_count.png',
      privileges: [
        ..._basePrivileges.take(7), // Adds Bubble
        ..._functionalPrivileges.take(6), // Seat, Return, Gift, Speed, Fly, Emoji
      ],
    ),
    // 4. Marquis (500k sent coins)
    NobleRank(
      id: 'marquis',
      name: 'Marquis',
      requiredSentCoins: 500000,
      firstMonthCost: 500000,
      returnPercentage: 60,
      durationDays: 30,
      colors: const [Color(0xFFC2185B), Color(0xFF880E4F)],
      badgeAsset: 'assets/images/rank_marquis.png',
      privileges: [
        ..._basePrivileges, // All display perks including World Notif
        ..._functionalPrivileges.take(7), // Adds Send Picture
      ],
    ),
    // 5. Duke (1,000,000 sent coins)
    NobleRank(
      id: 'duke',
      name: 'Duke',
      requiredSentCoins: 1000000,
      firstMonthCost: 800000,
      returnPercentage: 80, // 640k return
      durationDays: 30,
      colors: const [Color(0xFF8E24AA), Color(0xFF4A148C)],
      badgeAsset: 'assets/images/rank_duke.png',
      privileges: [
        ..._basePrivileges,
        ..._micPrivileges, // Adds Mic Wave, Mic Effect
        ..._functionalPrivileges.take(8), // Adds Lucky Bag Limit
      ],
    ),
    // 6. King (2,000,000 sent coins)
    NobleRank(
      id: 'king',
      name: 'King',
      requiredSentCoins: 2000000,
      firstMonthCost: 1500000,
      returnPercentage: 80, // 1.2M return
      durationDays: 30,
      colors: const [Color(0xFFD4AF37), Color(0xFF5D4037)],
      badgeAsset: 'assets/images/rank_king.png',
      privileges: [
        ..._basePrivileges,
        ..._micPrivileges,
        ..._functionalPrivileges.take(11), // Adds Anti-Disturb, Custom Title, Home BG
      ],
    ),
    // 7. Emperor (5,000,000 sent coins)
    NobleRank(
      id: 'emperor',
      name: 'Emperor',
      requiredSentCoins: 5000000,
      firstMonthCost: 3000000,
      returnPercentage: 80, // 2.4M return
      durationDays: 30,
      colors: const [Color(0xFFFFD700), Color(0xFFBF360C)],
      badgeAsset: 'assets/images/rank_emperor.png',
      privileges: [
        ..._basePrivileges,
        ..._micPrivileges,
        ..._functionalPrivileges, // All perks including Anti-Follow and Shake
      ],
    ),
    // 8. Sovereign (Future Level Extension)
    NobleRank(
      id: 'sovereign',
      name: 'Sovereign',
      requiredSentCoins: 10000000,
      firstMonthCost: 5000000,
      returnPercentage: 80,
      durationDays: 30,
      colors: const [Color(0xFFFF6F00), Color(0xFF3E2723)],
      badgeAsset: 'assets/images/rank_sovereign.png',
      privileges: [
        ..._basePrivileges,
        ..._micPrivileges,
        ..._functionalPrivileges,
      ],
    ),
  ];

  List<NobleRank> get ranks => List.unmodifiable(_ranks);

  NobleRank? get currentActiveRank {
    if (_activeRankId == null) return null;
    return _ranks.firstWhere((r) => r.id == _activeRankId, orElse: () => _ranks.first);
  }

  Future<void> fetchNobleData() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> activateRank(NobleRank rank, WalletProvider wallet) async {
    // Direct Noble rank purchase via wallet coins is blocked until backend exposes dedicated noble activation API.
    // Aristocracy/Noble rank is authoritatively assigned by backend policies / BD management.
    if (wallet.coins < rank.firstMonthCost) {
      return false;
    }
    await wallet.fetchWallet();
    return false;
  }

  // BD Operator manual noble controls
  void manualGrantNoble({
    required String rankId,
    required String reason,
    required String operatorId,
    DateTime? customExpiry,
  }) {
    _activeRankId = rankId;
    _expiryDate = customExpiry ?? DateTime.now().add(const Duration(days: 30));
    _auditHistory.insert(0, NobleAuditRecord(
      id: 'aud_${DateTime.now().millisecondsSinceEpoch}',
      rankId: rankId,
      type: 'manual_grant',
      timestamp: DateTime.now(),
      note: reason,
      operatorId: operatorId,
    ));
    notifyListeners();
  }

  void manualRevokeNoble({
    required String reason,
    required String operatorId,
  }) {
    final prevRank = _activeRankId ?? 'none';
    _activeRankId = null;
    _expiryDate = null;
    _auditHistory.insert(0, NobleAuditRecord(
      id: 'aud_${DateTime.now().millisecondsSinceEpoch}',
      rankId: prevRank,
      type: 'revoke',
      timestamp: DateTime.now(),
      note: reason,
      operatorId: operatorId,
    ));
    notifyListeners();
  }

  void recordEligibleCoins(int coins) {
    if (coins <= 0) return;
    _eligibleSentCoins += coins;
    notifyListeners();
  }
}
