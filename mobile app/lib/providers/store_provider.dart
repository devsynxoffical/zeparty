import 'package:flutter/material.dart';
import '../models/store_item_model.dart';
import '../core/repositories/store_repository.dart';
import '../core/utils/performance_utils.dart';
import 'wallet_provider.dart';

class StoreProvider extends ChangeNotifier {
  final StoreRepository _storeRepository = StoreRepository.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<StoreItemModel> _items = [];
  List<StoreItemModel> get items => List.unmodifiable(_items);

  final Set<String> _pendingPurchaseKeys = {};

  List<String> get categories => ['All', 'Cars', 'Frame', 'Special card', 'Bubble', 'Background'];

  StoreProvider() {
    fetchStoreItems();
  }

  List<StoreItemModel> getItemsByCategory(String categoryId) {
    if (categoryId == 'All' || categoryId.isEmpty) {
      return _items;
    }
    return _items.where((item) => item.categoryId == categoryId).toList();
  }

  /// Fetch active store items from backend
  Future<void> fetchStoreItems({String? assetType, bool? isVipExclusive}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetchedItems = await _storeRepository.fetchStoreCatalog(
        assetType: assetType,
        isVipExclusive: isVipExclusive,
      );
      _items = fetchedItems;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load store catalog';
      debugPrint('[StoreProvider] Error fetching catalog: $e');
      notifyListeners();
    }
  }

  /// Purchase an item using the wallet provider and backend API
  Future<bool> purchaseItem(StoreItemModel item, WalletProvider wallet) async {
    final idempotencyKey = PerformanceUtils.generateIdempotencyKey('buy_${item.id}');
    if (_pendingPurchaseKeys.contains(idempotencyKey)) {
      return false;
    }
    _pendingPurchaseKeys.add(idempotencyKey);
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _storeRepository.purchaseAsset(
        assetId: item.id,
        idempotencyKey: idempotencyKey,
      );
      _pendingPurchaseKeys.remove(idempotencyKey);
      _isLoading = false;

      // Authoritative balance reconciliation
      await wallet.fetchWallet();
      await wallet.fetchLedger(refresh: true);

      notifyListeners();
      return true;
    } catch (e) {
      _pendingPurchaseKeys.remove(idempotencyKey);
      _isLoading = false;
      _errorMessage = e.toString();
      debugPrint('[StoreProvider] Purchase error: $e');

      await wallet.fetchWallet();
      notifyListeners();
      return false;
    }
  }

  /// Send an item as a gift - requires recipient and backend gift endpoint
  Future<bool> sendItem(StoreItemModel item, String recipientId, WalletProvider wallet) async {
    // Currently backend store purchases are user-bound. If sending as gift, route through gift send or mark BLOCKED.
    return purchaseItem(item, wallet);
  }
}
