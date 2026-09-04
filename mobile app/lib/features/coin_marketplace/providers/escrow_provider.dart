import 'package:flutter/material.dart';
import '../models/p2p_order.dart';

class EscrowProvider extends ChangeNotifier {
  final List<P2POrder> _orders = [];

  List<P2POrder> get orders => List.unmodifiable(_orders);

  List<P2POrder> getUserOrders(String userId) {
    return _orders.where((o) => o.buyerId == userId || o.sellerId == userId).toList();
  }

  void createOrder(P2POrder order) {
    _orders.insert(0, order);
    notifyListeners();
  }

  void updateOrderStatus(String orderId, String newStatus, {DateTime? paidAt, DateTime? completedAt}) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      final old = _orders[index];
      _orders[index] = P2POrder(
        id: old.id,
        offerId: old.offerId,
        buyerId: old.buyerId,
        buyerName: old.buyerName,
        buyerAvatar: old.buyerAvatar,
        sellerId: old.sellerId,
        sellerName: old.sellerName,
        sellerAvatar: old.sellerAvatar,
        coins: old.coins,
        fiatAmount: old.fiatAmount,
        fiatCurrency: old.fiatCurrency,
        paymentMethod: old.paymentMethod,
        status: newStatus,
        createdAt: old.createdAt,
        paidAt: paidAt ?? old.paidAt,
        completedAt: completedAt ?? old.completedAt,
      );
      notifyListeners();
    }
  }
}
