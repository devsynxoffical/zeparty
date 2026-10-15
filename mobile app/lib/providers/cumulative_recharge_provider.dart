import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cumulative_recharge_model.dart';
import 'wallet_provider.dart';

class CumulativeRechargeProvider extends ChangeNotifier {
  bool _isLoading = false;
  double _cumulativeRechargeUsd = 0.00;
  String? _activeUserId;
  final Set<int> _claimedMilestoneLevels = {};

  bool get isLoading => _isLoading;
  double get cumulativeRechargeUsd => _cumulativeRechargeUsd;

  static const List<RechargeMilestone> _templateMilestones = [
    RechargeMilestone(
      level: 1,
      thresholdUsd: 10.0,
      bonusCoins: 1000,
      bonusDiamonds: 500,
      specialRewardName: 'Bronze VIP Entry Badge (7 Days)',
      specialRewardIcon: '🥉',
      status: MilestoneClaimStatus.locked,
    ),
    RechargeMilestone(
      level: 2,
      thresholdUsd: 50.0,
      bonusCoins: 6000,
      bonusDiamonds: 3000,
      specialRewardName: 'Neon Gold Chat Bubble (15 Days)',
      specialRewardIcon: '💬',
      status: MilestoneClaimStatus.locked,
    ),
    RechargeMilestone(
      level: 3,
      thresholdUsd: 100.0,
      bonusCoins: 15000,
      bonusDiamonds: 8000,
      specialRewardName: 'Cyber Ride Vehicle (30 Days)',
      specialRewardIcon: '🏎️',
      status: MilestoneClaimStatus.locked,
    ),
    RechargeMilestone(
      level: 4,
      thresholdUsd: 300.0,
      bonusCoins: 50000,
      bonusDiamonds: 25000,
      specialRewardName: 'Golden Phoenix Avatar Frame',
      specialRewardIcon: '👑',
      status: MilestoneClaimStatus.locked,
    ),
    RechargeMilestone(
      level: 5,
      thresholdUsd: 1000.0,
      bonusCoins: 200000,
      bonusDiamonds: 100000,
      specialRewardName: 'Custom Vanity ID + Room Spotlight',
      specialRewardIcon: '💎',
      status: MilestoneClaimStatus.locked,
    ),
    RechargeMilestone(
      level: 6,
      thresholdUsd: 3000.0,
      bonusCoins: 750000,
      bonusDiamonds: 400000,
      specialRewardName: 'Emperor Royal Broadcast Halo (Permanent)',
      specialRewardIcon: '🌟',
      status: MilestoneClaimStatus.locked,
    ),
  ];

  late CumulativeRechargeEvent _currentEvent;

  CumulativeRechargeProvider() {
    _initEvent();
  }

  void _initEvent() {
    final now = DateTime.now();
    // Configured event dates: Active current event window
    final startDate = DateTime(now.year, now.month, 1);
    final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    _currentEvent = CumulativeRechargeEvent(
      id: 'evt_grand_fiesta_${now.year}_${now.month}',
      title: 'ZeParty Grand Recharge Fiesta',
      description: 'Recharge cumulative dollar amounts during the event window to unlock limited luxury animated assets and coin rebates!',
      startDate: startDate,
      endDate: endDate,
      currentRechargeUsd: _cumulativeRechargeUsd,
      milestones: _buildCurrentMilestones(),
    );
  }

  List<RechargeMilestone> _buildCurrentMilestones() {
    return _templateMilestones.map((m) {
      if (_claimedMilestoneLevels.contains(m.level)) {
        return m.copyWith(status: MilestoneClaimStatus.claimed);
      } else if (_cumulativeRechargeUsd >= m.thresholdUsd) {
        return m.copyWith(status: MilestoneClaimStatus.eligible);
      } else {
        return m.copyWith(status: MilestoneClaimStatus.locked);
      }
    }).toList();
  }

  CumulativeRechargeEvent get currentEvent => _currentEvent;

  /// Synchronize event progress isolated by authenticated account ID
  Future<void> syncWithUser(String userId) async {
    if (userId.isEmpty) {
      resetUserProgress();
      return;
    }

    if (_activeUserId != userId) {
      _activeUserId = userId;
      await _loadUserProgress(userId);
    }
  }

  /// Reset to clean zero starting state
  void resetUserProgress() {
    _activeUserId = null;
    _cumulativeRechargeUsd = 0.00;
    _claimedMilestoneLevels.clear();
    _refreshEventState();
    notifyListeners();
  }

  Future<void> _loadUserProgress(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'zeparty_recharge_rewards_${userId}_${_currentEvent.id}';
      final raw = prefs.getString(key);

      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _cumulativeRechargeUsd = (data['cumulativeUsd'] as num?)?.toDouble() ?? 0.00;
        final claimed = (data['claimedLevels'] as List?)?.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e > 0).toSet() ?? {};
        _claimedMilestoneLevels.clear();
        _claimedMilestoneLevels.addAll(claimed);
      } else {
        // Zero starting state for user with no recorded event progress
        _cumulativeRechargeUsd = 0.00;
        _claimedMilestoneLevels.clear();
      }
    } catch (_) {
      _cumulativeRechargeUsd = 0.00;
      _claimedMilestoneLevels.clear();
    } finally {
      _refreshEventState();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _persistUserProgress() async {
    if (_activeUserId == null || _activeUserId!.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'zeparty_recharge_rewards_${_activeUserId}_${_currentEvent.id}';
      final payload = {
        'cumulativeUsd': _cumulativeRechargeUsd,
        'claimedLevels': _claimedMilestoneLevels.toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(key, jsonEncode(payload));
    } catch (_) {}
  }

  void _refreshEventState() {
    _currentEvent = CumulativeRechargeEvent(
      id: _currentEvent.id,
      title: _currentEvent.title,
      description: _currentEvent.description,
      startDate: _currentEvent.startDate,
      endDate: _currentEvent.endDate,
      currentRechargeUsd: _cumulativeRechargeUsd,
      milestones: _buildCurrentMilestones(),
    );
  }

  Future<void> fetchRechargeData() async {
    _isLoading = true;
    notifyListeners();
    if (_activeUserId != null && _activeUserId!.isNotEmpty) {
      await _loadUserProgress(_activeUserId!);
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> claimMilestone(int milestoneLevel, WalletProvider wallet) async {
    final index = _currentEvent.milestones.indexWhere((m) => m.level == milestoneLevel);
    if (index == -1) return false;

    final target = _currentEvent.milestones[index];
    if (_cumulativeRechargeUsd < target.thresholdUsd) {
      return false; // Threshold not met
    }
    if (_claimedMilestoneLevels.contains(milestoneLevel)) {
      return false; // Prevent duplicate claims
    }

    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 250));

    // Award rewards
    wallet.rechargeCoins(target.bonusCoins, 0.0);
    _claimedMilestoneLevels.add(milestoneLevel);

    _refreshEventState();
    await _persistUserProgress();

    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Increments progress strictly from confirmed eligible recharge transactions
  void addRechargeAmount(double usd) {
    if (usd <= 0) return;
    _cumulativeRechargeUsd += usd;
    _refreshEventState();
    _persistUserProgress();
    notifyListeners();
  }
}
