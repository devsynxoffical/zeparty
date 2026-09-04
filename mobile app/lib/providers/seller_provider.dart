import 'package:flutter/material.dart';

class OfflineRechargeRequest {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String packageTitle;
  final int coins;
  final double priceUsd;
  final String paymentMethod;
  final String referenceNumber;
  final String? proofImagePath;
  final DateTime timestamp;
  String status; // 'pending', 'approved', 'rejected'

  OfflineRechargeRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.packageTitle,
    required this.coins,
    required this.priceUsd,
    required this.paymentMethod,
    required this.referenceNumber,
    this.proofImagePath,
    required this.timestamp,
    this.status = 'pending',
  });
}

class SellerDistributionLog {
  final String id;
  final String userId;
  final int amount;
  final DateTime timestamp;
  final String type; // 'offline_approval' or 'direct_transfer'
  final String reference;

  SellerDistributionLog({
    required this.id,
    required this.userId,
    required this.amount,
    required this.timestamp,
    required this.type,
    required this.reference,
  });
}

class SellerProvider extends ChangeNotifier {
  int _sellerBalance = 150000;
  int _totalDistributedCoins = 45000;

  int get sellerBalance => _sellerBalance;
  int get totalDistributedCoins => _totalDistributedCoins;

  final List<OfflineRechargeRequest> _requests = [
    OfflineRechargeRequest(
      id: 'REQ-991',
      userId: 'USR-8821',
      userName: 'Alexander Wright',
      userAvatar: 'https://i.pravatar.cc/150?img=12',
      packageTitle: 'Gold Pack (12,000 Coins)',
      coins: 12000,
      priceUsd: 49.99,
      paymentMethod: 'Bank Transfer (HSBC)',
      referenceNumber: 'TXN-99882214',
      proofImagePath: null,
      timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      status: 'pending',
    ),
    OfflineRechargeRequest(
      id: 'REQ-992',
      userId: 'USR-5542',
      userName: 'Sophia Martinez',
      userAvatar: 'https://i.pravatar.cc/150?img=44',
      packageTitle: 'Silver Pack (5,000 Coins)',
      coins: 5000,
      priceUsd: 19.99,
      paymentMethod: 'Mobile Wallet (EasyPaisa)',
      referenceNumber: 'EP-4411993',
      proofImagePath: null,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      status: 'pending',
    ),
  ];

  final List<SellerDistributionLog> _distributionLogs = [
    SellerDistributionLog(
      id: 'DIS-101',
      userId: 'USR-3301',
      amount: 10000,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      type: 'offline_approval',
      reference: 'REQ-988',
    ),
    SellerDistributionLog(
      id: 'DIS-102',
      userId: 'USR-9022',
      amount: 5000,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      type: 'direct_transfer',
      reference: 'DIR-8812',
    ),
  ];

  List<OfflineRechargeRequest> get requests => _requests;
  List<OfflineRechargeRequest> get pendingRequests =>
      _requests.where((r) => r.status == 'pending').toList();
  List<OfflineRechargeRequest> get processedRequests =>
      _requests.where((r) => r.status != 'pending').toList();
  List<SellerDistributionLog> get distributionLogs => _distributionLogs;

  void addRechargeRequest(OfflineRechargeRequest request) {
    _requests.insert(0, request);
    notifyListeners();
  }

  bool approveRequest(String requestId) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final req = _requests[index];
      if (_sellerBalance >= req.coins) {
        req.status = 'approved';
        _sellerBalance -= req.coins;
        _totalDistributedCoins += req.coins;

        _distributionLogs.insert(
          0,
          SellerDistributionLog(
            id: 'DIS-${DateTime.now().millisecondsSinceEpoch}',
            userId: req.userId,
            amount: req.coins,
            timestamp: DateTime.now(),
            type: 'offline_approval',
            reference: req.id,
          ),
        );
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  void rejectRequest(String requestId) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _requests[index].status = 'rejected';
      notifyListeners();
    }
  }

  bool directTransfer({required String userId, required int coinAmount}) {
    if (_sellerBalance >= coinAmount && coinAmount > 0) {
      _sellerBalance -= coinAmount;
      _totalDistributedCoins += coinAmount;

      _distributionLogs.insert(
        0,
        SellerDistributionLog(
          id: 'DIR-${DateTime.now().millisecondsSinceEpoch}',
          userId: userId,
          amount: coinAmount,
          timestamp: DateTime.now(),
          type: 'direct_transfer',
          reference: 'Manual Seller Transfer',
        ),
      );
      notifyListeners();
      return true;
    }
    return false;
  }
}
