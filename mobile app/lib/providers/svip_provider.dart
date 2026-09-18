import 'package:flutter/material.dart';
import '../models/svip_model.dart';
import 'wallet_provider.dart';

class SVIPProvider extends ChangeNotifier {
  int _currentPoints = 0;
  int _currentLevel = 0;
  int _selectedViewLevel = 1;
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));
  bool _isLoading = false;
  final List<SVIPAuditRecord> _auditHistory = [];

  int get currentPoints => _currentPoints;
  int get currentLevel => _currentLevel;
  int get selectedViewLevel => _selectedViewLevel;
  DateTime get expiryDate => _expiryDate;
  bool get isLoading => _isLoading;
  List<SVIPAuditRecord> get auditHistory => List.unmodifiable(_auditHistory);

  void setSelectedViewLevel(int level) {
    _selectedViewLevel = level;
    notifyListeners();
  }

  // Master 37 Privileges Catalog
  static const List<SVIPPrivilegeItem> privilegeCatalog = [
    SVIPPrivilegeItem(id: 'p_1', name: 'VIP Tag', icon: Icons.verified_rounded, description: 'Exclusive VIP name tag in rooms and profile', requiredLevel: 1),
    SVIPPrivilegeItem(id: 'p_2', name: 'Homepage Skin', icon: Icons.palette_rounded, description: 'Luxury customized profile background theme', requiredLevel: 1),
    SVIPPrivilegeItem(id: 'p_3', name: 'Chat Bubble', icon: Icons.chat_bubble_outline_rounded, description: 'Gold glowing chat bubble in all streams', requiredLevel: 1),
    SVIPPrivilegeItem(id: 'p_4', name: 'Profile Card', icon: Icons.badge_rounded, description: 'Special animated 3D profile pop-up card', requiredLevel: 2),
    SVIPPrivilegeItem(id: 'p_5', name: 'VIP Vehicle', icon: Icons.directions_car_filled_rounded, description: 'Luxury hypercar entrance ride-in animation', requiredLevel: 2),
    SVIPPrivilegeItem(id: 'p_6', name: 'Avatar Frame', icon: Icons.circle_outlined, description: 'Animated golden luxury avatar ring frame', requiredLevel: 2),
    SVIPPrivilegeItem(id: 'p_7', name: 'Visiting Traces', icon: Icons.visibility_rounded, description: 'Special footprint trail when visiting user profiles', requiredLevel: 3),
    SVIPPrivilegeItem(id: 'p_8', name: 'Exclusive Gifts', icon: Icons.card_giftcard_rounded, description: 'Unlock high-tier SVIP exclusive animated gifts', requiredLevel: 3),
    SVIPPrivilegeItem(id: 'p_9', name: 'Double Task Reward', icon: Icons.auto_awesome_rounded, description: '2x multiplier on all daily quest rewards', requiredLevel: 3),
    SVIPPrivilegeItem(id: 'p_10', name: 'VIP Seat', icon: Icons.chair_rounded, description: 'Priority reserved guest seat in room stages', requiredLevel: 4),
    SVIPPrivilegeItem(id: 'p_11', name: 'Exclusive Emoji', icon: Icons.emoji_emotions_rounded, description: 'Special 3D animated emoji collection', requiredLevel: 4),
    SVIPPrivilegeItem(id: 'p_12', name: 'Fly Comments', icon: Icons.air_rounded, description: 'Full-screen floating bullet comments across room', requiredLevel: 5),
    SVIPPrivilegeItem(id: 'p_13', name: 'Entrance Effect', icon: Icons.flash_on_rounded, description: 'World notification and grand entrance splash', requiredLevel: 6),
    SVIPPrivilegeItem(id: 'p_14', name: 'Upgraded Broadcast', icon: Icons.campaign_rounded, description: 'Bold color system broadcast message', requiredLevel: 7),
    SVIPPrivilegeItem(id: 'p_15', name: 'Mic Sound Wave', icon: Icons.graphic_eq_rounded, description: 'Dynamic glowing audio wave ring when speaking', requiredLevel: 8),
    SVIPPrivilegeItem(id: 'p_16', name: 'Room Theme', icon: Icons.dashboard_customize_rounded, description: 'Customizable party room luxury wallpapers', requiredLevel: 8),
    SVIPPrivilegeItem(id: 'p_17', name: 'Exclusive Customer', icon: Icons.support_agent_rounded, description: '24/7 dedicated 1-on-1 VIP VIP support manager', requiredLevel: 9),
    SVIPPrivilegeItem(id: 'p_18', name: 'Mysterious Visitor', icon: Icons.masks_rounded, description: 'Option to visit rooms without entrance announcement', requiredLevel: 9),
    SVIPPrivilegeItem(id: 'p_19', name: 'Online Hide', icon: Icons.person_off_rounded, description: 'Hide real-time online status and room presence', requiredLevel: 10),
    SVIPPrivilegeItem(id: 'p_20', name: 'Lucky Bag Limit', icon: Icons.shopping_bag_rounded, description: 'Send and claim increased lucky diamond bags', requiredLevel: 10),
    SVIPPrivilegeItem(id: 'p_21', name: 'Hide Gift Record', icon: Icons.lock_outline_rounded, description: 'Keep high-value gift transactions private', requiredLevel: 11),
    SVIPPrivilegeItem(id: 'p_22', name: 'Special ID', icon: Icons.tag_rounded, description: 'Custom short 4-digit or 5-digit premium ID', requiredLevel: 11),
    SVIPPrivilegeItem(id: 'p_23', name: 'Special Room ID', icon: Icons.meeting_room_rounded, description: 'Permanent custom vanity party room number', requiredLevel: 12),
    SVIPPrivilegeItem(id: 'p_24', name: 'Dynamic Avatar', icon: Icons.motion_photos_on_rounded, description: 'Animated MP4/GIF active avatar support', requiredLevel: 12),
    SVIPPrivilegeItem(id: 'p_25', name: 'Rank Invisible', icon: Icons.shield_rounded, description: 'Toggle leaderboard visibility on demand', requiredLevel: 13),
    SVIPPrivilegeItem(id: 'p_26', name: 'More Administrators', icon: Icons.supervisor_account_rounded, description: 'Add up to 20 room admins to your parties', requiredLevel: 13),
    SVIPPrivilegeItem(id: 'p_27', name: 'Prevent Being Muted', icon: Icons.mic_rounded, description: 'Immunity from room moderator mute actions', requiredLevel: 14),
    SVIPPrivilegeItem(id: 'p_28', name: 'Room Invisible', icon: Icons.hide_source_rounded, description: 'Create secret hidden rooms accessible by invite', requiredLevel: 14),
    SVIPPrivilegeItem(id: 'p_29', name: 'Avoid Being Kicked', icon: Icons.security_rounded, description: 'Complete immunity from room kick actions', requiredLevel: 15),
    SVIPPrivilegeItem(id: 'p_30', name: 'VIP Identity Hidden', icon: Icons.vpn_key_rounded, description: 'Full incognito disguise mode', requiredLevel: 15),
    SVIPPrivilegeItem(id: 'p_31', name: 'Unban Account', icon: Icons.lock_open_rounded, description: 'Direct emergency appeal priority pathway', requiredLevel: 15),
    SVIPPrivilegeItem(id: 'p_32', name: 'Open Screen', icon: Icons.screenshot_monitor_rounded, description: 'Display personal banner on app launch', requiredLevel: 16),
    SVIPPrivilegeItem(id: 'p_33', name: 'Customized Broadcasts', icon: Icons.volume_up_rounded, description: 'Global push alert customized banner', requiredLevel: 16),
    SVIPPrivilegeItem(id: 'p_34', name: 'Official Party', icon: Icons.celebration_rounded, description: 'Official ZeParty staff co-hosted party event', requiredLevel: 16),
    SVIPPrivilegeItem(id: 'p_35', name: 'Customized Frame', icon: Icons.crop_square_rounded, description: 'Designer hand-crafted exclusive avatar border', requiredLevel: 16),
    SVIPPrivilegeItem(id: 'p_36', name: 'Customized Banner', icon: Icons.flag_rounded, description: 'Official in-app marketing hero carousel slot', requiredLevel: 16),
    SVIPPrivilegeItem(id: 'p_37', name: 'Coming Soon', icon: Icons.stars_rounded, description: 'Next generation future SVIP privileges', requiredLevel: 16),
  ];

  // Reusable SVIP1 to SVIP16 Progression Tiers
  final List<SVIPLevel> _levels = [
    const SVIPLevel(level: 1, name: 'SVIP 1', requiredPoints: 100000, privilegeIds: ['p_1', 'p_2', 'p_3'], badgeText: 'SVIP 1', gradientColors: [Color(0xFF9E9E9E), Color(0xFF616161)]),
    const SVIPLevel(level: 2, name: 'SVIP 2', requiredPoints: 200000, privilegeIds: ['p_1', 'p_2', 'p_3', 'p_4', 'p_5', 'p_6'], badgeText: 'SVIP 2', gradientColors: [Color(0xFF8D6E63), Color(0xFF5D4037)]),
    const SVIPLevel(level: 3, name: 'SVIP 3', requiredPoints: 300000, privilegeIds: ['p_1', 'p_2', 'p_3', 'p_4', 'p_5', 'p_6', 'p_7', 'p_8', 'p_9'], badgeText: 'SVIP 3', gradientColors: [Color(0xFF42A5F5), Color(0xFF1976D2)]),
    const SVIPLevel(level: 4, name: 'SVIP 4', requiredPoints: 400000, privilegeIds: ['p_1', 'p_2', 'p_3', 'p_4', 'p_5', 'p_6', 'p_7', 'p_8', 'p_9', 'p_10', 'p_11'], badgeText: 'SVIP 4', gradientColors: [Color(0xFF26A69A), Color(0xFF00796B)]),
    const SVIPLevel(level: 5, name: 'SVIP 5', requiredPoints: 500000, privilegeIds: ['p_1', 'p_2', 'p_3', 'p_4', 'p_5', 'p_6', 'p_7', 'p_8', 'p_9', 'p_10', 'p_11', 'p_12'], badgeText: 'SVIP 5', gradientColors: [Color(0xFF66BB6A), Color(0xFF388E3C)]),
    const SVIPLevel(level: 6, name: 'SVIP 6', requiredPoints: 700000, privilegeIds: ['p_1', 'p_2', 'p_3', 'p_4', 'p_5', 'p_6', 'p_7', 'p_8', 'p_9', 'p_10', 'p_11', 'p_12', 'p_13'], badgeText: 'SVIP 6', gradientColors: [Color(0xFFAB47BC), Color(0xFF7B1FA2)]),
    const SVIPLevel(level: 7, name: 'SVIP 7', requiredPoints: 1500000, privilegeIds: ['p_1', 'p_2', 'p_3', 'p_4', 'p_5', 'p_6', 'p_7', 'p_8', 'p_9', 'p_10', 'p_11', 'p_12', 'p_13', 'p_14'], badgeText: 'SVIP 7', gradientColors: [Color(0xFFEC407A), Color(0xFFC2185B)]),
    const SVIPLevel(level: 8, name: 'SVIP 8', requiredPoints: 3000000, privilegeIds: ['p_1', 'p_2', 'p_3', 'p_4', 'p_5', 'p_6', 'p_7', 'p_8', 'p_9', 'p_10', 'p_11', 'p_12', 'p_13', 'p_14', 'p_15', 'p_16'], badgeText: 'SVIP 8', gradientColors: [Color(0xFFFFA726), Color(0xFFF57C00)]),
    const SVIPLevel(level: 9, name: 'SVIP 9', requiredPoints: 5000000, privilegeIds: ['p_1', 'p_2', 'p_3', 'p_4', 'p_5', 'p_6', 'p_7', 'p_8', 'p_9', 'p_10', 'p_11', 'p_12', 'p_13', 'p_14', 'p_15', 'p_16', 'p_17', 'p_18'], badgeText: 'SVIP 9', gradientColors: [Color(0xFFFF7043), Color(0xFFD84315)]),
    const SVIPLevel(level: 10, name: 'SVIP 10', requiredPoints: 7000000, privilegeIds: ['p_1', 'p_2', 'p_3', 'p_4', 'p_5', 'p_6', 'p_7', 'p_8', 'p_9', 'p_10', 'p_11', 'p_12', 'p_13', 'p_14', 'p_15', 'p_16', 'p_17', 'p_18', 'p_19', 'p_20'], badgeText: 'SVIP 10', gradientColors: [Color(0xFFE91E63), Color(0xFF880E4F)]),
    const SVIPLevel(level: 11, name: 'SVIP 11', requiredPoints: 12000000, privilegeIds: ['p_1', 'p_2', 'p_3', 'p_4', 'p_5', 'p_6', 'p_7', 'p_8', 'p_9', 'p_10', 'p_11', 'p_12', 'p_13', 'p_14', 'p_15', 'p_16', 'p_17', 'p_18', 'p_19', 'p_20', 'p_21', 'p_22'], badgeText: 'SVIP 11', gradientColors: [Color(0xFFFFB300), Color(0xFFFF6F00)]),
    const SVIPLevel(level: 12, name: 'SVIP 12', requiredPoints: 20000000, privilegeIds: ['p_1', 'p_2', 'p_3', 'p_4', 'p_5', 'p_6', 'p_7', 'p_8', 'p_9', 'p_10', 'p_11', 'p_12', 'p_13', 'p_14', 'p_15', 'p_16', 'p_17', 'p_18', 'p_19', 'p_20', 'p_21', 'p_22', 'p_23', 'p_24'], badgeText: 'SVIP 12', gradientColors: [Color(0xFF7E57C2), Color(0xFF4527A0)]),
    const SVIPLevel(level: 13, name: 'SVIP 13', requiredPoints: 30000000, privilegeIds: ['p_1', 'p_2', 'p_3', 'p_4', 'p_5', 'p_6', 'p_7', 'p_8', 'p_9', 'p_10', 'p_11', 'p_12', 'p_13', 'p_14', 'p_15', 'p_16', 'p_17', 'p_18', 'p_19', 'p_20', 'p_21', 'p_22', 'p_23', 'p_24', 'p_25', 'p_26'], badgeText: 'SVIP 13', gradientColors: [Color(0xFF5C6BC0), Color(0xFF283593)]),
    const SVIPLevel(level: 14, name: 'SVIP 14', requiredPoints: 50000000, privilegeIds: ['p_1', 'p_2', 'p_3', 'p_4', 'p_5', 'p_6', 'p_7', 'p_8', 'p_9', 'p_10', 'p_11', 'p_12', 'p_13', 'p_14', 'p_15', 'p_16', 'p_17', 'p_18', 'p_19', 'p_20', 'p_21', 'p_22', 'p_23', 'p_24', 'p_25', 'p_26', 'p_27', 'p_28'], badgeText: 'SVIP 14', gradientColors: [Color(0xFF26C6DA), Color(0xFF00838F)]),
    const SVIPLevel(level: 15, name: 'SVIP 15', requiredPoints: 100000000, privilegeIds: ['p_1', 'p_2', 'p_3', 'p_4', 'p_5', 'p_6', 'p_7', 'p_8', 'p_9', 'p_10', 'p_11', 'p_12', 'p_13', 'p_14', 'p_15', 'p_16', 'p_17', 'p_18', 'p_19', 'p_20', 'p_21', 'p_22', 'p_23', 'p_24', 'p_25', 'p_26', 'p_27', 'p_28', 'p_29', 'p_30', 'p_31'], badgeText: 'SVIP 15', gradientColors: [Color(0xFFD4AF37), Color(0xFF8C601C)]),
    const SVIPLevel(level: 16, name: 'SVIP 16', requiredPoints: 150000000, privilegeIds: ['p_1', 'p_2', 'p_3', 'p_4', 'p_5', 'p_6', 'p_7', 'p_8', 'p_9', 'p_10', 'p_11', 'p_12', 'p_13', 'p_14', 'p_15', 'p_16', 'p_17', 'p_18', 'p_19', 'p_20', 'p_21', 'p_22', 'p_23', 'p_24', 'p_25', 'p_26', 'p_27', 'p_28', 'p_29', 'p_30', 'p_31', 'p_32', 'p_33', 'p_34', 'p_35', 'p_36', 'p_37'], badgeText: 'SVIP 16', gradientColors: [Color(0xFFFFD700), Color(0xFFE65100)]),
  ];

  final List<SVIPPackage> _storePackages = [
    const SVIPPackage(id: 'pkg_1', name: '10,000 Points', points: 10000, priceCoins: 10000),
    const SVIPPackage(id: 'pkg_2', name: '50,000 Points', points: 50000, priceCoins: 50000, bonusPoints: 5000),
    const SVIPPackage(id: 'pkg_3', name: '100,000 Points', points: 100000, priceCoins: 100000, bonusPoints: 15000),
    const SVIPPackage(id: 'pkg_4', name: '500,000 Points', points: 500000, priceCoins: 500000, bonusPoints: 100000),
  ];

  List<SVIPLevel> get levels => List.unmodifiable(_levels);
  List<SVIPPackage> get storePackages => List.unmodifiable(_storePackages);

  SVIPLevel get currentSVIPLevelData => _levels.firstWhere(
    (l) => l.level == _currentLevel, 
    orElse: () => _levels.first
  );

  SVIPLevel get selectedSVIPLevelData => _levels.firstWhere(
    (l) => l.level == _selectedViewLevel, 
    orElse: () => currentSVIPLevelData
  );

  SVIPLevel? get nextSVIPLevelData {
    final nextLevels = _levels.where((l) => l.level > _currentLevel).toList();
    if (nextLevels.isEmpty) return null;
    nextLevels.sort((a, b) => a.level.compareTo(b.level));
    return nextLevels.first;
  }

  int get unlockedPrivilegesCount {
    return selectedSVIPLevelData.privilegeIds.length;
  }

  int get totalPrivilegesCount => privilegeCatalog.length;

  bool isPrivilegeUnlocked(String privilegeId, [int? targetLevel]) {
    final lvl = targetLevel ?? _selectedViewLevel;
    final levelData = _levels.firstWhere((l) => l.level == lvl, orElse: () => _levels.first);
    return levelData.privilegeIds.contains(privilegeId);
  }

  Future<void> fetchSVIPData() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> purchasePoints(SVIPPackage package, WalletProvider wallet) async {
    // Direct SVIP points purchase via wallet coins is blocked until backend exposes dedicated VIP package purchase API.
    // Points are authoritatively accumulated on backend via cumulative recharge and live room gifting.
    if (wallet.coins < package.priceCoins) {
      return false;
    }
    // Reconcile wallet
    await wallet.fetchWallet();
    return false;
  }

  void _checkAutoUpgrade() {
    for (final lvl in _levels.reversed) {
      if (_currentPoints >= lvl.requiredPoints) {
        if (_currentLevel < lvl.level) {
          _currentLevel = lvl.level;
          _selectedViewLevel = lvl.level;
          _auditHistory.insert(0, SVIPAuditRecord(
            id: 'aud_${DateTime.now().millisecondsSinceEpoch}',
            type: 'upgrade',
            points: _currentPoints,
            level: _currentLevel,
            timestamp: DateTime.now(),
            note: 'Auto upgraded to SVIP $_currentLevel',
          ));
        }
        break;
      }
    }
  }

  Future<bool> upgradeLevel() async {
    final next = nextSVIPLevelData;
    if (next != null && _currentPoints >= next.requiredPoints) {
      _currentLevel = next.level;
      _selectedViewLevel = next.level;
      notifyListeners();
      return true;
    }
    return false;
  }

  // BD Operator Manual Grant / Revoke
  void manualGrantLevel({
    required int targetLevel,
    required String reason,
    required String operatorId,
    DateTime? customExpiry,
  }) {
    final clampedLevel = targetLevel.clamp(1, 16);
    _currentLevel = clampedLevel;
    _selectedViewLevel = clampedLevel;
    if (customExpiry != null) _expiryDate = customExpiry;
    _auditHistory.insert(0, SVIPAuditRecord(
      id: 'aud_${DateTime.now().millisecondsSinceEpoch}',
      type: 'manual_grant',
      points: _currentPoints,
      level: _currentLevel,
      timestamp: DateTime.now(),
      note: reason,
      operatorId: operatorId,
    ));
    notifyListeners();
  }

  void manualRevokeLevel({
    required String reason,
    required String operatorId,
  }) {
    _currentLevel = 0;
    _selectedViewLevel = 1;
    _auditHistory.insert(0, SVIPAuditRecord(
      id: 'aud_${DateTime.now().millisecondsSinceEpoch}',
      type: 'revoke',
      points: _currentPoints,
      level: 0,
      timestamp: DateTime.now(),
      note: reason,
      operatorId: operatorId,
    ));
    notifyListeners();
  }
}
