import 'package:flutter/material.dart';
import '../models/user_asset_model.dart';
import '../core/repositories/backpack_repository.dart';

class BackpackProvider extends ChangeNotifier {
  final BackpackRepository _backpackRepository = BackpackRepository.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<UserAssetModel> _userAssets = [];
  List<UserAssetModel> get userAssets => List.unmodifiable(_userAssets);

  BackpackProvider() {
    fetchBackpack();
  }

  List<UserAssetModel> get equippedAssets =>
      _userAssets.where((a) => a.isEquipped && !a.isExpired).toList();

  List<UserAssetModel> getAssetsByCategory(String category) {
    if (category == 'All') return _userAssets;
    return _userAssets.where((a) {
      final itemCategory = a.asset?.categoryId ?? '';
      return itemCategory.toLowerCase() == category.toLowerCase();
    }).toList();
  }

  Future<void> fetchBackpack({bool refresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    if (refresh) notifyListeners();

    try {
      final items = await _backpackRepository.fetchBackpack();
      _userAssets = items;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load backpack';
      debugPrint('[BackpackProvider] fetchBackpack error: $e');
      notifyListeners();
    }
  }

  Future<bool> equipAsset(String userAssetId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _backpackRepository.equipAsset(userAssetId);
      // Update local state: unequip others with same assetType and equip this one
      final targetType = updated.asset?.assetType;
      for (int i = 0; i < _userAssets.length; i++) {
        if (_userAssets[i].id == updated.id) {
          _userAssets[i] = updated;
        } else if (targetType != null && _userAssets[i].asset?.assetType == targetType) {
          _userAssets[i] = _userAssets[i].copyWith(isEquipped: false);
        }
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      debugPrint('[BackpackProvider] equipAsset error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> unequipAsset(String userAssetId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _backpackRepository.unequipAsset(userAssetId);
      final index = _userAssets.indexWhere((a) => a.id == updated.id);
      if (index != -1) {
        _userAssets[index] = updated;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      debugPrint('[BackpackProvider] unequipAsset error: $e');
      notifyListeners();
      return false;
    }
  }
}
