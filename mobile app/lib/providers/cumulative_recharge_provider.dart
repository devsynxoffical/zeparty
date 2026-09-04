import 'package:flutter/material.dart';
import '../models/cumulative_recharge_model.dart';
import 'wallet_provider.dart';

class CumulativeRechargeProvider extends ChangeNotifier {
  bool _isLoading = false;
  double _cumulativeRechargeUsd = 145.00;

  bool get isLoading => _isLoading;
  double get cumulativeRechargeUsd => _cumulativeRechargeUsd;

  final List<RechargeMilestone> _milestones = [
    const RechargeMilestone(
      level: 1,
      thresholdUsd: 10.0,
      bonusCoins: 1000,
      bonusDiamonds: 500,
      specialRewardName: 'Bronze VIP Entry Badge (7 Days)',
      specialRewardIcon: '🥉',
      status: MilestoneClaimStatus.claimed,
    ),
    const RechargeMilestone(
      level: 2,
      thresholdUsd: 50.0,
      bonusCoins: 6000,
      bonusDiamonds: 3000,
      specialRewardName: 'Neon Gold Chat Bubble (15 Days)',
      specialRewardIcon: '💬',
      status: MilestoneClaimStatus.claimed,
    ),
    const RechargeMilestone(
      level: 3,
      thresholdUsd: 100.0,
      bonusCoins: 15000,
      bonusDiamonds: 8000,
      specialRewardName: 'Cyber Ride Vehicle (30 Days)',
      specialRewardIcon: '🏎️',
      status: MilestoneClaimStatus.eligible,
    ),
    const RechargeMilestone(
      level: 4,
      thresholdUsd: 300.0,
      bonusCoins: 50000,
      bonusDiamonds: 25000,
      specialRewardName: 'Golden Phoenix Avatar Frame',
      specialRewardIcon: '👑',
      status: MilestoneClaimStatus.locked,
    ),
    const RechargeMilestone(
      level: 5,
      thresholdUsd: 1000.0,
      bonusCoins: 200000,
      bonusDiamonds: 100000,
      specialRewardName: 'Custom Vanity ID + Room Spotlight',
      specialRewardIcon: '💎',
      status: MilestoneClaimStatus.locked,
    ),
    const RechargeMilestone(
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
    _currentEvent = CumulativeRechargeEvent(
      id: 'evt_summer_recharge_2026',
      title: 'ZeParty Grand Recharge Fiesta',
      description: 'Recharge cumulative dollar amounts during the event window to unlock limited luxury animated assets and coin rebates!',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31, 23, 59, 59),
      currentRechargeUsd: _cumulativeRechargeUsd,
      milestones: _milestones,
    );
  }

  CumulativeRechargeEvent get currentEvent => _currentEvent;

  Future<void> fetchRechargeData() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 250));
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> claimMilestone(int milestoneLevel, WalletProvider wallet) async {
    final index = _currentEvent.milestones.indexWhere((m) => m.level == milestoneLevel);
    if (index == -1) return false;

    final target = _currentEvent.milestones[index];
    if (target.status != MilestoneClaimStatus.eligible && _cumulativeRechargeUsd < target.thresholdUsd) {
      return false;
    }
    if (target.status == MilestoneClaimStatus.claimed) {
      return false; // Prevent duplicate claims
    }

    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 350));

    // Award rewards
    wallet.rechargeCoins(target.bonusCoins, 0.0);

    // Update milestone state
    final updatedList = List<RechargeMilestone>.from(_currentEvent.milestones);
    updatedList[index] = target.copyWith(status: MilestoneClaimStatus.claimed);

    _currentEvent = CumulativeRechargeEvent(
      id: _currentEvent.id,
      title: _currentEvent.title,
      description: _currentEvent.description,
      startDate: _currentEvent.startDate,
      endDate: _currentEvent.endDate,
      currentRechargeUsd: _cumulativeRechargeUsd,
      milestones: updatedList,
    );

    _isLoading = false;
    notifyListeners();
    return true;
  }

  void addRechargeAmount(double usd) {
    if (usd <= 0) return;
    _cumulativeRechargeUsd += usd;
    _currentEvent = CumulativeRechargeEvent(
      id: _currentEvent.id,
      title: _currentEvent.title,
      description: _currentEvent.description,
      startDate: _currentEvent.startDate,
      endDate: _currentEvent.endDate,
      currentRechargeUsd: _cumulativeRechargeUsd,
      milestones: _currentEvent.milestones,
    );
    notifyListeners();
  }
}
