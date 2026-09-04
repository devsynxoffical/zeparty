import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegionProvider extends ChangeNotifier {
  String _selectedRegionCode = 'GLOBAL';
  String _selectedRegionFlag = '🌍';
  bool _isInitialized = false;

  String get selectedRegionCode => _selectedRegionCode;
  String get selectedRegionFlag => _selectedRegionFlag;
  bool get isInitialized => _isInitialized;

  RegionProvider() {
    _loadRegion();
  }

  Future<void> _loadRegion() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedRegionCode = prefs.getString('selected_country') ?? 'GLOBAL';
    // Mapping back flag might need the country list, but we can just let CountryPicker handle the initial sync
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setRegion(String code, String flag) async {
    _selectedRegionCode = code;
    _selectedRegionFlag = flag;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_country', code);
    notifyListeners();
  }
}
