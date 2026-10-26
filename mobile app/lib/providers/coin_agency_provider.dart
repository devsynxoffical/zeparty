import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/coin_seller_model.dart';
import '../core/services/api_client.dart';
import '../core/services/socket_service.dart';

class CoinAgencyProvider with ChangeNotifier {
  final List<CoinSellerModel> _sellers = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  UserCountryInfo? _userCountryInfo;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;

  String _searchQuery = '';
  String? _currentUserCountry;
  Timer? _debounceTimer;
  int _searchSequence = 0;

  List<CoinSellerModel> get sellers => List.unmodifiable(_sellers);
  List<CoinSellerModel> get approvedSellers =>
      _sellers.where((s) => s.status == SellerStatus.approved && s.isVisible).toList();

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  UserCountryInfo? get userCountryInfo => _userCountryInfo;
  String get countryDisplayName =>
      _userCountryInfo?.label ?? (_currentUserCountry ?? 'Pakistan');
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalCount => _totalCount;
  bool get hasMore => _currentPage < _totalPages;

  String get searchQuery => _searchQuery;
  String? get currentUserCountry => _currentUserCountry;

  StreamSubscription? _roleSubscription;
  bool _isCurrentSellerRevoked = false;
  bool get isCurrentSellerRevoked => _isCurrentSellerRevoked;

  CoinAgencyProvider() {
    _initSocketRoleListener();
  }

  void _initSocketRoleListener() {
    _roleSubscription = SocketService.instance.onUserRoleUpdated.listen((event) {
      final status = event['sellerStatus']?.toString().toUpperCase() ?? event['status']?.toString().toUpperCase();
      final isSeller = event['isSeller'];
      if (status == 'REVOKED' || status == 'SUSPENDED' || status == 'INACTIVE' || isSeller == false) {
        _isCurrentSellerRevoked = true;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _roleSubscription?.cancel();
    super.dispose();
  }

  static const String countryPrefKey = 'zeparty_selected_seller_country';

  Future<void> initSelectedCountry(String fallbackRegion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCountry = prefs.getString(countryPrefKey);
      if (savedCountry != null && savedCountry.isNotEmpty) {
        _currentUserCountry = savedCountry;
      } else {
        _currentUserCountry = fallbackRegion.isNotEmpty ? fallbackRegion : 'Pakistan';
      }
    } catch (_) {
      _currentUserCountry = fallbackRegion.isNotEmpty ? fallbackRegion : 'Pakistan';
    }
    notifyListeners();
  }

  void setUserCountry(String? country, {bool persist = true}) {
    _currentUserCountry = country;
    notifyListeners();

    if (persist && country != null && country.isNotEmpty) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(countryPrefKey, country);
      }).catchError((_) {});
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      fetchSellers(search: query, page: 1);
    });
  }

  /// Country equivalence matcher (normalizes names and codes, e.g. Pakistan, PK)
  static bool isCountryMatch(String? sellerRegion, String? userCountry) {
    if (sellerRegion == null || userCountry == null) return false;
    final s = sellerRegion.trim().toLowerCase();
    final u = userCountry.trim().toLowerCase();
    if (s.isEmpty || u.isEmpty) return false;
    if (s == u) return true;

    // Normalizations for Pakistan
    if ((s == 'pakistan' || s == 'pk') && (u == 'pakistan' || u == 'pk')) {
      return true;
    }

    // Normalizations for US, UK, UAE
    if ((s == 'united states' || s == 'usa' || s == 'us') &&
        (u == 'united states' || u == 'usa' || u == 'us')) {
      return true;
    }
    if ((s == 'united kingdom' || s == 'uk' || s == 'gb') &&
        (u == 'united kingdom' || u == 'uk' || u == 'gb')) {
      return true;
    }
    if ((s == 'uae' || s == 'united arab emirates' || s == 'ae') &&
        (u == 'uae' || u == 'united arab emirates' || u == 'ae')) {
      return true;
    }

    return s.contains(u) || u.contains(s);
  }

  /// Returns approved sellers strictly filtered by the user's registered country
  List<CoinSellerModel> getSellersForCountry(String? userCountry) {
    final country = userCountry ?? _currentUserCountry;
    final query = _searchQuery.trim().toLowerCase();

    return approvedSellers.where((s) {
      // Preserve country isolation strictly
      if (!isCountryMatch(s.region, country) && !isCountryMatch(s.countryName, country)) {
        return false;
      }

      // Filter by search query if present (supports nickname, name, publicUserId, id)
      if (query.isNotEmpty) {
        final matchesName = s.name.toLowerCase().contains(query) ||
            s.nickname.toLowerCase().contains(query);
        final matchesId = s.id.toLowerCase().contains(query) ||
            s.userId.toLowerCase().contains(query) ||
            s.publicUserId.toLowerCase().contains(query);
        if (!matchesName && !matchesId) return false;
      }

      return true;
    }).toList();
  }

  List<CoinSellerModel> get filteredSellers => getSellersForCountry(_currentUserCountry);

  /// Fetch registered and approved coin sellers from backend API
  Future<void> fetchSellers({
    String? country,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final sequence = ++_searchSequence;
    _isLoading = (page == 1);
    if (page == 1) _errorMessage = null;

    if (country != null && country.isNotEmpty) {
      _currentUserCountry = country;
    }
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      final activeSearch = (search ?? _searchQuery).trim();
      if (activeSearch.isNotEmpty) {
        queryParams['search'] = activeSearch;
      }

      Response res;
      try {
        res = await ApiClient.instance.get('/v1/sellers/public', queryParameters: queryParams);
      } catch (_) {
        res = await ApiClient.instance.get('/v1/sellers', queryParameters: queryParams);
      }

      if (sequence != _searchSequence) return; // Stale request guard

      if (res.statusCode == 200 && res.data != null) {
        final rawData = res.data;

        // Parse country information from userCountry object
        if (rawData['userCountry'] is Map<String, dynamic>) {
          _userCountryInfo = UserCountryInfo.fromJson(rawData['userCountry'] as Map<String, dynamic>);
        }

        // Parse pagination metadata
        if (rawData['pagination'] is Map<String, dynamic>) {
          final p = rawData['pagination'] as Map<String, dynamic>;
          _currentPage = int.tryParse(p['page']?.toString() ?? '$page') ?? page;
          _totalPages = int.tryParse(p['totalPages']?.toString() ?? '1') ?? 1;
          _totalCount = int.tryParse(p['totalCount']?.toString() ?? '0') ?? 0;
        }

        final rawList = rawData['data'] is List
            ? rawData['data'] as List
            : (rawData['sellers'] is List ? rawData['sellers'] as List : []);

        final fetched = <CoinSellerModel>[];
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            fetched.add(CoinSellerModel.fromJson(item));
          }
        }

        if (page == 1) {
          _sellers.clear();
          _sellers.addAll(fetched);
        } else {
          final existingIds = _sellers.map((s) => s.id).toSet();
          for (final item in fetched) {
            if (existingIds.add(item.id)) {
              _sellers.add(item);
            }
          }
        }
        _errorMessage = null;
      } else {
        if (page == 1) {
          _errorMessage = 'Failed to load sellers. Please try again.';
        }
      }
    } catch (e) {
      if (sequence == _searchSequence && page == 1) {
        _errorMessage = e.toString();
      }
    } finally {
      if (sequence == _searchSequence) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreSellers() async {
    if (_isLoadingMore || !hasMore || _isLoading) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      await fetchSellers(page: _currentPage + 1);
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void addSeller(CoinSellerModel seller) {
    _sellers.add(seller);
    notifyListeners();
  }

  void updateSeller(CoinSellerModel updatedSeller) {
    final index = _sellers.indexWhere((s) => s.id == updatedSeller.id);
    if (index != -1) {
      _sellers[index] = updatedSeller;
      notifyListeners();
    }
  }

  void deleteSeller(String id) {
    _sellers.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  /// Verifies active seller authorization with backend. In case of revocation (403),
  /// invalidates seller state immediately (Item 41).
  Future<bool> verifySellerAccess() async {
    try {
      final res = await ApiClient.instance.get('/v1/sellers/me');
      if (res.statusCode == 200 && res.data != null) {
        _isCurrentSellerRevoked = false;
        notifyListeners();
        return true;
      }
      return false;
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 403 || dioErr.response?.statusCode == 401) {
        _isCurrentSellerRevoked = true;
        notifyListeners();
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
