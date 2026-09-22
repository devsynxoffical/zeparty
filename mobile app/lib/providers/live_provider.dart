import 'dart:async';
import 'package:flutter/material.dart';
import '../models/live_room_model.dart';
import '../models/pk_battle_model.dart';
import '../models/gift_model.dart';
import '../models/user_model.dart';
import '../core/services/agora_rtc_service.dart';
import '../core/services/socket_service.dart';
import '../core/repositories/room_repository.dart';

class LiveMessage {
  final String id;
  final String senderId;
  final String sender;
  final String text;
  final bool isGift;
  final GiftModel? gift;
  final String? avatarUrl;
  final bool isHost;
  final bool isMod;
  final bool isVip;
  final String? nobleTitle;
  final DateTime timestamp;

  LiveMessage({
    String? id,
    this.senderId = '',
    required this.sender,
    required this.text,
    this.isGift = false,
    this.gift,
    this.avatarUrl,
    this.isHost = false,
    this.isMod = false,
    this.isVip = false,
    this.nobleTitle,
    DateTime? timestamp,
  })  : id = id ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
        timestamp = timestamp ?? DateTime.now();
}

class LiveProvider extends ChangeNotifier {
  final AgoraRtcService _agoraService = AgoraRtcService();
  final RoomRepository _roomRepository = RoomRepository.instance;
  final SocketService _socketService = SocketService.instance;

  LiveRoomModel? _activeRoom;
  UserModel? _currentUser;
  List<LiveMessage> _messages = [];
  GiftModel? _activeGiftAnimation;
  PKBattleModel? _activePkBattle;
  Timer? _pkTimer;
  Timer? _giftTimer;
  int _pkTimeRemainingSeconds = 180;
  int _likeCount = 0;
  int _giftPoints = 0;
  static const int _maxMessageBuffer = 100;

  // Stream Subscriptions
  StreamSubscription? _socketUserJoinedSub;
  StreamSubscription? _socketUserLeftSub;
  StreamSubscription? _socketViewerCountSub;
  StreamSubscription? _socketGiftSentSub;
  StreamSubscription? _socketChatMessageSub;
  StreamSubscription? _socketRoomClosedSub;
  StreamSubscription? _socketRoomLikeSub;
  StreamSubscription? _socketUserKickedSub;
  StreamSubscription? _socketRoomWarningSub;
  StreamSubscription? _socketRoomMutedSub;
  StreamSubscription? _socketRoomUserMutedSub;
  StreamSubscription? _socketRoomSnapshotSub;

  final _likeReceivedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onLikeReceived => _likeReceivedController.stream;

  final _warningReceivedController = StreamController<String>.broadcast();
  Stream<String> get onWarningReceived => _warningReceivedController.stream;

  final _kickedReceivedController = StreamController<String>.broadcast();
  Stream<String> get onKickedReceived => _kickedReceivedController.stream;

  // ── Moderation State ─────────────────────────────────────
  bool _isRoomMuted = false;
  bool _isLocalMicMuted = false;
  String? _activeWarningMessage;
  bool _wasKicked = false;
  String? _kickReason;

  // ── Room Tool State ──────────────────────────────────────
  bool _isRoomLocked = false;
  String? _currentMusicTrack;
  String? _superWheelWinner;
  int _luckyBagDiamonds = 0;
  bool _luckyBagActive = false;
  String _activeEffect = 'None';

  // ── Getters ─────────────────────────────────────────────
  LiveRoomModel? get activeRoom => _activeRoom;
  UserModel? get currentUser => _currentUser;
  List<LiveMessage> get messages => List.unmodifiable(_messages);
  GiftModel? get activeGiftAnimation => _activeGiftAnimation;
  PKBattleModel? get activePkBattle => _activePkBattle;
  int get pkTimeRemainingSeconds => _pkTimeRemainingSeconds;
  int get likeCount => _likeCount;
  int get giftPoints => _giftPoints;
  bool get isRoomMuted => _isRoomMuted;
  bool get isLocalMicMuted => _isLocalMicMuted;
  // Combined mic muted: true if either room is muted OR user muted their own mic
  bool get isMicMuted => _isRoomMuted || _isLocalMicMuted;
  String? get activeWarningMessage => _activeWarningMessage;
  bool get wasKicked => _wasKicked;
  String? get kickReason => _kickReason;

  String get likeCountFormatted {
    if (_likeCount >= 1000000) {
      return '${(_likeCount / 1000000).toStringAsFixed(1)}M';
    } else if (_likeCount >= 1000) {
      return '${(_likeCount / 1000).toStringAsFixed(1)}K';
    }
    return '$_likeCount';
  }

  String get pointsFormatted {
    if (_giftPoints >= 1000000) {
      return '${(_giftPoints / 1000000).toStringAsFixed(1)}M';
    } else if (_giftPoints >= 1000) {
      return '${(_giftPoints / 1000).toStringAsFixed(1)}K';
    }
    return '$_giftPoints';
  }

  bool get isRoomLocked => _isRoomLocked;
  String? get currentMusicTrack => _currentMusicTrack;
  bool get isMusicPlaying => _currentMusicTrack != null;
  String? get superWheelWinner => _superWheelWinner;
  int get luckyBagDiamonds => _luckyBagDiamonds;
  bool get luckyBagActive => _luckyBagActive;
  String get activeEffect => _activeEffect;

  // ── Core Methods ─────────────────────────────────────────

  Future<void> joinRoom(LiveRoomModel room, {UserModel? currentUser}) async {
    _activeRoom = room.copyWith(viewerCount: room.viewerCount + 1);
    _currentUser = currentUser;
    _isRoomLocked = false;
    _isRoomMuted = room.isMuted;
    _activeWarningMessage = null;
    _wasKicked = false;
    _kickReason = null;
    _currentMusicTrack = null;
    _luckyBagActive = false;
    _activeEffect = 'None';
    _likeCount = 0;
    _giftPoints = 0;
    final displayName = currentUser?.displayName.isNotEmpty == true
        ? currentUser!.displayName
        : (currentUser?.name.isNotEmpty == true ? currentUser!.name : (currentUser?.username ?? 'User'));

    _messages = [
      LiveMessage(sender: 'System', text: 'Welcome to ${room.title}! Remember to follow community rules.'),
      LiveMessage(sender: 'System', text: '👋 $displayName joined the room! 🔥'),
    ];
    notifyListeners();

    final isHost = (currentUser != null) &&
        (room.host.id == currentUser.id || room.creatorUserId == currentUser.id);

    try {
      // 1. Connect Socket.IO
      _socketService.connect();
      _socketService.joinRoom(room.id);
      _setupSocketSubscriptions(currentUser);

      // 2. REST Join
      await _roomRepository.joinRoom(room.id);

      // 3. Acquire short-lived Agora RTC token
      final agoraData = await _roomRepository.getAgoraToken(room.id);
      if (agoraData['token'] != null) {
        final token = agoraData['token'] as String;
        final channelName = agoraData['channelName'] as String? ?? room.agoraChannelName ?? room.id;
        final uid = agoraData['uid'] as int? ?? agoraData['agoraUid'] as int? ?? 0;
        final appId = agoraData['appId'] as String?;

        final isVideo = (room.roomType == 'LIVE_VIDEO' || room.roomType == 'VIDEO_PARTY' || !room.roomType.contains('AUDIO'));

        await _agoraService.initialize(appId: appId, enableVideo: isVideo);
        await _agoraService.joinChannel(
          token,
          channelName,
          uid,
          isHost: isHost,
          isVideo: isVideo,
        );

        if (_isRoomMuted && isHost) {
          await _agoraService.muteLocalAudio(true);
        }
      }
    } catch (e) {
      debugPrint('[LiveProvider] joinRoom error: $e');
    }
    notifyListeners();
  }

  void _setupSocketSubscriptions(UserModel? currentUser) {
    _socketUserJoinedSub?.cancel();
    _socketUserJoinedSub = _socketService.userJoinedStream.listen((data) {
      if (_activeRoom != null && data['roomId'] != null && data['roomId'] != _activeRoom!.id) {
        return;
      }
      final userObj = data['user'] is Map ? Map<String, dynamic>.from(data['user']) : data;
      final userName = userObj['name'] ?? userObj['displayName'] ?? userObj['username'] ?? data['name'] ?? data['username'] ?? 'A user';
      final joinedId = data['userId'] ?? data['id'] ?? userObj['id'];

      if (joinedId != currentUser?.id) {
        _messages.add(LiveMessage(
          sender: 'System',
          text: '👋 $userName joined the room! 🔥',
        ));
        if (_messages.length > _maxMessageBuffer) _messages.removeAt(0);

        final rawCount = data['viewerCount'] ?? data['count'];
        final newCount = rawCount is int ? rawCount : (_activeRoom != null ? _activeRoom!.viewerCount + 1 : 1);
        if (_activeRoom != null) {
          _activeRoom = _activeRoom!.copyWith(viewerCount: newCount);
        }
        notifyListeners();
      }
    });

    _socketUserLeftSub?.cancel();
    _socketUserLeftSub = _socketService.userLeftStream.listen((data) {
      if (_activeRoom != null && data['roomId'] != null && data['roomId'] != _activeRoom!.id) {
        return;
      }
      final rawCount = data['viewerCount'] ?? data['count'];
      if (_activeRoom != null) {
        final newCount = rawCount is int ? rawCount : (_activeRoom!.viewerCount > 1 ? _activeRoom!.viewerCount - 1 : 1);
        _activeRoom = _activeRoom!.copyWith(viewerCount: newCount);
        notifyListeners();
      }
    });

    _socketViewerCountSub?.cancel();
    _socketViewerCountSub = _socketService.viewerCountStream.listen((data) {
      if (_activeRoom != null && data['roomId'] != null && data['roomId'] != _activeRoom!.id) {
        return;
      }
      final count = data['viewerCount'] ?? data['count'];
      if (count is int && _activeRoom != null) {
        _activeRoom = _activeRoom!.copyWith(viewerCount: count);
        notifyListeners();
      }
    });

    _socketRoomLikeSub?.cancel();
    _socketRoomLikeSub = _socketService.onRoomLike.listen((data) {
      if (_activeRoom != null && data['roomId'] != null && data['roomId'] != _activeRoom!.id) {
        return;
      }
      final senderMap = data['sender'] is Map ? Map<String, dynamic>.from(data['sender']) : {};
      final senderId = senderMap['id'] ?? data['userId'];
      final addedLikes = data['count'] is int ? data['count'] as int : 1;

      if (senderId != currentUser?.id) {
        _likeCount += addedLikes;
        notifyListeners();
      }
      _likeReceivedController.add(data);
    });

    _socketGiftSentSub?.cancel();
    _socketGiftSentSub = _socketService.giftSentStream.listen((data) {
      if (_activeRoom != null && data['roomId'] != null && data['roomId'] != _activeRoom!.id) {
        return;
      }
      final giftMap = data['gift'] is Map ? Map<String, dynamic>.from(data['gift']) : {};
      final senderMap = data['sender'] is Map ? Map<String, dynamic>.from(data['sender']) : {};
      final senderName = senderMap['displayName'] ?? senderMap['username'] ?? 'A fan';
      final giftName = giftMap['name'] ?? 'Gift';
      final giftIcon = giftMap['icon'] ?? '🎁';
      final qty = data['quantity'] ?? 1;

      _messages.add(LiveMessage(
        sender: senderName,
        text: 'sent $qty × $giftName $giftIcon!',
        isGift: true,
      ));
      if (_messages.length > _maxMessageBuffer) _messages.removeAt(0);
      notifyListeners();
    });

    _socketChatMessageSub?.cancel();
    _socketChatMessageSub = _socketService.onRoomChatMessage.listen((data) {
      try {
        final incomingRoomId = data['roomId']?.toString();
        if (_activeRoom != null && incomingRoomId != null && incomingRoomId != _activeRoom!.id) {
          return;
        }
        final senderMap = data['sender'] is Map ? Map<String, dynamic>.from(data['sender'] as Map) : <String, dynamic>{};
        final senderId = senderMap['id']?.toString() ?? data['senderUserId']?.toString() ?? '';
        final text = data['text']?.toString() ?? '';
        if (text.trim().isEmpty) return;

        final incomingId = data['id']?.toString();
        if (incomingId != null && _messages.any((m) => m.id == incomingId)) {
          return;
        }

        // Deduplicate optimistic local messages from the current user
        final isSelf = _currentUser != null && (senderId == _currentUser!.id || senderId == _currentUser!.username);
        if (isSelf && _messages.isNotEmpty) {
          final recentSelf = _messages.reversed.take(5).where(
            (m) => (m.senderId == _currentUser!.id || m.sender == _currentUser!.name || m.sender == _currentUser!.username) && m.text == text
          ).firstOrNull;
          if (recentSelf != null && DateTime.now().difference(recentSelf.timestamp).inSeconds < 4) {
            return;
          }
        }

        final senderName = senderMap['displayName']?.toString() ??
            senderMap['name']?.toString() ??
            senderMap['username']?.toString() ??
            'User';
        final isHost = (_activeRoom != null) &&
            (_activeRoom!.host.id == senderId || _activeRoom!.creatorUserId == senderId || senderMap['isHost'] == true);

        _messages.add(LiveMessage(
          id: incomingId,
          senderId: senderId,
          sender: senderName,
          text: text,
          avatarUrl: senderMap['avatarUrl']?.toString(),
          isHost: isHost,
          isVip: senderMap['isVip'] == true,
          nobleTitle: senderMap['nobleTitle']?.toString() ?? senderMap['nobleLevel']?.toString(),
          timestamp: DateTime.tryParse(data['timestamp']?.toString() ?? '') ?? DateTime.now(),
        ));
        if (_messages.length > _maxMessageBuffer) _messages.removeAt(0);
        notifyListeners();
      } catch (e) {
        debugPrint('[LiveProvider] ChatMessage receive error: $e');
      }
    });

    // ── Snapshot Subscription ─────────────────────────────────
    _socketRoomSnapshotSub?.cancel();
    _socketRoomSnapshotSub = _socketService.roomSnapshotStream.listen((data) {
      try {
        final roomObj = data['room'] is Map ? Map<String, dynamic>.from(data['room']) : <String, dynamic>{};
        if (roomObj.isNotEmpty && _activeRoom != null) {
          _activeRoom = LiveRoomModel.fromJson(roomObj);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[LiveProvider] Snapshot parse error: $e');
      }
    });

    // ── Moderation Event Subscriptions ──────────────────────
    _socketRoomWarningSub?.cancel();
    _socketRoomWarningSub = _socketService.roomWarningStream.listen((data) {
      if (_activeRoom != null && data['roomId'] != null && data['roomId'] != _activeRoom!.id) {
        return;
      }
      final msg = data['message'] ?? data['reason'] ?? 'Official moderation warning issued';
      _activeWarningMessage = msg.toString();
      _warningReceivedController.add(_activeWarningMessage!);
      _messages.add(LiveMessage(sender: '🛡️ Moderation Warning', text: msg.toString()));
      notifyListeners();

      Timer(const Duration(seconds: 8), () {
        _activeWarningMessage = null;
        notifyListeners();
      });
    });

    _socketRoomMutedSub?.cancel();
    _socketRoomMutedSub = _socketService.roomMutedStream.listen((data) {
      if (_activeRoom != null && data['roomId'] != null && data['roomId'] != _activeRoom!.id) {
        return;
      }
      final muted = data['isMuted'] == true || data['muted'] == true;
      _isRoomMuted = muted;
      // Mute ALL participants' local audio (not just host)
      try {
        _agoraService.muteLocalAudio(muted);
      } catch (_) {}
      _messages.add(LiveMessage(
        sender: 'System',
        text: muted ? '🔇 Room audio has been MUTED by platform moderation.' : '🎙️ Room audio has been UNMUTED.',
      ));
      notifyListeners();
    });

    _socketRoomUserMutedSub?.cancel();
    _socketRoomUserMutedSub = _socketService.onRoomUserMuted.listen((data) {
      if (_activeRoom != null && data['roomId'] != null && data['roomId'] != _activeRoom!.id) {
        return;
      }
      final targetId = data['targetUserId']?.toString();
      final muted = data['isMuted'] == true;
      if (targetId != null && targetId == currentUser?.id) {
        try {
          _agoraService.muteLocalAudio(muted);
        } catch (_) {}
        _messages.add(LiveMessage(
          sender: 'System',
          text: muted ? '🔇 Your microphone has been muted by moderation.' : '🎙️ Your microphone has been unmuted.',
        ));
        notifyListeners();
      }
    });

    _socketUserKickedSub?.cancel();
    _socketUserKickedSub = _socketService.userKickedStream.listen((data) {
      if (_activeRoom != null && data['roomId'] != null && data['roomId'] != _activeRoom!.id) {
        return;
      }
      final targetId = data['targetUserId']?.toString() ?? data['userId']?.toString();
      final isHostKicked = data['isHost'] == true;

      if (targetId != null && targetId == currentUser?.id) {
        _wasKicked = true;
        _kickReason = data['reason']?.toString() ?? 'You have been removed from this room by moderation.';
        _kickedReceivedController.add(_kickReason!);
        leaveRoom();
      } else if (isHostKicked) {
        _messages.add(LiveMessage(sender: 'System', text: '🛑 Stream ended: Host was removed by moderation.'));
        leaveRoom();
      }
    });

    _socketRoomClosedSub?.cancel();
    _socketRoomClosedSub = _socketService.roomClosedStream.listen((data) {
      sendMessage('🛑 Stream was closed', 'System');
      leaveRoom();
    });
  }

  Future<void> leaveRoom() async {
    final roomId = _activeRoom?.id;
    final isHost = _currentUser != null &&
        (_activeRoom?.host.id == _currentUser?.id || _activeRoom?.creatorUserId == _currentUser?.id);

    if (roomId != null) {
      try {
        _socketService.leaveRoom(roomId);
        if (isHost) {
          await _roomRepository.closeRoom(roomId);
        } else {
          await _roomRepository.leaveRoom(roomId);
        }
      } catch (_) {}
    }

    await _agoraService.leaveChannel();

    _socketUserJoinedSub?.cancel();
    _socketUserLeftSub?.cancel();
    _socketViewerCountSub?.cancel();
    _socketRoomLikeSub?.cancel();
    _socketGiftSentSub?.cancel();
    _socketChatMessageSub?.cancel();
    _socketRoomClosedSub?.cancel();
    _socketUserKickedSub?.cancel();
    _socketRoomWarningSub?.cancel();
    _socketRoomMutedSub?.cancel();
    _socketRoomUserMutedSub?.cancel();
    _socketRoomSnapshotSub?.cancel();
    _pkTimer?.cancel();
    _giftTimer?.cancel();

    _activeRoom = null;
    _currentUser = null;
    _messages.clear();
    _activeGiftAnimation = null;
    _activePkBattle = null;
    _isRoomLocked = false;
    _isLocalMicMuted = false;
    _currentMusicTrack = null;
    _luckyBagActive = false;
    notifyListeners();
  }

  /// Toggle local mic mute and sync state. Returns new muted value.
  bool toggleLocalMic() {
    if (_isRoomMuted) return true; // Can't unmute if room is admin-muted
    _isLocalMicMuted = !_isLocalMicMuted;
    try {
      _agoraService.muteLocalAudio(_isLocalMicMuted);
    } catch (_) {}
    notifyListeners();
    return _isLocalMicMuted;
  }

  void sendLike({int count = 1}) {
    _likeCount += count;
    notifyListeners();
    if (_activeRoom != null) {
      final senderMap = _currentUser != null
          ? {
              'id': _currentUser!.id,
              'name': _currentUser!.name,
              'username': _currentUser!.username,
              'avatarUrl': _currentUser!.avatarUrl,
            }
          : null;
      _socketService.sendRoomLike(
        roomId: _activeRoom!.id,
        count: count,
        sender: senderMap,
      );
    }
  }

  void sendMessage(String text, String sender, {UserModel? user}) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    final effectiveUser = user ?? _currentUser;
    final isHost = (effectiveUser != null && _activeRoom != null) &&
        (_activeRoom!.host.id == effectiveUser.id || _activeRoom!.creatorUserId == effectiveUser.id);

    final localMsg = LiveMessage(
      senderId: effectiveUser?.id ?? '',
      sender: sender.isNotEmpty ? sender : (effectiveUser?.name ?? 'User'),
      text: trimmedText,
      avatarUrl: effectiveUser?.avatarUrl,
      isHost: isHost,
      isVip: effectiveUser?.isVip ?? false,
      nobleTitle: effectiveUser?.nobleTitle,
    );

    _messages.add(localMsg);
    if (_messages.length > _maxMessageBuffer) {
      _messages.removeAt(0);
    }
    notifyListeners();

    if (_activeRoom != null && sender != 'System') {
      _socketService.sendRoomChatMessage(
        roomId: _activeRoom!.id,
        text: trimmedText,
      );
    }
  }

  void sendGift(GiftModel gift, String sender) {
    _activeGiftAnimation = gift;
    _giftPoints += (gift.priceCoins > 0 ? gift.priceCoins : gift.diamondPrice);
    _messages.add(
      LiveMessage(
        sender: sender,
        text: 'sent ${gift.name} ${gift.icon}!',
        isGift: true,
        gift: gift,
      ),
    );
    if (_messages.length > _maxMessageBuffer) {
      _messages.removeAt(0);
    }
    notifyListeners();

    _giftTimer?.cancel();
    _giftTimer = Timer(const Duration(seconds: 3), () {
      _activeGiftAnimation = null;
      notifyListeners();
    });
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  void startPkBattle({UserModel? currentHost, UserModel? opponentHost}) {
    final hostA = currentHost ?? const UserModel(
      id: 'host_1',
      username: 'host_alpha',
      name: 'Team Blue',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
    );
    final hostB = opponentHost ?? const UserModel(
      id: 'host_2',
      username: 'host_beta',
      name: 'Team Red',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
    );

    _activePkBattle = PKBattleModel(
      id: 'pk_${DateTime.now().millisecondsSinceEpoch}',
      hostA: hostA,
      hostB: hostB,
      scoreA: 0,
      scoreB: 0,
      remainingTime: const Duration(minutes: 3),
    );
    _pkTimeRemainingSeconds = 180;
    _pkTimer?.cancel();
    _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_pkTimeRemainingSeconds > 0) {
        _pkTimeRemainingSeconds--;
        notifyListeners();
      } else {
        _pkTimer?.cancel();
      }
    });
    notifyListeners();
  }

  void endPkBattle() {
    _activePkBattle = null;
    _pkTimer?.cancel();
    notifyListeners();
  }

  // ── Tool Actions ─────────────────────────────────────────

  void toggleRoomLock() {
    _isRoomLocked = !_isRoomLocked;
    sendMessage(
      _isRoomLocked
          ? 'Room is now LOCKED. No new viewers can join.'
          : 'Room has been UNLOCKED.',
      'System',
    );
  }

  void playMusic(String trackName) {
    _currentMusicTrack = trackName;
    sendMessage('Now playing: $trackName', 'System');
    notifyListeners();
  }

  void stopMusic() {
    _currentMusicTrack = null;
    notifyListeners();
  }

  void spinSuperWheel(List<String> participants) {
    if (participants.isEmpty) return;
    final winner = participants[DateTime.now().millisecondsSinceEpoch % participants.length];
    _superWheelWinner = winner;
    sendMessage('Super Wheel spun! Winner: $winner gets 100 diamonds!', 'System');
    Timer(const Duration(seconds: 5), () {
      _superWheelWinner = null;
      notifyListeners();
    });
  }

  void startLuckyBag(int diamonds) {
    _luckyBagDiamonds = diamonds;
    _luckyBagActive = true;
    sendMessage('Lucky Bag is live! $diamonds diamonds to grab — tap fast!', 'System');
    notifyListeners();
    Timer(const Duration(seconds: 12), () {
      _luckyBagActive = false;
      notifyListeners();
    });
  }

  void setEffect(String effectName) {
    _activeEffect = effectName;
    notifyListeners();
  }

  void addPkScore(bool toHostA, int score) {
    if (_activePkBattle != null) {
      if (toHostA) {
        _activePkBattle = _activePkBattle!.copyWith(
          scoreA: _activePkBattle!.scoreA + score,
        );
      } else {
        _activePkBattle = _activePkBattle!.copyWith(
          scoreB: _activePkBattle!.scoreB + score,
        );
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _socketUserJoinedSub?.cancel();
    _socketUserLeftSub?.cancel();
    _socketViewerCountSub?.cancel();
    _socketRoomLikeSub?.cancel();
    _socketGiftSentSub?.cancel();
    _socketChatMessageSub?.cancel();
    _socketRoomClosedSub?.cancel();
    _pkTimer?.cancel();
    _giftTimer?.cancel();
    _likeReceivedController.close();
    super.dispose();
  }
}
