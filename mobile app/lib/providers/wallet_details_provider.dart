import 'package:flutter/material.dart';
import '../models/categorized_transaction_model.dart';
import '../models/user_model.dart';
import '../core/repositories/wallet_repository.dart';

class WalletDetailsProvider extends ChangeNotifier {
  final WalletRepository _repository = WalletRepository.instance;
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
    fetchInitialData();
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

    try {
      final items = await _repository.fetchLedger();
      if (items.isNotEmpty) {
        _allLedgerEntries.clear();
        for (final item in items) {
          _allLedgerEntries.add(
            CategorizedTransactionModel(
              transactionId: item.id,
              category: item.type,
              amount: item.amount,
              currency: item.currency,
              direction: item.amount >= 0 ? TransactionDirection.credit : TransactionDirection.debit,
              senderName: 'ZeParty Network',
              senderId: 'SYSTEM',
              receiverName: 'Self',
              receiverId: 'user_me',
              balanceBefore: (item.balanceAfter ?? 0) - item.amount,
              balanceAfter: (item.balanceAfter ?? 0).toDouble(),
              status: item.status,
              timestamp: item.date,
              reason: item.title,
            ),
          );
        }
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load ledger: $e';
      notifyListeners();
    }
  }

  Future<void> refreshData() async {
    logAudit('refresh');
    _errorMessage = null;
    _currentPage = 1;
    _hasMore = true;
    await fetchInitialData();
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

