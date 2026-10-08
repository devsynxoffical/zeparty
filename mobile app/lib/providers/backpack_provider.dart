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
      final merged = List<UserAssetModel>.from(items);

      if (currentUser != null && currentUser.id.isNotEmpty) {
        _mergeAssignedFrames(merged, currentUser);
      }

      _userAssets = merged;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // If offline or network error, synthesize from currentUser
      if (currentUser != null && currentUser.id.isNotEmpty) {
        final localList = <UserAssetModel>[];
        _mergeAssignedFrames(localList, currentUser);
        _userAssets = localList;
      }
      _isLoading = false;
      _errorMessage = 'Failed to load backpack';
      debugPrint('[BackpackProvider] fetchBackpack error: $e');
      notifyListeners();
    }
  }

  static const List<Map<String, String>> _allAvailableFrames = [
    {'key': 'host', 'name': 'Official Host Frame', 'asset': 'assets/roles/host_frame.webp'},
    {'key': 'king', 'name': 'King Supreme Frame', 'asset': 'assets/nobles/king_frame.webp'},
    {'key': 'emperor', 'name': 'Emperor Celestial Frame', 'asset': 'assets/nobles/emperor_frame.webp'},
    {'key': 'duke', 'name': 'Duke Royal Frame', 'asset': 'assets/nobles/duke_frame.webp'},
    {'key': 'marquis', 'name': 'Marquis Royal Frame', 'asset': 'assets/nobles/marquis_frame.webp'},
    {'key': 'count', 'name': 'Count Royal Frame', 'asset': 'assets/nobles/count_frame.webp'},
    {'key': 'viscount', 'name': 'Viscount Royal Frame', 'asset': 'assets/nobles/viscount_frame.webp'},
    {'key': 'baron', 'name': 'Baron Royal Frame', 'asset': 'assets/nobles/baron_frame.webp'},
    {'key': 'admin', 'name': 'Super Admin Frame', 'asset': 'assets/roles/admin_frame.webp'},
    {'key': 'agency', 'name': 'Agency Boss Frame', 'asset': 'assets/roles/agency_frame.webp'},
    {'key': 'cs', 'name': 'Customer Support Frame', 'asset': 'assets/roles/cs_frame.webp'},
    {'key': 'ceo', 'name': 'Executive CEO Frame', 'asset': 'assets/roles/ceo_frame.webp'},
    {'key': 'bd', 'name': 'Business Development Frame', 'asset': 'assets/roles/bd_frame.webp'},
    {'key': 'game_master', 'name': 'Game Master Frame', 'asset': 'assets/roles/game_master_frame.webp'},
    {'key': 'coins_seller', 'name': 'Coins Seller Frame', 'asset': 'assets/roles/coins_seller_frame.webp'},
    {'key': 'merchant', 'name': 'Official Merchant Frame', 'asset': 'assets/roles/merchant_frame.webp'},
    {'key': 'lover', 'name': 'Romantic Lover Frame', 'asset': 'assets/roles/lover_frame.webp'},
    {'key': 'manager', 'name': 'Operations Manager Frame', 'asset': 'assets/roles/manager_frame.webp'},
    {'key': 'official', 'name': 'ZeParty Official Frame', 'asset': 'assets/roles/official_frame.webp'},
    {'key': 'top_fan', 'name': 'Top Fan VIP Frame', 'asset': 'assets/roles/top_fan_frame.webp'},
    {'key': 'assistant', 'name': 'Official Assistant Frame', 'asset': 'assets/roles/assistant_frame.webp'},
    {'key': 'boss', 'name': 'Big Boss Frame', 'asset': 'assets/roles/boss_frame.webp'},
    {'key': 'svip15', 'name': 'SVIP 15 Infinite Divinity Frame', 'asset': 'assets/svip/svip15_frame.webp'},
    {'key': 'svip14', 'name': 'SVIP 14 Supreme Deity Frame', 'asset': 'assets/svip/svip14_frame.webp'},
    {'key': 'svip13', 'name': 'SVIP 13 Immortal Frame', 'asset': 'assets/svip/svip13_frame.webp'},
    {'key': 'svip12', 'name': 'SVIP 12 Monarch Frame', 'asset': 'assets/svip/svip12_frame.webp'},
    {'key': 'svip11', 'name': 'SVIP 11 Sovereign Frame', 'asset': 'assets/svip/svip11_frame.webp'},
    {'key': 'svip10', 'name': 'SVIP 10 Dragon Frame', 'asset': 'assets/svip/svip10_frame.webp'},
    {'key': 'svip9', 'name': 'SVIP 9 Phoenix Frame', 'asset': 'assets/svip/svip9_frame.webp'},
    {'key': 'svip8', 'name': 'SVIP 8 Celestial Frame', 'asset': 'assets/svip/svip8_frame.webp'},
    {'key': 'svip7', 'name': 'SVIP 7 Aurora Frame', 'asset': 'assets/svip/svip7_frame.webp'},
    {'key': 'svip6', 'name': 'SVIP 6 Obsidian Frame', 'asset': 'assets/svip/svip6_frame.webp'},
    {'key': 'mystery', 'name': 'Mystery Astral Frame', 'asset': 'assets/animations/mystery_frame.webp'},
  ];

  void _mergeAssignedFrames(List<UserAssetModel> list, UserModel user) {
    final isHost = user.isHost || user.role == UserRole.host;
    final nobleTitle = user.nobleTitle?.toLowerCase().trim();
    final currentFrame = user.avatarFrame.toLowerCase().trim();

    // Determine default equipped frame if avatarFrame is empty
    String defaultFrameKey = '';
    if (isHost) {
      defaultFrameKey = 'host';
    } else if (nobleTitle != null && nobleTitle.isNotEmpty) {
      defaultFrameKey = nobleTitle;
    } else if (user.role == UserRole.admin) {
      defaultFrameKey = 'admin';
    } else if (user.isAgency || user.role == UserRole.agency) {
      defaultFrameKey = 'agency';
    }

    for (final item in _allAvailableFrames) {
      final key = item['key']!;
      final name = item['name']!;
      final assetPath = item['asset']!;

      bool isEquipped = false;
      if (currentFrame != 'none') {
        if (currentFrame.isNotEmpty) {
          isEquipped = currentFrame == key || currentFrame.contains(key) || currentFrame == assetPath;
        } else {
          isEquipped = (defaultFrameKey == key);
        }
      }

      final alreadyExists = list.any((a) =>
          a.id.contains(key) ||
          a.asset?.imageUrl == assetPath ||
          a.asset?.name == name);

      if (!alreadyExists) {
        final userAsset = UserAssetModel(
          id: 'assigned-frame-$key-${user.id}',
          userId: user.id,
          assetId: 'assigned-asset-$key-frame',
          isEquipped: isEquipped,
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          asset: StoreItemModel(
            id: 'assigned-asset-$key-frame',
            name: name,
            categoryId: 'Frame',
            assetType: 'AVATAR_FRAME',
            imageUrl: assetPath,
            priceCoins: 0,
          ),
        );

        // Put equipped frame at top, others follow
        if (isEquipped) {
          list.insert(0, userAsset);
        } else {
          list.add(userAsset);
        }
      }
    }
  }

  Future<bool> equipAsset(String userAssetId, {void Function(String)? onAvatarFrameChanged}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _backpackRepository.equipAsset(userAssetId);
      final targetType = updated.asset?.assetType ?? 'AVATAR_FRAME';
      
      for (int i = 0; i < _userAssets.length; i++) {
        if (_userAssets[i].id == userAssetId || _userAssets[i].id == updated.id) {
          _userAssets[i] = _userAssets[i].copyWith(isEquipped: true);
        } else if (_userAssets[i].asset?.assetType == targetType) {
          _userAssets[i] = _userAssets[i].copyWith(isEquipped: false);
        }
      }

      if (targetType == 'AVATAR_FRAME') {
        final frameAsset = updated.asset?.imageUrl ?? updated.asset?.name ?? 'host';
        onAvatarFrameChanged?.call(frameAsset);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Fallback local equip for assigned assets
      if (userAssetId.startsWith('assigned-frame-')) {
        for (int i = 0; i < _userAssets.length; i++) {
          if (_userAssets[i].id == userAssetId) {
            _userAssets[i] = _userAssets[i].copyWith(isEquipped: true);
            final frameAsset = _userAssets[i].asset?.imageUrl ?? 'host';
            onAvatarFrameChanged?.call(frameAsset);
          } else if (_userAssets[i].asset?.assetType == 'AVATAR_FRAME') {
            _userAssets[i] = _userAssets[i].copyWith(isEquipped: false);
          }
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      _errorMessage = e.toString();
      debugPrint('[BackpackProvider] equipAsset error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> unequipAsset(String userAssetId, {void Function(String)? onAvatarFrameChanged}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _backpackRepository.unequipAsset(userAssetId);
      final index = _userAssets.indexWhere((a) => a.id == userAssetId);
      if (index != -1) {
        _userAssets[index] = _userAssets[index].copyWith(isEquipped: false);
        if (_userAssets[index].asset?.assetType == 'AVATAR_FRAME') {
          onAvatarFrameChanged?.call('none');
        }
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Fallback local unequip for assigned assets
      if (userAssetId.startsWith('assigned-frame-')) {
        final index = _userAssets.indexWhere((a) => a.id == userAssetId);
        if (index != -1) {
          _userAssets[index] = _userAssets[index].copyWith(isEquipped: false);
          onAvatarFrameChanged?.call('none');
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      _errorMessage = e.toString();
      debugPrint('[BackpackProvider] unequipAsset error: $e');
      notifyListeners();
      return false;
    }
  }
}
