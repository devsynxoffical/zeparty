import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/api_client.dart';
import '../models/mystery_suit_model.dart';
import 'wallet_provider.dart';

class MysteryProvider extends ChangeNotifier {
  static const String _storageKey = 'zeparty_mystery_status_v1';

  final ApiClient _apiClient = ApiClient.instance;

  bool _isActive = false;
  DateTime? _expiryDate;
  bool _isMysteryIdentityEnabled = false;
  bool _hasDukeFreeAccess = false;
  bool _isLoading = false;

  bool get isActive {
    if (_isActive && _expiryDate != null && _expiryDate!.isBefore(DateTime.now())) {
      _isActive = false; // Auto expire
    }
    return _isActive;
  }

  DateTime? get expiryDate => _expiryDate;
  bool get isMysteryIdentityEnabled => _isMysteryIdentityEnabled;
  bool get hasDukeFreeAccess => _hasDukeFreeAccess;
  bool get isLoading => _isLoading;
  MysterySuitModel get currentPackage => MysterySuitModel.standard;

  MysteryProvider() {
    _loadFromLocal();
    fetchMysteryStatus();
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _isActive = data['isActive'] == true;
        if (data['expiresAt'] != null) {
          _expiryDate = DateTime.tryParse(data['expiresAt'].toString());
        }
        _isMysteryIdentityEnabled = data['isMysteryIdentityEnabled'] == true;
        _hasDukeFreeAccess = data['hasDukeFreeAccess'] == true;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'isActive': _isActive,
        'expiresAt': _expiryDate?.toIso8601String(),
        'isMysteryIdentityEnabled': _isMysteryIdentityEnabled,
        'hasDukeFreeAccess': _hasDukeFreeAccess,
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> fetchMysteryStatus() async {
    try {
      final res = await _apiClient.get('/v1/mystery/status');
      if (res.statusCode == 200 && res.data?['data'] != null) {
        final data = res.data['data'] as Map<String, dynamic>;
        _isActive = data['isActive'] == true;
        if (data['expiresAt'] != null) {
          _expiryDate = DateTime.tryParse(data['expiresAt'].toString());
        }
        _hasDukeFreeAccess = data['hasDukeFreeAccess'] == true;
        if (data['isMysteryIdentityEnabled'] != null) {
          _isMysteryIdentityEnabled = data['isMysteryIdentityEnabled'] == true;
        }
        await _saveToLocal();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> purchaseMysterySuit(WalletProvider wallet, {bool isDukeFreeClaim = false}) async {
    _isLoading = true;
    notifyListeners();

    final pkg = MysterySuitModel.standard;

    try {
      final res = await _apiClient.post('/v1/mystery/purchase', data: {
        'isDukeFreeClaim': isDukeFreeClaim,
      });

      if (res.statusCode == 200 && res.data?['data'] != null) {
        final data = res.data['data'] as Map<String, dynamic>;
        _isActive = true;
        if (data['expiresAt'] != null) {
          _expiryDate = DateTime.tryParse(data['expiresAt'].toString());
        } else {
          _expiryDate = DateTime.now().add(Duration(days: pkg.durationDays));
        }
        _isMysteryIdentityEnabled = true;
        await _saveToLocal();
        await wallet.fetchWallet();
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[MysteryProvider] backend purchase error: $e');
    }

    // Local fallback for offline / preview
    final success = isDukeFreeClaim || wallet.spendCoins(pkg.price, 'mystery_suit_${DateTime.now().millisecondsSinceEpoch}');
    if (success) {
      if (isActive && _expiryDate != null) {
        _expiryDate = _expiryDate!.add(Duration(days: pkg.durationDays));
      } else {
        _isActive = true;
        _expiryDate = DateTime.now().add(Duration(days: isDukeFreeClaim ? 7 : pkg.durationDays));
        _isMysteryIdentityEnabled = true;
      }
      await _saveToLocal();
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  void toggleMysteryIdentity(bool value) {
    if (isActive) {
      _isMysteryIdentityEnabled = value;
      _saveToLocal();
      notifyListeners();
    }
  }
}
