import 'package:flutter/material.dart';
import '../models/user_asset_model.dart';
import '../models/store_item_model.dart';
import '../models/user_model.dart';
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

  String? get equippedFrameUrl {
    for (final a in _userAssets) {
      if (a.isEquipped && !a.isExpired) {
        final type = (a.asset?.assetType ?? '').toUpperCase();
        final cat = (a.asset?.categoryId ?? '').toUpperCase();
        if (type.contains('FRAME') || cat.contains('FRAME')) {
          return a.asset?.imageUrl ?? a.asset?.name;
        }
      }
    }
    return null;
  }

  String? get equippedBubbleUrl {
    for (final a in _userAssets) {
      if (a.isEquipped && !a.isExpired) {
        final type = (a.asset?.assetType ?? '').toUpperCase();
        final cat = (a.asset?.categoryId ?? '').toUpperCase();
        if (type.contains('BUBBLE') || cat.contains('BUBBLE')) {
          return a.asset?.imageUrl;
        }
      }
    }
    return null;
  }

  String? get equippedThemeUrl {
    for (final a in _userAssets) {
      if (a.isEquipped && !a.isExpired) {
        final type = (a.asset?.assetType ?? '').toUpperCase();
        final cat = (a.asset?.categoryId ?? '').toUpperCase();
        if (type.contains('THEME') || type.contains('BACKGROUND') || cat.contains('BACKGROUND')) {
          return a.asset?.imageUrl;
        }
      }
    }
    return null;
  }

  List<UserAssetModel> getAssetsByCategory(String category) {
    if (category == 'All') return _userAssets;
    return _userAssets.where((a) {
      final itemCategory = a.asset?.categoryId ?? '';
      return itemCategory.toLowerCase() == category.toLowerCase();
    }).toList();
  }

  Future<void> fetchBackpack({bool refresh = false, UserModel? currentUser}) async {
    _isLoading = true;
    _errorMessage = null;
    if (refresh) notifyListeners();

    try {
      final items = await _backpackRepository.fetchBackpack();
      _userAssets = List<UserAssetModel>.from(items);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load backpack';
      debugPrint('[BackpackProvider] fetchBackpack error: $e');
      notifyListeners();
    }
  }

  Future<bool> equipAsset(String userAssetId, {void Function(String)? onAvatarFrameChanged}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _backpackRepository.equipAsset(userAssetId);
    } catch (e) {
      debugPrint('[BackpackProvider] Backend equip error (using local equip fallback): $e');
    }

    final index = _userAssets.indexWhere((a) => a.id == userAssetId || a.assetId == userAssetId || (a.asset != null && a.asset!.id == userAssetId));
    if (index != -1) {
      final targetType = _userAssets[index].asset?.assetType ?? 'AVATAR_FRAME';
      for (int i = 0; i < _userAssets.length; i++) {
        final itemType = _userAssets[i].asset?.assetType ?? 'AVATAR_FRAME';
        if (i == index) {
          _userAssets[i] = _userAssets[i].copyWith(isEquipped: true);
        } else if (itemType == targetType) {
          _userAssets[i] = _userAssets[i].copyWith(isEquipped: false);
        }
      }

      final frameAsset = _userAssets[index].asset?.imageUrl ?? _userAssets[index].asset?.name ?? '';
      if (frameAsset.isNotEmpty) {
        onAvatarFrameChanged?.call(frameAsset);
      }
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> unequipAsset(String userAssetId, {void Function(String)? onAvatarFrameChanged}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _backpackRepository.unequipAsset(userAssetId);
    } catch (e) {
      debugPrint('[BackpackProvider] Backend unequip error (using local unequip fallback): $e');
    }

    final index = _userAssets.indexWhere((a) => a.id == userAssetId || a.assetId == userAssetId || (a.asset != null && a.asset!.id == userAssetId));
    if (index != -1) {
      _userAssets[index] = _userAssets[index].copyWith(isEquipped: false);
      onAvatarFrameChanged?.call('none');
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Check if a store item is already owned in backpack
  bool isItemOwned(StoreItemModel item) {
    final cleanItemName = item.name.toLowerCase().trim();
    return _userAssets.any((ua) {
      if (ua.isExpired) return false;
      if (ua.assetId == item.id || (ua.asset != null && ua.asset!.id == item.id)) return true;

      final assetName = (ua.asset?.name ?? '').toLowerCase().trim();
      if (assetName.isNotEmpty && (assetName == cleanItemName || assetName.contains(cleanItemName) || cleanItemName.contains(assetName))) {
        return true;
      }
      return false;
    });
  }

  /// Add a newly purchased store item directly to user's backpack
  void addPurchasedAsset(StoreItemModel item) {
    final alreadyOwned = isItemOwned(item);
    if (!alreadyOwned) {
      final userAsset = UserAssetModel(
        id: 'purchased-${item.id}-${DateTime.now().millisecondsSinceEpoch}',
        userId: 'current-user',
        assetId: item.id,
        isEquipped: false,
        expiresAt: DateTime.now().add(Duration(days: item.durationDays)),
        asset: item,
        createdAt: DateTime.now(),
      );
      _userAssets.insert(0, userAsset);
      notifyListeners();
    }
  }
}
