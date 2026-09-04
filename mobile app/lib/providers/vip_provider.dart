import 'package:flutter/material.dart';
import '../models/vip_item_model.dart';
import '../core/constants/dummy_data.dart';

class VipProvider extends ChangeNotifier {
  final List<VipItemModel> _vipItems = List.from(DummyData.vipItems);

  List<VipItemModel> get vipItems => _vipItems;
  List<VipItemModel> get ownedItems => _vipItems.where((item) => item.isOwned).toList();

  void purchaseVipItem(String itemId) {
    final index = _vipItems.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      final item = _vipItems[index];
      _vipItems[index] = VipItemModel(
        id: item.id,
        title: item.title,
        description: item.description,
        icon: item.icon,
        category: item.category,
        coinPrice: item.coinPrice,
        validityPeriod: item.validityPeriod,
        isOwned: true,
      );
      notifyListeners();
    }
  }
}
