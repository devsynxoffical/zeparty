import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_session_model.dart';
import '../core/repositories/backend_repository.dart';
import 'wallet_provider.dart';

class GameProvider extends ChangeNotifier {
  bool _isPlaying = false;
  int _lastResultMultiplier = 1;
  int _lastWinnings = 0;
  String _gameMessage = 'Place your coin bet to start playing!';
  Timer? _gameTimer;

  final List<GameSessionModel> _sessionsHistory = [];
  GameSessionModel? _activeSession;

  int _dailyStreak = 1;
  bool _dailyRewardClaimed = false;
  final int _dailyRewardCoins = 250;

  // Rocket Game Level Target Configuration (Default: 100K, 300K, 400K, 500K, 1M)
  static const List<int> defaultRocketTargets = [100000, 300000, 400000, 500000, 1000000];
  List<int> _rocketLevelTargets = List.from(defaultRocketTargets);
  List<Map<String, dynamic>> _rocketAdminLogs = [];
  int _configVersion = 1;
  final Set<String> _distributedRewardKeys = {};

  // Module 02: Paid Room Theme & Room DP Upload Configuration
  bool _paidRoomThemeUploadsEnabled = true;
  int _customRoomThemeUploadPrice = 100000;
  Map<String, int> _countryRoomThemeUploadPrices = {
    'Pakistan': 100000,
    'Global': 100000,
  };
  List<Map<String, dynamic>> _roomThemeUploadTransactions = [];
  List<Map<String, dynamic>> _roomThemePriceAdminLogs = [];

  bool get isPlaying => _isPlaying;
  int get lastResultMultiplier => _lastResultMultiplier;
  int get lastWinnings => _lastWinnings;
  String get gameMessage => _gameMessage;
  List<GameSessionModel> get sessionsHistory => List.unmodifiable(_sessionsHistory);
  GameSessionModel? get activeSession => _activeSession;
  int get dailyStreak => _dailyStreak;
  bool get dailyRewardClaimed => _dailyRewardClaimed;
  int get dailyRewardCoins => _dailyRewardCoins;
  List<int> get rocketLevelTargets => List.unmodifiable(_rocketLevelTargets);
  List<Map<String, dynamic>> get rocketAdminLogs => List.unmodifiable(_rocketAdminLogs);
  int get configVersion => _configVersion;

  bool get paidRoomThemeUploadsEnabled => _paidRoomThemeUploadsEnabled;
  int get customRoomThemeUploadPrice => _customRoomThemeUploadPrice;
  Map<String, int> get countryRoomThemeUploadPrices => Map.unmodifiable(_countryRoomThemeUploadPrices);
  List<Map<String, dynamic>> get roomThemeUploadTransactions => List.unmodifiable(_roomThemeUploadTransactions);
  List<Map<String, dynamic>> get roomThemePriceAdminLogs => List.unmodifiable(_roomThemePriceAdminLogs);

  // ── Module 03: Mic Seat Size & Room Entry Announcements ──
  String _roomMicSizePreset = 'Large';
  String get roomMicSizePreset => _roomMicSizePreset;

  Map<String, Map<String, dynamic>> _roomAnnouncements = {};
  Map<String, dynamic> _globalMandatoryAnnouncement = {};
  Map<String, Map<String, dynamic>> _countryMandatoryAnnouncements = {};
  List<Map<String, dynamic>> _announcementHistoryLogs = [];
  List<Map<String, dynamic>> _announcementAdminLogs = [];

  Map<String, Map<String, dynamic>> get roomAnnouncements => Map.unmodifiable(_roomAnnouncements);
  Map<String, dynamic> get globalMandatoryAnnouncement => Map.unmodifiable(_globalMandatoryAnnouncement);
  Map<String, Map<String, dynamic>> get countryMandatoryAnnouncements => Map.unmodifiable(_countryMandatoryAnnouncements);
  List<Map<String, dynamic>> get announcementHistoryLogs => List.unmodifiable(_announcementHistoryLogs);
  List<Map<String, dynamic>> get announcementAdminLogs => List.unmodifiable(_announcementAdminLogs);

  // ── Module 04: Room Card Display & Room DP Moderation Fallbacks ──
  String _roomCardDisplayMode = 'Full Room DP';
  String _globalDefaultRoomDp = 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500';
  final Map<String, String> _countryDefaultRoomDps = {'Pakistan': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500'};
  Map<String, String> _moderatedRoomDps = {}; // roomId -> status ('approved', 'rejected', 'removed')
  List<Map<String, dynamic>> _roomDpModerationLogs = [];

  String get roomCardDisplayMode => _roomCardDisplayMode;
  String get globalDefaultRoomDp => _globalDefaultRoomDp;
  Map<String, String> get countryDefaultRoomDps => Map.unmodifiable(_countryDefaultRoomDps);
  Map<String, String> get moderatedRoomDps => Map.unmodifiable(_moderatedRoomDps);
  List<Map<String, dynamic>> get roomDpModerationLogs => List.unmodifiable(_roomDpModerationLogs);

  GameProvider() {
    _loadRocketTargets();
    _loadRoomThemeUploadConfig();
    _loadModule03And04Config();
  }

  Future<void> _loadRocketTargets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetsJson = prefs.getString('rocket_level_targets');
      if (targetsJson != null) {
        final List<dynamic> list = jsonDecode(targetsJson);
        final parsed = list.map((e) => (e as num).toInt()).toList();
        final validationError = validateRocketTargets(parsed);
        if (validationError == null) {
          _rocketLevelTargets = parsed;
        } else {
          // Use safe fallback defaults if saved target config is invalid
          _rocketLevelTargets = List.from(defaultRocketTargets);
        }
      } else {
        _rocketLevelTargets = List.from(defaultRocketTargets);
      }

      _configVersion = prefs.getInt('rocket_config_version') ?? 1;

      final logsJson = prefs.getString('rocket_admin_logs');
      if (logsJson != null) {
        final List<dynamic> logs = jsonDecode(logsJson);
        _rocketAdminLogs = logs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      notifyListeners();
    } catch (_) {
      _rocketLevelTargets = List.from(defaultRocketTargets);
    }
  }

  Future<void> _loadRoomThemeUploadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _paidRoomThemeUploadsEnabled = prefs.getBool('paid_room_theme_enabled') ?? true;
      _customRoomThemeUploadPrice = prefs.getInt('custom_room_theme_price') ?? 100000;
      
      final countryJson = prefs.getString('country_room_theme_prices');
      if (countryJson != null) {
        final Map<String, dynamic> map = jsonDecode(countryJson);
        _countryRoomThemeUploadPrices = map.map((k, v) => MapEntry(k, (v as num).toInt()));
      }

      final txJson = prefs.getString('room_theme_upload_transactions');
      if (txJson != null) {
        final List<dynamic> txs = jsonDecode(txJson);
        _roomThemeUploadTransactions = txs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      final logsJson = prefs.getString('room_theme_price_admin_logs');
      if (logsJson != null) {
        final List<dynamic> logs = jsonDecode(logsJson);
        _roomThemePriceAdminLogs = logs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveRoomThemeTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_theme_upload_transactions', jsonEncode(_roomThemeUploadTransactions));
    } catch (_) {}
  }

  /// Validate Rocket configuration according to admin rules
  static String? validateRocketTargets(List<int> targets) {
    if (targets.length != 5) {
      return 'Exactly five Rocket levels must exist.';
    }
    for (int i = 0; i < targets.length; i++) {
      if (targets[i] <= 0) {
        return 'Rocket ${i + 1} target must be greater than zero.';
      }
    }
    for (int i = 0; i < targets.length - 1; i++) {
      if (targets[i] > targets[i + 1]) {
        return 'Rocket level targets must be ordered sequentially (Rocket ${i + 1} <= Rocket ${i + 2}).';
      }
    }
    return null;
  }

  /// Update Rocket Game Targets with validation, audit logging, and versioning
  Future<String?> updateRocketLevelTargets(List<int> newTargets, {String adminId = 'Admin Owner'}) async {
    final validationError = validateRocketTargets(newTargets);
    if (validationError != null) {
      return validationError;
    }

    final previousTargets = List<int>.from(_rocketLevelTargets);
    _rocketLevelTargets = List.from(newTargets);
    _configVersion += 1;

    final changeId = 'cfg_${DateTime.now().millisecondsSinceEpoch}_$_configVersion';
    final log = {
      'changeId': changeId,
      'configVersion': _configVersion,
      'timestamp': DateTime.now().toIso8601String(),
      'admin': adminId,
      'action': 'Updated Rocket Game Level Targets',
      'previousTargets': previousTargets,
      'newTargets': List<int>.from(newTargets),
      'details': 'v$_configVersion: Rocket 1: ${formatRocketTarget(newTargets[0])}, Rocket 2: ${formatRocketTarget(newTargets[1])}, Rocket 3: ${formatRocketTarget(newTargets[2])}, Rocket 4: ${formatRocketTarget(newTargets[3])}, Rocket 5: ${formatRocketTarget(newTargets[4])}',
    };
    _rocketAdminLogs.insert(0, log);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rocket_level_targets', jsonEncode(_rocketLevelTargets));
      await prefs.setInt('rocket_config_version', _configVersion);
      await prefs.setString('rocket_admin_logs', jsonEncode(_rocketAdminLogs));
    } catch (_) {}

    BackendRepository.instance.logTransaction(
      title: 'Admin: Rocket Targets Updated (v$_configVersion)',
      type: 'ADMIN_CONFIG',
      amount: 0,
      currency: 'LOG',
    );
    BackendRepository.instance.sendNotification(
      title: 'Rocket Game Update 🚀',
      message: 'Rocket Game progression targets updated to v$_configVersion by admin.',
      category: 'System',
    );

    notifyListeners();
    return null;
  }

  /// Idempotent Reward Distribution check to prevent duplicate payouts
  bool claimRocketRewardIdempotent(WalletProvider walletProvider, String rewardId, int amount, String description) {
    if (_distributedRewardKeys.contains(rewardId)) {
      return false; // Already rewarded
    }
    _distributedRewardKeys.add(rewardId);
    walletProvider.earnCoins(amount, description, referenceId: rewardId);
    return true;
  }

  static String formatRocketTarget(int target) {
    if (target >= 1000000) {
      double m = target / 1000000;
      return m % 1 == 0 ? '${m.toInt()}M' : '${m.toStringAsFixed(1)}M';
    } else if (target >= 1000) {
      double k = target / 1000;
      return k % 1 == 0 ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    }
    return target.toString();
  }

  /// Central Price Resolution Method (Section 10)
  /// 1. Checks if paid Room Theme uploads are enabled. If false, returns 0 (Free).
  /// 2. Checks for valid country/region price in countryRoomThemeUploadPrices.
  /// 3. If available and > 0, returns country/region price.
  /// 4. Otherwise returns global customRoomThemeUploadPrice.
  /// 5. Safe fallback: 100,000 coins.
  int getCustomRoomThemeUploadPrice(String? userCountry) {
    if (!_paidRoomThemeUploadsEnabled) return 0;
    if (userCountry != null && userCountry != 'Global' && _countryRoomThemeUploadPrices.containsKey(userCountry)) {
      final countryPrice = _countryRoomThemeUploadPrices[userCountry];
      if (countryPrice != null && countryPrice > 0) {
        return countryPrice;
      }
    }
    return _customRoomThemeUploadPrice > 0 ? _customRoomThemeUploadPrice : 100000;
  }

  /// Process Paid Room Theme Upload Transaction
  Future<Map<String, dynamic>> processRoomThemePayment({
    required WalletProvider walletProvider,
    required String userId,
    required String roomId,
    required String uploadType,
    required String? userCountry,
  }) async {
    final price = getCustomRoomThemeUploadPrice(userCountry);
    final txId = 'tx_theme_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

    if (price <= 0) {
      final freeTx = {
        'transactionId': txId,
        'userId': userId,
        'roomId': roomId,
        'uploadType': uploadType,
        'coinAmount': 0,
        'currency': 'Coins',
        'country': userCountry ?? 'Global',
        'paymentStatus': 'Completed',
        'uploadStatus': 'Completed',
        'chargedAmount': 0,
        'refundAmount': 0,
        'timestamp': DateTime.now().toIso8601String(),
        'configPriceUsed': 0,
      };
      _roomThemeUploadTransactions.insert(0, freeTx);
      notifyListeners();
      return {'success': true, 'transactionId': txId, 'chargedAmount': 0};
    }

    if (walletProvider.coins < price) {
      return {
        'success': false,
        'error': 'INSUFFICIENT_COINS',
        'requiredCoins': price,
        'currentCoins': walletProvider.coins,
      };
    }

    // Deduct coins atomically
    final previousBalance = walletProvider.coins;
    final deducted = walletProvider.spendCoins(price, 'Paid $uploadType Upload');
    if (!deducted) {
      return {
        'success': false,
        'error': 'PAYMENT_FAILED',
        'requiredCoins': price,
      };
    }
    final newBalance = walletProvider.coins;

    final txRecord = {
      'transactionId': txId,
      'userId': userId,
      'roomId': roomId,
      'uploadType': uploadType,
      'coinAmount': price,
      'currency': 'Coins',
      'country': userCountry ?? 'Global',
      'previousBalance': previousBalance,
      'newBalance': newBalance,
      'paymentStatus': 'Completed',
      'uploadStatus': 'Processing',
      'refundStatus': 'None',
      'chargedAmount': price,
      'refundAmount': 0,
      'timestamp': DateTime.now().toIso8601String(),
      'configPriceUsed': price,
    };
    _roomThemeUploadTransactions.insert(0, txRecord);
    _saveRoomThemeTransactions();

    BackendRepository.instance.logTransaction(
      title: 'Paid $uploadType Upload',
      type: 'ROOM_THEME_PAYMENT',
      amount: price.toDouble(),
      currency: 'Coins',
    );

    notifyListeners();
    return {
      'success': true,
      'transactionId': txId,
      'chargedAmount': price,
    };
  }

  /// Automatic Refund logic if image upload fails or user cancels
  Future<bool> refundRoomThemePayment({
    required WalletProvider walletProvider,
    required String transactionId,
    required String reason,
  }) async {
    final idx = _roomThemeUploadTransactions.indexWhere((t) => t['transactionId'] == transactionId);
    if (idx == -1) return false;

    final tx = _roomThemeUploadTransactions[idx];
    final int chargedAmount = tx['chargedAmount'] as int? ?? 0;
    final String paymentStatus = tx['paymentStatus'] as String? ?? '';
    final String refundStatus = tx['refundStatus'] as String? ?? 'None';

    if (chargedAmount <= 0 || refundStatus == 'Refunded' || paymentStatus == 'Refunded') {
      return false; // Prevent duplicate refunds or refunding free uploads
    }

    final refundTxId = 'ref_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    walletProvider.earnCoins(chargedAmount, 'Refund: Room Theme Upload ($reason)', referenceId: refundTxId);

    _roomThemeUploadTransactions[idx]['paymentStatus'] = 'Refunded';
    _roomThemeUploadTransactions[idx]['uploadStatus'] = 'Failed';
    _roomThemeUploadTransactions[idx]['refundStatus'] = 'Refunded';
    _roomThemeUploadTransactions[idx]['refundAmount'] = chargedAmount;
    _roomThemeUploadTransactions[idx]['refundReason'] = reason;
    _roomThemeUploadTransactions[idx]['refundTxId'] = refundTxId;
    _roomThemeUploadTransactions[idx]['refundTimestamp'] = DateTime.now().toIso8601String();

    _saveRoomThemeTransactions();

    BackendRepository.instance.logTransaction(
      title: 'Refund: Room Theme Upload',
      type: 'ROOM_THEME_REFUND',
      amount: chargedAmount.toDouble(),
      currency: 'Coins',
    );

    notifyListeners();
    return true;
  }

  /// Complete upload status after successful image application
  void completeRoomThemeUpload(String transactionId) {
    final idx = _roomThemeUploadTransactions.indexWhere((t) => t['transactionId'] == transactionId);
    if (idx != -1) {
      _roomThemeUploadTransactions[idx]['uploadStatus'] = 'Completed';
      _saveRoomThemeTransactions();
      notifyListeners();
    }
  }

  /// Admin Configuration update method for Room Theme Upload Price & Toggles
  Future<String?> updateRoomThemeUploadConfig({
    required bool enabled,
    required int globalPrice,
    Map<String, int>? countryPrices,
    String adminId = 'Admin Owner',
  }) async {
    if (globalPrice < 0) {
      return 'Price must be non-negative.';
    }

    final prevEnabled = _paidRoomThemeUploadsEnabled;
    final prevPrice = _customRoomThemeUploadPrice;
    final prevCountryPrices = Map<String, int>.from(_countryRoomThemeUploadPrices);

    _paidRoomThemeUploadsEnabled = enabled;
    _customRoomThemeUploadPrice = globalPrice;
    if (countryPrices != null) {
      _countryRoomThemeUploadPrices = Map.from(countryPrices);
    }

    final auditLog = {
      'logId': 'log_theme_${DateTime.now().millisecondsSinceEpoch}',
      'adminId': adminId,
      'previousPrice': prevPrice,
      'newPrice': globalPrice,
      'previousEnabled': prevEnabled,
      'newEnabled': enabled,
      'previousCountryPrices': prevCountryPrices,
      'newCountryPrices': Map<String, int>.from(_countryRoomThemeUploadPrices),
      'scope': 'Global & Country Pricing',
      'timestamp': DateTime.now().toIso8601String(),
    };
    _roomThemePriceAdminLogs.insert(0, auditLog);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('paid_room_theme_enabled', _paidRoomThemeUploadsEnabled);
      await prefs.setInt('custom_room_theme_price', _customRoomThemeUploadPrice);
      await prefs.setString('country_room_theme_prices', jsonEncode(_countryRoomThemeUploadPrices));
      await prefs.setString('room_theme_price_admin_logs', jsonEncode(_roomThemePriceAdminLogs));
    } catch (_) {}

    notifyListeners();
    return null;
  }

  // ── Module 03: Mic Seat Sizing & Room Entry Announcement Logic ──

  Future<void> _loadModule03And04Config() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _roomMicSizePreset = prefs.getString('room_mic_size_preset') ?? 'Large';
      if (!['Small', 'Medium', 'Large'].contains(_roomMicSizePreset)) {
        _roomMicSizePreset = 'Large';
      }

      final annJson = prefs.getString('room_announcements_map');
      if (annJson != null) {
        final Map<String, dynamic> map = jsonDecode(annJson);
        _roomAnnouncements = map.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
      }

      final globalAnnJson = prefs.getString('global_mandatory_announcement');
      if (globalAnnJson != null) {
        _globalMandatoryAnnouncement = Map<String, dynamic>.from(jsonDecode(globalAnnJson));
      }

      final countryAnnJson = prefs.getString('country_mandatory_announcements');
      if (countryAnnJson != null) {
        final Map<String, dynamic> map = jsonDecode(countryAnnJson);
        _countryMandatoryAnnouncements = map.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
      }

      final histJson = prefs.getString('announcement_history_logs');
      if (histJson != null) {
        final List<dynamic> list = jsonDecode(histJson);
        _announcementHistoryLogs = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      final adminLogJson = prefs.getString('announcement_admin_logs');
      if (adminLogJson != null) {
        final List<dynamic> list = jsonDecode(adminLogJson);
        _announcementAdminLogs = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      _roomCardDisplayMode = prefs.getString('room_card_display_mode') ?? 'Full Room DP';
      _globalDefaultRoomDp = prefs.getString('global_default_room_dp') ?? 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500';

      final modDpJson = prefs.getString('moderated_room_dps');
      if (modDpJson != null) {
        final Map<String, dynamic> map = jsonDecode(modDpJson);
        _moderatedRoomDps = map.map((k, v) => MapEntry(k, v.toString()));
      }

      final modLogJson = prefs.getString('room_dp_moderation_logs');
      if (modLogJson != null) {
        final List<dynamic> list = jsonDecode(modLogJson);
        _roomDpModerationLogs = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      notifyListeners();
    } catch (_) {
      _roomMicSizePreset = 'Large';
    }
  }

  /// Update Admin Room Mic Seat Size Preset (Small, Medium, Large)
  Future<String?> updateRoomMicSizePreset(String preset, {String adminId = 'admin'}) async {
    if (!['Small', 'Medium', 'Large'].contains(preset)) {
      return 'Invalid preset. Must be Small, Medium, or Large.';
    }

    _roomMicSizePreset = preset;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_mic_size_preset', _roomMicSizePreset);
    } catch (_) {}

    notifyListeners();
    return null;
  }

  /// Resolve priority announcement for a given room & user country:
  /// Priority:
  /// 1. Mandatory Global Announcement (if active & enabled)
  /// 2. Mandatory Country Announcement (if active & enabled for user country)
  /// 3. Room Owner Active Announcement (if active & enabled)
  /// 4. Default Announcement
  Map<String, dynamic> getResolvedAnnouncement(String roomId, String? userCountry) {
    // 1. Mandatory Global Announcement
    if (_globalMandatoryAnnouncement.isNotEmpty &&
        _globalMandatoryAnnouncement['enabled'] == true &&
        _globalMandatoryAnnouncement['status'] == 'Active') {
      return {
        'source': 'Mandatory Global',
        'isMandatory': true,
        'title': _globalMandatoryAnnouncement['title'] ?? '📢 Mandatory Notice',
        'text': _globalMandatoryAnnouncement['text'] ?? '',
        'status': _globalMandatoryAnnouncement['status'] ?? 'Active',
      };
    }

    // 2. Mandatory Country Announcement
    if (userCountry != null && _countryMandatoryAnnouncements.containsKey(userCountry)) {
      final cAnn = _countryMandatoryAnnouncements[userCountry]!;
      if (cAnn['enabled'] == true && cAnn['status'] == 'Active') {
        return {
          'source': 'Country Mandatory ($userCountry)',
          'isMandatory': true,
          'title': cAnn['title'] ?? '📢 Regional Notice',
          'text': cAnn['text'] ?? '',
          'status': cAnn['status'] ?? 'Active',
        };
      }
    }

    // 3. Room Owner Announcement
    if (_roomAnnouncements.containsKey(roomId)) {
      final rAnn = _roomAnnouncements[roomId]!;
      if (rAnn['enabled'] == true && rAnn['status'] == 'Active') {
        return {
          'source': 'Room Owner',
          'isMandatory': false,
          'title': rAnn['title'] ?? '📢 Room Announcement',
          'text': rAnn['text'] ?? '',
          'status': rAnn['status'] ?? 'Active',
        };
      }
    }

    // 4. Default Announcement
    return {
      'source': 'Default',
      'isMandatory': false,
      'title': '📢 Welcome to ZeParty',
      'text': 'Welcome to ZeParty. Please respect each other and communicate in a friendly and appropriate manner.',
      'status': 'Active',
    };
  }

  /// Create or edit a Room Announcement (Room Owner or Admin)
  Future<String?> setRoomAnnouncement({
    required String roomId,
    required String editorUserId,
    required String text,
    String title = '📢 Room Announcement',
    bool enabled = true,
    String status = 'Active',
    bool isMandatory = false,
    String? country,
    bool isAdmin = false,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return 'Announcement text cannot be empty.';
    }

    // Enforce Character Limit (200 characters max)
    if (trimmedText.length > 200) {
      return 'Announcement exceeds 200 character limit (Current: ${trimmedText.length}).';
    }

    // Prohibited Word Filter
    final prohibitedWords = ['abuse', 'scam', 'hate', 'badword', 'fraud', 'cheat', 'banned'];
    final lowerText = trimmedText.toLowerCase();
    for (final word in prohibitedWords) {
      if (lowerText.contains(word)) {
        return 'Moderation Error: Announcement contains prohibited or inappropriate content.';
      }
    }

    final prevAnn = _roomAnnouncements[roomId];
    final prevText = prevAnn?['text'] ?? '';
    final prevStatus = prevAnn?['status'] ?? 'None';

    final annId = 'ann_${DateTime.now().millisecondsSinceEpoch}';
    final annData = {
      'announcementId': annId,
      'roomId': roomId,
      'editorUserId': editorUserId,
      'title': title,
      'text': trimmedText,
      'enabled': enabled,
      'status': status,
      'isMandatory': isMandatory,
      'country': country,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (isMandatory && country != null) {
      _countryMandatoryAnnouncements[country] = annData;
    } else if (isMandatory) {
      _globalMandatoryAnnouncement = annData;
    } else {
      _roomAnnouncements[roomId] = annData;
    }

    // History Log
    _announcementHistoryLogs.insert(0, {
      'announcementId': annId,
      'roomId': roomId,
      'editorUserId': editorUserId,
      'actionType': prevAnn == null ? 'Create' : 'Edit',
      'previousText': prevText,
      'newText': trimmedText,
      'previousStatus': prevStatus,
      'newStatus': status,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (isAdmin) {
      _announcementAdminLogs.insert(0, {
        'adminId': editorUserId,
        'roomId': roomId,
        'action': 'Set Announcement',
        'status': status,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_announcements_map', jsonEncode(_roomAnnouncements));
      await prefs.setString('global_mandatory_announcement', jsonEncode(_globalMandatoryAnnouncement));
      await prefs.setString('country_mandatory_announcements', jsonEncode(_countryMandatoryAnnouncements));
      await prefs.setString('announcement_history_logs', jsonEncode(_announcementHistoryLogs));
      await prefs.setString('announcement_admin_logs', jsonEncode(_announcementAdminLogs));
    } catch (_) {}

    notifyListeners();
    return null;
  }

  /// Admin method to approve/reject/disable room announcements
  Future<void> updateAnnouncementStatus({
    required String roomId,
    required String newStatus, // 'Approved', 'Rejected', 'Disabled', 'Active'
    String adminId = 'admin',
    String? reason,
  }) async {
    if (_roomAnnouncements.containsKey(roomId)) {
      final ann = _roomAnnouncements[roomId]!;
      final prevStatus = ann['status'];
      ann['status'] = newStatus;
      if (newStatus == 'Disabled' || newStatus == 'Rejected') {
        ann['enabled'] = false;
      }

      _announcementAdminLogs.insert(0, {
        'adminId': adminId,
        'roomId': roomId,
        'action': 'Update Status ($newStatus)',
        'previousStatus': prevStatus,
        'newStatus': newStatus,
        'reason': reason ?? 'Admin Moderation',
        'timestamp': DateTime.now().toIso8601String(),
      });

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('room_announcements_map', jsonEncode(_roomAnnouncements));
        await prefs.setString('announcement_admin_logs', jsonEncode(_announcementAdminLogs));
      } catch (_) {}

      notifyListeners();
    }
  }

  // ── Module 04: Room Card Display & Room DP Moderation Logic ──

  /// Get effective Room DP with instant moderation fallback safety
  String getEffectiveRoomDp(String roomId, String? uploadedDp, String? userCountry, {String? hostAvatarUrl}) {
    final status = _moderatedRoomDps[roomId];
    if (status == 'rejected' || status == 'removed' || uploadedDp == null || uploadedDp.isEmpty) {
      if (hostAvatarUrl != null && hostAvatarUrl.isNotEmpty) {
        return hostAvatarUrl;
      }
      if (userCountry != null && _countryDefaultRoomDps.containsKey(userCountry)) {
        return _countryDefaultRoomDps[userCountry]!;
      }
      return _globalDefaultRoomDp;
    }
    return uploadedDp;
  }

  /// Admin moderation action on Room DP
  Future<void> moderateRoomDp({
    required String roomId,
    required String action, // 'Approve', 'Reject', 'Remove', 'Replace'
    String? newImage,
    String? reason,
    String adminId = 'Admin Moderation',
  }) async {
    final currentStatus = _moderatedRoomDps[roomId] ?? 'approved';
    if (action == 'Reject' || action == 'Remove') {
      _moderatedRoomDps[roomId] = 'removed';
    } else if (action == 'Approve') {
      _moderatedRoomDps[roomId] = 'approved';
    }

    _roomDpModerationLogs.insert(0, {
      'logId': 'log_dp_${DateTime.now().millisecondsSinceEpoch}',
      'adminId': adminId,
      'roomId': roomId,
      'action': action,
      'previousStatus': currentStatus,
      'newStatus': _moderatedRoomDps[roomId],
      'newImage': newImage,
      'reason': reason ?? 'Admin Moderation',
      'timestamp': DateTime.now().toIso8601String(),
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('moderated_room_dps', jsonEncode(_moderatedRoomDps));
      await prefs.setString('room_dp_moderation_logs', jsonEncode(_roomDpModerationLogs));
    } catch (_) {}

    notifyListeners();
  }

  /// Start a validated game session
  Future<GameSessionModel?> startSession({
    required WalletProvider walletProvider,
    required String gameId,
    required String gameType,
    required int entryCoins,
  }) async {
    if (_isPlaying) return null;

    if (walletProvider.coins < entryCoins) {
      _gameMessage = 'Insufficient coin balance to join game.';
      notifyListeners();
      return null;
    }

    final sessionId = 'gs_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    _activeSession = GameSessionModel(
      gameSessionId: sessionId,
      gameId: gameId,
      gameType: gameType,
      userId: 'user_current',
      entryCoins: entryCoins,
      rewardCoins: 0,
      result: 'in_progress',
      status: GameSessionStatus.started,
      startedAt: DateTime.now(),
    );

    // Deduct entry coins atomically via WalletProvider
    walletProvider.spendCoins(entryCoins, '${sessionId}_entry');


    _isPlaying = true;
    _gameMessage = 'Game session started...';
    notifyListeners();
    return _activeSession;
  }

  /// Complete game session with verified multiplier result
  void completeSession({
    required WalletProvider walletProvider,
    required int multiplier,
  }) {
    if (_activeSession == null) return;

    _lastResultMultiplier = multiplier;
    _lastWinnings = _activeSession!.entryCoins * multiplier;

    if (_lastWinnings > 0) {
      walletProvider.earnCoins(
        _lastWinnings,
        'Game Win Reward: ${_activeSession!.gameType}',
        referenceId: '${_activeSession!.gameSessionId}_win',
      );
    }

    final completedSession = _activeSession!.copyWith(
      rewardCoins: _lastWinnings,
      result: multiplier > 0 ? 'won' : 'lost',
      status: GameSessionStatus.completed,
      completedAt: DateTime.now(),
    );

    _sessionsHistory.insert(0, completedSession);
    _activeSession = null;
    _isPlaying = false;

    if (multiplier > 0) {
      _gameMessage = '🎉 CONGRATS! You won $_lastWinnings Coins (${multiplier}x)!';
    } else {
      _gameMessage = 'Better luck next time! Try again! 💫';
    }
    notifyListeners();
  }

  void claimDailyReward(WalletProvider walletProvider) {
    if (_dailyRewardClaimed) return;
    walletProvider.earnCoins(_dailyRewardCoins, 'Daily Login Reward (Day $_dailyStreak)');
    _dailyRewardClaimed = true;
    _dailyStreak += 1;
    notifyListeners();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }
}


