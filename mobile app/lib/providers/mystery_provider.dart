import 'package:flutter/material.dart';
import '../models/mystery_suit_model.dart';
import 'wallet_provider.dart';

class MysteryProvider extends ChangeNotifier {
  bool _isActive = false;
  DateTime? _expiryDate;
  bool _isMysteryIdentityEnabled = false; // Used for privacy settings toggle

  bool get isActive {
    if (_isActive && _expiryDate != null && _expiryDate!.isBefore(DateTime.now())) {
      _isActive = false; // Auto expire
    }
    return _isActive;
  }

  DateTime? get expiryDate => _expiryDate;
  bool get isMysteryIdentityEnabled => _isMysteryIdentityEnabled;
  MysterySuitModel get currentPackage => MysterySuitModel.standard;

  Future<bool> purchaseMysterySuit(WalletProvider wallet) async {
    final pkg = MysterySuitModel.standard;
    final success = wallet.spendCoins(pkg.price, 'mystery_suit_${DateTime.now().millisecondsSinceEpoch}');
    if (success) {
      await Future.delayed(const Duration(milliseconds: 500));
      
      // If already active, stack the duration
      if (isActive && _expiryDate != null) {
        _expiryDate = _expiryDate!.add(Duration(days: pkg.durationDays));
      } else {
        _isActive = true;
        _expiryDate = DateTime.now().add(Duration(days: pkg.durationDays));
        _isMysteryIdentityEnabled = true; // Auto enable on first purchase
      }
      
      notifyListeners();
      return true;
    }
    return false;
  }

  void toggleMysteryIdentity(bool value) {
    if (isActive) {
      _isMysteryIdentityEnabled = value;
      notifyListeners();
    }
  }
}
