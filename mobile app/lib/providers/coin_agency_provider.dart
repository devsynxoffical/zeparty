import 'package:flutter/foundation.dart';
import '../models/coin_seller_model.dart';
import '../core/services/api_client.dart';

class CoinAgencyProvider with ChangeNotifier {
  final List<CoinSellerModel> _sellers = [];
  bool _isLoading = false;

  List<CoinSellerModel> get sellers => List.unmodifiable(_sellers);
  List<CoinSellerModel> get approvedSellers => _sellers.where((s) => s.status == SellerStatus.approved && s.isVisible).toList();
  bool get isLoading => _isLoading;

  String _searchQuery = '';
  String? _currentUserCountry;

  String get searchQuery => _searchQuery;
  String? get currentUserCountry => _currentUserCountry;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setUserCountry(String? country) {
    _currentUserCountry = country;
    notifyListeners();
  }

  /// Country equivalence matcher (normalizes names and codes, e.g. Pakistan, PK)
  static bool isCountryMatch(String? sellerRegion, String? userCountry) {
    if (sellerRegion == null || userCountry == null) return false;
    final s = sellerRegion.trim().toLowerCase();
    final u = userCountry.trim().toLowerCase();
    if (s.isEmpty || u.isEmpty) return false;
    if (s == u) return true;

    // Normalizations for Pakistan
    if ((s == 'pakistan' || s == 'pk') && (u == 'pakistan' || u == 'pk')) return true;

    // Normalizations for US, UK, UAE
    if ((s == 'united states' || s == 'usa' || s == 'us') && (u == 'united states' || u == 'usa' || u == 'us')) return true;
    if ((s == 'united kingdom' || s == 'uk' || s == 'gb') && (u == 'united kingdom' || u == 'uk' || u == 'gb')) return true;
    if ((s == 'uae' || s == 'united arab emirates' || s == 'ae') && (u == 'uae' || u == 'united arab emirates' || u == 'ae')) return true;

    return s.contains(u) || u.contains(s);
  }

  /// Returns approved sellers strictly filtered by the user's registered country
  List<CoinSellerModel> getSellersForCountry(String? userCountry) {
    final country = userCountry ?? _currentUserCountry;
    final query = _searchQuery.trim().toLowerCase();

    return approvedSellers.where((s) {
      // Must match user country strictly
      if (!isCountryMatch(s.region, country)) {
        return false;
      }

      // Filter by search query if present
      if (query.isNotEmpty) {
        final matchesName = s.name.toLowerCase().contains(query);
        final matchesId = s.id.toLowerCase().contains(query) || s.userId.toLowerCase().contains(query);
        if (!matchesName && !matchesId) return false;
      }

      return true;
    }).toList();
  }

  List<CoinSellerModel> get filteredSellers => getSellersForCountry(_currentUserCountry);

  /// Fetch registered and approved coin sellers from backend API
  Future<void> fetchSellers({String? country}) async {
    _isLoading = true;
    if (country != null && country.isNotEmpty) {
      _currentUserCountry = country;
    }
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{};
      if (_currentUserCountry != null && _currentUserCountry!.isNotEmpty) {
        queryParams['country'] = _currentUserCountry;
      }
      final res = await ApiClient.instance.get('/v1/agency/sellers', queryParameters: queryParams);
      if (res.statusCode == 200 && res.data['data'] != null) {
        final list = res.data['data'] as List;
        _sellers.clear();
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            _sellers.add(CoinSellerModel.fromJson(item));
          }
        }
      }
    } catch (_) {
      // Per Module 29 requirements: Never repopulate sample/mock sellers on error or empty response
    } finally {
      _isLoading = false;
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
}
