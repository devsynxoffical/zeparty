import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../core/constants/dummy_data.dart';

class HostAgencyProvider extends ChangeNotifier {
  bool _isHostApplied = true;
  String _hostStatus = 'Approved Host';

  final int _totalStreams = 48;
  final double _streamingHours = 124.5;
  final int _totalGiftEarnings = 184500;
  final double _commissionEarned = 1450.00;

  final List<UserModel> _managedHosts = List.from(DummyData.popularUsers);

  bool get isHostApplied => _isHostApplied;
  String get hostStatus => _hostStatus;
  int get totalStreams => _totalStreams;
  double get streamingHours => _streamingHours;
  int get totalGiftEarnings => _totalGiftEarnings;
  double get commissionEarned => _commissionEarned;
  List<UserModel> get managedHosts => _managedHosts;

  void applyForHost(String realName, String idCardNumber, String bio) {
    _isHostApplied = true;
    _hostStatus = 'Pending Approval';
    notifyListeners();
  }

  void addHostToAgency(UserModel user) {
    _managedHosts.add(user);
    notifyListeners();
  }

  void removeHostFromAgency(String userId) {
    _managedHosts.removeWhere((h) => h.id == userId);
    notifyListeners();
  }
}
