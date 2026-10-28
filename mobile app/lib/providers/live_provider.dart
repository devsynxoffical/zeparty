import 'dart:async';
import 'package:flutter/material.dart';
import '../models/live_room_model.dart';
import '../models/pk_battle_model.dart';
import '../models/gift_model.dart';
import '../models/user_model.dart';
import '../core/services/agora_rtc_service.dart';
import '../core/services/socket_service.dart';
import '../core/repositories/room_repository.dart';
import '../core/repositories/pk_repository.dart';
import '../core/utils/noble_badge_helper.dart';
import '../core/constants/dummy_data.dart';

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
  final String? avatarFrame;
  final String? chatBubble;
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
    this.avatarFrame,
    this.chatBubble,
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
  final Set<String> _processedGiftTxIds = {};

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
  StreamSubscription? _socketPkCreatedSub;
  StreamSubscription? _socketPkParticipantJoinedSub;
  StreamSubscription? _socketPkReadySub;
  StreamSubscription? _socketPkStartedSub;
  StreamSubscription? _socketPkScoreSub;
  StreamSubscription? _socketPkEndedSub;
  StreamSubscription? _socketPkInviteSub;
  StreamSubscription? _socketPkPreparingSub;
  StreamSubscription? _socketPkCountdownSub;
  StreamSubscription? _socketPkHostConnectionSub;
  StreamSubscription? _socketPkMatchFinishedSub;
  StreamSubscription? _socketPkForfeitedSub;
  StreamSubscription? _socketPkAbortedSub;

  int _pkCountdown = 0;
  int get pkCountdown => _pkCountdown;
  bool get isPkCountdown => _pkCountdown > 0;
  bool _isPkOpponentDisconnected = false;
  int _pkDisconnectGrace = 30;
  bool get isPkOpponentDisconnected => _isPkOpponentDisconnected;
  int get pkDisconnectGrace => _pkDisconnectGrace;
  bool _isOpponentAudioMuted = false;
  bool get isOpponentAudioMuted => _isOpponentAudioMuted;

  final _likeReceivedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onLikeReceived => _likeReceivedController.stream;

  final _warningReceivedController = StreamController<String>.broadcast();
  Stream<String> get onWarningReceived => _warningReceivedController.stream;

  final _kickedReceivedController = StreamController<String>.broadcast();
  Stream<String> get onKickedReceived => _kickedReceivedController.stream;

  final _pkInvitationReceivedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onPkInvitationReceived => _pkInvitationReceivedController.stream;

  final _pkResultController = StreamController<PKBattleModel>.broadcast();
  Stream<PKBattleModel> get onPkResult => _pkResultController.stream;

  final _roomClosedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onRoomClosed => _roomClosedController.stream;

  final List<UserModel> _viewers = [];
  List<UserModel> get viewers => List.unmodifiable(_viewers);

  final Set<String> _announcedViewerIds = {};

  bool _isLiveEnded = false;
  bool get isLiveEnded => _isLiveEnded;
  String? _liveEndedReason;
  String? get liveEndedReason => _liveEndedReason;

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
    final isRejoiningSameRoom = (_activeRoom != null && _activeRoom!.id == room.id);
    final isHost = (currentUser != null) &&
        (room.host.id == currentUser.id || room.creatorUserId == currentUser.id);

    _activeRoom = room.copyWith(
      viewerCount: isHost ? room.viewerCount : room.viewerCount + 1,
      totalGifts: room.totalGifts > 0 ? room.totalGifts : _giftPoints,
      totalLikes: room.totalLikes > 0 ? room.totalLikes : _likeCount,
    );
    _currentUser = currentUser;
    _viewers.clear();
    _isLiveEnded = false;
    _liveEndedReason = null;
    _isRoomLocked = false;
    _isRoomMuted = room.isMuted;
    _activeWarningMessage = null;
    _wasKicked = false;
    _kickReason = null;
    _currentMusicTrack = null;
    _luckyBagActive = false;
    _activeEffect = 'None';

    // Preserve points & likes if rejoining/expanding from minimize, otherwise initialize from room
    if (!isRejoiningSameRoom) {
      _likeCount = room.totalLikes;
      _giftPoints = room.totalGifts > 0 ? room.totalGifts : room.giftsReceivedCoins;
    }
    final displayName = currentUser?.displayName.isNotEmpty == true
        ? currentUser!.displayName
        : (currentUser?.name.isNotEmpty == true ? currentUser!.name : (currentUser?.username ?? 'User'));

    _messages = [
      LiveMessage(sender: 'System', text: 'Welcome to ${room.title}! Remember to follow community rules.'),
      LiveMessage(sender: 'System', text: '👋 $displayName joined the room! 🔥'),
    ];
    notifyListeners();

    try {
      // 1. Connect Socket.IO
      _socketService.connect(user: currentUser?.toJson());
      _socketService.joinRoom(room.id, user: currentUser?.toJson());
      _setupSocketSubscriptions(currentUser);

      // 2. REST Join
      final joinResult = await _roomRepository.joinRoom(room.id);
      final roomData = joinResult['room'] ?? joinResult;
      if (roomData is Map<String, dynamic>) {
        final rawCount = roomData['currentViewersCount'] ?? roomData['viewerCount'];
        if (rawCount is int && _activeRoom != null) {
          _activeRoom = _activeRoom!.copyWith(viewerCount: rawCount);
        }
        final rawGifts = int.tryParse(roomData['totalGifts']?.toString() ?? '') ??
            int.tryParse(roomData['giftsReceivedCoins']?.toString() ?? '') ??
            int.tryParse(roomData['trophyCoins']?.toString() ?? '');
        if (rawGifts != null && rawGifts > _giftPoints) {
          _giftPoints = rawGifts;
        }
        final rawLikes = int.tryParse(roomData['totalLikes']?.toString() ?? '') ??
            int.tryParse(roomData['likesCount']?.toString() ?? '');
        if (rawLikes != null && rawLikes > _likeCount) {
          _likeCount = rawLikes;
        }
        notifyListeners();
        if (roomData['members'] is List) {
          for (final mRaw in (roomData['members'] as List)) {
            if (mRaw is! Map) continue;
            final mMap = Map<String, dynamic>.from(mRaw);
            final uRaw = mMap['user'] ?? mMap;
            if (uRaw is! Map) continue;
            final uMap = Map<String, dynamic>.from(uRaw);
            final mId = uMap['id']?.toString() ?? mMap['userId']?.toString() ?? '';
            final isHostUser = (_activeRoom != null) &&
                (mId == _activeRoom!.host.id || mId == _activeRoom!.creatorUserId);
            if (!isHostUser && mId.isNotEmpty && !_viewers.any((v) => v.id == mId)) {
              _viewers.add(UserModel(
                id: mId,
                name: uMap['displayName']?.toString() ?? uMap['name']?.toString() ?? uMap['username']?.toString() ?? 'Viewer',
                username: uMap['username']?.toString() ?? 'user_$mId',
                avatarUrl: uMap['avatarUrl']?.toString() ?? '',
              ));
            }
          }
        }
      }

      // 3. Acquire short-lived Agora RTC token & initialize video camera
      final isVideo = (room.roomType == 'LIVE_VIDEO' || room.roomType == 'VIDEO_PARTY' || !room.roomType.contains('AUDIO'));
      try {
        await _agoraService.initialize(enableVideo: isVideo);
        if (isHost && isVideo) {
          await _agoraService.startPreview();
        }

        final agoraData = await _roomRepository.getAgoraToken(room.id);
        if (agoraData['token'] != null && (agoraData['token'] as String).isNotEmpty) {
          final token = agoraData['token'] as String;
          final channelName = agoraData['channelName'] as String? ?? room.agoraChannelName ?? room.id;
          final uid = agoraData['uid'] as int? ?? agoraData['agoraUid'] as int? ?? 0;
          final appId = agoraData['appId'] as String?;

          await _agoraService.initialize(appId: appId, enableVideo: isVideo);
          await _agoraService.joinChannel(
            token,
            channelName,
            uid,
            isHost: isHost,
            isVideo: isVideo,
          );
        }
      } catch (e) {
        debugPrint('[LiveProvider] Agora initialize / joinChannel error: $e');
        if (isVideo) {
          try {
            await _agoraService.initialize(enableVideo: true);
            if (isHost) await _agoraService.startPreview();
          } catch (_) {}
        }
      }

      if (_isRoomMuted && isHost) {
        await _agoraService.muteLocalAudio(true);
      }
    } catch (e) {
      debugPrint('[LiveProvider] joinRoom error: $e');
    }
    notifyListeners();
  }

  void _setupSocketSubscriptions(UserModel? currentUser) {
    _socketRoomSnapshotSub?.cancel();
    _socketRoomSnapshotSub = _socketService.roomSnapshotStream.listen((data) {
      if (_activeRoom != null && data['roomId'] != null && data['roomId'] != _activeRoom!.id) {
        return;
      }
      final roomObj = data['room'] is Map ? Map<String, dynamic>.from(data['room'] as Map) : <String, dynamic>{};
      final rawCount = data['viewerCount'] ?? roomObj['currentViewersCount'] ?? roomObj['viewerCount'];
      if (rawCount is int && _activeRoom != null) {
        _activeRoom = _activeRoom!.copyWith(viewerCount: rawCount);
      }
      final membersList = data['members'] is List
          ? (data['members'] as List)
          : (roomObj['members'] is List ? (roomObj['members'] as List) : []);
      for (final mRaw in membersList) {
        if (mRaw is! Map) continue;
        final mMap = Map<String, dynamic>.from(mRaw);
        final uRaw = mMap['user'] ?? mMap;
        if (uRaw is! Map) continue;
        final uMap = Map<String, dynamic>.from(uRaw);
        final mId = uMap['id']?.toString() ?? mMap['userId']?.toString() ?? '';
        final isHostUser = (_activeRoom != null) &&
            (mId == _activeRoom!.host.id || mId == _activeRoom!.creatorUserId);
        if (!isHostUser && mId.isNotEmpty && !_viewers.any((v) => v.id == mId)) {
          _viewers.add(UserModel(
            id: mId,
            name: uMap['displayName']?.toString() ?? uMap['name']?.toString() ?? uMap['username']?.toString() ?? 'Viewer',
            username: uMap['username']?.toString() ?? 'user_$mId',
            avatarUrl: uMap['avatarUrl']?.toString() ?? '',
          ));
        }
      }

      // Process recent gifts snapshot (Issue 01)
      final recentGifts = data['recentGifts'] is List
          ? (data['recentGifts'] as List)
          : (roomObj['recentGifts'] is List ? (roomObj['recentGifts'] as List) : []);
      for (final g in recentGifts) {
        if (g is! Map) continue;
        final gMap = Map<String, dynamic>.from(g);
        final txId = (gMap['transactionId'] ?? gMap['id'] ?? gMap['_id'] ?? '').toString();
        if (txId.isNotEmpty) {
          if (_processedGiftTxIds.contains(txId) || _messages.any((m) => m.id == 'snap_$txId' || m.id == 'gift_$txId')) continue;
          _processedGiftTxIds.add(txId);
          if (_processedGiftTxIds.length > 500) _processedGiftTxIds.remove(_processedGiftTxIds.first);
        }
        final giftMap = gMap['gift'] is Map ? Map<String, dynamic>.from(gMap['gift']) : {};
        final senderMap = gMap['sender'] is Map ? Map<String, dynamic>.from(gMap['sender']) : {};
        final senderName = gMap['senderName'] ?? senderMap['displayName'] ?? senderMap['username'] ?? 'A fan';
        final giftName = gMap['giftName'] ?? giftMap['name'] ?? 'Gift';
        final qty = (gMap['quantity'] is num) ? (gMap['quantity'] as num).toInt() : 1;
        final senderId = senderMap['id']?.toString() ?? senderMap['_id']?.toString() ?? gMap['senderId']?.toString() ?? '';
        final senderAvatar = senderMap['avatarUrl']?.toString() ?? senderMap['avatar']?.toString() ?? gMap['senderAvatar']?.toString();
        final isHostSender = (_activeRoom != null) &&
            (senderId == _activeRoom!.host.id || senderId == _activeRoom!.creatorUserId || senderName.toString() == _activeRoom!.host.name);
        final effectiveAvatar = (senderAvatar != null && senderAvatar.isNotEmpty)
            ? senderAvatar
            : (isHostSender ? _activeRoom?.host.avatarUrl : null);
        final formattedText = qty > 1 ? 'sent $qty × $giftName!' : 'sent $giftName!';

        _messages.add(LiveMessage(
          id: 'snap_$txId',
          sender: senderName.toString(),
          senderId: senderId,
          avatarUrl: effectiveAvatar,
          isHost: isHostSender,
          text: formattedText,
          isGift: true,
        ));
      }
      if (_messages.length > _maxMessageBuffer) {
        _messages.removeRange(0, _messages.length - _maxMessageBuffer);
      }

      notifyListeners();
    });

    _socketUserJoinedSub?.cancel();
    _socketUserJoinedSub = _socketService.userJoinedStream.listen((data) {
      if (_activeRoom != null && data['roomId'] != null && data['roomId'] != _activeRoom!.id) {
        return;
      }
      final userObj = data['user'] is Map ? Map<String, dynamic>.from(data['user']) : data;
      final userName = userObj['name'] ?? userObj['displayName'] ?? userObj['username'] ?? data['name'] ?? data['username'] ?? 'A user';
      final joinedId = data['userId']?.toString() ?? data['id']?.toString() ?? userObj['id']?.toString();

      final isHostUser = (_activeRoom != null) &&
          (joinedId == _activeRoom!.host.id || joinedId == _activeRoom!.creatorUserId);

      // Track viewers list (all non-host users)
      if (!isHostUser && joinedId != null && joinedId.isNotEmpty) {
        final viewerModel = UserModel(
          id: joinedId,
          name: userName.toString(),
          username: userObj['username']?.toString() ?? 'user_$joinedId',
          avatarUrl: userObj['avatarUrl']?.toString() ?? '',
          region: userObj['region']?.toString() ?? 'Global',
        );
        _viewers.removeWhere((v) => v.id == joinedId);
        _viewers.insert(0, viewerModel);
      }

      if (joinedId != null && joinedId != currentUser?.id) {
        if (!_announcedViewerIds.contains(joinedId)) {
          _announcedViewerIds.add(joinedId);
          _messages.add(LiveMessage(
            sender: 'System',
            text: '👋 $userName joined the room! 🔥',
          ));
          if (_messages.length > _maxMessageBuffer) _messages.removeAt(0);
        }

        final rawCount = data['viewerCount'] ?? data['count'];
        final newCount = rawCount is int
            ? rawCount
            : (isHostUser ? (_activeRoom?.viewerCount ?? 0) : (_activeRoom != null ? _activeRoom!.viewerCount + 1 : 0));
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
      final leftId = data['userId']?.toString() ?? data['id']?.toString();
      if (leftId != null) {
        _viewers.removeWhere((v) => v.id == leftId);
      }

      final rawCount = data['viewerCount'] ?? data['count'];
      if (_activeRoom != null) {
        final newCount = rawCount is int ? rawCount : (_activeRoom!.viewerCount > 0 ? _activeRoom!.viewerCount - 1 : 0);
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

    _socketRoomSnapshotSub?.cancel();
    _socketRoomSnapshotSub = _socketService.roomSnapshotStream.listen((data) {
      if (_activeRoom != null && data['roomId'] != null && data['roomId'] != _activeRoom!.id) {
        return;
      }
      final snapLikes = int.tryParse(data['totalLikes']?.toString() ?? '') ??
          int.tryParse(data['likesCount']?.toString() ?? '');
      if (snapLikes != null && snapLikes > _likeCount) {
        _likeCount = snapLikes;
      }
      final snapGifts = int.tryParse(data['dailySendingTotal']?.toString() ?? '') ??
          int.tryParse(data['totalGifts']?.toString() ?? '') ??
          int.tryParse(data['trophyCoins']?.toString() ?? '');
      if (snapGifts != null && snapGifts > _giftPoints) {
        _giftPoints = snapGifts;
      }
      notifyListeners();
    });

    _socketRoomLikeSub?.cancel();
    _socketRoomLikeSub = _socketService.onRoomLike.listen((data) {
      if (_activeRoom != null && data['roomId'] != null && data['roomId'] != _activeRoom!.id) {
        return;
      }
      final senderMap = data['sender'] is Map ? Map<String, dynamic>.from(data['sender']) : {};
      final senderId = senderMap['id'] ?? data['userId'];
      final addedLikes = data['count'] is int ? data['count'] as int : 1;
      final incomingTotal = int.tryParse(data['totalLikes']?.toString() ?? '') ??
          int.tryParse(data['likesCount']?.toString() ?? '');

      if (incomingTotal != null && incomingTotal > _likeCount) {
        _likeCount = incomingTotal;
      } else if (senderId != currentUser?.id) {
        _likeCount += addedLikes;
      }
      notifyListeners();
      _likeReceivedController.add(data);
    });

    _socketGiftSentSub?.cancel();
    _socketGiftSentSub = _socketService.giftSentStream.listen((data) {
      if (_activeRoom != null && data['roomId'] != null && data['roomId'] != _activeRoom!.id) {
        return;
      }
      final txId = (data['transactionId'] ?? data['id'] ?? data['_id'] ?? '').toString();
      if (txId.isNotEmpty) {
        if (_processedGiftTxIds.contains(txId)) {
          return;
        }
        _processedGiftTxIds.add(txId);
        if (_processedGiftTxIds.length > 500) {
          _processedGiftTxIds.remove(_processedGiftTxIds.first);
        }
      }

      final giftMap = data['gift'] is Map ? Map<String, dynamic>.from(data['gift']) : {};
      final senderMap = data['sender'] is Map ? Map<String, dynamic>.from(data['sender']) : {};
      final senderName = senderMap['displayName'] ?? senderMap['username'] ?? data['senderName'] ?? 'A fan';
      final rawGiftId = giftMap['id']?.toString() ?? data['giftId']?.toString() ?? '';
      final rawGiftName = giftMap['name']?.toString() ?? data['giftName']?.toString() ?? 'Gift';
      final catalogGift = GiftModel.findById(rawGiftId) ?? GiftModel.findById(rawGiftName);
      final giftName = catalogGift?.name ?? rawGiftName;
      final qty = (data['quantity'] is num) ? (data['quantity'] as num).toInt() : 1;
      final senderId = senderMap['id']?.toString() ?? senderMap['_id']?.toString() ?? data['senderId']?.toString() ?? data['userId']?.toString() ?? '';
      final senderAvatar = senderMap['avatarUrl']?.toString() ?? senderMap['avatar']?.toString() ?? data['senderAvatar']?.toString() ?? (senderId == currentUser?.id ? currentUser?.avatarUrl : null);
      final isHostSender = (_activeRoom != null) &&
          (senderId == _activeRoom!.host.id || senderId == _activeRoom!.creatorUserId || senderName.toString() == _activeRoom!.host.name);
      final effectiveAvatar = (senderAvatar != null && senderAvatar.isNotEmpty)
          ? senderAvatar
          : (isHostSender ? _activeRoom?.host.avatarUrl : (senderId == currentUser?.id ? currentUser?.avatarUrl : null));
      final formattedText = qty > 1 ? 'sent $qty × $giftName!' : 'sent $giftName!';

      // Comprehensive deduplication against locally added optimistic message
      final isOptimisticDuplicate = _messages.any((m) =>
          m.isGift &&
          ( (txId.isNotEmpty && (m.id == 'gift_$txId' || m.id == txId)) ||
            ( ((senderId.isNotEmpty && m.senderId == senderId) ||
               m.sender.trim().toLowerCase() == senderName.toString().trim().toLowerCase()) &&
              m.text.toLowerCase().contains(giftName.toLowerCase()) &&
              DateTime.now().difference(m.timestamp).inSeconds.abs() <= 5 )
          ));
      if (isOptimisticDuplicate) return;

      _messages.add(LiveMessage(
        id: txId.isNotEmpty ? 'gift_$txId' : null,
        sender: senderName.toString(),
        senderId: senderId,
        avatarUrl: effectiveAvatar,
        isHost: isHostSender,
        text: formattedText,
        isGift: true,
        gift: catalogGift,
      ));
      if (_messages.length > _maxMessageBuffer) _messages.removeAt(0);

      // Trigger gift animation and points update for stream viewers
      if (senderId != currentUser?.id && catalogGift != null) {
        _activeGiftAnimation = catalogGift;
        _giftPoints += ((catalogGift.priceCoins > 0 ? catalogGift.priceCoins : catalogGift.diamondPrice) * qty);
        _giftTimer?.cancel();
        _giftTimer = Timer(const Duration(seconds: 3), () {
          _activeGiftAnimation = null;
          notifyListeners();
        });
      }

      notifyListeners();
    });

    _socketChatMessageSub?.cancel();
    _socketChatMessageSub = _socketService.onRoomChatMessage.listen((data) {
      try {
        final incomingRoomId = (data['roomId'] ?? '').toString().trim();
        final incomingClientRoomId = (data['clientRoomId'] ?? data['room'] ?? '').toString().trim();
        final currentRoomId = (_activeRoom?.id ?? '').trim().toLowerCase();
        final inRoomId = incomingRoomId.toLowerCase();
        final inClientRoomId = incomingClientRoomId.toLowerCase();

        final validRoomIds = <String>{
          if (currentRoomId.isNotEmpty) currentRoomId,
        };

        if (validRoomIds.isNotEmpty) {
          final match = (inRoomId.isNotEmpty && validRoomIds.contains(inRoomId)) ||
              (inClientRoomId.isNotEmpty && validRoomIds.contains(inClientRoomId)) ||
              (inRoomId.isEmpty && inClientRoomId.isEmpty);
          if (!match) return;
        }
        final senderMap = data['sender'] is Map ? Map<String, dynamic>.from(data['sender'] as Map) : <String, dynamic>{};
        final senderId = (senderMap['id'] ?? senderMap['_id'] ?? data['senderUserId'] ?? data['userId'] ?? '').toString();
        final text = (data['text'] ?? data['message'] ?? data['content'] ?? '').toString().trim();
        if (text.isEmpty) return;

        final incomingId = (data['id'] ?? data['_id'])?.toString();
        final clientMsgId = data['clientMessageId']?.toString();
        if (incomingId != null && incomingId.isNotEmpty && _messages.any((m) => m.id == incomingId)) {
          return;
        }
        if (clientMsgId != null && clientMsgId.isNotEmpty && _messages.any((m) => m.id == clientMsgId)) {
          return;
        }

        // Deduplicate only our own optimistic local message echo
        if (_messages.isNotEmpty && senderId.isNotEmpty && senderId == _currentUser?.id) {
          final recentMatchingIndex = _messages.lastIndexWhere((m) =>
            m.senderId == senderId &&
            m.text.trim() == text &&
            DateTime.now().difference(m.timestamp).inSeconds < 8
          );

          if (recentMatchingIndex != -1) {
            // Update local message with server assigned id if available
            if (incomingId != null) {
              final existing = _messages[recentMatchingIndex];
              _messages[recentMatchingIndex] = LiveMessage(
                id: incomingId,
                senderId: existing.senderId,
                sender: existing.sender,
                text: existing.text,
                avatarUrl: existing.avatarUrl,
                isHost: existing.isHost,
                isVip: existing.isVip,
                nobleTitle: existing.nobleTitle,
                avatarFrame: existing.avatarFrame,
                chatBubble: existing.chatBubble,
                timestamp: existing.timestamp,
              );
            }
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
          avatarFrame: senderMap['avatarFrame']?.toString() ?? senderMap['frameUrl']?.toString(),
          chatBubble: senderMap['chatBubble']?.toString() ?? senderMap['bubbleUrl']?.toString(),
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

      Timer(const Duration(seconds: 10), () {
        if (_activeWarningMessage == msg.toString()) {
          _activeWarningMessage = null;
          notifyListeners();
        }
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
      final isMe = targetId != null && (targetId == currentUser?.id || targetId == currentUser?.username);
      if (isMe) {
        try {
          _agoraService.muteLocalAudio(muted);
        } catch (_) {}
        _messages.add(LiveMessage(
          sender: 'System',
          text: muted ? '🔇 Your microphone has been MUTED by moderation.' : '🎙️ Your microphone has been UNMUTED.',
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
      final isMe = targetId != null && (targetId == currentUser?.id || targetId == currentUser?.username);

      if (isMe) {
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
      if (_activeRoom != null && data['roomId'] != null && data['roomId'] != _activeRoom!.id) {
        return;
      }
      _isLiveEnded = true;
      _liveEndedReason = data['message']?.toString() ?? data['reason']?.toString() ?? 'Live stream has ended.';
      _messages.add(LiveMessage(sender: 'System', text: '🛑 ${_liveEndedReason!}'));
      _roomClosedController.add(Map<String, dynamic>.from(data));
      notifyListeners();
    });

    // ── PK Battle Real-time Subscriptions ───────────────────
    _socketPkCreatedSub?.cancel();
    _socketPkCreatedSub = _socketService.onPkCreated.listen((data) {
      try {
        final pk = PKBattleModel.fromJson(data);
        setPkBattle(pk);
      } catch (e) {
        debugPrint('[LiveProvider] PK created parse error: $e');
      }
    });

    _socketPkPreparingSub?.cancel();
    _socketPkPreparingSub = _socketService.onPkPreparing.listen((data) {
      try {
        final pk = PKBattleModel.fromJson(data);
        setPkBattle(pk);
        final isHost = _activeRoom != null && (_activeRoom!.host.id == currentUser?.id || _activeRoom!.creatorUserId == currentUser?.id);
        if (isHost) {
          PKRepository.instance.setOperatorReady(matchId: pk.id, mediaPrepared: true);
        }
      } catch (e) {
        debugPrint('[LiveProvider] PK preparing error: $e');
      }
    });

    _socketPkCountdownSub?.cancel();
    _socketPkCountdownSub = _socketService.onPkCountdownStarted.listen((data) {
      _pkCountdown = 3;
      notifyListeners();
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_pkCountdown > 0) {
          _pkCountdown--;
          notifyListeners();
        } else {
          timer.cancel();
        }
      });
    });

    _socketPkParticipantJoinedSub?.cancel();
    _socketPkParticipantJoinedSub = _socketService.onPkParticipantJoined.listen((data) {
      try {
        final pk = PKBattleModel.fromJson(data);
        setPkBattle(pk);
      } catch (e) {
        debugPrint('[LiveProvider] PK participant joined parse error: $e');
      }
    });

    _socketPkReadySub?.cancel();
    _socketPkReadySub = _socketService.onPkReady.listen((data) {
      try {
        final pk = PKBattleModel.fromJson(data);
        setPkBattle(pk);
      } catch (e) {
        debugPrint('[LiveProvider] PK ready parse error: $e');
      }
    });

    _socketPkStartedSub?.cancel();
    _socketPkStartedSub = _socketService.onPkStarted.listen((data) {
      try {
        final pk = PKBattleModel.fromJson(data);
        _pkCountdown = 0;
        _isPkOpponentDisconnected = false;
        setPkBattle(pk);
        _setupVideoPkRelay(pk);
      } catch (e) {
        debugPrint('[LiveProvider] PK started parse error: $e');
      }
    });

    _socketPkScoreSub?.cancel();
    _socketPkScoreSub = _socketService.onPkScoreUpdated.listen((data) {
      if (_activePkBattle != null) {
        final scoreA = int.tryParse(data['scoreA']?.toString() ?? data['hostAScore']?.toString() ?? '') ?? _activePkBattle!.scoreA;
        final scoreB = int.tryParse(data['scoreB']?.toString() ?? data['hostBScore']?.toString() ?? '') ?? _activePkBattle!.scoreB;
        _activePkBattle = _activePkBattle!.copyWith(scoreA: scoreA, scoreB: scoreB);
        notifyListeners();
      }
    });

    _socketPkHostConnectionSub?.cancel();
    _socketPkHostConnectionSub = _socketService.onPkHostConnectionChanged.listen((data) {
      final status = data['status']?.toString();
      if (status == 'OFFLINE' || status == 'RECONNECTING') {
        _isPkOpponentDisconnected = true;
        _pkDisconnectGrace = data['graceRemainingSeconds'] ?? 30;
      } else if (status == 'CONNECTED') {
        _isPkOpponentDisconnected = false;
      }
      notifyListeners();
    });

    _socketPkMatchFinishedSub?.cancel();
    _socketPkMatchFinishedSub = _socketService.onPkMatchFinished.listen((data) {
      try {
        final pk = PKBattleModel.fromJson(data);
        _activePkBattle = pk;
        _pkTimer?.cancel();
        _agoraService.leaveOpponentPKChannel();
        _pkResultController.add(pk);
        notifyListeners();
      } catch (_) {}
    });

    _socketPkForfeitedSub?.cancel();
    _socketPkForfeitedSub = _socketService.onPkMatchForfeited.listen((data) {
      try {
        final pk = PKBattleModel.fromJson(data);
        _activePkBattle = pk;
        _pkTimer?.cancel();
        _agoraService.leaveOpponentPKChannel();
        _messages.add(LiveMessage(sender: 'System', text: '⚔️ PK ended: ${data['endReason'] ?? "Opponent forfeited."}'));
        _pkResultController.add(pk);
        notifyListeners();
      } catch (_) {}
    });

    _socketPkAbortedSub?.cancel();
    _socketPkAbortedSub = _socketService.onPkMatchAborted.listen((data) {
      try {
        final pk = PKBattleModel.fromJson(data);
        _activePkBattle = pk;
        _pkTimer?.cancel();
        _agoraService.leaveOpponentPKChannel();
        _messages.add(LiveMessage(sender: 'System', text: '⚠️ PK aborted: ${data['endReason'] ?? "Incident."}'));
        notifyListeners();
      } catch (_) {}
    });

    _socketPkEndedSub?.cancel();
    _socketPkEndedSub = _socketService.onPkEnded.listen((data) {
      if (_activePkBattle != null) {
        final winner = data['winnerHostUserId']?.toString() ?? data['winnerHostId']?.toString();
        _activePkBattle = _activePkBattle!.copyWith(
          winnerId: winner,
          status: 'FINISHED',
        );
        _pkTimer?.cancel();
        _agoraService.leaveOpponentPKChannel();
        notifyListeners();
      }
    });

    _socketPkInviteSub?.cancel();
    _socketPkInviteSub = _socketService.onPkInvitationReceived.listen((data) {
      _pkInvitationReceivedController.add(data);
    });
  }

  Future<void> closeRoom() async {
    final roomId = _activeRoom?.id;
    if (roomId != null) {
      try {
        _socketService.closeRoomRealtime(roomId);
        await _roomRepository.closeRoom(roomId);
      } catch (_) {}
    }
    await leaveRoom();
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
    _socketUserKickedSub?.cancel();
    _socketRoomWarningSub?.cancel();
    _socketRoomMutedSub?.cancel();
    _socketRoomUserMutedSub?.cancel();
    _socketRoomSnapshotSub?.cancel();
    _socketPkCreatedSub?.cancel();
    _socketPkParticipantJoinedSub?.cancel();
    _socketPkReadySub?.cancel();
    _socketPkStartedSub?.cancel();
    _socketPkScoreSub?.cancel();
    _socketPkEndedSub?.cancel();
    _socketPkInviteSub?.cancel();
    _pkTimer?.cancel();
    _giftTimer?.cancel();

    _activeRoom = null;
    _currentUser = null;
    _messages.clear();
    _processedGiftTxIds.clear();
    _announcedViewerIds.clear();
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

  void sendMessage(String text, String sender, {UserModel? user, String? roomId}) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    final effectiveUser = user ?? _currentUser;
    final isHost = (effectiveUser != null && _activeRoom != null) &&
        (_activeRoom!.host.id == effectiveUser.id || _activeRoom!.creatorUserId == effectiveUser.id);

    final resolvedSender = (effectiveUser?.displayName.isNotEmpty == true)
        ? effectiveUser!.displayName
        : (sender.isNotEmpty
            ? sender
            : (effectiveUser?.name.isNotEmpty == true
                ? effectiveUser!.name
                : (effectiveUser?.username.isNotEmpty == true ? effectiveUser!.username : 'User')));

    final clientMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${effectiveUser?.id ?? "anon"}';

    final localMsg = LiveMessage(
      id: clientMsgId,
      senderId: effectiveUser?.id ?? '',
      sender: resolvedSender,
      text: trimmedText,
      avatarUrl: effectiveUser?.avatarUrl,
      isHost: isHost,
      isVip: effectiveUser?.isVip ?? false,
      nobleTitle: effectiveUser?.nobleTitle,
      avatarFrame: effectiveUser?.avatarFrame,
      chatBubble: (effectiveUser?.nobleTitle != null && effectiveUser!.nobleTitle!.isNotEmpty)
          ? NobleBadgeHelper.getChatBubbleAsset(effectiveUser.nobleTitle)
          : null,
    );

    _messages.add(localMsg);
    if (_messages.length > _maxMessageBuffer) {
      _messages.removeAt(0);
    }
    notifyListeners();

    final targetRoomId = (_activeRoom?.id.isNotEmpty == true) ? _activeRoom!.id : (roomId ?? '');
    if (targetRoomId.isNotEmpty && sender != 'System') {
      _socketService.sendRoomChatMessage(
        roomId: targetRoomId,
        text: trimmedText,
        sender: effectiveUser?.toJson(),
        messageId: clientMsgId,
      );
    }
  }

  void sendGift(GiftModel gift, String sender, {String? transactionId, int quantity = 1}) {
    _activeGiftAnimation = gift;
    _giftPoints += ((gift.priceCoins > 0 ? gift.priceCoins : gift.diamondPrice) * quantity);

    _giftTimer?.cancel();
    _giftTimer = Timer(const Duration(seconds: 3), () {
      _activeGiftAnimation = null;
      notifyListeners();
    });

    final txId = (transactionId != null && transactionId.isNotEmpty)
        ? transactionId
        : 'opt_${DateTime.now().millisecondsSinceEpoch}_${gift.id}';

    if (_processedGiftTxIds.contains(txId)) {
      notifyListeners();
      return;
    }
    _processedGiftTxIds.add(txId);
    if (_processedGiftTxIds.length > 500) {
      _processedGiftTxIds.remove(_processedGiftTxIds.first);
    }

    final isDuplicate = _messages.any((m) =>
        m.isGift &&
        (m.id == 'gift_$txId' ||
         ((m.senderId.isNotEmpty && m.senderId == (currentUser?.id ?? '')) ||
          m.sender.toLowerCase().trim() == sender.toLowerCase().trim()) &&
         m.text.toLowerCase().contains(gift.name.toLowerCase()) &&
         DateTime.now().difference(m.timestamp).inSeconds.abs() <= 5));

    if (!isDuplicate) {
      final isHostSender = (_activeRoom != null && currentUser != null) &&
          (currentUser!.id == _activeRoom!.host.id || currentUser!.id == _activeRoom!.creatorUserId);
      final effectiveAvatar = currentUser?.avatarUrl ?? (isHostSender ? _activeRoom?.host.avatarUrl : null);
      final formattedText = quantity > 1 ? 'sent $quantity × ${gift.name}!' : 'sent ${gift.name}!';

      _messages.add(
        LiveMessage(
          id: 'gift_$txId',
          sender: sender,
          senderId: currentUser?.id ?? '',
          avatarUrl: effectiveAvatar,
          isHost: isHostSender,
          text: formattedText,
          isGift: true,
          gift: gift,
        ),
      );
      if (_messages.length > _maxMessageBuffer) {
        _messages.removeAt(0);
      }
    }
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  void setPkBattle(PKBattleModel pk) {
    _activePkBattle = pk;
    _pkTimer?.cancel();
    if (pk.isStarted && !pk.isEnded) {
      _pkTimeRemainingSeconds = pk.calculateRemainingSeconds();
      if (_pkTimeRemainingSeconds > 0) {
        _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_pkTimeRemainingSeconds > 0) {
            _pkTimeRemainingSeconds--;
            notifyListeners();
          } else {
            _pkTimer?.cancel();
          }
        });
      }
    } else {
      _pkTimeRemainingSeconds = pk.durationSeconds > 0 ? pk.durationSeconds : 300;
    }
    notifyListeners();
  }

  void startPkBattle({UserModel? currentHost}) {
    final host = currentHost ?? _currentUser;
    final fallbackPk = PKBattleModel(
      id: 'pk_${DateTime.now().millisecondsSinceEpoch}',
      roomAId: _activeRoom?.id ?? '',
      hostA: host,
      hostB: const UserModel(
        id: 'host_opponent',
        username: 'opponent',
        name: 'Challenger',
        avatarUrl: '',
      ),
      durationSeconds: 180,
      status: 'STARTED',
      startedAt: DateTime.now(),
    );
    setPkBattle(fallbackPk);
  }

  /// Host initiates/creates a server-authoritative PK Battle session
  Future<PKBattleModel?> createHostPKBattle({int durationSeconds = 300}) async {
    if (_activeRoom == null) return null;
    try {
      final pk = await PKRepository.instance.createPKSession(
        roomId: _activeRoom!.id,
        durationSeconds: durationSeconds,
      );
      setPkBattle(pk);
      return pk;
    } catch (e) {
      debugPrint('[LiveProvider] createHostPKBattle error: $e');
      rethrow;
    }
  }

  /// Host invites a specific user or host
  Future<bool> sendPKInvite(String targetUserId) async {
    if (_activePkBattle == null) return false;
    try {
      await PKRepository.instance.sendPKInvite(
        pkId: _activePkBattle!.id,
        targetUserId: targetUserId,
      );
      return true;
    } catch (e) {
      debugPrint('[LiveProvider] sendPKInvite error: $e');
      rethrow;
    }
  }

  /// Host explicitly starts the PK Battle
  Future<PKBattleModel?> startHostPKBattle({UserModel? currentHost, UserModel? opponentHost}) async {
    if (_activePkBattle != null) {
      try {
        final pk = await PKRepository.instance.startPKBattle(_activePkBattle!.id);
        setPkBattle(pk);
        return pk;
      } catch (e) {
        debugPrint('[LiveProvider] startHostPKBattle remote error: $e');
        final active = _activePkBattle!.copyWith(status: 'STARTED', startedAt: DateTime.now());
        setPkBattle(active);
        return active;
      }
    }

    // Check if room has an active match on server
    if (_activeRoom != null) {
      try {
        final existing = await PKRepository.instance.getActiveMatchForRoom(_activeRoom!.id);
        if (existing != null) {
          setPkBattle(existing);
          return existing;
        }
      } catch (_) {}
    }

    // Initialize battle session with fallback to prevent infinite loading
    final host = currentHost ?? _currentUser ?? _activeRoom?.host ?? DummyData.currentUser;
    final opponent = opponentHost ?? DummyData.popularUsers.firstWhere(
      (u) => u.id != host.id,
      orElse: () => DummyData.popularUsers.first,
    );

    final newPk = PKBattleModel(
      id: 'pk_${DateTime.now().millisecondsSinceEpoch}',
      roomAId: _activeRoom?.id ?? 'room_${host.id}',
      roomBId: 'room_${opponent.id}',
      initiatorUserId: host.id,
      hostA: host,
      hostB: opponent,
      scoreA: 0,
      scoreB: 0,
      durationSeconds: 300,
      remainingSeconds: 300,
      status: 'STARTED',
      startedAt: DateTime.now(),
    );
    setPkBattle(newPk);
    return newPk;
  }

  /// Host ends the PK Battle
  Future<PKBattleModel?> endHostPKBattle() async {
    if (_activePkBattle == null) return null;
    try {
      final pk = await PKRepository.instance.endPKBattle(_activePkBattle!.id);
      setPkBattle(pk);
      return pk;
    } catch (e) {
      debugPrint('[LiveProvider] endHostPKBattle error: $e');
      rethrow;
    }
  }

  /// Join PK by invite code
  Future<PKBattleModel?> joinPKByCode(String code) async {
    try {
      final pk = await PKRepository.instance.joinByInviteCode(code);
      setPkBattle(pk);
      return pk;
    } catch (e) {
      debugPrint('[LiveProvider] joinPKByCode error: $e');
      rethrow;
    }
  }

  void _setupVideoPkRelay(PKBattleModel pk) {
    if (pk.agoraRelay == null) return;
    final relay = pk.agoraRelay!;
    final currentRoomId = _activeRoom?.id ?? '';
    String opponentChannel = relay.channelB;
    int opponentUid = relay.hostBUid;

    if (currentRoomId == pk.roomBId || currentRoomId == relay.channelB) {
      opponentChannel = relay.channelA;
      opponentUid = relay.hostAUid;
    }

    final localUid = _agoraService.currentUid ?? 0;
    _agoraService.joinOpponentPKChannel(
      opponentChannel: opponentChannel,
      localUid: localUid,
      opponentUid: opponentUid,
      isVideo: true,
    );
  }

  void toggleOpponentMute() {
    _isOpponentAudioMuted = !_isOpponentAudioMuted;
    _agoraService.muteOpponentAudio(_isOpponentAudioMuted);
    notifyListeners();
  }

  Future<void> requestPkRematch() async {
    if (_activePkBattle == null) return;
    try {
      await PKRepository.instance.requestRematch(_activePkBattle!.id);
    } catch (e) {
      debugPrint('[LiveProvider] requestPkRematch error: $e');
    }
  }

  /// Respond to PK invitation (Section 1)
  Future<void> respondToPKInvite(String inviteId, bool accept) async {
    try {
      await PKRepository.instance.respondInvitation(
        invitationId: inviteId,
        action: accept ? 'ACCEPT' : 'REJECT',
        targetRoomId: _activeRoom?.id,
      );
    } catch (e) {
      debugPrint('[LiveProvider] respondToPKInvite error: $e');
      rethrow;
    }
  }

  void endPkBattle() {
    _activePkBattle = null;
    _pkTimer?.cancel();
    _agoraService.leaveOpponentPKChannel();
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
