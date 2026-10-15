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
  Map<String, dynamic>? _cachedUserData;
  Completer<void>? _connectCompleter;

  bool get isConnected => _isConnected;
  String? get currentRoomId => _currentRoomId;

  // Real-time Event Streams - Room
  final _userJoinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _userLeftController = StreamController<Map<String, dynamic>>.broadcast();
  final _viewerCountController = StreamController<Map<String, dynamic>>.broadcast();
  final _seatOccupiedController = StreamController<Map<String, dynamic>>.broadcast();
  final _seatReleasedController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomCreatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomClosedController = StreamController<Map<String, dynamic>>.broadcast();
  final _giftSentController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomChatMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _userKickedController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomLikeController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomWarningController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomMutedController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomUserMutedController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomEmojiController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomSnapshotController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomRoleUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomMicInviteController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomMicInviteResponseController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomFeedClearedController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomDetailsUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomSeatLockedController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomLayoutUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomSendingTotalController = StreamController<Map<String, dynamic>>.broadcast();

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

  // Banner Real-time event streams
  final _bannerUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onBannerUpdated => _bannerUpdatedController.stream;

  // Direct Messaging Real-time event streams
  final _directMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _directMessageReadController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();

  // PK Battle Real-time event streams
  final _pkCreatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _pkParticipantJoinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _pkReadyController = StreamController<Map<String, dynamic>>.broadcast();
  final _pkStartedController = StreamController<Map<String, dynamic>>.broadcast();
  final _pkActiveController = StreamController<Map<String, dynamic>>.broadcast();
  final _pkScoreUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _pkEndedController = StreamController<Map<String, dynamic>>.broadcast();
  final _pkInvitationReceivedController = StreamController<Map<String, dynamic>>.broadcast();
  final _pkInvitationAcceptedController = StreamController<Map<String, dynamic>>.broadcast();
  final _pkInvitationDeclinedController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters - PK Battle
  Stream<Map<String, dynamic>> get onPkCreated => _pkCreatedController.stream;
  Stream<Map<String, dynamic>> get onPkParticipantJoined => _pkParticipantJoinedController.stream;
  Stream<Map<String, dynamic>> get onPkReady => _pkReadyController.stream;
  Stream<Map<String, dynamic>> get onPkStarted => _pkStartedController.stream;
  Stream<Map<String, dynamic>> get onPkActive => _pkActiveController.stream;
  Stream<Map<String, dynamic>> get onPkScoreUpdated => _pkScoreUpdatedController.stream;
  Stream<Map<String, dynamic>> get onPkEnded => _pkEndedController.stream;
  Stream<Map<String, dynamic>> get onPkInvitationReceived => _pkInvitationReceivedController.stream;
  Stream<Map<String, dynamic>> get onPkInvitationAccepted => _pkInvitationAcceptedController.stream;
  Stream<Map<String, dynamic>> get onPkInvitationDeclined => _pkInvitationDeclinedController.stream;

  // Getters - Room
  Stream<Map<String, dynamic>> get onUserJoined => _userJoinedController.stream;
  Stream<Map<String, dynamic>> get onUserLeft => _userLeftController.stream;
  Stream<Map<String, dynamic>> get onViewerCountChanged => _viewerCountController.stream;
  Stream<Map<String, dynamic>> get onSeatOccupied => _seatOccupiedController.stream;
  Stream<Map<String, dynamic>> get onSeatReleased => _seatReleasedController.stream;
  Stream<Map<String, dynamic>> get onRoomCreated => _roomCreatedController.stream;
  Stream<Map<String, dynamic>> get onRoomClosed => _roomClosedController.stream;
  Stream<Map<String, dynamic>> get onGiftSent => _giftSentController.stream;
  Stream<Map<String, dynamic>> get onRoomChatMessage => _roomChatMessageController.stream;
  Stream<Map<String, dynamic>> get onUserKicked => _userKickedController.stream;
  Stream<Map<String, dynamic>> get onRoomLike => _roomLikeController.stream;
  Stream<Map<String, dynamic>> get onRoomWarning => _roomWarningController.stream;
  Stream<Map<String, dynamic>> get onRoomMuted => _roomMutedController.stream;
  Stream<Map<String, dynamic>> get onRoomUserMuted => _roomUserMutedController.stream;
  Stream<Map<String, dynamic>> get onRoomEmoji => _roomEmojiController.stream;
  Stream<Map<String, dynamic>> get onRoomSnapshot => _roomSnapshotController.stream;
  Stream<Map<String, dynamic>> get onRoomRoleUpdated => _roomRoleUpdatedController.stream;
  Stream<Map<String, dynamic>> get onRoomMicInvite => _roomMicInviteController.stream;
  Stream<Map<String, dynamic>> get onRoomMicInviteResponse => _roomMicInviteResponseController.stream;
  Stream<Map<String, dynamic>> get onRoomFeedCleared => _roomFeedClearedController.stream;
  Stream<Map<String, dynamic>> get onRoomDetailsUpdated => _roomDetailsUpdatedController.stream;
  Stream<Map<String, dynamic>> get onSeatLocked => _roomSeatLockedController.stream;
  Stream<Map<String, dynamic>> get onRoomLayoutUpdated => _roomLayoutUpdatedController.stream;
  Stream<Map<String, dynamic>> get onRoomSendingTotalUpdated => _roomSendingTotalController.stream;

  // Stream aliases for backwards compatibility
  Stream<Map<String, dynamic>> get roomCreatedStream => onRoomCreated;
  Stream<Map<String, dynamic>> get userJoinedStream => onUserJoined;
  Stream<Map<String, dynamic>> get userLeftStream => onUserLeft;
  Stream<Map<String, dynamic>> get viewerCountStream => onViewerCountChanged;
  Stream<Map<String, dynamic>> get seatOccupiedStream => onSeatOccupied;
  Stream<Map<String, dynamic>> get seatReleasedStream => onSeatReleased;
  Stream<Map<String, dynamic>> get roomClosedStream => onRoomClosed;
  Stream<Map<String, dynamic>> get giftSentStream => onGiftSent;
  Stream<Map<String, dynamic>> get roomChatMessageStream => onRoomChatMessage;
  Stream<Map<String, dynamic>> get userKickedStream => onUserKicked;
  Stream<Map<String, dynamic>> get roomLikeStream => onRoomLike;
  Stream<Map<String, dynamic>> get roomWarningStream => onRoomWarning;
  Stream<Map<String, dynamic>> get roomMutedStream => onRoomMuted;
  Stream<Map<String, dynamic>> get roomUserMutedStream => onRoomUserMuted;
  Stream<Map<String, dynamic>> get roomSnapshotStream => onRoomSnapshot;
  Stream<Map<String, dynamic>> get roomRoleUpdatedStream => onRoomRoleUpdated;

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

  // Getters - Direct Messaging
  Stream<Map<String, dynamic>> get onDirectMessage => _directMessageController.stream;
  Stream<Map<String, dynamic>> get onDirectMessageRead => _directMessageReadController.stream;
  Stream<Map<String, dynamic>> get onChatTyping => _typingController.stream;

  void markMessageAsRead(String senderId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('direct_message_read', {'senderId': senderId});
    }
  }

  /// Connect to backend Socket.IO server with JWT token
  Future<void> connect({String? token, Map<String, dynamic>? user}) async {
    final authToken = token ?? await ApiClient.instance.getAccessToken() ?? 'guest_anonymous';

    if (user != null) {
      _cachedUserData = user;
    }

    final hasSameUser = user == null ||
        (_cachedUserData != null &&
         (user['id'] == _cachedUserData!['id'] || user['_id'] == _cachedUserData!['_id']));

    if (_socket != null && _socket!.connected && hasSameUser) {
      return;
    }

    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      return _connectCompleter!.future;
    }

    _connectCompleter = Completer<void>();

    // Safety timeout to prevent awaiting forever if server is unreachable
    Future.delayed(const Duration(seconds: 4), () {
      if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
        _connectCompleter!.complete();
      }
    });

    // Clean up any stale disconnected instance
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    final baseUrl = ApiClient.baseUrl;

    final authMap = <String, dynamic>{'token': authToken};
    if (user != null || _cachedUserData != null) {
      final u = user ?? _cachedUserData;
      authMap['user'] = u;
      if (u != null && (u['id'] != null || u['_id'] != null)) {
        authMap['userId'] = u['id'] ?? u['_id'];
      }
    }

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setAuth(authMap)
          .setExtraHeaders({'Authorization': 'Bearer $authToken'})
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('[SocketService] Connected to backend realtime server ($baseUrl)');
      if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
        _connectCompleter!.complete();
      }
      if (_currentRoomId != null) {
        joinRoomSubscription(_currentRoomId!, user: _cachedUserData);
      }
    });

    _socket!.onDisconnect((reason) {
      _isConnected = false;
      debugPrint('[SocketService] Disconnected from realtime server: $reason');
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      debugPrint('[SocketService] Connection notice: $err');
      if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
        _connectCompleter!.complete();
      }
    });

    _socket!.onError((err) {
      debugPrint('[SocketService] Socket error: $err');
      if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
        _connectCompleter!.complete();
      }
    });

    _socket!.on('error', (err) {
      debugPrint('[SocketService] Application error: $err');
    });

    // Helper for recursive safe string-key mapping
    Map<String, dynamic> safeMap(dynamic data) {
      if (data is! Map) return <String, dynamic>{};
      return data.map((key, value) {
        if (value is Map) {
          return MapEntry(key.toString(), safeMap(value));
        } else if (value is List) {
          return MapEntry(
            key.toString(),
            value.map((e) => e is Map ? safeMap(e) : e).toList(),
          );
        }
        return MapEntry(key.toString(), value);
      });
    }

    // Register Authoritative Room Event Listeners with multi-alias support & deduplication
    final Map<String, int> recentJoins = {};
    void handleUserJoined(dynamic data) {
      if (data != null) {
        final map = safeMap(data);
        final userObj = map['user'] is Map ? map['user'] as Map : map;
        final uid = map['userId'] ?? map['id'] ?? userObj['id'] ?? userObj['username'] ?? '';
        final key = '${map['roomId']}_$uid';
        final now = DateTime.now().millisecondsSinceEpoch;
        if (uid.toString().isNotEmpty && recentJoins.containsKey(key)) {
          if (now - recentJoins[key]! < 4000) {
            return; // Ignore duplicate alias emissions within 4 seconds
          }
        }
        recentJoins[key] = now;
        _userJoinedController.add(map);
      }
    }
    _socket!.on('room:user_joined', handleUserJoined);
    _socket!.on('user_joined', handleUserJoined);
    _socket!.on('user:joined', handleUserJoined);
    _socket!.on('room_user_joined', handleUserJoined);

    void handleUserLeft(dynamic data) {
      if (data != null) _userLeftController.add(safeMap(data));
    }
    _socket!.on('room:user_left', handleUserLeft);
    _socket!.on('user_left', handleUserLeft);
    _socket!.on('user:left', handleUserLeft);

    void handleViewerCount(dynamic data) {
      if (data != null) _viewerCountController.add(safeMap(data));
    }
    _socket!.on('room:viewer_count_changed', handleViewerCount);
    _socket!.on('room:viewer_count', handleViewerCount);
    _socket!.on('viewer_count_changed', handleViewerCount);

    void handleRoomLike(dynamic data) {
      if (data != null) _roomLikeController.add(safeMap(data));
    }
    _socket!.on('room:like', handleRoomLike);
    _socket!.on('room:like_sent', handleRoomLike);
    _socket!.on('room_like', handleRoomLike);
    _socket!.on('like_sent', handleRoomLike);

    void handleSnapshot(dynamic data) {
      if (data != null) _roomSnapshotController.add(safeMap(data));
    }
    _socket!.on('room:snapshot', handleSnapshot);
    _socket!.on('room_snapshot', handleSnapshot);

    _socket!.on('room:seat_occupied', (data) {
      if (data != null) _seatOccupiedController.add(safeMap(data));
    });
    _socket!.on('room:seat_released', (data) {
      if (data != null) _seatReleasedController.add(safeMap(data));
    });
    void handleRoomCreated(dynamic data) {
      if (data != null) _roomCreatedController.add(safeMap(data));
    }
    _socket!.on('room:created', handleRoomCreated);
    _socket!.on('room_created', handleRoomCreated);
    _socket!.on('room:started', handleRoomCreated);
    _socket!.on('room_started', handleRoomCreated);

    void handleRoomClosed(dynamic data) {
      if (data != null) _roomClosedController.add(safeMap(data));
    }
    _socket!.on('room:closed', handleRoomClosed);
    _socket!.on('room_closed', handleRoomClosed);
    _socket!.on('room:deleted', handleRoomClosed);
    _socket!.on('room_deleted', handleRoomClosed);
    _socket!.on('stream:ended', handleRoomClosed);
    _socket!.on('stream_ended', handleRoomClosed);
    _socket!.on('room:host_left', (data) {
      if (data != null) {
        final map = safeMap(data);
        if (map['roomType'] == 'LIVE_VIDEO' || map['roomType'] == 'LIVE') {
          _roomClosedController.add(map);
        }
      }
    });
    final Map<String, int> recentChats = {};
    void handleChatMessage(dynamic data) {
      if (data != null) {
        final map = safeMap(data);
        final msgId = (map['id'] ?? map['_id'] ?? '').toString();
        final text = (map['text'] ?? map['message'] ?? map['content'] ?? '').toString().trim();
        final senderMap = map['sender'] is Map
            ? map['sender'] as Map
            : (map['user'] is Map ? map['user'] as Map : {});
        final senderId = (senderMap['id'] ?? senderMap['_id'] ?? map['senderUserId'] ?? map['userId'] ?? '').toString();
        final key = msgId.isNotEmpty ? msgId : '${map['roomId']}_${senderId}_$text';
        final now = DateTime.now().millisecondsSinceEpoch;
        if (key.isNotEmpty && recentChats.containsKey(key)) {
          if (now - recentChats[key]! < 500) {
            return; // Ignore duplicate chat alias emissions within 500ms
          }
        }
        recentChats[key] = now;
        _roomChatMessageController.add(map);
      }
    }
    _socket!.off('room:chat_message');
    _socket!.on('room:chat_message', handleChatMessage);
    _socket!.off('room_chat_message');
    _socket!.on('room_chat_message', handleChatMessage);
    _socket!.off('chat_message');
    _socket!.on('chat_message', handleChatMessage);
    _socket!.off('room:comment');
    _socket!.on('room:comment', handleChatMessage);
    _socket!.off('room:chat');
    _socket!.on('room:chat', handleChatMessage);
    _socket!.off('room_chat');
    _socket!.on('room_chat', handleChatMessage);
    _socket!.off('room:message');
    _socket!.on('room:message', handleChatMessage);
    _socket!.off('room_message');
    _socket!.on('room_message', handleChatMessage);
    _socket!.off('new_message');
    _socket!.on('new_message', handleChatMessage);
    _socket!.off('chat');
    _socket!.on('chat', handleChatMessage);

    // Authoritative Room Gift Event Listeners with deduplication
    final Map<String, int> recentGifts = {};
    void handleGiftSent(dynamic data) {
      if (data != null) {
        final map = safeMap(data);
        final txId = (map['transactionId'] ?? map['id'] ?? map['_id'] ?? '').toString();
        final now = DateTime.now().millisecondsSinceEpoch;
        if (txId.isNotEmpty && recentGifts.containsKey(txId)) {
          if (now - recentGifts[txId]! < 5000) {
            return; // Deduplicate alias emissions within 5s
          }
        }
        if (txId.isNotEmpty) {
          recentGifts[txId] = now;
        }
        _giftSentController.add(map);
      }
    }
    _socket!.off('room:gift_sent');
    _socket!.on('room:gift_sent', handleGiftSent);
    _socket!.off('room_gift_sent');
    _socket!.on('room_gift_sent', handleGiftSent);
    _socket!.off('gift:sent');
    _socket!.on('gift:sent', handleGiftSent);
    _socket!.off('gift_sent');
    _socket!.on('gift_sent', handleGiftSent);
    _socket!.off('room:gift');
    _socket!.on('room:gift', handleGiftSent);
    _socket!.off('room_gift');
    _socket!.on('room_gift', handleGiftSent);
    _socket!.off('live:gift');
    _socket!.on('live:gift', handleGiftSent);

    _socket!.on('room:user_kicked', (data) {
      if (data != null) _userKickedController.add(safeMap(data));
    });
    _socket!.on('user_kicked', (data) {
      if (data != null) _userKickedController.add(safeMap(data));
    });
    _socket!.on('room_user_kicked', (data) {
      if (data != null) _userKickedController.add(safeMap(data));
    });
    _socket!.on('room:warning', (data) {
      if (data != null) _roomWarningController.add(safeMap(data));
    });
    _socket!.on('room_warning', (data) {
      if (data != null) _roomWarningController.add(safeMap(data));
    });
    _socket!.on('room:warning_issued', (data) {
      if (data != null) _roomWarningController.add(safeMap(data));
    });
    _socket!.on('room:muted', (data) {
      if (data != null) _roomMutedController.add(safeMap(data));
    });
    _socket!.on('room_muted', (data) {
      if (data != null) _roomMutedController.add(safeMap(data));
    });
    _socket!.on('room:user_muted', (data) {
      if (data != null) _roomUserMutedController.add(safeMap(data));
    });
    _socket!.on('room_user_muted', (data) {
      if (data != null) _roomUserMutedController.add(safeMap(data));
    });
    // Emoji reactions broadcast from backend
    _socket!.on('room:emoji', (data) {
      if (data != null) _roomEmojiController.add(safeMap(data));
    });
    _socket!.on('room:role_updated', (data) {
      if (data != null) _roomRoleUpdatedController.add(safeMap(data));
    });
    _socket!.on('room:mic_invite', (data) {
      if (data != null) _roomMicInviteController.add(safeMap(data));
    });
    _socket!.on('room_mic_invite', (data) {
      if (data != null) _roomMicInviteController.add(safeMap(data));
    });
    void handleFeedCleared(dynamic data) {
      final map = data != null ? safeMap(data) : <String, dynamic>{'roomId': _currentRoomId};
      _roomFeedClearedController.add(map);
    }
    _socket!.off('room:feed_cleared');
    _socket!.on('room:feed_cleared', handleFeedCleared);
    _socket!.off('party:clear_screen');
    _socket!.on('party:clear_screen', handleFeedCleared);
    _socket!.off('room:clear_screen');
    _socket!.on('room:clear_screen', handleFeedCleared);
    _socket!.on('room:mic_invite_response', (data) {
      if (data != null) _roomMicInviteResponseController.add(safeMap(data));
    });
    _socket!.on('room_mic_invite_response', (data) {
      if (data != null) _roomMicInviteResponseController.add(safeMap(data));
    });

    // Room Profile & Details Sync (Item 09)
    void handleDetailsUpdated(dynamic data) {
      if (data != null) _roomDetailsUpdatedController.add(safeMap(data));
    }
    _socket!.off('room:details_updated');
    _socket!.on('room:details_updated', handleDetailsUpdated);
    _socket!.off('room:update_details');
    _socket!.on('room:update_details', handleDetailsUpdated);

    // Mic Seat Locking Sync (Item 04 & 07, Mic 7 & 8)
    void handleSeatLocked(dynamic data) {
      if (data != null) _roomSeatLockedController.add(safeMap(data));
    }
    _socket!.off('room:seat_locked_status');
    _socket!.on('room:seat_locked_status', handleSeatLocked);
    _socket!.off('room:seat_locked');
    _socket!.on('room:seat_locked', handleSeatLocked);
    _socket!.off('room:lock_seat');
    _socket!.on('room:lock_seat', handleSeatLocked);

    // Room Seat Count & Layout Sync (Item 11)
    void handleLayoutUpdated(dynamic data) {
      if (data != null) _roomLayoutUpdatedController.add(safeMap(data));
    }
    _socket!.off('room:layout_updated');
    _socket!.on('room:layout_updated', handleLayoutUpdated);
    _socket!.off('room:update_layout');
    _socket!.on('room:update_layout', handleLayoutUpdated);

    // Room Sending Coin Total Sync (Item 08)
    void handleSendingTotalUpdated(dynamic data) {
      if (data != null) _roomSendingTotalController.add(safeMap(data));
    }
    _socket!.off('room:sending_total_updated');
    _socket!.on('room:sending_total_updated', handleSendingTotalUpdated);
    _socket!.off('room:sending_total');
    _socket!.on('room:sending_total', handleSendingTotalUpdated);

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

    // Banner Live Events
    void handleBannerLiveEvent(dynamic data) {
      if (data != null) _bannerUpdatedController.add(safeMap(data));
    }
    _socket!.on('banner:created', handleBannerLiveEvent);
    _socket!.on('banner:updated', handleBannerLiveEvent);
    _socket!.on('banner:deleted', handleBannerLiveEvent);

    // Direct Messaging Events
    _socket!.on('direct_message', (data) {
      if (data is Map) _directMessageController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('direct_message_sent', (data) {
      if (data is Map) _directMessageController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('direct_message_read', (data) {
      if (data is Map) _directMessageReadController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('message_read', (data) {
      if (data is Map) _directMessageReadController.add(Map<String, dynamic>.from(data));
    });
    // PK Battle Real-time Events
    _socket!.on('pk:created', (data) {
      if (data is Map) _pkCreatedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('pk:participant_joined', (data) {
      if (data is Map) _pkParticipantJoinedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('pk:ready', (data) {
      if (data is Map) _pkReadyController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('pk:started', (data) {
      if (data is Map) _pkStartedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('pk:active', (data) {
      if (data is Map) _pkActiveController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('pk:score_updated', (data) {
      if (data is Map) _pkScoreUpdatedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('pk:ended', (data) {
      if (data is Map) _pkEndedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('pk:invitation_received', (data) {
      if (data is Map) _pkInvitationReceivedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('pk:invitation_accepted', (data) {
      if (data is Map) _pkInvitationAcceptedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('pk:invitation_declined', (data) {
      if (data is Map) _pkInvitationDeclinedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.connect();
    return _connectCompleter?.future ?? Future.value();
  }

  /// Send typing indicator to target user via socket
  void sendTyping({required String targetUserId, required bool isTyping}) {
    if (_socket != null && _isConnected) {
      _socket!.emit('chat:typing', {
        'targetUserId': targetUserId,
        'isTyping': isTyping,
      });
    }
  }

  /// Subscribe to room channel on server
  void joinRoomSubscription(String roomId, {Map<String, dynamic>? user}) {
    _currentRoomId = roomId;
    if (user != null) _cachedUserData = user;
    final targetUser = user ?? _cachedUserData;

    final payload = {
      'roomId': roomId,
      if (targetUser != null) 'user': targetUser,
      if (targetUser != null && (targetUser['id'] != null || targetUser['_id'] != null))
        'userId': targetUser['id'] ?? targetUser['_id'],
    };

    if (_socket != null && _socket!.connected) {
      _socket!.emit('room:join', payload);
      debugPrint('[SocketService] Subscribed to room:$roomId with user: ${targetUser?['name'] ?? targetUser?['username']}');
    } else {
      connect(user: targetUser).then((_) {
        if (_socket != null && _socket!.connected) {
          _socket!.emit('room:join', payload);
          debugPrint('[SocketService] Subscribed to room:$roomId after connect with user: ${targetUser?['name'] ?? targetUser?['username']}');
        }
      });
    }
  }

  void joinRoom(String roomId, {Map<String, dynamic>? user}) => joinRoomSubscription(roomId, user: user);

  /// Unsubscribe from room channel on server
  void leaveRoomSubscription(String roomId) {
    if (_socket != null) {
      _socket!.emit('room:leave', {'roomId': roomId});
      debugPrint('[SocketService] Unsubscribed from room:$roomId');
    }
    if (_currentRoomId == roomId) {
      _currentRoomId = null;
    }
  }

  void leaveRoom(String roomId) => leaveRoomSubscription(roomId);

  /// Inform server in realtime to end and close the room
  void closeRoomRealtime(String roomId) {
    if (_socket != null) {
      _socket!.emit('room:close', {'roomId': roomId});
      _socket!.emit('stream:end', {'roomId': roomId});
      _socket!.emit('room_close', {'roomId': roomId});
      debugPrint('[SocketService] Sent room:close for room:$roomId');
    }
  }

  /// Occupy a seat via realtime socket emission
  void occupySeat(String roomId, int seatIndex, {Map<String, dynamic>? user}) {
    if (_socket != null) {
      _socket!.emit('room:seat_occupy', {
        'roomId': roomId,
        'seatIndex': seatIndex,
        if (user != null) 'user': user,
      });
      _socket!.emit('seat:occupy', {
        'roomId': roomId,
        'seatIndex': seatIndex,
        if (user != null) 'user': user,
      });
    }
  }

  /// Release a seat via realtime socket emission
  void leaveSeat(String roomId, int seatIndex) {
    if (_socket != null) {
      _socket!.emit('room:seat_leave', {
        'roomId': roomId,
        'seatIndex': seatIndex,
      });
    }
  }

  /// Broadcast a chat message in a live party or streaming room
  void sendRoomChatMessage({
    required String roomId,
    required String text,
    String type = 'text',
    Map<String, dynamic>? sender,
    String? messageId,
  }) {
    final effectiveId = (messageId != null && messageId.isNotEmpty)
        ? messageId
        : 'msg_${DateTime.now().millisecondsSinceEpoch}_${(sender?['id'] ?? sender?['userId'] ?? 'anon')}';
    final payload = {
      'id': effectiveId,
      'clientMessageId': effectiveId,
      'roomId': roomId,
      'text': text,
      'message': text,
      'content': text,
      'type': type,
      if (sender != null) 'sender': sender,
      if (sender != null) 'user': sender,
      if (sender != null && (sender['id'] != null || sender['_id'] != null))
        'senderUserId': sender['id'] ?? sender['_id'],
    };

    if (_socket != null && _socket!.connected) {
      _socket!.emit('room:chat_send', payload);
      _socket!.emit('room_chat_send', payload);
      _socket!.emit('room:chat', payload);
      _socket!.emit('chat:send', payload);
      debugPrint('[SocketService] Sent room:chat_send for room:$roomId (msgId: $effectiveId)');
    } else {
      connect(user: sender).then((_) {
        if (_socket != null && _socket!.connected) {
          _socket!.emit('room:chat_send', payload);
          _socket!.emit('room_chat_send', payload);
          _socket!.emit('room:chat', payload);
          _socket!.emit('chat:send', payload);
          debugPrint('[SocketService] Sent room:chat_send after connect for room:$roomId (msgId: $effectiveId)');
        }
      });
    }
  }

  /// Broadcast a gift sent event in a live party or streaming room
  void sendRoomGift({
    required String roomId,
    required String giftId,
    required String giftName,
    required String giftIcon,
    required int quantity,
    required Map<String, dynamic> sender,
    required Map<String, dynamic> receiver,
    String? transactionId,
  }) {
    final effectiveTxId = (transactionId != null && transactionId.isNotEmpty)
        ? transactionId
        : 'tx_${DateTime.now().millisecondsSinceEpoch}_${(sender['id'] ?? sender['userId'] ?? 'anon')}';

    final payload = {
      'transactionId': effectiveTxId,
      'id': effectiveTxId,
      'roomId': roomId,
      'giftId': giftId,
      'giftName': giftName,
      'giftIcon': giftIcon,
      'quantity': quantity,
      'sender': sender,
      'senderUserId': sender['id'] ?? sender['_id'] ?? sender['userId'],
      'senderName': sender['name'] ?? sender['username'] ?? 'User',
      'senderAvatar': sender['avatarUrl'] ?? sender['avatar'] ?? '',
      'receiver': receiver,
      'receiverUserId': receiver['id'] ?? receiver['_id'] ?? receiver['userId'],
      'receiverName': receiver['name'] ?? receiver['username'] ?? 'Host',
      'receiverAvatar': receiver['avatarUrl'] ?? receiver['avatar'] ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (_socket != null && _socket!.connected) {
      _socket!.emit('room:gift_send', payload);
      _socket!.emit('room_gift_send', payload);
      _socket!.emit('gift:send', payload);
      _socket!.emit('room:gift_sent', payload);
      debugPrint('[SocketService] Sent room:gift_send for room:$roomId (txId: $effectiveTxId)');
    } else {
      connect(user: sender).then((_) {
        if (_socket != null && _socket!.connected) {
          _socket!.emit('room:gift_send', payload);
          _socket!.emit('room_gift_send', payload);
          _socket!.emit('gift:send', payload);
          _socket!.emit('room:gift_sent', payload);
          debugPrint('[SocketService] Sent room:gift_send after connect for room:$roomId (txId: $effectiveTxId)');
        }
      });
    }
  }

  /// Kick a participant from a room
  void kickUserFromRoom({
    required String roomId,
    required String targetUserId,
  }) {
    if (_socket != null && _isConnected) {
      _socket!.emit('room:kick_user', {
        'roomId': roomId,
        'targetUserId': targetUserId,
      });
    }
  }

  /// Broadcast an emoji reaction to all room participants
  void sendRoomEmoji({
    required String roomId,
    required String emoji,
    String? targetUserId,
  }) {
    if (_socket != null && _isConnected) {
      _socket!.emit('room:emoji_send', {
        'roomId': roomId,
        'emoji': emoji,
        if (targetUserId != null) 'targetUserId': targetUserId,
      });
    }
  }

  /// Broadcast double-tap likes to all room participants
  void sendRoomLike({
    required String roomId,
    int count = 1,
    Map<String, dynamic>? sender,
  }) {
    if (_socket != null && _isConnected) {
      _socket!.emit('room:like', {
        'roomId': roomId,
        'count': count,
        if (sender != null) 'sender': sender,
      });
    }
  }

  /// Realtime Mic Invitation methods
  void sendMicInvite({
    required String roomId,
    required String targetUserId,
    required Map<String, dynamic> inviter,
    required Map<String, dynamic> targetUser,
    String? invitationId,
    String? roomTitle,
  }) {
    if (_socket != null && _isConnected) {
      _socket!.emit('room:mic_invite', {
        'id': invitationId ?? 'inv_${DateTime.now().millisecondsSinceEpoch}_$targetUserId',
        'roomId': roomId,
        if (roomTitle != null) 'roomTitle': roomTitle,
        'targetUserId': targetUserId,
        'inviter': inviter,
        'targetUser': targetUser,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
  }

  void respondMicInvite({
    required String roomId,
    required String invitationId,
    required String targetUserId,
    required bool accepted,
    String? reason,
  }) {
    if (_socket != null && _isConnected) {
      _socket!.emit('room:mic_invite_response', {
        'id': invitationId,
        'roomId': roomId,
        'targetUserId': targetUserId,
        'accepted': accepted,
        if (reason != null) 'reason': reason,
      });
    }
  }

  /// Broadcast user joined event to room participants
  void sendUserJoined({
    required String roomId,
    Map<String, dynamic>? user,
    int? viewerCount,
  }) {
    if (_socket != null && _isConnected) {
      _socket!.emit('room:user_joined', {
        'roomId': roomId,
        if (user != null) 'user': user,
        if (viewerCount != null) 'viewerCount': viewerCount,
      });
    }
  }

  /// Clear room lower feed broadcast
  void clearRoomFeed(String roomId) {
    emit('party:clear_screen', {
      'roomId': roomId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Broadcast Room Title & Cover Updates (Item 09)
  void emitRoomDetailsUpdate(String roomId, {String? title, String? coverUrl}) {
    final payload = {
      'roomId': roomId,
      if (title != null) 'title': title,
      if (coverUrl != null) 'coverUrl': coverUrl,
      'timestamp': DateTime.now().toIso8601String(),
    };
    emit('room:update_details', payload);
    emit('room:details_updated', payload);
  }

  /// Broadcast Mic Seat Locking State (Item 04 & 07, Mic 7 & 8)
  void emitRoomSeatLock(String roomId, int seatIndex, bool isLocked) {
    final payload = {
      'roomId': roomId,
      'seatIndex': seatIndex,
      'isLocked': isLocked,
      'timestamp': DateTime.now().toIso8601String(),
    };
    emit('room:lock_seat', payload);
    emit('room:seat_locked_status', payload);
  }

  /// Broadcast Room Capacity & Layout Updates (Item 11)
  void emitRoomLayoutUpdate(String roomId, int capacity, String roomType) {
    final payload = {
      'roomId': roomId,
      'capacity': capacity,
      'seatCapacity': capacity,
      'roomType': roomType,
      'timestamp': DateTime.now().toIso8601String(),
    };
    emit('room:update_layout', payload);
    emit('room:layout_updated', payload);
  }

  /// Broadcast Room Sending Coin Total Updates (Item 08)
  void emitRoomSendingTotal(String roomId, num totalCoins) {
    final payload = {
      'roomId': roomId,
      'period': 'daily',
      'totalCoins': totalCoins,
      'timestamp': DateTime.now().toIso8601String(),
    };
    emit('room:sending_total_updated', payload);
    emit('room:sending_total', payload);
  }

  /// Generic emit helper for real-time events
  void emit(String event, dynamic data) {
    if (_socket != null && _isConnected) {
      _socket!.emit(event, data);
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
