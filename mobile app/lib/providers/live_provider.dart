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
  final String sender;
  final String text;
  final bool isGift;
  final GiftModel? gift;
  final String? avatarUrl;

  LiveMessage({
    required this.sender,
    required this.text,
    this.isGift = false,
    this.gift,
    this.avatarUrl,
  });
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

  final _likeReceivedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onLikeReceived => _likeReceivedController.stream;

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

      // Broadcast user joined event to room subscribers
      final userMap = currentUser != null
          ? {
              'id': currentUser.id,
              'name': currentUser.name,
              'username': currentUser.username,
              'avatarUrl': currentUser.avatarUrl,
            }
          : null;
      _socketService.sendUserJoined(
        roomId: room.id,
        user: userMap,
        viewerCount: _activeRoom?.viewerCount ?? (room.viewerCount + 1),
      );

      // 2. REST Join
      await _roomRepository.joinRoom(room.id);

      // 3. Acquire short-lived Agora RTC token
      final agoraData = await _roomRepository.getAgoraToken(room.id);
      if (agoraData['token'] != null) {
        final token = agoraData['token'] as String;
        final channelName = agoraData['channelName'] as String? ?? room.agoraChannelName ?? room.id;
        final uid = agoraData['uid'] as int? ?? 0;
        final appId = agoraData['appId'] as String?;

        await _agoraService.initialize(appId: appId);
        await _agoraService.joinChannel(
          token,
          channelName,
          uid,
          isHost: isHost,
        );
      }
    } catch (e) {
      debugPrint('[LiveProvider] joinRoom error: $e');
    }
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
      if (_activeRoom != null && data['roomId'] != null && data['roomId'] != _activeRoom!.id) {
        return;
      }
      final senderMap = data['sender'] as Map<String, dynamic>? ?? {};
      final senderName = senderMap['displayName'] ?? senderMap['username'] ?? 'User';
      final text = data['text']?.toString() ?? '';

      _messages.add(LiveMessage(
        sender: senderName,
        text: text,
        avatarUrl: senderMap['avatarUrl']?.toString(),
      ));
      if (_messages.length > _maxMessageBuffer) _messages.removeAt(0);
      notifyListeners();
    });

    _socketRoomClosedSub?.cancel();
    _socketRoomClosedSub = _socketService.roomClosedStream.listen((data) {
      sendMessage('🛑 Stream was closed by the host', 'System');
      leaveRoom();
    });
  }

  Future<void> leaveRoom() async {
    final roomId = _activeRoom?.id;
    if (roomId != null) {
      try {
        _socketService.leaveRoom(roomId);
        await _roomRepository.leaveRoom(roomId);
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
    _pkTimer?.cancel();
    _giftTimer?.cancel();

    _activeRoom = null;
    _currentUser = null;
    _messages.clear();
    _activeGiftAnimation = null;
    _activePkBattle = null;
    _isRoomLocked = false;
    _currentMusicTrack = null;
    _luckyBagActive = false;
    notifyListeners();
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

  void sendMessage(String text, String sender) {
    _messages.add(LiveMessage(sender: sender, text: text));
    if (_messages.length > _maxMessageBuffer) {
      _messages.removeAt(0);
    }
    if (_activeRoom != null && sender != 'System') {
      _socketService.sendRoomChatMessage(
        roomId: _activeRoom!.id,
        text: text,
      );
    }
    notifyListeners();
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
