import 'package:flutter/material.dart';
import '../models/vip_item_model.dart';
import '../core/repositories/store_repository.dart';
import 'wallet_provider.dart';

class VipProvider extends ChangeNotifier {
  final StoreRepository _storeRepository = StoreRepository.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<VipItemModel> _vipItems = [];
  List<VipItemModel> get vipItems => List.unmodifiable(_vipItems);

  final List<String> _ownedItemIds = [];
  List<VipItemModel> get ownedItems =>
      _vipItems.where((item) => _ownedItemIds.contains(item.id)).toList();

  VipProvider() {
    fetchVipCatalog();
  }

  /// Fetch VIP exclusive items from the backend store
  Future<void> fetchVipCatalog() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final items = await _storeRepository.fetchStoreCatalog(isVipExclusive: true);
      _vipItems = items
          .map((item) => VipItemModel.fromStoreItem(item, isOwned: _ownedItemIds.contains(item.id)))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load VIP items';
      debugPrint('[VipProvider] fetchVipCatalog error: $e');
      notifyListeners();
    }
  }

  /// Purchase VIP item through the authoritative store backend
  Future<bool> purchaseVipItem(String itemId, WalletProvider wallet) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _storeRepository.purchaseAsset(assetId: itemId);
      _ownedItemIds.add(itemId);
      _isLoading = false;

      // Re-map with ownership updated
      _vipItems = _vipItems
          .map((item) => item.id == itemId
              ? VipItemModel(
                  id: item.id,
                  title: item.title,
                  description: item.description,
                  icon: item.icon,
                  category: item.category,
                  coinPrice: item.coinPrice,
                  validityPeriod: item.validityPeriod,
                  isOwned: true,
                )
              : item)
          .toList();

      await wallet.fetchWallet();
      await wallet.fetchLedger(refresh: true);
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      debugPrint('[VipProvider] purchaseVipItem error: $e');
      await wallet.fetchWallet();
      notifyListeners();
      return false;
    }
  }
}
