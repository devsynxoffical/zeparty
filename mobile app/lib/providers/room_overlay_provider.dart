import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/live_room_model.dart';
import '../features/live/live_room_screen.dart';
import '../features/party_room/live_party_room_screen.dart';
import 'live_provider.dart';
import 'live_party_provider.dart';

class RoomOverlayProvider extends ChangeNotifier {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _isMinimized = false;
  String? _roomType; // 'LIVE' or 'PARTY'
  LiveRoomModel? _activeRoom;
  Offset _position = const Offset(16, 120);

  bool get isMinimized => _isMinimized;
  String? get roomType => _roomType;
  LiveRoomModel? get activeRoom => _activeRoom;
  Offset get position => _position;

  void minimizeRoom({required String roomType, required LiveRoomModel room}) {
    _isMinimized = true;
    _roomType = roomType;
    _activeRoom = room;
    notifyListeners();
  }

  void expandRoom([BuildContext? context]) {
    if (_activeRoom == null || _roomType == null) return;

    final targetRoom = _activeRoom!;
    final targetType = _roomType!;

    _isMinimized = false;
    notifyListeners();

    final navState = navigatorKey.currentState ?? (context != null ? Navigator.maybeOf(context) : null);

    if (navState != null) {
      if (targetType == 'LIVE') {
        navState.push(
          MaterialPageRoute(
            builder: (_) => LiveRoomScreen(room: targetRoom),
          ),
        );
      } else {
        navState.push(
          MaterialPageRoute(
            builder: (_) => LivePartyRoomScreen(room: targetRoom),
          ),
        );
      }
    } else {
      debugPrint('[RoomOverlayProvider] Error: No NavigatorState found to expand room.');
    }
  }

  Future<void> closeRoom(BuildContext context) async {
    final type = _roomType;
    _isMinimized = false;
    _activeRoom = null;
    _roomType = null;
    notifyListeners();

    if (type == 'LIVE') {
      await Provider.of<LiveProvider>(context, listen: false).leaveRoom();
    } else if (type == 'PARTY') {
      await Provider.of<LivePartyProvider>(context, listen: false).unjoinCurrentRoom();
    }
  }

  void updatePosition(Offset delta, Size screenSize) {
    double newX = _position.dx + delta.dx;
    double newY = _position.dy + delta.dy;

    const double cardWidth = 150;
    const double cardHeight = 190;

    newX = newX.clamp(8.0, (screenSize.width - cardWidth - 8.0).clamp(8.0, screenSize.width));
    newY = newY.clamp(40.0, (screenSize.height - cardHeight - 40.0).clamp(40.0, screenSize.height));

    _position = Offset(newX, newY);
    notifyListeners();
  }
}
