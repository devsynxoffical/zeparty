import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_asset_model.dart';
import '../models/store_item_model.dart';
import '../models/user_model.dart';
import '../core/repositories/backpack_repository.dart';
import '../core/repositories/store_repository.dart';
import '../core/utils/noble_badge_helper.dart';

class BackpackProvider extends ChangeNotifier {
  final BackpackRepository _backpackRepository = BackpackRepository.instance;
  static const String _purchasesStorageKey = 'persisted_user_purchases_v1';

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<UserAssetModel> _userAssets = [];
  List<UserAssetModel> get userAssets => List.unmodifiable(_userAssets);

  BackpackProvider() {
    _loadLocalPurchases().then((_) => fetchBackpack());
  }

  Future<void> _loadLocalPurchases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_purchasesStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        for (final item in list) {
          final ua = UserAssetModel.fromJson(item as Map<String, dynamic>);
          final assetId = ua.assetId.toLowerCase().trim();
          final exists = _userAssets.any((existing) =>
              existing.id == ua.id ||
              existing.assetId.toLowerCase().trim() == assetId ||
              (existing.asset != null && existing.asset!.id.toLowerCase().trim() == assetId));
          if (!exists) {
            _userAssets.insert(0, _enrichUserAsset(ua));
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[BackpackProvider] _loadLocalPurchases error: $e');
    }
  }

  Future<void> _saveLocalPurchases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final purchases = _userAssets.where((a) => a.id.startsWith('purchased-')).toList();
      final raw = jsonEncode(purchases.map((a) => a.toJson()).toList());
      await prefs.setString(_purchasesStorageKey, raw);
    } catch (e) {
      debugPrint('[BackpackProvider] _saveLocalPurchases error: $e');
    }
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

  UserAssetModel _enrichUserAsset(UserAssetModel ua) {
    StoreItemModel? asset = ua.asset;
    final assetId = ua.assetId.toLowerCase().trim();

    // 1. Check for exact stable catalog ID match in defaultStoreCatalog or adminSpecialRoleAssets
    StoreItemModel? catalogMatch;
    for (final item in StoreRepository.defaultStoreCatalog) {
      if (item.id.toLowerCase().trim() == assetId ||
          (asset != null && item.id.toLowerCase().trim() == asset.id.toLowerCase().trim())) {
        catalogMatch = item;
        break;
      }
    }
    if (catalogMatch == null) {
      for (final item in StoreRepository.adminSpecialRoleAssets) {
        if (item.id.toLowerCase().trim() == assetId ||
            (asset != null && item.id.toLowerCase().trim() == asset.id.toLowerCase().trim())) {
          catalogMatch = item;
          break;
        }
      }
    }

    if (catalogMatch != null) {
      // Enforce the approved catalog item's exact artwork and details
      asset = StoreItemModel(
        id: catalogMatch.id,
        name: catalogMatch.name,
        categoryId: (asset != null && asset.categoryId.isNotEmpty) ? asset.categoryId : catalogMatch.categoryId,
        assetType: (asset != null && asset.assetType.isNotEmpty) ? asset.assetType : catalogMatch.assetType,
        imageUrl: catalogMatch.imageUrl,
        assetUrl: catalogMatch.assetUrl,
        priceCoins: (asset != null && asset.priceCoins > 0) ? asset.priceCoins : catalogMatch.priceCoins,
        durationDays: (asset != null && asset.durationDays > 0) ? asset.durationDays : catalogMatch.durationDays,
      );
    } else if (asset != null &&
        (asset.imageUrl.startsWith('assets/') ||
            asset.imageUrl.startsWith('http://') ||
            asset.imageUrl.startsWith('https://'))) {
      // Preserve existing valid asset/remote URL
      asset = asset;
    } else {
      // Only resolve via NobleBadgeHelper if asset image is completely empty or unresolved
      final candidateName = asset?.name ?? '';
      String resolvedImage = asset?.imageUrl ?? '';
      if (resolvedImage.isEmpty || (!resolvedImage.startsWith('assets/') && !resolvedImage.startsWith('http'))) {
        final localFrame = NobleBadgeHelper.getFrameAsset(candidateName) ?? NobleBadgeHelper.getFrameAsset(assetId);
        final localBadge = NobleBadgeHelper.getBadgeAsset(candidateName) ?? NobleBadgeHelper.getBadgeAsset(assetId);
        final localTag = NobleBadgeHelper.getTagAsset(candidateName);
        resolvedImage = localFrame ?? localBadge ?? localTag ?? 'assets/store/ZP-134_avatar-frames_frame.webp';
      }

      asset = StoreItemModel(
        id: ua.assetId.isNotEmpty ? ua.assetId : ua.id,
        name: candidateName.isNotEmpty ? candidateName : 'Store Item',
        categoryId: (asset?.categoryId.isNotEmpty == true) ? asset!.categoryId : 'Frame',
        assetType: (asset?.assetType.isNotEmpty == true) ? asset!.assetType : 'AVATAR_FRAME',
        imageUrl: resolvedImage,
        priceCoins: asset?.priceCoins ?? 50000,
        durationDays: asset?.durationDays ?? 30,
      );
    }

    return ua.copyWith(asset: asset);
  }

  Future<void> fetchBackpack({bool refresh = false, UserModel? currentUser}) async {
    _isLoading = true;
    _errorMessage = null;
    if (refresh) notifyListeners();

    final localPurchased = _userAssets.where((a) => a.id.startsWith('purchased-')).toList();

    try {
      final items = await _backpackRepository.fetchBackpack();
      final enrichedBackend = items.map((ua) => _enrichUserAsset(ua)).toList();

      final mergedAssets = List<UserAssetModel>.from(enrichedBackend);

      for (final local in localPurchased) {
        final localAssetId = local.assetId.toLowerCase().trim();
        final localItemName = (local.asset?.name ?? '').toLowerCase().trim();

        final exists = mergedAssets.any((b) {
          final bId = b.assetId.toLowerCase().trim();
          final bNestedId = (b.asset?.id ?? '').toLowerCase().trim();
          final bName = (b.asset?.name ?? '').toLowerCase().trim();
          return bId == localAssetId || bNestedId == localAssetId || (bName.isNotEmpty && bName == localItemName);
        });

        if (!exists) {
          mergedAssets.insert(0, _enrichUserAsset(local));
        }
      }

      _userAssets = mergedAssets;
      _isLoading = false;
      _saveLocalPurchases();
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      if (localPurchased.isNotEmpty) {
        final existingIds = _userAssets.map((a) => a.id).toSet();
        for (final lp in localPurchased) {
          if (!existingIds.contains(lp.id)) {
            _userAssets.insert(0, _enrichUserAsset(lp));
          }
        }
      }
      _saveLocalPurchases();
      _errorMessage = 'Failed to load backpack';
      debugPrint('[BackpackProvider] fetchBackpack error: $e');
      notifyListeners();
    }
  }

  Future<bool> equipAsset(
    String userAssetId, {
    void Function(String)? onAvatarFrameChanged,
    void Function(String)? onBadgeChanged,
  }) async {
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

      final assetImage = _userAssets[index].asset?.imageUrl ?? '';
      final assetName = _userAssets[index].asset?.name ?? '';
      final type = (_userAssets[index].asset?.assetType ?? '').toUpperCase();
      final cat = (_userAssets[index].asset?.categoryId ?? '').toUpperCase();

      if (type.contains('FRAME') || cat.contains('FRAME') || assetName.toLowerCase().contains('frame') || assetName.toLowerCase().contains('merchant')) {
        String frameAsset = assetImage;
        // Only use NobleBadgeHelper fallback if assetImage is NOT already an approved asset/URL path
        if (!frameAsset.startsWith('assets/') && !frameAsset.startsWith('http://') && !frameAsset.startsWith('https://')) {
          final resolved = NobleBadgeHelper.getFrameAsset(assetName) ??
              NobleBadgeHelper.getFrameAsset(assetImage);
          if (resolved != null) {
            frameAsset = resolved;
          } else if (frameAsset.isEmpty) {
            frameAsset = NobleBadgeHelper.getFrameAsset(assetName) ?? assetName;
          }
        }
        onAvatarFrameChanged?.call(frameAsset);
      } else if (type.contains('BADGE') || cat.contains('BADGE') || assetName.toLowerCase().contains('badge')) {
        String badgeAsset = assetImage;
        if (!badgeAsset.startsWith('assets/') && !badgeAsset.startsWith('http://') && !badgeAsset.startsWith('https://')) {
          final resolved = NobleBadgeHelper.getBadgeAsset(assetName) ??
              NobleBadgeHelper.getBadgeAsset(assetImage);
          if (resolved != null) {
            badgeAsset = resolved;
          }
        }
        onBadgeChanged?.call(badgeAsset);
      }
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> unequipAsset(
    String userAssetId, {
    void Function(String)? onAvatarFrameChanged,
    void Function(String)? onBadgeChanged,
  }) async {
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
      final type = (_userAssets[index].asset?.assetType ?? '').toUpperCase();
      final cat = (_userAssets[index].asset?.categoryId ?? '').toUpperCase();
      final assetName = (_userAssets[index].asset?.name ?? '').toLowerCase();

      _userAssets[index] = _userAssets[index].copyWith(isEquipped: false);

      if (type.contains('FRAME') || cat.contains('FRAME') || assetName.contains('frame') || assetName.contains('merchant')) {
        onAvatarFrameChanged?.call('none');
      } else if (type.contains('BADGE') || cat.contains('BADGE') || assetName.contains('badge')) {
        onBadgeChanged?.call('');
      }
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Check if a store item is already owned in backpack
  bool isItemOwned(StoreItemModel item) {
    final cleanItemId = item.id.toLowerCase().trim();
    final cleanItemName = item.name.toLowerCase().trim();

    return _userAssets.any((ua) {
      if (ua.isExpired) return false;

      final uaAssetId = ua.assetId.toLowerCase().trim();
      final uaNestedId = (ua.asset?.id ?? '').toLowerCase().trim();
      if (uaAssetId == cleanItemId || uaNestedId == cleanItemId) {
        return true;
      }

      final assetName = (ua.asset?.name ?? '').toLowerCase().trim();
      if (assetName.isNotEmpty && assetName == cleanItemName) {
        return true;
      }

      return false;
    });
  }

  /// Add a newly purchased store item directly to user's backpack
  void addPurchasedAsset(StoreItemModel item) {
    final userAsset = UserAssetModel(
      id: 'purchased-${item.id}-${DateTime.now().millisecondsSinceEpoch}',
      userId: 'current-user',
      assetId: item.id,
      isEquipped: false,
      expiresAt: DateTime.now().add(Duration(days: item.durationDays)),
      asset: item,
      createdAt: DateTime.now(),
    );

    // Remove any previous duplicate / expired entry of this exact item
    _userAssets.removeWhere((ua) =>
        ua.assetId.toLowerCase().trim() == item.id.toLowerCase().trim() ||
        (ua.asset != null && ua.asset!.id.toLowerCase().trim() == item.id.toLowerCase().trim()) ||
        (ua.asset != null && ua.asset!.name.toLowerCase().trim() == item.name.toLowerCase().trim()));

    _userAssets.insert(0, _enrichUserAsset(userAsset));
    _saveLocalPurchases();
    notifyListeners();
  }
}

