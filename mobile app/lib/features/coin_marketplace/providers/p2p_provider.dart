import 'package:flutter/material.dart';
import '../models/p2p_offer.dart';

class P2PProvider extends ChangeNotifier {
  final List<P2POffer> _offers = [
    // Dummy Data
    P2POffer(
      id: 'offer_1',
      sellerId: 'user_1',
      sellerName: 'CryptoKing',
      sellerAvatar: 'https://i.pravatar.cc/150?img=11',
      type: 'sell',
      totalCoins: 10000,
      availableCoins: 10000,
      fiatPricePerCoin: 0.05,
      fiatCurrency: 'USD',
      acceptedPaymentMethods: ['Bank Transfer', 'PayPal'],
      minLimit: 100,
      maxLimit: 5000,
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    P2POffer(
      id: 'offer_2',
      sellerId: 'user_2',
      sellerName: 'CoinMaster',
      sellerAvatar: 'https://i.pravatar.cc/150?img=12',
      type: 'buy',
      totalCoins: 5000,
      availableCoins: 5000,
      fiatPricePerCoin: 0.048,
      fiatCurrency: 'USD',
      acceptedPaymentMethods: ['Zelle', 'CashApp'],
      minLimit: 50,
      maxLimit: 2000,
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  List<P2POffer> get offers => List.unmodifiable(_offers);
  
  List<P2POffer> get sellOffers => _offers.where((o) => o.type == 'sell' && o.status == 'active').toList();
  List<P2POffer> get buyOffers => _offers.where((o) => o.type == 'buy' && o.status == 'active').toList();

  void createOffer(P2POffer offer) {
    _offers.insert(0, offer);
    notifyListeners();
  }

  void updateOffer(P2POffer updatedOffer) {
    final index = _offers.indexWhere((o) => o.id == updatedOffer.id);
    if (index != -1) {
      _offers[index] = updatedOffer;
      notifyListeners();
    }
  }

  void cancelOffer(String offerId) {
    final index = _offers.indexWhere((o) => o.id == offerId);
    if (index != -1) {
      final old = _offers[index];
      _offers[index] = P2POffer(
        id: old.id,
        sellerId: old.sellerId,
        sellerName: old.sellerName,
        sellerAvatar: old.sellerAvatar,
        type: old.type,
        totalCoins: old.totalCoins,
        availableCoins: old.availableCoins,
        fiatPricePerCoin: old.fiatPricePerCoin,
        fiatCurrency: old.fiatCurrency,
        acceptedPaymentMethods: old.acceptedPaymentMethods,
        minLimit: old.minLimit,
        maxLimit: old.maxLimit,
        status: 'cancelled',
        createdAt: old.createdAt,
      );
      notifyListeners();
    }
  }
}
