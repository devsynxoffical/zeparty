import 'dart:async';
import 'package:flutter/material.dart';
import '../core/services/agora_rtc_service.dart';
import '../core/services/socket_service.dart';
import '../core/repositories/room_repository.dart';
import '../models/live_room_model.dart';
import '../models/party_participant_model.dart';
import '../models/party_message_model.dart';
import '../models/user_model.dart';

class LivePartyProvider extends ChangeNotifier {
  final AgoraRtcService _agoraService = AgoraRtcService();
  final RoomRepository _roomRepository = RoomRepository.instance;
  final SocketService _socketService = SocketService.instance;

  LiveRoomModel? _activeRoom;
  LiveRoomModel? get activeRoom => _activeRoom;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  List<PartyParticipantModel> _participants = [];
  List<PartyParticipantModel> get participants => _participants;

  List<PartyMessageModel> _messages = [];
  List<PartyMessageModel> get messages => _messages;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Stream Subscriptions
  StreamSubscription? _speakerSub;
  StreamSubscription? _socketUserJoinedSub;
  StreamSubscription? _socketUserLeftSub;
  StreamSubscription? _socketSeatOccupiedSub;
  StreamSubscription? _socketSeatReleasedSub;
  StreamSubscription? _socketViewerCountSub;
  StreamSubscription? _socketRoomClosedSub;
  StreamSubscription? _socketGiftSentSub;
  StreamSubscription? _socketChatMessageSub;
  StreamSubscription? _socketUserKickedSub;
  StreamSubscription? _socketRoomWarningSub;
  StreamSubscription? _socketRoomMutedSub;
  StreamSubscription? _socketRoomUserMutedSub;

  // Admin Moderation State
  bool _isRoomMuted = false;
  bool get isRoomMuted => _isRoomMuted;
  String? _activeWarningMessage;
  String? get activeWarningMessage => _activeWarningMessage;

  // PK Battle State
  bool _isPkActive = false;
  bool get isPkActive => _isPkActive;
  int _pkScoreA = 0;
  int _pkScoreB = 0;
  int get pkScoreA => _pkScoreA;
  int get pkScoreB => _pkScoreB;
  int _pkTimerRemaining = 300; // 5 minutes
  int get pkTimerRemaining => _pkTimerRemaining;
  Timer? _pkTimer;
  UserModel? _pkOpponent;
  UserModel? get pkOpponent => _pkOpponent;

  // ── Module 05: Room Gift Activity & Deduplication ──
  final Set<String> _processedGiftTxIds = {};
  Set<String> get processedGiftTxIds => Set.unmodifiable(_processedGiftTxIds);

  // ── Module 06: Room Lock, YouTube, Super Wheel & Lucky Bag State ──
  bool _isRoomLocked = false;
  String _roomLockMode = 'PIN'; // 'PIN' or 'Approval'
  String _roomPinCode = '1234';
  final List<Map<String, String>> _pendingJoinRequests = [];

  bool get isRoomLocked => _isRoomLocked;
  String get roomLockMode => _roomLockMode;
  String get roomPinCode => _roomPinCode;
  List<Map<String, String>> get pendingJoinRequests => List.unmodifiable(_pendingJoinRequests);

  // YouTube Synchronization
  String? _youtubeVideoId;
  String _youtubeTitle = '';
  String _youtubePlayState = 'stopped'; // 'playing', 'paused', 'stopped'
  int _youtubePositionSeconds = 0;
  String? _youtubeSessionId;

  String? get youtubeVideoId => _youtubeVideoId;
  String get youtubeTitle => _youtubeTitle;
  String get youtubePlayState => _youtubePlayState;
  int get youtubePositionSeconds => _youtubePositionSeconds;
  String? get youtubeSessionId => _youtubeSessionId;

  // Super Wheel
  bool _isSuperWheelActive = false;
  String? _superWheelSessionId;
  Map<String, dynamic>? _lastSuperWheelResult;

  bool get isSuperWheelActive => _isSuperWheelActive;
  String? get superWheelSessionId => _superWheelSessionId;
  Map<String, dynamic>? get lastSuperWheelResult => _lastSuperWheelResult;

  // Lucky Bag
  bool _isLuckyBagActive = false;
  String? _luckyBagId;
  int _luckyBagTotalCoins = 0;
  int _luckyBagClaimsRemaining = 0;
  final Set<String> _luckyBagClaimedUserIds = {};

  bool get isLuckyBagActive => _isLuckyBagActive;
  String? get luckyBagId => _luckyBagId;
  int get luckyBagTotalCoins => _luckyBagTotalCoins;
  int get luckyBagClaimsRemaining => _luckyBagClaimsRemaining;
  Set<String> get luckyBagClaimedUserIds => Set.unmodifiable(_luckyBagClaimedUserIds);

  // Module 07: Mic Seat Audit Logs & Invitations & Seat Mute State
  final List<Map<String, dynamic>> _micSeatAuditLogs = [];
  final List<Map<String, dynamic>> _micSeatInvitations = [];
  final Set<int> _mutedSeatIndices = {};
  final Map<int, double> _seatVolumes = {}; // micIndex -> volume (0.0 to 1.0)

  List<Map<String, dynamic>> get micSeatAuditLogs => List.unmodifiable(_micSeatAuditLogs);
  List<Map<String, dynamic>> get micSeatInvitations => List.unmodifiable(_micSeatInvitations);
  Set<int> get mutedSeatIndices => Set.unmodifiable(_mutedSeatIndices);

  bool isSeatMuted(int seatIndex) {
    if (_mutedSeatIndices.contains(seatIndex)) return true;
    final occupant = _participants.where((p) => p.seatNumber == seatIndex).firstOrNull;
    return occupant?.micStatus == MicStatus.muted;
  }

  double getSeatVolume(int seatIndex) => _seatVolumes[seatIndex] ?? 1.0;

  void setSeatVolume(int seatIndex, double volume) {
    _seatVolumes[seatIndex] = volume.clamp(0.0, 1.0);
    notifyListeners();
  }

  // Module 08: Mic Reactions & Duration
  final Map<int, Map<String, dynamic>> _activeMicReactions = {};
  final Map<String, DateTime> _lastUserReactionTimestamp = {};
  int _reactionDurationSeconds = 3;

  Map<int, Map<String, dynamic>> get activeMicReactions => Map.unmodifiable(_activeMicReactions);
  int get reactionDurationSeconds => _reactionDurationSeconds;

  // Effects Settings Toggles
  bool _giftEffectsEnabled = true;
  bool get giftEffectsEnabled => _giftEffectsEnabled;

  bool _frameEffectsEnabled = true;
  bool get frameEffectsEnabled => _frameEffectsEnabled;

  bool _entryEffectsEnabled = true;
  bool get entryEffectsEnabled => _entryEffectsEnabled;

  bool _giftBannerNotificationEnabled = true;
  bool get giftBannerNotificationEnabled => _giftBannerNotificationEnabled;

  bool _redEnvelopeBannerNotificationEnabled = true;
  bool get redEnvelopeBannerNotificationEnabled => _redEnvelopeBannerNotificationEnabled;

  bool _gameBannerNotificationEnabled = true;
  bool get gameBannerNotificationEnabled => _gameBannerNotificationEnabled;

  bool _isSpeakerMuted = false;
  bool get isSpeakerMuted => _isSpeakerMuted;

  final Set<int> _lockedSeatIndices = {};
  Set<int> get lockedSeatIndices => _lockedSeatIndices;

  void toggleGiftEffects(bool value) {
    _giftEffectsEnabled = value;
    notifyListeners();
  }

  void toggleFrameEffects(bool value) {
    _frameEffectsEnabled = value;
    notifyListeners();
  }

  void toggleEntryEffects(bool value) {
    _entryEffectsEnabled = value;
    notifyListeners();
  }

  void toggleGiftBannerNotification(bool value) {
    _giftBannerNotificationEnabled = value;
    notifyListeners();
  }

  void toggleRedEnvelopeBannerNotification(bool value) {
    _redEnvelopeBannerNotificationEnabled = value;
    notifyListeners();
  }

  void toggleGameBannerNotification(bool value) {
    _gameBannerNotificationEnabled = value;
    notifyListeners();
  }

  Future<void> initialize() async {
    await _agoraService.initialize();
  }

  // ── Real Backend & Realtime Room Entry ─────────────────────────────────────
  Future<void> joinParty(LiveRoomModel room, UserModel currentUser, {String? password}) async {
    _isLoading = true;
    _errorMessage = null;
    _activeRoom = room;
    _currentUser = currentUser;
    _participants = [];
    _messages = [];
    notifyListeners();

    final isHost = (room.host.id == currentUser.id) ||
        (room.creatorUserId == currentUser.id) ||
        (room.host.name.trim().toLowerCase() == currentUser.name.trim().toLowerCase()) ||
        (room.host.username.trim().toLowerCase() == currentUser.username.trim().toLowerCase()) ||
        (currentUser.name.trim().isNotEmpty && room.title.toLowerCase().contains(currentUser.name.trim().toLowerCase()));

    try {
      // 1. Connect Socket.IO
      _socketService.connect();
      _socketService.joinRoom(room.id);
      _setupSocketSubscriptions(currentUser);

      // 2. Perform backend REST join
      final joinResult = await _roomRepository.joinRoom(room.id, password: password);
      final roomData = joinResult['room'] ?? joinResult;
      if (roomData is Map<String, dynamic> && roomData.isNotEmpty) {
        _activeRoom = LiveRoomModel.fromJson(roomData);
      }

      // Add Host and self to participants
      if (isHost) {
        _participants.add(PartyParticipantModel(
          user: currentUser.copyWith(
            avatarUrl: currentUser.avatarUrl.isNotEmpty ? currentUser.avatarUrl : room.host.avatarUrl,
            name: currentUser.name,
          ),
          role: ParticipantRole.host,
          seatNumber: 0,
          joinedAt: DateTime.now(),
        ));
      } else {
        // Place room host on Seat 0
        _participants.add(PartyParticipantModel(
          user: room.host,
          role: ParticipantRole.host,
          seatNumber: 0,
          joinedAt: room.startTime,
        ));

        // Add current user as listener
        _participants.add(PartyParticipantModel(
          user: currentUser,
          role: ParticipantRole.listener,
          seatNumber: null,
          joinedAt: DateTime.now(),
        ));
      }

      // 3. Acquire short-lived Agora RTC token from backend
      final agoraData = await _roomRepository.getAgoraToken(room.id);
      if (agoraData['token'] != null) {
        final token = agoraData['token'] as String;
        final channelName = agoraData['channelName'] as String? ?? room.agoraChannelName ?? room.id;
        final uid = agoraData['uid'] as int? ?? agoraData['agoraUid'] as int? ?? 0;
        final appId = agoraData['appId'] as String?;

        await _agoraService.initialize(appId: appId, enableVideo: false);
        await _agoraService.joinChannel(
          token,
          channelName,
          uid,
          isHost: isHost,
          isVideo: false,
        );
      }

      // 4. Listen to Agora Active Speaker stream
      _speakerSub?.cancel();
      _speakerSub = _agoraService.activeSpeakerStream.listen((uid) {
        final speakerParticipant = _participants.where((p) => p.seatNumber != null).firstOrNull;
        if (speakerParticipant != null) {
          // Temporarily pulse active speaking
        }
      });

      final displayName = currentUser.displayName.isNotEmpty
          ? currentUser.displayName
          : (currentUser.name.isNotEmpty ? currentUser.name : currentUser.username);
      sendSystemMessage('👋 Welcome to ${room.title}! Please follow community guidelines.');
      sendSystemMessage('🎉 $displayName joined the room! 🔥');
    } catch (e) {
      _errorMessage = e.toString();
      sendSystemMessage('⚠️ Room connection alert: ${_errorMessage ?? "Unknown error"}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  StreamSubscription? _socketRoomSnapshotSub;

  void _setupSocketSubscriptions(UserModel currentUser) {
    // 1. Room Snapshot Subscription (Authoritative Seat & Participant State)
    _socketRoomSnapshotSub?.cancel();
    _socketRoomSnapshotSub = _socketService.roomSnapshotStream.listen((data) {
      try {
        final roomObj = data['room'] is Map ? Map<String, dynamic>.from(data['room'] as Map) : <String, dynamic>{};
        if (roomObj.isNotEmpty) {
          _activeRoom = LiveRoomModel.fromJson(roomObj);
        }

        final seatsList = data['seats'] is List ? (data['seats'] as List) : (roomObj['seats'] is List ? (roomObj['seats'] as List) : []);
        for (final seatRaw in seatsList) {
          if (seatRaw is! Map) continue;
          final seatMap = Map<String, dynamic>.from(seatRaw);
          final seatIndex = (seatMap['seatIndex'] is num) ? (seatMap['seatIndex'] as num).toInt() : int.tryParse(seatMap['seatIndex']?.toString() ?? '');
          final userRaw = seatMap['user'];
          if (seatIndex != null && userRaw is Map) {
            final userMap = Map<String, dynamic>.from(userRaw);
            final userObj = UserModel(
              id: userMap['id']?.toString() ?? '',
              username: userMap['username']?.toString() ?? 'User',
              name: userMap['displayName']?.toString() ?? userMap['name']?.toString() ?? userMap['username']?.toString() ?? 'User',
              avatarUrl: userMap['avatarUrl']?.toString() ?? '',
            );
            if (userObj.id.isNotEmpty) {
              final isSeatHost = seatIndex == 0 || (_activeRoom != null && _activeRoom!.host.id == userObj.id);
              final existingIdx = _participants.indexWhere((p) => p.user.id == userObj.id || p.seatNumber == seatIndex);
              if (existingIdx != -1) {
                _participants[existingIdx] = _participants[existingIdx].copyWith(
                  user: userObj,
                  seatNumber: seatIndex,
                  role: isSeatHost ? ParticipantRole.host : ParticipantRole.speaker,
                  micStatus: seatMap['isMuted'] == true ? MicStatus.muted : MicStatus.on,
                );
              } else {
                _participants.add(PartyParticipantModel(
                  user: userObj,
                  role: isSeatHost ? ParticipantRole.host : ParticipantRole.speaker,
                  seatNumber: seatIndex,
                  micStatus: seatMap['isMuted'] == true ? MicStatus.muted : MicStatus.on,
                  joinedAt: DateTime.now(),
                ));
              }
            }
          }
        }
        notifyListeners();
      } catch (e) {
        debugPrint('[LivePartyProvider] Snapshot processing error: $e');
      }
    });

    // 2. User Joined Stream
    _socketUserJoinedSub?.cancel();
    _socketUserJoinedSub = _socketService.userJoinedStream.listen((data) {
      try {
        final userObj = data['user'] is Map ? Map<String, dynamic>.from(data['user'] as Map) : <String, dynamic>{};
        final joinedUserId = userObj['id']?.toString() ?? data['userId']?.toString() ?? data['id']?.toString();
        if (joinedUserId != null && joinedUserId != currentUser.id) {
          final existingIdx = _participants.indexWhere((p) => p.user.id == joinedUserId);
          if (existingIdx == -1) {
            final joinedUser = UserModel(
              id: joinedUserId,
              username: userObj['username']?.toString() ?? 'viewer',
              name: userObj['displayName']?.toString() ?? userObj['name']?.toString() ?? userObj['username']?.toString() ?? 'Viewer',
              avatarUrl: userObj['avatarUrl']?.toString() ?? '',
            );
            _participants.add(PartyParticipantModel(
              user: joinedUser,
              role: ParticipantRole.listener,
              seatNumber: null,
              joinedAt: DateTime.now(),
            ));
          }
          final displayName = userObj['displayName']?.toString() ?? userObj['name']?.toString() ?? userObj['username']?.toString() ?? 'A user';
          sendSystemMessage('👋 $displayName joined the room.');
          final viewerCount = (data['viewerCount'] is num) ? (data['viewerCount'] as num).toInt() : int.tryParse(data['viewerCount']?.toString() ?? '');
          if (viewerCount != null && _activeRoom != null) {
            _activeRoom = _activeRoom!.copyWith(viewerCount: viewerCount);
          }
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[LivePartyProvider] UserJoined error: $e');
      }
    });

    // 3. User Left Stream
    _socketUserLeftSub?.cancel();
    _socketUserLeftSub = _socketService.userLeftStream.listen((data) {
      final leftUserId = data['userId']?.toString() ?? data['id']?.toString();
      if (leftUserId != null) {
        _participants.removeWhere((p) => p.user.id == leftUserId);
        final viewerCount = (data['viewerCount'] is num) ? (data['viewerCount'] as num).toInt() : int.tryParse(data['viewerCount']?.toString() ?? '');
        if (viewerCount != null && _activeRoom != null) {
          _activeRoom = _activeRoom!.copyWith(viewerCount: viewerCount);
        }
        notifyListeners();
      }
    });

    // 4. Viewer Count Changed Stream
    _socketViewerCountSub?.cancel();
    _socketViewerCountSub = _socketService.viewerCountStream.listen((data) {
      final count = (data['viewerCount'] is num) ? (data['viewerCount'] as num).toInt() : (data['count'] is num ? (data['count'] as num).toInt() : null);
      if (count != null && _activeRoom != null) {
        _activeRoom = _activeRoom!.copyWith(viewerCount: count);
        notifyListeners();
      }
    });

    // 5. Seat Occupied Stream
    _socketSeatOccupiedSub?.cancel();
    _socketSeatOccupiedSub = _socketService.seatOccupiedStream.listen((data) {
      try {
        final seatIndex = (data['seatIndex'] is num) ? (data['seatIndex'] as num).toInt() : int.tryParse(data['seatIndex']?.toString() ?? '');
        final userMap = data['user'] is Map ? Map<String, dynamic>.from(data['user'] as Map) : null;
        if (seatIndex != null && userMap != null) {
          final occupantUser = UserModel(
            id: userMap['id']?.toString() ?? userMap['userId']?.toString() ?? '',
            username: userMap['username']?.toString() ?? userMap['name']?.toString() ?? 'Speaker',
            name: userMap['displayName']?.toString() ?? userMap['name']?.toString() ?? userMap['username']?.toString() ?? 'Speaker',
            avatarUrl: userMap['avatarUrl']?.toString() ?? '',
          );

          final pIdx = _participants.indexWhere((p) => p.user.id == occupantUser.id);
          if (pIdx != -1) {
            _participants[pIdx] = _participants[pIdx].copyWith(
              seatNumber: seatIndex,
              role: ParticipantRole.speaker,
              micStatus: MicStatus.on,
            );
          } else {
            _participants.add(PartyParticipantModel(
              user: occupantUser,
              role: ParticipantRole.speaker,
              seatNumber: seatIndex,
              micStatus: MicStatus.on,
              joinedAt: DateTime.now(),
            ));
          }

          if (occupantUser.id == currentUser.id) {
            _agoraService.switchRole(isHost: true);
          }

          sendSystemMessage('🎙️ ${occupantUser.name} took Mic ${seatIndex + 1}.');
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[LivePartyProvider] SeatOccupied error: $e');
      }
    });

    // 6. Seat Released Stream
    _socketSeatReleasedSub?.cancel();
    _socketSeatReleasedSub = _socketService.seatReleasedStream.listen((data) {
      try {
        final seatIndex = (data['seatIndex'] is num) ? (data['seatIndex'] as num).toInt() : int.tryParse(data['seatIndex']?.toString() ?? '');
        final userId = data['userId']?.toString() ?? data['releasedByUserId']?.toString();
        if (seatIndex != null) {
          final pIdx = _participants.indexWhere((p) => p.seatNumber == seatIndex);
          if (pIdx != -1) {
            final occupant = _participants[pIdx];
            _participants[pIdx] = occupant.copyWith(
              seatNumber: null,
              role: ParticipantRole.listener,
              micStatus: MicStatus.muted,
            );

            if (occupant.user.id == currentUser.id) {
              _agoraService.switchRole(isHost: false);
            }
            sendSystemMessage('🚫 ${occupant.user.name} released Mic ${seatIndex + 1}.');
          }
        } else if (userId != null) {
          final pIdx = _participants.indexWhere((p) => p.user.id == userId);
          if (pIdx != -1) {
            _participants[pIdx] = _participants[pIdx].copyWith(
              seatNumber: null,
              role: ParticipantRole.listener,
              micStatus: MicStatus.muted,
            );
            if (userId == currentUser.id) {
              _agoraService.switchRole(isHost: false);
            }
          }
        }
        notifyListeners();
      } catch (e) {
        debugPrint('[LivePartyProvider] SeatReleased error: $e');
      }
    });

    // 7. Room Closed Stream
    _socketRoomClosedSub?.cancel();
    _socketRoomClosedSub = _socketService.roomClosedStream.listen((data) {
      sendSystemMessage('🛑 Room has been closed by host.');
      leaveParty();
    });

    // 8. Gift Sent Stream
    _socketGiftSentSub?.cancel();
    _socketGiftSentSub = _socketService.giftSentStream.listen((data) {
      try {
        final txId = data['transactionId']?.toString() ?? data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
        if (_processedGiftTxIds.contains(txId)) return;
        _processedGiftTxIds.add(txId);

        final senderMap = data['sender'] is Map ? Map<String, dynamic>.from(data['sender'] as Map) : <String, dynamic>{};
        final receiverMap = data['receiver'] is Map ? Map<String, dynamic>.from(data['receiver'] as Map) : <String, dynamic>{};

        final sender = UserModel(
          id: data['senderUserId']?.toString() ?? senderMap['id']?.toString() ?? '',
          username: data['senderName']?.toString() ?? senderMap['name']?.toString() ?? 'User',
          name: data['senderName']?.toString() ?? senderMap['name']?.toString() ?? 'User',
          avatarUrl: data['senderAvatar']?.toString() ?? senderMap['avatarUrl']?.toString() ?? '',
        );
        final receiver = UserModel(
          id: data['receiverUserId']?.toString() ?? receiverMap['id']?.toString() ?? '',
          username: data['receiverName']?.toString() ?? receiverMap['name']?.toString() ?? 'Host',
          name: data['receiverName']?.toString() ?? receiverMap['name']?.toString() ?? 'Host',
          avatarUrl: '',
        );

        final giftMsg = PartyMessageModel(
          id: 'gift_$txId',
          sender: sender,
          receiver: receiver,
          text: '${sender.name} sent ${data['quantity'] ?? 1} × ${data['giftName'] ?? 'Gift'} 🎁',
          timestamp: DateTime.now(),
          isGiftMessage: true,
          giftId: data['giftId']?.toString() ?? '',
          giftName: data['giftName']?.toString() ?? 'Gift',
          giftIcon: data['giftIcon']?.toString() ?? '🎁',
          quantity: (data['quantity'] is num) ? (data['quantity'] as num).toInt() : 1,
          transactionId: txId,
          serverTimestamp: DateTime.now(),
        );
        _messages.add(giftMsg);
        notifyListeners();
      } catch (e) {
        debugPrint('[LivePartyProvider] GiftSent error: $e');
      }
    });

    // 9. Chat Message Stream
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
        final msgId = data['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';

        if (_messages.any((m) => m.id == msgId)) return;

        // Prevent duplicate self-messages added optimistically
        final isSelf = (senderId == currentUser.id || senderId == currentUser.username);
        if (isSelf && _messages.isNotEmpty) {
          final recentSelf = _messages.reversed.take(5).where((m) => m.sender.id == currentUser.id && m.text == text).firstOrNull;
          if (recentSelf != null && DateTime.now().difference(recentSelf.timestamp).inSeconds < 4) {
            return;
          }
        }

        final sender = UserModel(
          id: senderId,
          username: senderMap['username']?.toString() ?? 'User',
          name: senderMap['displayName']?.toString() ?? senderMap['name']?.toString() ?? senderMap['username']?.toString() ?? 'User',
          avatarUrl: senderMap['avatarUrl']?.toString() ?? '',
          isVip: senderMap['isVip'] == true,
          nobleTitle: senderMap['nobleTitle']?.toString() ?? senderMap['nobleLevel']?.toString(),
        );

        final msg = PartyMessageModel(
          id: msgId,
          sender: sender,
          text: text,
          timestamp: DateTime.tryParse(data['timestamp']?.toString() ?? '') ?? DateTime.now(),
        );

        _messages.add(msg);
        notifyListeners();
      } catch (e) {
        debugPrint('[LivePartyProvider] ChatMessage error: $e');
      }
    });

    // 10. User Kicked Stream
    _socketUserKickedSub?.cancel();
    _socketUserKickedSub = _socketService.onUserKicked.listen((data) {
      final targetUserId = data['targetUserId']?.toString();
      if (targetUserId == currentUser.id) {
        sendSystemMessage('🚫 You have been kicked out of this room by the host.');
        leaveParty();
      } else if (targetUserId != null) {
        final kickedIdx = _participants.indexWhere((p) => p.user.id == targetUserId);
        if (kickedIdx != -1) {
          final kickedName = _participants[kickedIdx].user.name;
          _participants.removeAt(kickedIdx);
          sendSystemMessage('🚫 $kickedName was removed from the room.');
          notifyListeners();
        }
      }
    });

    // 11. Admin moderation: Room Warning
    _socketRoomWarningSub?.cancel();
    _socketRoomWarningSub = _socketService.roomWarningStream.listen((data) {
      final roomId = data['roomId']?.toString() ?? '';
      if (_activeRoom != null && roomId.isNotEmpty && roomId != _activeRoom!.id) return;
      final msg = data['message'] ?? data['reason'] ?? 'Official moderation warning issued';
      _activeWarningMessage = msg.toString();
      sendSystemMessage('⚠️ MODERATION WARNING: $_activeWarningMessage');
      notifyListeners();
      Future.delayed(const Duration(seconds: 8), () {
        _activeWarningMessage = null;
        notifyListeners();
      });
    });

    // 12. Admin moderation: Room Mute
    _socketRoomMutedSub?.cancel();
    _socketRoomMutedSub = _socketService.roomMutedStream.listen((data) {
      final roomId = data['roomId']?.toString() ?? '';
      if (_activeRoom != null && roomId.isNotEmpty && roomId != _activeRoom!.id) return;
      final muted = data['isMuted'] == true || data['muted'] == true;
      _isRoomMuted = muted;
      try {
        _agoraService.muteLocalAudio(muted);
      } catch (_) {}
      sendSystemMessage(muted ? '🔇 Room audio has been MUTED by platform moderation.' : '🎙️ Room audio has been UNMUTED.');
      notifyListeners();
    });

    // 13. Admin moderation: Specific user muted
    _socketRoomUserMutedSub?.cancel();
    _socketRoomUserMutedSub = _socketService.onRoomUserMuted.listen((data) {
      final roomId = data['roomId']?.toString() ?? '';
      if (_activeRoom != null && roomId.isNotEmpty && roomId != _activeRoom!.id) return;
      final targetId = data['targetUserId']?.toString();
      final muted = data['isMuted'] == true;
      if (targetId != null && targetId == currentUser.id) {
        try {
          _agoraService.muteLocalAudio(muted);
        } catch (_) {}
        sendSystemMessage(muted ? '🔇 Your microphone has been muted by moderation.' : '🎙️ Your microphone has been unmuted.');
        notifyListeners();
      }
      if (targetId != null) {
        final idx = _participants.indexWhere((p) => p.user.id == targetId);
        if (idx != -1) {
          _participants[idx] = _participants[idx].copyWith(
            micStatus: muted ? MicStatus.muted : MicStatus.on,
          );
          notifyListeners();
        }
      }
    });
  }

  Future<void> leaveParty() async {
    final roomId = _activeRoom?.id;
    if (roomId != null) {
      try {
        _socketService.leaveRoom(roomId);
        await _roomRepository.leaveRoom(roomId);
      } catch (_) {}
    }

    await _agoraService.leaveChannel();

    _speakerSub?.cancel();
    _socketRoomSnapshotSub?.cancel();
    _socketUserJoinedSub?.cancel();
    _socketUserLeftSub?.cancel();
    _socketSeatOccupiedSub?.cancel();
    _socketSeatReleasedSub?.cancel();
    _socketViewerCountSub?.cancel();
    _socketRoomClosedSub?.cancel();
    _socketGiftSentSub?.cancel();
    _socketChatMessageSub?.cancel();
    _socketUserKickedSub?.cancel();
    _socketRoomWarningSub?.cancel();
    _socketRoomMutedSub?.cancel();
    _socketRoomUserMutedSub?.cancel();
    _pkTimer?.cancel();

    _activeRoom = null;
    _currentUser = null;
    _isPkActive = false;
    _participants = [];
    _messages = [];
    notifyListeners();
  }

  Future<void> closeRoom() async {
    final roomId = _activeRoom?.id;
    if (roomId != null) {
      try {
        await _roomRepository.closeRoom(roomId);
      } catch (_) {}
      await leaveParty();
    }
  }

  // ── Seat Management ────────────────────────────────────────────────────────
  Future<String?> takeMicSeat(int seatIndex, UserModel actor) async {
    if (isSeatLocked(seatIndex)) {
      return 'Mic ${seatIndex + 1} is locked.';
    }
    if (_activeRoom == null) return 'No active room.';

    try {
      await _roomRepository.occupySeat(_activeRoom!.id, seatIndex);
      _socketService.occupySeat(_activeRoom!.id, seatIndex);

      // Update local state
      final existingIdx = _participants.indexWhere((p) => p.user.id == actor.id);
      if (existingIdx != -1) {
        _participants[existingIdx] = _participants[existingIdx].copyWith(
          seatNumber: seatIndex,
          role: ParticipantRole.speaker,
          micStatus: MicStatus.on,
        );
      } else {
        _participants.add(PartyParticipantModel(
          user: actor,
          role: ParticipantRole.speaker,
          seatNumber: seatIndex,
          micStatus: MicStatus.on,
          joinedAt: DateTime.now(),
        ));
      }

      // Promote Agora Role to Broadcaster if actor is current user
      if (actor.id == _currentUser?.id) {
        await _agoraService.switchRole(isHost: true);
      }

      _logMicAudit(
        seatIndex: seatIndex,
        actorId: actor.id,
        actorRole: _getRoleString(actor.id),
        targetId: actor.id,
        action: 'TAKE_MIC',
        previousState: 'Audience',
        newState: 'Mic ${seatIndex + 1}',
      );

      sendSystemMessage('🎙️ ${actor.name} took Mic ${seatIndex + 1}.');
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> clearMicSeat(int seatIndex, {required UserModel actor}) async {
    if (_activeRoom == null) return;
    final occupant = _participants.where((p) => p.seatNumber == seatIndex).firstOrNull;

    try {
      await _roomRepository.leaveSeat(_activeRoom!.id, seatIndex);
      _socketService.leaveSeat(_activeRoom!.id, seatIndex);

      if (occupant != null) {
        final existingIdx = _participants.indexWhere((p) => p.user.id == occupant.user.id);
        if (existingIdx != -1) {
          _participants[existingIdx] = _participants[existingIdx].copyWith(
            seatNumber: null,
            role: ParticipantRole.listener,
            micStatus: MicStatus.muted,
          );
        }

        if (occupant.user.id == _currentUser?.id) {
          await _agoraService.switchRole(isHost: false);
        }

        _logMicAudit(
          seatIndex: seatIndex,
          actorId: actor.id,
          actorRole: _getRoleString(actor.id),
          targetId: occupant.user.id,
          action: 'CLEAR_MIC_SEAT',
          previousState: 'Occupied (${occupant.user.name})',
          newState: 'Empty',
        );

        sendSystemMessage('🚫 ${occupant.user.name} was moved off Mic ${seatIndex + 1}.');
        notifyListeners();
      }
    } catch (e) {
      sendSystemMessage('⚠️ Error leaving seat: $e');
    }
  }

  void takeSeat(UserModel user, int seatIndex) {
    takeMicSeat(seatIndex, user);
  }

  void lockMicSeat(int seatIndex, bool lock, {required UserModel actor}) {
    if (lock) {
      if (!_lockedSeatIndices.contains(seatIndex)) {
        _lockedSeatIndices.add(seatIndex);
        final onSeat = _participants.where((p) => p.seatNumber == seatIndex && p.role != ParticipantRole.host).firstOrNull;
        if (onSeat != null) clearMicSeat(seatIndex, actor: actor);
      }
    } else {
      _lockedSeatIndices.remove(seatIndex);
    }

    _logMicAudit(
      seatIndex: seatIndex,
      actorId: actor.id,
      actorRole: _getRoleString(actor.id),
      targetId: null,
      action: lock ? 'LOCK_MIC' : 'UNLOCK_MIC',
      previousState: lock ? 'Unlocked' : 'Locked',
      newState: lock ? 'Locked' : 'Unlocked',
    );

    sendSystemMessage(lock ? '🔒 Mic ${seatIndex + 1} locked.' : '🔓 Mic ${seatIndex + 1} unlocked.');
    notifyListeners();
  }

  void muteMicSeat(int seatIndex, bool mute, {required UserModel actor}) {
    if (mute) {
      _mutedSeatIndices.add(seatIndex);
    } else {
      _mutedSeatIndices.remove(seatIndex);
    }

    final occupantIdx = _participants.indexWhere((p) => p.seatNumber == seatIndex);
    if (occupantIdx != -1) {
      _participants[occupantIdx] = _participants[occupantIdx].copyWith(
        micStatus: mute ? MicStatus.muted : MicStatus.on,
      );
      if (_participants[occupantIdx].user.id == _currentUser?.id) {
        _agoraService.muteLocalAudio(mute);
      }
    }

    _logMicAudit(
      seatIndex: seatIndex,
      actorId: actor.id,
      actorRole: _getRoleString(actor.id),
      targetId: occupantIdx != -1 ? _participants[occupantIdx].user.id : null,
      action: mute ? 'MUTE_MIC' : 'UNMUTE_MIC',
      previousState: mute ? 'Active' : 'Muted',
      newState: mute ? 'Muted' : 'Active',
    );

    sendSystemMessage(mute ? '🔇 Mic ${seatIndex + 1} muted.' : '🔊 Mic ${seatIndex + 1} unmuted.');
    notifyListeners();
  }

  String? inviteUserToMic(int seatIndex, UserModel inviter, UserModel targetUser) {
    if (isSeatLocked(seatIndex)) return 'Cannot invite to a locked mic.';

    final inviteId = 'inv_${DateTime.now().millisecondsSinceEpoch}';
    final invitation = {
      'id': inviteId,
      'roomId': _activeRoom?.id ?? 'room_101',
      'micIndex': seatIndex,
      'invitingUserId': inviter.id,
      'invitingUserName': inviter.name,
      'targetUserId': targetUser.id,
      'targetUserName': targetUser.name,
      'createdAt': DateTime.now().toIso8601String(),
      'expiresAt': DateTime.now().add(const Duration(seconds: 30)).toIso8601String(),
      'status': 'pending',
    };

    _micSeatInvitations.add(invitation);

    _logMicAudit(
      seatIndex: seatIndex,
      actorId: inviter.id,
      actorRole: _getRoleString(inviter.id),
      targetId: targetUser.id,
      action: 'INVITE_MIC',
      previousState: 'Available',
      newState: 'Invited',
    );

    sendSystemMessage('📩 ${inviter.name} invited ${targetUser.name} to take Mic ${seatIndex + 1}.');
    notifyListeners();
    return inviteId;
  }

  void _logMicAudit({
    required int seatIndex,
    required String actorId,
    required String actorRole,
    required String? targetId,
    required String action,
    required String previousState,
    required String newState,
  }) {
    _micSeatAuditLogs.add({
      'roomId': _activeRoom?.id ?? 'room_101',
      'micIndex': seatIndex,
      'actorId': actorId,
      'actorRole': actorRole,
      'targetId': targetId,
      'action': action,
      'previousState': previousState,
      'newState': newState,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  String _getRoleString(String userId) {
    if (_activeRoom?.host.id == userId || _activeRoom?.creatorUserId == userId) return 'Host';
    final p = _participants.where((pt) => pt.user.id == userId).firstOrNull;
    if (p?.role == ParticipantRole.moderator) return 'Admin';
    return 'User';
  }

  bool isSeatLocked(int seatIndex) => _lockedSeatIndices.contains(seatIndex);

  void toggleSpeakerOutput() {
    _isSpeakerMuted = !_isSpeakerMuted;
    notifyListeners();
  }

  void muteLocalMic(bool muted) {
    _agoraService.muteLocalAudio(muted);
    final selfIdx = _participants.indexWhere((p) => p.user.id == _currentUser?.id);
    if (selfIdx != -1) {
      _participants[selfIdx] = _participants[selfIdx].copyWith(
        micStatus: muted ? MicStatus.muted : MicStatus.on,
      );
      notifyListeners();
    }
  }

  // ── Chat & Messages ────────────────────────────────────────────────────────
  void sendSystemMessage(String text) {
    _messages.add(PartyMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: const UserModel(
        id: 'system',
        username: 'system',
        name: 'System',
        avatarUrl: '',
      ),
      text: text,
      timestamp: DateTime.now(),
      isSystemMessage: true,
    ));
    notifyListeners();
  }

  void sendMessage(UserModel sender, String text) {
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    _messages.add(PartyMessageModel(
      id: msgId,
      sender: sender,
      text: text,
      timestamp: DateTime.now(),
    ));
    if (_activeRoom != null) {
      _socketService.sendRoomChatMessage(
        roomId: _activeRoom!.id,
        text: text,
      );
    }
    notifyListeners();
  }

  void sendGlobalFlyingMessage(String text, UserModel sender) {
    final msgId = 'flying_${DateTime.now().millisecondsSinceEpoch}';
    final fullText = '🚀 [GLOBAL FLYING MESSAGE]: $text';
    _messages.add(PartyMessageModel(
      id: msgId,
      sender: sender,
      text: fullText,
      timestamp: DateTime.now(),
    ));
    if (_activeRoom != null) {
      _socketService.sendRoomChatMessage(
        roomId: _activeRoom!.id,
        text: fullText,
        type: 'flying',
      );
    }
    notifyListeners();
  }

  // ── Reaction Anchoring ─────────────────────────────────────────────────────
  bool sendMicReaction({
    required String reactionAsset,
    required String category,
    required UserModel sender,
  }) {
    final occupant = _participants.where((p) => p.user.id == sender.id && p.seatNumber != null).firstOrNull;
    if (occupant == null || occupant.seatNumber == null) {
      return false;
    }

    final lastTime = _lastUserReactionTimestamp[sender.id];
    if (lastTime != null && DateTime.now().difference(lastTime).inMilliseconds < 1500) {
      return false;
    }
    _lastUserReactionTimestamp[sender.id] = DateTime.now();

    final micIndex = occupant.seatNumber!;
    final reactionEvent = {
      'id': 'react_${DateTime.now().millisecondsSinceEpoch}',
      'senderUserId': sender.id,
      'senderName': sender.name,
      'roomId': _activeRoom?.id ?? 'room_101',
      'micIndex': micIndex,
      'reactionAsset': reactionAsset,
      'category': category,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _activeMicReactions[micIndex] = reactionEvent;
    notifyListeners();

    Future.delayed(Duration(seconds: _reactionDurationSeconds), () {
      if (_activeMicReactions[micIndex]?['id'] == reactionEvent['id']) {
        _activeMicReactions.remove(micIndex);
        notifyListeners();
      }
    });

    return true;
  }

  void setReactionDuration(int seconds) {
    _reactionDurationSeconds = seconds.clamp(1, 10);
    notifyListeners();
  }

  // ── Tool Actions (SuperWheel, LuckyBag, YouTube, PK) ────────────────────────
  Map<String, dynamic> spinSuperWheelServer({
    required String userId,
    required String sessionId,
    required int costCoins,
  }) {
    _isSuperWheelActive = true;
    _superWheelSessionId = sessionId;

    final prizes = [
      {'name': '100 Coins 🪙', 'amount': 100, 'type': 'coins'},
      {'name': '500 Coins 🪙', 'amount': 500, 'type': 'coins'},
      {'name': 'Rose Gift 🌹', 'amount': 1, 'type': 'gift'},
      {'name': 'Gold Crown 👑', 'amount': 1, 'type': 'gift'},
      {'name': '1,000 Coins 💎', 'amount': 1000, 'type': 'coins'},
      {'name': 'VIP Frame 🏆', 'amount': 1, 'type': 'frame'},
    ];

    final winningIdx = (sessionId.hashCode.abs() + DateTime.now().millisecondsSinceEpoch) % prizes.length;
    final prize = prizes[winningIdx];

    _lastSuperWheelResult = {
      'sessionId': sessionId,
      'userId': userId,
      'prize': prize,
      'timestamp': DateTime.now().toIso8601String(),
    };

    sendSystemMessage('🎰 Super Wheel spun! Won: ${prize['name']}!');
    _isSuperWheelActive = false;
    notifyListeners();
    return _lastSuperWheelResult!;
  }

  String? createLuckyBag({
    required String id,
    required int totalCoins,
    required int totalClaims,
  }) {
    if (totalCoins <= 0 || totalClaims <= 0) {
      return 'Total coins and claim quantity must be greater than 0.';
    }

    _isLuckyBagActive = true;
    _luckyBagId = id;
    _luckyBagTotalCoins = totalCoins;
    _luckyBagClaimsRemaining = totalClaims;
    _luckyBagClaimedUserIds.clear();

    sendSystemMessage('💰 Lucky Bag live! $totalCoins Coins for $totalClaims users — Grab fast!');
    notifyListeners();
    return null;
  }

  Map<String, dynamic>? claimLuckyBag({
    required String userId,
    required String userName,
  }) {
    if (!_isLuckyBagActive || _luckyBagClaimsRemaining <= 0) {
      return null;
    }

    if (_luckyBagClaimedUserIds.contains(userId)) {
      return {'status': 'Already Claimed', 'coins': 0};
    }

    _luckyBagClaimedUserIds.add(userId);
    final reward = (_luckyBagTotalCoins / (_luckyBagClaimedUserIds.length + _luckyBagClaimsRemaining)).round().clamp(10, _luckyBagTotalCoins);
    _luckyBagClaimsRemaining--;

    if (_luckyBagClaimsRemaining <= 0) {
      _isLuckyBagActive = false;
    }

    sendSystemMessage('🎉 $userName claimed $reward Coins from Lucky Bag!');
    notifyListeners();

    return {
      'status': 'Success',
      'coins': reward,
      'remaining': _luckyBagClaimsRemaining,
    };
  }

  void startYouTubeTrack({
    required String videoId,
    required String title,
    required String sessionId,
  }) {
    _youtubeVideoId = videoId;
    _youtubeTitle = title;
    _youtubePlayState = 'playing';
    _youtubePositionSeconds = 0;
    _youtubeSessionId = sessionId;
    sendSystemMessage('📺 Host started YouTube video: "$title"');
    notifyListeners();
  }

  void setYouTubePlayState(String state, {int? position}) {
    _youtubePlayState = state;
    if (position != null) {
      _youtubePositionSeconds = position;
    }
    notifyListeners();
  }

  void stopYouTubeTrack() {
    _youtubeVideoId = null;
    _youtubeTitle = '';
    _youtubePlayState = 'stopped';
    _youtubePositionSeconds = 0;
    _youtubeSessionId = null;
    sendSystemMessage('📺 Host stopped YouTube playback.');
    notifyListeners();
  }

  void startPk(UserModel opponent) {
    _pkOpponent = opponent;
    _isPkActive = true;
    _pkScoreA = 0;
    _pkScoreB = 0;
    _pkTimerRemaining = 300;
    notifyListeners();

    _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_pkTimerRemaining > 0) {
        _pkTimerRemaining--;
        notifyListeners();
      } else {
        endPk();
      }
    });
  }

  void endPk() {
    _isPkActive = false;
    _pkTimer?.cancel();
    notifyListeners();
  }

  void addPkScore(bool isHostA, int amount) {
    if (isHostA) {
      _pkScoreA += amount;
    } else {
      _pkScoreB += amount;
    }
    notifyListeners();
  }

  void updateRoomTypeAndCapacity(String roomType, int capacity) {
    if (_activeRoom != null) {
      _activeRoom = _activeRoom!.copyWith(
        roomType: roomType,
        seatCapacity: capacity,
      );
      sendSystemMessage('⚙️ Room mode changed to $roomType ($capacity seats).');
      notifyListeners();
    }
  }

  void muteParticipant(String userId) {
    final idx = _participants.indexWhere((p) => p.user.id == userId);
    if (idx != -1) {
      final p = _participants[idx];
      if (p.seatNumber != null && _currentUser != null) {
        muteMicSeat(p.seatNumber!, true, actor: _currentUser!);
      } else {
        _participants[idx] = p.copyWith(micStatus: MicStatus.muted);
        notifyListeners();
      }
    }
  }

  void unmuteParticipant(String userId) {
    final idx = _participants.indexWhere((p) => p.user.id == userId);
    if (idx != -1) {
      final p = _participants[idx];
      if (p.seatNumber != null && _currentUser != null) {
        muteMicSeat(p.seatNumber!, false, actor: _currentUser!);
      } else {
        _participants[idx] = p.copyWith(micStatus: MicStatus.on);
        notifyListeners();
      }
    }
  }

  void promoteToModerator(String userId) {
    final idx = _participants.indexWhere((p) => p.user.id == userId);
    if (idx != -1) {
      _participants[idx] = _participants[idx].copyWith(role: ParticipantRole.moderator);
      sendSystemMessage('⭐ ${_participants[idx].user.name} was promoted to Moderator.');
      notifyListeners();
    }
  }

  void demoteModerator(String userId) {
    final idx = _participants.indexWhere((p) => p.user.id == userId);
    if (idx != -1) {
      _participants[idx] = _participants[idx].copyWith(role: ParticipantRole.listener);
      sendSystemMessage('ℹ️ ${_participants[idx].user.name} moderator status removed.');
      notifyListeners();
    }
  }

  void removeParticipant(String userId) {
    final idx = _participants.indexWhere((p) => p.user.id == userId);
    if (idx != -1) {
      final targetName = _participants[idx].user.name;
      _participants.removeAt(idx);
      if (_activeRoom != null) {
        _socketService.kickUserFromRoom(
          roomId: _activeRoom!.id,
          targetUserId: userId,
        );
      }
      sendSystemMessage('🚫 $targetName was kicked out of the room.');
      notifyListeners();
    }
  }

  void toggleSeatLock(int index) {
    final locked = isSeatLocked(index);
    if (_currentUser != null) {
      lockMicSeat(index, !locked, actor: _currentUser!);
    }
  }

  void updateRoomDetails({
    String? coverUrl,
    String? title,
    String? category,
    String? nobleTitle,
    String? roomType,
    int? capacity,
  }) {
    if (_activeRoom != null) {
      _activeRoom = _activeRoom!.copyWith(
        coverUrl: coverUrl ?? _activeRoom!.coverUrl,
        title: title ?? _activeRoom!.title,
        category: category ?? _activeRoom!.category,
        nobleTitle: nobleTitle ?? _activeRoom!.nobleTitle,
        roomType: roomType ?? _activeRoom!.roomType,
        seatCapacity: capacity ?? _activeRoom!.seatCapacity,
      );
      sendSystemMessage('✏️ Room details updated.');
      notifyListeners();
    }
  }

  void configureRoomLock({required bool isLocked, String? mode, String? pin}) {
    _isRoomLocked = isLocked;
    if (mode != null) _roomLockMode = mode;
    if (pin != null) _roomPinCode = pin;
    sendSystemMessage(isLocked ? '🔒 Room is now locked ($mode).' : '🔓 Room is now unlocked.');
    notifyListeners();
  }

  bool validateRoomPin(String pin) => _roomPinCode == pin;

  void requestJoinRoom(UserModel user) {
    _pendingJoinRequests.add({
      'userId': user.id,
      'username': user.username,
      'name': user.name,
      'avatarUrl': user.avatarUrl,
      'requestedAt': DateTime.now().toIso8601String(),
    });
    sendSystemMessage('📩 ${user.name} requested to join the room.');
    notifyListeners();
  }

  void handleJoinRequest(String userId, bool accept) {
    _pendingJoinRequests.removeWhere((req) => req['userId'] == userId);
    if (accept) {
      sendSystemMessage('✅ User join request approved.');
    } else {
      sendSystemMessage('❌ User join request declined.');
    }
    notifyListeners();
  }

  void sendGiftActivityMessage({
    required UserModel sender,
    required UserModel receiver,
    required String giftName,
    required int quantity,
    required String giftIcon,
    String? giftId,
    String? transactionId,
  }) {
    final txId = transactionId ?? DateTime.now().millisecondsSinceEpoch.toString();
    if (_processedGiftTxIds.contains(txId)) return;
    _processedGiftTxIds.add(txId);

    final giftMsg = PartyMessageModel(
      id: 'gift_$txId',
      sender: sender,
      receiver: receiver,
      text: '${sender.name} sent $quantity × $giftName $giftIcon to ${receiver.name}',
      timestamp: DateTime.now(),
      isGiftMessage: true,
      giftId: giftId ?? '',
      giftName: giftName,
      giftIcon: giftIcon,
      quantity: quantity,
      transactionId: txId,
      serverTimestamp: DateTime.now(),
    );
    _messages.add(giftMsg);
    notifyListeners();
  }

  void kickFromSeat(String userId) {
    final seatIdx = _participants.where((p) => p.user.id == userId && p.seatNumber != null).firstOrNull?.seatNumber;
    if (seatIdx != null && _currentUser != null) {
      clearMicSeat(seatIdx, actor: _currentUser!);
    }
  }

  @override
  void dispose() {
    leaveParty();
    _agoraService.dispose();
    super.dispose();
  }
}
