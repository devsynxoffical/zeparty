import 'package:flutter/foundation.dart';
import '../models/coin_seller_model.dart';

class CoinAgencyProvider with ChangeNotifier {
  final List<CoinSellerModel> _sellers = [
    const CoinSellerModel(
      id: 'seller_1',
      userId: 'user_1001',
      name: 'Global Coins Ltd',
      avatarUrl: 'https://i.pravatar.cc/150?img=1',
      region: 'Global',
      type: SellerType.official,
      status: SellerStatus.approved,
      isVisible: true,
      paymentMethods: ['Google Play', 'Apple Pay', 'Visa', 'Mastercard'],
      stockCoins: 10000000,
    ),
    const CoinSellerModel(
      id: 'seller_2',
      userId: 'user_1002',
      name: 'Middle East Topup',
      avatarUrl: 'https://i.pravatar.cc/150?img=2',
      region: 'Middle East',
      type: SellerType.verified,
      status: SellerStatus.approved,
      isVisible: true,
      paymentMethods: ['Visa', 'Mastercard', 'STC Pay'],
      stockCoins: 500000,
    ),
    const CoinSellerModel(
      id: 'seller_3',
      userId: 'user_1003',
      name: 'Asia Swift Recharge',
      avatarUrl: 'https://i.pravatar.cc/150?img=3',
      region: 'Asia',
      type: SellerType.standard,
      status: SellerStatus.approved,
      isVisible: true,
      paymentMethods: ['WeChat Pay', 'Alipay', 'Visa'],
      stockCoins: 250000,
    ),
  ];

  List<CoinSellerModel> get sellers => _sellers;
  List<CoinSellerModel> get approvedSellers => _sellers.where((s) => s.status == SellerStatus.approved && s.isVisible).toList();

  String _searchQuery = '';
  String _selectedRegion = 'All';

  String get searchQuery => _searchQuery;
  String get selectedRegion => _selectedRegion;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setRegionFilter(String region) {
    _selectedRegion = region;
    notifyListeners();
  }

  List<CoinSellerModel> get filteredSellers {
    return approvedSellers.where((s) {
      final matchesSearch = s.name.toLowerCase().contains(_searchQuery.toLowerCase()) || s.id.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRegion = _selectedRegion == 'All' || s.region == _selectedRegion;
      return matchesSearch && matchesRegion;
    }).toList();
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
