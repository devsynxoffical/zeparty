import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/live_room_model.dart';

/// Manages durable local persistence and overrides for room configuration:
/// - Custom Room Name & DP (Item 09)
/// - Configured Seat Capacity & Layout (Item 11)
/// - Locked Mic Seat Indices (Item 04 / 07 / Mic 7 & 8)
/// - Room Sending Coin Total (Item 08)
class RoomConfigManager extends ChangeNotifier {
  static final RoomConfigManager instance = RoomConfigManager._internal();
  RoomConfigManager._internal() {
    _loadFromPrefs();
  }

  final Map<String, String> _customTitles = {};
  final Map<String, String> _customCovers = {};
  final Map<String, int> _customCapacities = {};
  final Map<String, String> _customRoomTypes = {};
  final Map<String, Set<int>> _lockedSeats = {};
  final Map<String, num> _roomSendingTotals = {};

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  @visibleForTesting
  void resetForTesting() {
    _customTitles.clear();
    _customCovers.clear();
    _customCapacities.clear();
    _customRoomTypes.clear();
    _lockedSeats.clear();
    _roomSendingTotals.clear();
    _isLoaded = false;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (key.startsWith('zeparty_room_title_')) {
          final id = key.replaceFirst('zeparty_room_title_', '');
          final val = prefs.getString(key);
          if (val != null && val.isNotEmpty) _customTitles[id] = val;
        } else if (key.startsWith('zeparty_room_cover_')) {
          final id = key.replaceFirst('zeparty_room_cover_', '');
          final val = prefs.getString(key);
          if (val != null && val.isNotEmpty) _customCovers[id] = val;
        } else if (key.startsWith('zeparty_room_capacity_')) {
          final id = key.replaceFirst('zeparty_room_capacity_', '');
          final val = prefs.getInt(key);
          if (val != null && val > 0) _customCapacities[id] = val;
        } else if (key.startsWith('zeparty_room_type_')) {
          final id = key.replaceFirst('zeparty_room_type_', '');
          final val = prefs.getString(key);
          if (val != null && val.isNotEmpty) _customRoomTypes[id] = val;
        } else if (key.startsWith('zeparty_room_locked_seats_')) {
          final id = key.replaceFirst('zeparty_room_locked_seats_', '');
          final val = prefs.getString(key);
          if (val != null && val.isNotEmpty) {
            final list = (jsonDecode(val) as List).cast<int>();
            _lockedSeats[id] = list.toSet();
          }
        } else if (key.startsWith('zeparty_room_sending_total_')) {
          final id = key.replaceFirst('zeparty_room_sending_total_', '');
          final val = prefs.getDouble(key);
          if (val != null) _roomSendingTotals[id] = val;
        }
      }
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[RoomConfigManager] Error loading prefs: $e');
    }
  }

  // ── Room Title & Cover (Item 09) ──────────────────────────────────────────
  String? getCustomTitle(String roomId) => _customTitles[roomId];
  String? getCustomCover(String roomId) => _customCovers[roomId];

  Future<void> saveRoomProfile(String roomId, {String? title, String? coverUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    if (title != null && title.trim().isNotEmpty) {
      _customTitles[roomId] = title.trim();
      await prefs.setString('zeparty_room_title_$roomId', title.trim());
    }
    if (coverUrl != null && coverUrl.trim().isNotEmpty) {
      _customCovers[roomId] = coverUrl.trim();
      await prefs.setString('zeparty_room_cover_$roomId', coverUrl.trim());
    }
    notifyListeners();
  }

  // ── Room Capacity & Layout (Item 11) ──────────────────────────────────────
  int? getCustomCapacity(String roomId) => _customCapacities[roomId];
  String? getCustomRoomType(String roomId) => _customRoomTypes[roomId];

  Future<void> saveRoomLayout(String roomId, {required int capacity, required String roomType}) async {
    _customCapacities[roomId] = capacity;
    _customRoomTypes[roomId] = roomType;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('zeparty_room_capacity_$roomId', capacity);
    await prefs.setString('zeparty_room_type_$roomId', roomType);
    notifyListeners();
  }

  // ── Mic Seat Locking (Item 04 & 07, Mic 7 & 8) ───────────────────────────
  Set<int> getLockedSeats(String roomId) => Set.from(_lockedSeats[roomId] ?? {});

  Future<void> setSeatLocked(String roomId, int seatIndex, bool isLocked) async {
    final set = _lockedSeats.putIfAbsent(roomId, () => <int>{});
    if (isLocked) {
      set.add(seatIndex);
    } else {
      set.remove(seatIndex);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zeparty_room_locked_seats_$roomId', jsonEncode(set.toList()));
    notifyListeners();
  }

  // ── Room Sending Total (Item 08) ─────────────────────────────────────────
  num getRoomSendingTotal(String roomId) => _roomSendingTotals[roomId] ?? 0;

  Future<void> saveRoomSendingTotal(String roomId, num total) async {
    if (total <= 0 && (_roomSendingTotals[roomId] ?? 0) > 0) {
      // Do not silently overwrite a positive sending total with 0 on failure
      return;
    }
    _roomSendingTotals[roomId] = total;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('zeparty_room_sending_total_$roomId', total.toDouble());
    notifyListeners();
  }

  Future<void> addSendingCoins(String roomId, num coins) async {
    final current = getRoomSendingTotal(roomId);
    await saveRoomSendingTotal(roomId, current + coins);
  }

  /// Apply all saved persistent overrides onto a LiveRoomModel instance
  LiveRoomModel applyOverrides(LiveRoomModel room) {
    String title = _customTitles[room.id] ?? room.title;
    String cover = _customCovers[room.id] ?? room.coverUrl;
    int capacity = _customCapacities[room.id] ?? room.seatCapacity;
    String roomType = _customRoomTypes[room.id] ?? room.roomType;

    if (title != room.title || cover != room.coverUrl || capacity != room.seatCapacity || roomType != room.roomType) {
      return room.copyWith(
        title: title,
        coverUrl: cover,
        seatCapacity: capacity,
        roomType: roomType,
      );
    }
    return room;
  }
}
