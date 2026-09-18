import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_client.dart';

class SocketService {
  static final SocketService instance = SocketService._internal();
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  String? _currentRoomId;

  bool get isConnected => _isConnected;
  String? get currentRoomId => _currentRoomId;

  // Real-time Event Streams - Room
  final _userJoinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _userLeftController = StreamController<Map<String, dynamic>>.broadcast();
  final _viewerCountController = StreamController<Map<String, dynamic>>.broadcast();
  final _seatOccupiedController = StreamController<Map<String, dynamic>>.broadcast();
  final _seatReleasedController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomClosedController = StreamController<Map<String, dynamic>>.broadcast();
  final _giftSentController = StreamController<Map<String, dynamic>>.broadcast();

  // Social realtime event streams
  final _postCreatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _postDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _postLikedController = StreamController<Map<String, dynamic>>.broadcast();
  final _postUnlikedController = StreamController<Map<String, dynamic>>.broadcast();
  final _commentCreatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _commentDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _followCreatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _followRemovedController = StreamController<Map<String, dynamic>>.broadcast();

  // Moderation & Safety event streams
  final _moderationRestrictionController = StreamController<Map<String, dynamic>>.broadcast();
  final _moderationBanController = StreamController<Map<String, dynamic>>.broadcast();
  final _moderationUnbanController = StreamController<Map<String, dynamic>>.broadcast();

  // Support Ticket event streams
  final _ticketMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _ticketUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _ticketResolvedController = StreamController<Map<String, dynamic>>.broadcast();

  // Notification event streams
  final _notificationNewController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationReadController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationReadAllController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationBroadcastController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters - Room
  Stream<Map<String, dynamic>> get onUserJoined => _userJoinedController.stream;
  Stream<Map<String, dynamic>> get onUserLeft => _userLeftController.stream;
  Stream<Map<String, dynamic>> get onViewerCountChanged => _viewerCountController.stream;
  Stream<Map<String, dynamic>> get onSeatOccupied => _seatOccupiedController.stream;
  Stream<Map<String, dynamic>> get onSeatReleased => _seatReleasedController.stream;
  Stream<Map<String, dynamic>> get onRoomClosed => _roomClosedController.stream;
  Stream<Map<String, dynamic>> get onGiftSent => _giftSentController.stream;

  // Stream aliases for backwards compatibility
  Stream<Map<String, dynamic>> get userJoinedStream => onUserJoined;
  Stream<Map<String, dynamic>> get userLeftStream => onUserLeft;
  Stream<Map<String, dynamic>> get viewerCountStream => onViewerCountChanged;
  Stream<Map<String, dynamic>> get seatOccupiedStream => onSeatOccupied;
  Stream<Map<String, dynamic>> get seatReleasedStream => onSeatReleased;
  Stream<Map<String, dynamic>> get roomClosedStream => onRoomClosed;
  Stream<Map<String, dynamic>> get giftSentStream => onGiftSent;

  // Getters - Social
  Stream<Map<String, dynamic>> get onPostCreated => _postCreatedController.stream;
  Stream<Map<String, dynamic>> get onPostDeleted => _postDeletedController.stream;
  Stream<Map<String, dynamic>> get onPostLiked => _postLikedController.stream;
  Stream<Map<String, dynamic>> get onPostUnliked => _postUnlikedController.stream;
  Stream<Map<String, dynamic>> get onCommentCreated => _commentCreatedController.stream;
  Stream<Map<String, dynamic>> get onCommentDeleted => _commentDeletedController.stream;
  Stream<Map<String, dynamic>> get onFollowCreated => _followCreatedController.stream;
  Stream<Map<String, dynamic>> get onFollowRemoved => _followRemovedController.stream;

  // Getters - Moderation
  Stream<Map<String, dynamic>> get onModerationRestriction => _moderationRestrictionController.stream;
  Stream<Map<String, dynamic>> get onModerationBan => _moderationBanController.stream;
  Stream<Map<String, dynamic>> get onModerationUnban => _moderationUnbanController.stream;

  // Getters - Support
  Stream<Map<String, dynamic>> get onTicketMessage => _ticketMessageController.stream;
  Stream<Map<String, dynamic>> get onTicketUpdated => _ticketUpdatedController.stream;
  Stream<Map<String, dynamic>> get onTicketResolved => _ticketResolvedController.stream;

  // Getters - Notifications
  Stream<Map<String, dynamic>> get onNotificationNew => _notificationNewController.stream;
  Stream<Map<String, dynamic>> get onNotificationRead => _notificationReadController.stream;
  Stream<Map<String, dynamic>> get onNotificationReadAll => _notificationReadAllController.stream;
  Stream<Map<String, dynamic>> get onNotificationBroadcast => _notificationBroadcastController.stream;

  /// Connect to backend Socket.IO server with JWT token
  Future<void> connect({String? token}) async {
    final authToken = token ?? await ApiClient.instance.getAccessToken();
    if (authToken == null || authToken.isEmpty) {
      debugPrint('[SocketService] Cannot connect without valid JWT access token.');
      return;
    }

    if (_socket != null && _isConnected) {
      return;
    }

    final baseUrl = ApiClient.baseUrl;

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': authToken})
          .setExtraHeaders({'Authorization': 'Bearer $authToken'})
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1000)
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('[SocketService] Connected to backend realtime server ($baseUrl)');
      if (_currentRoomId != null) {
        joinRoomSubscription(_currentRoomId!);
      }
    });

    _socket!.onDisconnect((reason) {
      _isConnected = false;
      debugPrint('[SocketService] Disconnected from realtime server: $reason');
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      debugPrint('[SocketService] Connection error: $err');
    });

    _socket!.onError((err) {
      debugPrint('[SocketService] Socket error: $err');
    });

    // Register Authoritative Room Event Listeners
    _socket!.on('room:user_joined', (data) {
      if (data is Map) _userJoinedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('room:user_left', (data) {
      if (data is Map) _userLeftController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('room:viewer_count_changed', (data) {
      if (data is Map) _viewerCountController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('room:seat_occupied', (data) {
      if (data is Map) _seatOccupiedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('room:seat_released', (data) {
      if (data is Map) _seatReleasedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('room:closed', (data) {
      if (data is Map) _roomClosedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('room:gift_sent', (data) {
      if (data is Map) _giftSentController.add(Map<String, dynamic>.from(data));
    });

    // Social Events
    _socket!.on('post:created', (data) {
      if (data is Map) _postCreatedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('post:deleted', (data) {
      if (data is Map) _postDeletedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('post:liked', (data) {
      if (data is Map) _postLikedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('post:unliked', (data) {
      if (data is Map) _postUnlikedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('comment:created', (data) {
      if (data is Map) _commentCreatedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('comment:deleted', (data) {
      if (data is Map) _commentDeletedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('follow:created', (data) {
      if (data is Map) _followCreatedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('follow:removed', (data) {
      if (data is Map) _followRemovedController.add(Map<String, dynamic>.from(data));
    });

    // Moderation & Safety Events
    _socket!.on('moderation:restriction', (data) {
      if (data is Map) _moderationRestrictionController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('moderation:ban', (data) {
      if (data is Map) _moderationBanController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('moderation:unban', (data) {
      if (data is Map) _moderationUnbanController.add(Map<String, dynamic>.from(data));
    });

    // Support Events
    _socket!.on('ticket:message', (data) {
      if (data is Map) _ticketMessageController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('ticket:updated', (data) {
      if (data is Map) _ticketUpdatedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('ticket:resolved', (data) {
      if (data is Map) _ticketResolvedController.add(Map<String, dynamic>.from(data));
    });

    // Notification Events
    _socket!.on('notification:new', (data) {
      if (data is Map) _notificationNewController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('notification:read', (data) {
      if (data is Map) _notificationReadController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('notification:read_all', (data) {
      if (data is Map) _notificationReadAllController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('notification:broadcast', (data) {
      if (data is Map) _notificationBroadcastController.add(Map<String, dynamic>.from(data));
    });

    _socket!.connect();
  }

  /// Subscribe to room channel on server
  void joinRoomSubscription(String roomId) {
    _currentRoomId = roomId;
    if (_socket != null && _isConnected) {
      _socket!.emit('room:join', {'roomId': roomId});
      debugPrint('[SocketService] Subscribed to room:$roomId');
    }
  }

  void joinRoom(String roomId) => joinRoomSubscription(roomId);

  /// Unsubscribe from room channel on server
  void leaveRoomSubscription(String roomId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('room:leave', {'roomId': roomId});
      debugPrint('[SocketService] Unsubscribed from room:$roomId');
    }
    if (_currentRoomId == roomId) {
      _currentRoomId = null;
    }
  }

  void leaveRoom(String roomId) => leaveRoomSubscription(roomId);

  /// Occupy a seat via realtime socket emission
  void occupySeat(String roomId, int seatIndex) {
    if (_socket != null && _isConnected) {
      _socket!.emit('room:seat_occupy', {
        'roomId': roomId,
        'seatIndex': seatIndex,
      });
    }
  }

  /// Release a seat via realtime socket emission
  void leaveSeat(String roomId, int seatIndex) {
    if (_socket != null && _isConnected) {
      _socket!.emit('room:seat_leave', {
        'roomId': roomId,
        'seatIndex': seatIndex,
      });
    }
  }

  /// Disconnect socket cleanly
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _currentRoomId = null;
  }
}
