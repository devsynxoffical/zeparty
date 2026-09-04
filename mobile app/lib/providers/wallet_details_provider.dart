import 'package:flutter/material.dart';
import '../models/categorized_transaction_model.dart';
import '../models/user_model.dart';

class WalletDetailsProvider extends ChangeNotifier {
  final List<CategorizedTransactionModel> _allLedgerEntries = [];
  final List<String> _auditLogs = [];
  
  String _selectedCategoryFilter = 'All';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final bool _isOffline = false;
  String? _errorMessage;
  int _currentPage = 1;
  static const int _pageSize = 5;

  String get selectedCategoryFilter => _selectedCategoryFilter;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get isOffline => _isOffline;
  String? get errorMessage => _errorMessage;
  List<String> get auditLogs => List.unmodifiable(_auditLogs);

  /// Available horizontal filters supported by server for a given user role
  List<String> availableFiltersForRole([UserRole role = UserRole.host]) {
    final baseFilters = ['All', 'Transfer', 'Exchange', 'Withdrawal', 'Gift/Reward', 'Refund/Reversal'];
    
    // Add role specific settlement filters
    if (role == UserRole.host || role == UserRole.bd || role == UserRole.admin) {
      baseFilters.insert(1, 'Host Salary');
    }
    if (role == UserRole.agency || role == UserRole.bd || role == UserRole.admin) {
      baseFilters.insert(2, 'Agent Salary');
    }
    return baseFilters;
  }

  /// Get filtered transactions with pagination
  List<CategorizedTransactionModel> get transactions {
    final filtered = _filterTransactions();
    final limit = _currentPage * _pageSize;
    if (filtered.length <= limit) {
      return List.unmodifiable(filtered);
    }
    return List.unmodifiable(filtered.sublist(0, limit));
  }

  WalletDetailsProvider() {
    _initMockData();
  }

  void _initMockData() {
    final now = DateTime.now();
    _allLedgerEntries.addAll([
      // 1. Gift/Reward
      CategorizedTransactionModel(
        transactionId: 'tx_dia_101',
        category: 'Gift/Reward',
        amount: 52000.0,
        currency: 'Diamonds',
        direction: TransactionDirection.credit,
        senderName: 'Sophia Rose',
        senderId: 'user_1002',
        receiverName: 'Danial Khan',
        receiverId: 'user_1001',
        roomId: 'room_party_99',
        giftName: 'Luxury Yacht',
        balanceBefore: 120000.0,
        balanceAfter: 172000.0,
        status: 'Completed',
        timestamp: now.subtract(const Duration(hours: 3)),
        reason: 'Gift Received in Live Room #99',
        fee: 0.0,
      ),
      // 2. Host Salary
      CategorizedTransactionModel(
        transactionId: 'tx_dia_102',
        category: 'Host Salary',
        amount: 3200.0,
        currency: 'USD',
        direction: TransactionDirection.credit,
        senderName: 'ZeParty Finance Engine',
        senderId: 'SYSTEM_PAYOUT',
        receiverName: 'Danial Khan (Host)',
        receiverId: 'user_1001',
        balanceBefore: 800.0,
        balanceAfter: 4000.0,
        status: 'Completed',
        timestamp: now.subtract(const Duration(days: 2)),
        reason: '15-Day Host Settlement Payout',
        fee: 15.0,
        settlementType: 'Host',
        targetCycle: '2026-08 Cycle 1 (1st-15th)',
        earningSource: 'Live Streaming Gifts & Voice Party',
        settlementRef: 'SETTLE_HOST_20260815_99',
      ),
      // 3. Transfer
      CategorizedTransactionModel(
        transactionId: 'tx_dia_103',
        category: 'Transfer',
        amount: 5000.0,
        currency: 'Coins',
        direction: TransactionDirection.debit,
        senderName: 'Danial Khan',
        senderId: 'user_1001',
        receiverName: 'Alex Rivera (Coin Seller)',
        receiverId: 'seller_8801',
        balanceBefore: 172000.0,
        balanceAfter: 167000.0,
        status: 'Completed',
        timestamp: now.subtract(const Duration(days: 3)),
        reason: 'Direct P2P Diamond/Coin Transfer',
        fee: 50.0,
      ),
      // 4. Withdrawal
      CategorizedTransactionModel(
        transactionId: 'tx_dia_104',
        category: 'Withdrawal',
        amount: 1500.0,
        currency: 'USD',
        direction: TransactionDirection.debit,
        senderName: 'Danial Khan',
        senderId: 'user_1001',
        receiverName: 'Bank Account ****9921',
        receiverId: 'BANK_US_9921',
        balanceBefore: 4000.0,
        balanceAfter: 2500.0,
        status: 'Completed',
        timestamp: now.subtract(const Duration(days: 5)),
        reason: 'Host Salary Cashout Withdrawal',
        fee: 25.0,
      ),
      // 5. Exchange
      CategorizedTransactionModel(
        transactionId: 'tx_dia_105',
        category: 'Exchange',
        amount: 2000.0,
        currency: 'Coins',
        direction: TransactionDirection.credit,
        senderName: 'Danial Khan',
        senderId: 'user_1001',
        receiverName: 'ZeParty Treasury',
        receiverId: 'TREASURY_01',
        balanceBefore: 167000.0,
        balanceAfter: 169000.0,
        status: 'Completed',
        timestamp: now.subtract(const Duration(days: 6)),
        reason: 'Diamond to Coin Internal Exchange',
        fee: 10.0,
        exchangeRate: 1.0,
        inputAmount: 2000.0,
        outputAmount: 2000.0,
        inputCurrency: 'Diamonds',
        outputCurrency: 'Coins',
        configVersion: 'v2.4.1',
      ),
      // 6. Agent Salary
      CategorizedTransactionModel(
        transactionId: 'tx_dia_106',
        category: 'Agent Salary',
        amount: 8500.0,
        currency: 'USD',
        direction: TransactionDirection.credit,
        senderName: 'ZeParty Agency Desk',
        senderId: 'AGENCY_SYSTEM',
        receiverName: 'Danial Agency',
        receiverId: 'agency_7701',
        balanceBefore: 12500.0,
        balanceAfter: 21000.0,
        status: 'Completed',
        timestamp: now.subtract(const Duration(days: 8)),
        reason: 'Monthly Agency Host Commission Settlement',
        fee: 50.0,
        settlementType: 'Agent',
        targetCycle: '2026-07 Monthly Cycle',
        earningSource: 'Sub-host Agency Target Bonuses',
        settlementRef: 'AGENCY_SETTLE_202607_7701',
      ),
      // 7. Refund/Reversal
      CategorizedTransactionModel(
        transactionId: 'tx_dia_107',
        category: 'Refund/Reversal',
        amount: 1200.0,
        currency: 'Diamonds',
        direction: TransactionDirection.credit,
        senderName: 'ZeParty Moderation',
        senderId: 'SYSTEM_MOD',
        receiverName: 'Danial Khan',
        receiverId: 'user_1001',
        balanceBefore: 169000.0,
        balanceAfter: 170200.0,
        status: 'Reversed',
        timestamp: now.subtract(const Duration(days: 10)),
        reason: 'System Reversal for Interrupted Party Room Event',
        fee: 0.0,
        reversalReason: 'Room server disconnect during high value gift round',
      ),
      // 8. Pending Transfer
      CategorizedTransactionModel(
        transactionId: 'tx_dia_108',
        category: 'Transfer',
        amount: 800.0,
        currency: 'Diamonds',
        direction: TransactionDirection.debit,
        senderName: 'Danial Khan',
        senderId: 'user_1001',
        receiverName: 'Elena Rostova',
        receiverId: 'user_2004',
        balanceBefore: 170200.0,
        balanceAfter: 169400.0,
        status: 'Pending',
        timestamp: now.subtract(const Duration(hours: 1)),
        reason: 'P2P Gift Transfer Verification',
        fee: 8.0,
      ),
      // 9. Failed Withdrawal
      CategorizedTransactionModel(
        transactionId: 'tx_dia_109',
        category: 'Withdrawal',
        amount: 3000.0,
        currency: 'USD',
        direction: TransactionDirection.debit,
        senderName: 'Danial Khan',
        senderId: 'user_1001',
        receiverName: 'Wire Transfer ****4410',
        receiverId: 'WIRE_4410',
        balanceBefore: 2500.0,
        balanceAfter: 2500.0,
        status: 'Failed',
        timestamp: now.subtract(const Duration(days: 12)),
        reason: 'Withdrawal Request Rejected',
        fee: 0.0,
        failureReason: 'Invalid IBAN routing code supplied by user',
      ),
    ]);
  }

  void setCategoryFilter(String category) {
    if (_selectedCategoryFilter == category) return;
    _selectedCategoryFilter = category;
    _currentPage = 1;
    _hasMore = true;
    logAudit('filter changed', extra: {'filter': category});
    notifyListeners();
  }

  Future<void> fetchInitialData() async {
    _isLoading = true;
    _errorMessage = null;
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshData() async {
    logAudit('refresh');
    _errorMessage = null;
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));
    final filtered = _filterTransactions();
    if ((_currentPage + 1) * _pageSize >= filtered.length) {
      _hasMore = false;
    }
    _currentPage++;
    _isLoadingMore = false;
    notifyListeners();
  }

  void logAudit(String event, {Map<String, dynamic>? extra}) {
    final entry = '${DateTime.now().toIso8601String()} | AUDIT: $event ${extra != null ? extra.toString() : ''}';
    _auditLogs.add(entry);
  }

  List<CategorizedTransactionModel> _filterTransactions() {
    if (_selectedCategoryFilter.toLowerCase() == 'all') {
      return _allLedgerEntries;
    }
    // Backward compatibility with legacy filter string ('Received', 'Sent', etc.)
    if (_selectedCategoryFilter.toLowerCase() == 'received') {
      return _allLedgerEntries.where((t) => t.direction == TransactionDirection.credit).toList();
    }
    if (_selectedCategoryFilter.toLowerCase() == 'sent') {
      return _allLedgerEntries.where((t) => t.direction == TransactionDirection.debit).toList();
    }

    return _allLedgerEntries.where((t) {
      final cat = t.category.toLowerCase();
      final sel = _selectedCategoryFilter.toLowerCase();
      if (sel == 'gift/reward') {
        return cat.contains('gift') || cat.contains('reward');
      }
      if (sel == 'refund/reversal') {
        return cat.contains('refund') || cat.contains('reversal');
      }
      return cat == sel;
    }).toList();
  }
}

