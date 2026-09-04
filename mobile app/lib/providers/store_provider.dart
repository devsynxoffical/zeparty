import 'package:flutter/material.dart';
import '../models/store_item_model.dart';
import 'wallet_provider.dart';

class StoreProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final List<StoreItemModel> _items = [
    // Cars
    const StoreItemModel(
      id: 'car_1',
      categoryId: 'Cars',
      name: 'Golden Sports Car',
      imageUrl: 'assets/images/cars/car_gold.png',
      durationDays: 30,
      priceCoins: 500000,
    ),
    const StoreItemModel(
      id: 'car_2',
      categoryId: 'Cars',
      name: 'Luxury SUV',
      imageUrl: 'assets/images/cars/suv_black.png',
      durationDays: 30,
      priceCoins: 400000,
    ),
    const StoreItemModel(
      id: 'car_3',
      categoryId: 'Cars',
      name: 'Hypercar',
      imageUrl: 'assets/images/cars/hypercar.png',
      durationDays: 30,
      priceCoins: 800000,
    ),

    // Frame
    const StoreItemModel(
      id: 'frame_1',
      categoryId: 'Frame',
      name: 'Golden Warrior',
      imageUrl: 'assets/images/frames/warrior.png',
      durationDays: 15,
      priceCoins: 300000,
    ),
    const StoreItemModel(
      id: 'frame_2',
      categoryId: 'Frame',
      name: 'Spider Hero',
      imageUrl: 'assets/images/frames/spider.png',
      durationDays: 15,
      priceCoins: 400000,
    ),
    
    // Bubble
    const StoreItemModel(
      id: 'bubble_1',
      categoryId: 'Bubble',
      name: 'Unicorn Dream',
      imageUrl: 'assets/images/bubbles/unicorn.png',
      durationDays: 30,
      priceCoins: 200000,
    ),
  ];

  List<String> get categories => ['Cars', 'Frame', 'Special card', 'Bubble', 'Background'];

  List<StoreItemModel> getItemsByCategory(String categoryId) {
    return _items.where((item) => item.categoryId == categoryId).toList();
  }

  /// Simulate fetching from backend
  Future<void> fetchStoreItems() async {
    _isLoading = true;
    notifyListeners();
    
    await Future.delayed(const Duration(milliseconds: 800));
    
    _isLoading = false;
    notifyListeners();
  }

  /// Purchase an item using the wallet provider
  Future<bool> purchaseItem(StoreItemModel item, WalletProvider wallet) async {
    // Attempt to spend coins idempotently via the wallet
    final success = wallet.spendCoins(item.priceCoins, 'purchase_${item.id}_${DateTime.now().millisecondsSinceEpoch}');
    if (success) {
      // Simulate backend delay for adding item to inventory
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }
    return false;
  }

  /// Send an item as a gift using the wallet provider
  Future<bool> sendItem(StoreItemModel item, String recipientId, WalletProvider wallet) async {
    // Attempt to spend coins idempotently via the wallet
    final success = wallet.spendCoins(item.priceCoins, 'send_${item.id}_to_${recipientId}_${DateTime.now().millisecondsSinceEpoch}');
    if (success) {
      // Simulate backend delay for delivering item
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }
    return false;
  }
}
