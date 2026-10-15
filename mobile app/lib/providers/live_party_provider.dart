import 'dart:async';
import 'package:flutter/material.dart';
import '../core/services/agora_rtc_service.dart';
import '../core/services/socket_service.dart';
import '../core/repositories/room_repository.dart';
import '../core/repositories/backend_repository.dart';
import '../models/live_room_model.dart';
import '../models/party_participant_model.dart';
import '../models/party_message_model.dart';
import '../models/user_model.dart';
import '../core/services/room_config_manager.dart';

class LivePartyProvider extends ChangeNotifier {
  final AgoraRtcService _agoraService = AgoraRtcService();
  final RoomRepository _roomRepository = RoomRepository.instance;
  final SocketService _socketService = SocketService.instance;

  LiveRoomModel? _activeRoom;
  LiveRoomModel? get activeRoom => _activeRoom;
  String? _initialRoomId;
  String? get initialRoomId => _initialRoomId;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  List<PartyParticipantModel> _participants = [];
  List<PartyParticipantModel> get participants => _participants;

  List<PartyMessageModel> _messages = [];
  List<PartyMessageModel> get messages => _messages;

  final Set<String> _announcedJoinedUserIds = {};
  final Map<String, int> _recentSystemMessages = {};

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _lastJoinFailureReason;
  String? get lastJoinFailureReason => _lastJoinFailureReason;

  // Stream Subscriptions
  StreamSubscription? _speakerSub;
  StreamSubscription? _remoteUsersSub;
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
  StreamSubscription? _socketRoleUpdatedSub;
  StreamSubscription? _socketMicInviteSub;
  StreamSubscription? _socketMicInviteResponseSub;
  StreamSubscription? _socketFeedClearedSub;
  StreamSubscription? _socketDetailsUpdatedSub;
  StreamSubscription? _socketSeatLockedSub;
  StreamSubscription? _socketLayoutUpdatedSub;
  StreamSubscription? _socketSendingTotalSub;

  DateTime? _feedClearedAt;
  DateTime? get feedClearedAt => _feedClearedAt;

  final _incomingMicInviteController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onIncomingMicInvite => _incomingMicInviteController.stream;

  // Active outgoing pending invitations: targetUserId -> invitation map
  final Map<String, Map<String, dynamic>> _pendingOutgoingInvites = {};

  final _roomClosedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onRoomClosed => _roomClosedController.stream;

  bool _wasKicked = false;
  bool get wasKicked => _wasKicked;
  String? _kickReason;
  String? get kickReason => _kickReason;
  final _kickedController = StreamController<String>.broadcast();
  Stream<String> get onKicked => _kickedController.stream;

  bool get isHost {
    final room = _activeRoom;
    final user = _currentUser;
    if (room == null || user == null) return false;
    return (room.host.id == user.id) ||
        (room.creatorUserId == user.id) ||
        (room.host.name.trim().toLowerCase() == user.name.trim().toLowerCase()) ||
        (room.host.username.trim().toLowerCase() == user.username.trim().toLowerCase()) ||
        (user.name.trim().isNotEmpty && room.title.toLowerCase().contains(user.name.trim().toLowerCase()));
  }

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

  num _roomSendingTotal = 0;
  num get roomSendingTotal => _roomSendingTotal;
  void setRoomSendingTotal(num total) {
    _roomSendingTotal = total;
    if (_activeRoom != null) {
      RoomConfigManager.instance.saveRoomSendingTotal(_activeRoom!.id, total);
      _socketService.emitRoomSendingTotal(_activeRoom!.id, total);
    }
    notifyListeners();
  }

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

  void ensureSocketSubscribed(UserModel user, {String? roomId}) {
    _currentUser = user;
    final targetId = _activeRoom?.id ?? _initialRoomId ?? roomId;
    if (targetId != null && targetId.isNotEmpty) {
      _socketService.joinRoom(targetId, user: user.toJson());
      _setupSocketSubscriptions(user);
    }
  }

  Future<void> toggleSpeakerOutput() async {
    _isSpeakerMuted = !_isSpeakerMuted;
    await _agoraService.muteAllRemoteAudio(_isSpeakerMuted);
    notifyListeners();
  }

  Future<void> initialize() async {
    await _agoraService.initialize();
  }

  // ── Real Backend & Realtime Room Entry ─────────────────────────────────────
  Future<bool> joinParty(LiveRoomModel room, UserModel currentUser, {String? password}) async {
    _isLoading = true;
    _errorMessage = null;
    _activeRoom = room;
    _initialRoomId = room.id;
    _currentUser = currentUser;
    _participants = [];
    _messages = [];
    notifyListeners();

    if (room.status.toUpperCase() == 'ENDED' || room.status.toUpperCase() == 'CLOSED') {
      // Attempt to resolve current active session if the owner restarted the room
      try {
        final creatorId = room.creatorUserId;
        final hostId = (creatorId != null && creatorId.isNotEmpty) ? creatorId : room.host.id;
        final hostUsername = room.host.username.isNotEmpty ? room.host.username : null;
        final activeRooms = await _roomRepository.getActiveRooms(limit: 50);
        LiveRoomModel? currentActive;
        for (final r in activeRooms) {
          final rHostId = r.creatorUserId ?? r.host.id;
          final matchesHostId = hostId.isNotEmpty && (rHostId == hostId || r.host.id == hostId);
          final matchesUsername = hostUsername != null && hostUsername.isNotEmpty && r.host.username.toLowerCase() == hostUsername.toLowerCase();
          if (matchesHostId || matchesUsername) {
            currentActive = r;
            break;
          }
        }
        if (currentActive != null && currentActive.id != room.id) {
          debugPrint('[LivePartyProvider] Replaced ended room ${room.id} with current active session ${currentActive.id}');
          return await joinParty(currentActive, currentUser, password: password);
        }
      } catch (_) {}

      _errorMessage = 'ROOM_NOT_AVAILABLE';
      _lastJoinFailureReason = 'ROOM_NOT_AVAILABLE';
      _isLoading = false;
      _roomClosedController.add({
        'roomId': room.id,
        'status': 'ENDED',
        'reason': 'ROOM_NOT_AVAILABLE',
      });
      BackendRepository.instance.removeLiveRoom(room.id);
      notifyListeners();
      return false;
    }

    final isHost = (room.host.id == currentUser.id) ||
        (room.creatorUserId == currentUser.id) ||
        (room.host.name.trim().toLowerCase() == currentUser.name.trim().toLowerCase()) ||
        (room.host.username.trim().toLowerCase() == currentUser.username.trim().toLowerCase()) ||
        (currentUser.name.trim().isNotEmpty && room.title.toLowerCase().contains(currentUser.name.trim().toLowerCase()));

    try {
      // 1. Connect Socket.IO
      await _socketService.connect(user: currentUser.toJson());
      _socketService.joinRoom(room.id, user: currentUser.toJson());
      _setupSocketSubscriptions(currentUser);

      // 2. Perform backend REST join
      final joinResult = await _roomRepository.joinRoom(room.id, password: password);
      final roomData = joinResult['room'] ?? joinResult;
      if (roomData is Map<String, dynamic> && roomData.isNotEmpty) {
        _activeRoom = LiveRoomModel.fromJson(roomData);
        _socketService.joinRoom(_activeRoom!.id, user: currentUser.toJson());
      }

      // Re-fetch authoritative room details with seats state
      try {
        final details = await _roomRepository.getRoomDetails(room.id);
        _activeRoom = details;
      } catch (_) {}

      // Apply persistent room configuration overrides (Item 09, 11, 04, 08)
      if (_activeRoom != null) {
        _activeRoom = RoomConfigManager.instance.applyOverrides(_activeRoom!);
        _lockedSeatIndices.addAll(RoomConfigManager.instance.getLockedSeats(_activeRoom!.id));
        _roomSendingTotal = RoomConfigManager.instance.getRoomSendingTotal(_activeRoom!.id);

        // Synchronize Daily sending total with backend rankings
        RoomRepository.instance.getRoomSendingRankings(_activeRoom!.id, period: 'daily').then((res) {
          final serverDailyTotal = (res['periodTotalCoins'] as num?) ?? 0;
          if (serverDailyTotal > 0) {
            _roomSendingTotal = serverDailyTotal;
            RoomConfigManager.instance.saveRoomSendingTotal(_activeRoom!.id, serverDailyTotal);
            notifyListeners();
          }
        }).catchError((_) {});
      }

      final hostUserId = _activeRoom?.creatorUserId ?? _activeRoom?.host.id ?? room.host.id;
      final hostUserModel = isHost
          ? currentUser.copyWith(
              avatarUrl: currentUser.avatarUrl.isNotEmpty ? currentUser.avatarUrl : room.host.avatarUrl,
              name: currentUser.name,
            )
          : room.host;

      // Determine real seat positions from authoritative seats
      final seatsList = _activeRoom?.seats;
      int? hostSeatIndex;
      final seatedUsers = <int, UserModel>{};

      if (seatsList != null && seatsList.isNotEmpty) {
        for (final sRaw in seatsList) {
          if (sRaw is! Map) continue;
          final sMap = Map<String, dynamic>.from(sRaw);
          final sIdx = (sMap['seatIndex'] is num) ? (sMap['seatIndex'] as num).toInt() : int.tryParse(sMap['seatIndex']?.toString() ?? '');
          if (sIdx == null) continue;
          final occUserRaw = sMap['occupiedUser'] ?? sMap['user'];
          final occUserId = sMap['occupiedUserId']?.toString() ?? sMap['userId']?.toString() ?? (occUserRaw is Map ? occUserRaw['id']?.toString() : null);

          if (occUserId != null && occUserId.isNotEmpty) {
            final isHostOcc = occUserId == hostUserId || (isHost && occUserId == currentUser.id);
            if (isHostOcc) {
              hostSeatIndex = sIdx;
            } else if (occUserRaw is Map) {
              seatedUsers[sIdx] = UserModel.fromJson(Map<String, dynamic>.from(occUserRaw));
            } else {
              seatedUsers[sIdx] = UserModel(id: occUserId, name: 'Speaker ${sIdx + 1}', username: 'speaker_$sIdx', avatarUrl: '');
            }
          }
        }
      } else {
        // If room was just created and no seat array returned, default host to seat 0
        hostSeatIndex = 0;
      }

      // Add Host participant
      _participants.add(PartyParticipantModel(
        user: hostUserModel,
        role: ParticipantRole.host,
        seatNumber: hostSeatIndex,
        joinedAt: room.startTime,
        micStatus: hostSeatIndex != null ? MicStatus.on : MicStatus.muted,
      ));

      // Add any other seated speakers
      seatedUsers.forEach((sIdx, seatedUser) {
        if (seatedUser.id != hostUserModel.id) {
          _participants.add(PartyParticipantModel(
            user: seatedUser,
            role: ParticipantRole.speaker,
            seatNumber: sIdx,
            joinedAt: DateTime.now(),
            micStatus: MicStatus.on,
          ));
        }
      });

      // If current user is not host and not seated, add as listener
      if (!isHost) {
        final selfAlreadySeated = seatedUsers.values.any((u) => u.id == currentUser.id);
        if (!selfAlreadySeated) {
          _participants.add(PartyParticipantModel(
            user: currentUser,
            role: ParticipantRole.listener,
            seatNumber: null,
            joinedAt: DateTime.now(),
          ));
        }
      }

      // Fetch existing room members/viewers from backend
      try {
        final membersRes = await _roomRepository.getRoomMembers(room.id);
        final membersList = membersRes['data'] is List
            ? (membersRes['data'] as List)
            : (membersRes['members'] is List ? (membersRes['members'] as List) : []);
        for (final m in membersList) {
          if (m is! Map) continue;
          final userMap = m['user'] is Map ? (m['user'] as Map) : m;
          final uId = userMap['id']?.toString() ?? userMap['userId']?.toString();
          final uUsername = userMap['username']?.toString() ?? '';
          final isHostUser = (uId != null && (uId == room.host.id || uId == room.creatorUserId)) ||
              (room.host.username.isNotEmpty && uUsername.isNotEmpty && uUsername.toLowerCase() == room.host.username.toLowerCase());
          if (uId == null || uId.isEmpty || uId == currentUser.id || isHostUser) continue;
          final existing = _participants.any((p) =>
              p.user.id == uId ||
              (uUsername.isNotEmpty && p.user.username.isNotEmpty && p.user.username.toLowerCase() == uUsername.toLowerCase()));
          if (!existing) {
            final uName = userMap['displayName']?.toString() ??
                userMap['name']?.toString() ??
                (uUsername.isNotEmpty ? uUsername : 'Viewer');
            _participants.add(PartyParticipantModel(
              user: UserModel(
                id: uId,
                username: uUsername.isNotEmpty ? uUsername : uName,
                name: uName,
                avatarUrl: userMap['avatarUrl']?.toString() ?? '',
                nobleTitle: userMap['nobleTitle']?.toString() ?? userMap['nobleRank']?.toString(),
                isVip: userMap['isVip'] == true || (userMap['vipLevel'] is num && (userMap['vipLevel'] as num) > 0),
              ),
              role: ParticipantRole.listener,
              seatNumber: null,
              joinedAt: DateTime.now(),
            ));
          }
        }
      } catch (err) {
        debugPrint('[LivePartyProvider] Fetch members notice: $err');
      }

      _deduplicateParticipants();

      // 3. Acquire short-lived Agora RTC token from backend
      final isSelfSeated = _participants.any((p) => p.user.id == currentUser.id && p.seatNumber != null);
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
          isHost: isSelfSeated,
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

      // 5. Listen to Agora Remote Users (Keep real logged-in user names without overriding with dummy Guest IDs)
      _remoteUsersSub?.cancel();
      _remoteUsersSub = _agoraService.remoteUsersStream.listen((uids) {
        for (final uid in uids) {
          final isAlreadyTracked = _participants.any(
            (p) => p.user.id == uid.toString() || p.user.id == 'agora_$uid',
          );
          if (!isAlreadyTracked) {
            final guestUser = UserModel(
              id: 'agora_$uid',
              username: 'User_$uid',
              name: 'Guest $uid',
              avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100',
            );
            _participants.add(PartyParticipantModel(
              user: guestUser,
              role: ParticipantRole.listener,
              seatNumber: null,
              joinedAt: DateTime.now(),
            ));
          }
        }
        notifyListeners();
      });

      final displayName = currentUser.displayName.isNotEmpty
          ? currentUser.displayName
          : (currentUser.name.isNotEmpty ? currentUser.name : currentUser.username);
      _announcedJoinedUserIds.add(currentUser.id);
      sendSystemMessage('👋 Welcome to ${room.title}! Please follow community guidelines.');
      sendSystemMessage('🎉 $displayName has joined the party! 🔥');
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      final errLower = _errorMessage!.toLowerCase();
      final isUnavailable = errLower.contains('not live') ||
          errLower.contains('not available') ||
          errLower.contains('ended') ||
          errLower.contains('not found') ||
          errLower.contains('room_not_live') ||
          errLower.contains('room_not_found') ||
          errLower.contains('closed');

      if (isUnavailable) {
        // Attempt to resolve current active session of the room owner
        try {
          final creatorId = room.creatorUserId;
          final hostId = (creatorId != null && creatorId.isNotEmpty) ? creatorId : room.host.id;
          final hostUsername = room.host.username.isNotEmpty ? room.host.username : null;
          final activeRooms = await _roomRepository.getActiveRooms(limit: 50);
          LiveRoomModel? currentActive;
          for (final r in activeRooms) {
            final rHostId = r.creatorUserId ?? r.host.id;
            final matchesHostId = hostId.isNotEmpty && (rHostId == hostId || r.host.id == hostId);
            final matchesUsername = hostUsername != null && hostUsername.isNotEmpty && r.host.username.toLowerCase() == hostUsername.toLowerCase();
            if (matchesHostId || matchesUsername) {
              currentActive = r;
              break;
            }
          }
          if (currentActive != null && currentActive.id != room.id) {
            debugPrint('[LivePartyProvider] Resolved stale room ${room.id} to active session ${currentActive.id}');
            return await joinParty(currentActive, currentUser, password: password);
          }
        } catch (_) {}

        _errorMessage = 'ROOM_NOT_AVAILABLE';
        _lastJoinFailureReason = 'ROOM_NOT_AVAILABLE';
        _roomClosedController.add({
          'roomId': room.id,
          'status': 'ENDED',
          'reason': 'ROOM_NOT_AVAILABLE',
        });
        BackendRepository.instance.removeLiveRoom(room.id);
        return false;
      }
      _lastJoinFailureReason = 'CONNECTION_ERROR';
      sendSystemMessage('⚠️ Room connection alert: ${_errorMessage ?? "Unknown error"}');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  StreamSubscription? _socketRoomSnapshotSub;

  void _setupSocketSubscriptions(UserModel currentUser) {
    _currentUser = currentUser;
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
          final userRaw = seatMap['user'] ?? seatMap['occupiedUser'];
          if (seatIndex != null) {
            if (userRaw is Map && userRaw['id'] != null && userRaw['id'].toString().isNotEmpty) {
              final userMap = Map<String, dynamic>.from(userRaw);
              final userObj = UserModel(
                id: userMap['id']?.toString() ?? '',
                username: userMap['username']?.toString() ?? 'User',
                name: userMap['displayName']?.toString() ?? userMap['name']?.toString() ?? userMap['username']?.toString() ?? 'User',
                avatarUrl: userMap['avatarUrl']?.toString() ?? '',
              );
              if (userObj.id.isNotEmpty) {
                final isSeatHost = (_activeRoom != null && (_activeRoom!.host.id == userObj.id || _activeRoom!.creatorUserId == userObj.id)) ||
                    (isHost && _currentUser?.id == userObj.id);
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
            } else {
              // Authoritative vacant seat: vacate any participant currently marked with this seatIndex
              final emptySeatOccupant = _participants.indexWhere((p) => p.seatNumber == seatIndex);
              if (emptySeatOccupant != -1) {
                final occupant = _participants[emptySeatOccupant];
                final isHostOccupant = occupant.role == ParticipantRole.host ||
                    occupant.user.id == _activeRoom?.host.id ||
                    occupant.user.id == _activeRoom?.creatorUserId ||
                    (isHost && occupant.user.id == _currentUser?.id);
                _participants[emptySeatOccupant] = occupant.copyWith(
                  clearSeat: true,
                  role: isHostOccupant ? ParticipantRole.host : ParticipantRole.listener,
                  micStatus: MicStatus.muted,
                );
              }
            }
          }
        }
        _deduplicateParticipants();
        // Process existing members/viewers in snapshot
        final membersList = data['members'] is List
            ? (data['members'] as List)
            : (roomObj['members'] is List ? (roomObj['members'] as List) : []);
        for (final m in membersList) {
          if (m is! Map) continue;
          final userMap = m['user'] is Map ? (m['user'] as Map) : m;
          final uId = userMap['id']?.toString() ?? userMap['userId']?.toString();
          final uUsername = userMap['username']?.toString() ?? '';
          final isHostUser = (uId != null && (uId == _activeRoom?.host.id || uId == _activeRoom?.creatorUserId)) ||
              (_activeRoom != null && _activeRoom!.host.username.isNotEmpty && uUsername.isNotEmpty && uUsername.toLowerCase() == _activeRoom!.host.username.toLowerCase());
          if (uId == null || uId.isEmpty || uId == _currentUser?.id || isHostUser) continue;
          final existing = _participants.any((p) =>
              p.user.id == uId ||
              (uUsername.isNotEmpty && p.user.username.isNotEmpty && p.user.username.toLowerCase() == uUsername.toLowerCase()));
          if (!existing) {
            final uName = userMap['displayName']?.toString() ??
                userMap['name']?.toString() ??
                (uUsername.isNotEmpty ? uUsername : 'Viewer');
            _participants.add(PartyParticipantModel(
              user: UserModel(
                id: uId,
                username: uUsername.isNotEmpty ? uUsername : uName,
                name: uName,
                avatarUrl: userMap['avatarUrl']?.toString() ?? '',
                nobleTitle: userMap['nobleTitle']?.toString() ?? userMap['nobleRank']?.toString(),
                isVip: userMap['isVip'] == true || (userMap['vipLevel'] is num && (userMap['vipLevel'] as num) > 0),
              ),
              role: ParticipantRole.listener,
              seatNumber: null,
              joinedAt: DateTime.now(),
            ));
          }
        }

        final rawSnapshotCount = data['currentViewersCount'] ?? data['viewerCount'] ?? roomObj['currentViewersCount'] ?? roomObj['viewerCount'];
        final snapshotCount = (rawSnapshotCount is num) ? rawSnapshotCount.toInt() : int.tryParse(rawSnapshotCount?.toString() ?? '');
        final currentAudienceCount = _participants.where((p) => p.role != ParticipantRole.host && p.user.id != _activeRoom?.host.id && p.user.id != _activeRoom?.creatorUserId).length;
        final effectiveSnapshotCount = snapshotCount != null ? (snapshotCount > currentAudienceCount ? snapshotCount : currentAudienceCount) : currentAudienceCount;
        if (_activeRoom != null) {
          _activeRoom = _activeRoom!.copyWith(viewerCount: effectiveSnapshotCount);
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
        final joinedUserId = userObj['id']?.toString() ??
            userObj['userId']?.toString() ??
            data['userId']?.toString() ??
            data['id']?.toString();
        final uUsername = userObj['username']?.toString() ?? '';
        final displayName = userObj['displayName']?.toString() ??
            userObj['name']?.toString() ??
            (uUsername.isNotEmpty ? uUsername : (data['displayName']?.toString() ?? data['name']?.toString() ?? 'A user'));

        final isSelf = joinedUserId != null && currentUser.id == joinedUserId;
        final isHostUser = (joinedUserId != null && (_activeRoom != null && (joinedUserId == _activeRoom!.host.id || joinedUserId == _activeRoom!.creatorUserId))) ||
            (_activeRoom != null && _activeRoom!.host.username.isNotEmpty && uUsername.isNotEmpty && uUsername.toLowerCase() == _activeRoom!.host.username.toLowerCase());

        // Update participants for listeners
        if (joinedUserId != null && !isHostUser) {
          final existingIdx = _participants.indexWhere((p) =>
              p.user.id == joinedUserId ||
              (uUsername.isNotEmpty && p.user.username.isNotEmpty && p.user.username.toLowerCase() == uUsername.toLowerCase()));
          if (existingIdx == -1) {
            final joinedUser = UserModel(
              id: joinedUserId,
              username: uUsername.isNotEmpty ? uUsername : displayName,
              name: displayName,
              avatarUrl: userObj['avatarUrl']?.toString() ?? data['avatarUrl']?.toString() ?? '',
              nobleTitle: userObj['nobleTitle']?.toString() ?? userObj['nobleLevel']?.toString(),
              isVip: userObj['isVip'] == true || data['isVip'] == true,
            );
            _participants.add(PartyParticipantModel(
              user: joinedUser,
              role: ParticipantRole.listener,
              seatNumber: null,
              joinedAt: DateTime.now(),
            ));
          }
        }

        // Announce join in room chat
        final announceKey = joinedUserId ?? displayName;
        if (!_announcedJoinedUserIds.contains(announceKey)) {
          _announcedJoinedUserIds.add(announceKey);
          if (isSelf) {
            sendSystemMessage('🎉 Welcome $displayName to the party! 🔥');
          } else {
            sendSystemMessage('🎉 $displayName has joined the party! 🔥');
          }
        }

        final rawCount = data['viewerCount'] ?? data['count'] ?? data['currentViewersCount'];
        final parsedViewerCount = (rawCount is num) ? rawCount.toInt() : int.tryParse(rawCount?.toString() ?? '');
        final currentAudienceCount = _participants.where((p) => p.role != ParticipantRole.host && p.user.id != _activeRoom?.host.id && p.user.id != _activeRoom?.creatorUserId).length;
        final effectiveViewerCount = parsedViewerCount != null ? (parsedViewerCount > currentAudienceCount ? parsedViewerCount : currentAudienceCount) : currentAudienceCount;
        if (_activeRoom != null) {
          _activeRoom = _activeRoom!.copyWith(viewerCount: effectiveViewerCount);
        }
        notifyListeners();
      } catch (e) {
        debugPrint('[LivePartyProvider] UserJoined error: $e');
      }
    });

    // 3. User Left Stream
    _socketUserLeftSub?.cancel();
    _socketUserLeftSub = _socketService.userLeftStream.listen((data) {
      final leftUserId = data['userId']?.toString() ?? data['id']?.toString();
      if (leftUserId != null) {
        _announcedJoinedUserIds.remove(leftUserId);
        _pendingOutgoingInvites.remove(leftUserId);
        _participants.removeWhere((p) => p.user.id == leftUserId);
        final rawCount = data['viewerCount'] ?? data['count'] ?? data['currentViewersCount'];
        final parsedViewerCount = (rawCount is num) ? rawCount.toInt() : int.tryParse(rawCount?.toString() ?? '');
        final currentAudienceCount = _participants.where((p) => p.role != ParticipantRole.host && p.user.id != _activeRoom?.host.id && p.user.id != _activeRoom?.creatorUserId).length;
        final effectiveCount = parsedViewerCount ?? currentAudienceCount;
        if (_activeRoom != null) {
          _activeRoom = _activeRoom!.copyWith(viewerCount: effectiveCount);
        }
        notifyListeners();
      }
    });

    // 4. Viewer Count Changed Stream
    _socketViewerCountSub?.cancel();
    _socketViewerCountSub = _socketService.viewerCountStream.listen((data) {
      final rawCount = data['viewerCount'] ?? data['count'] ?? data['currentViewersCount'];
      final count = (rawCount is num) ? rawCount.toInt() : int.tryParse(rawCount?.toString() ?? '');
      if (_activeRoom != null) {
        final currentAudienceCount = _participants.where((p) => p.role != ParticipantRole.host && p.user.id != _activeRoom?.host.id && p.user.id != _activeRoom?.creatorUserId).length;
        final effectiveCount = count != null ? (count > currentAudienceCount ? count : currentAudienceCount) : currentAudienceCount;
        _activeRoom = _activeRoom!.copyWith(viewerCount: effectiveCount);
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
            id: userMap['id']?.toString() ?? userMap['_id']?.toString() ?? userMap['userId']?.toString() ?? '',
            username: userMap['username']?.toString() ?? userMap['name']?.toString() ?? 'Speaker',
            name: userMap['displayName']?.toString() ?? userMap['name']?.toString() ?? userMap['username']?.toString() ?? 'Speaker',
            avatarUrl: userMap['avatarUrl']?.toString() ?? '',
          );

          final isHostUser = occupantUser.id == _activeRoom?.host.id ||
              occupantUser.id == _activeRoom?.creatorUserId ||
              (isHost && occupantUser.id == currentUser.id) ||
              (_activeRoom != null && _activeRoom!.host.username.isNotEmpty && occupantUser.username.isNotEmpty && occupantUser.username.toLowerCase() == _activeRoom!.host.username.toLowerCase());

          // Detect previous seat occupied by this user to determine if it is a join or a move
          int? previousSeat;
          for (final p in _participants) {
            final isMatch = p.user.id == occupantUser.id ||
                (occupantUser.username.isNotEmpty && p.user.username.isNotEmpty && p.user.username.toLowerCase() == occupantUser.username.toLowerCase());
            if (isMatch && p.seatNumber != null) {
              previousSeat = p.seatNumber;
              break;
            }
          }
          final bool isUnchangedSeat = (previousSeat == seatIndex);

          // 1. Proactively vacate ANY previous seat held by occupantUser elsewhere
          for (int i = 0; i < _participants.length; i++) {
            final p = _participants[i];
            final isUserMatch = p.user.id == occupantUser.id ||
                (occupantUser.username.isNotEmpty && p.user.username.isNotEmpty && p.user.username.toLowerCase() == occupantUser.username.toLowerCase());
            if (isUserMatch && p.seatNumber != null && p.seatNumber != seatIndex) {
              _participants[i] = p.copyWith(
                clearSeat: true,
                role: (p.role == ParticipantRole.host || isHostUser) ? ParticipantRole.host : ParticipantRole.listener,
                micStatus: MicStatus.muted,
              );
            }
          }

          // 2. Proactively vacate ANY other participant who was previously sitting on seatIndex
          for (int i = 0; i < _participants.length; i++) {
            final p = _participants[i];
            final isNotOccupant = p.user.id != occupantUser.id &&
                (occupantUser.username.isEmpty || p.user.username.toLowerCase() != occupantUser.username.toLowerCase());
            if (p.seatNumber == seatIndex && isNotOccupant) {
              _participants[i] = p.copyWith(
                clearSeat: true,
                role: p.role == ParticipantRole.host ? ParticipantRole.host : ParticipantRole.listener,
                micStatus: MicStatus.muted,
              );
            }
          }

          final pIdx = _participants.indexWhere((p) =>
              p.user.id == occupantUser.id ||
              (occupantUser.username.isNotEmpty && p.user.username.isNotEmpty && p.user.username.toLowerCase() == occupantUser.username.toLowerCase()));
          if (pIdx != -1) {
            _participants[pIdx] = _participants[pIdx].copyWith(
              user: occupantUser,
              seatNumber: seatIndex,
              role: (isHostUser || _participants[pIdx].role == ParticipantRole.host) ? ParticipantRole.host : ParticipantRole.speaker,
              micStatus: MicStatus.on,
            );
          } else {
            _participants.add(PartyParticipantModel(
              user: occupantUser,
              role: isHostUser ? ParticipantRole.host : ParticipantRole.speaker,
              seatNumber: seatIndex,
              micStatus: MicStatus.on,
              joinedAt: DateTime.now(),
            ));
          }

          _pendingOutgoingInvites.remove(occupantUser.id);

          if (occupantUser.id == currentUser.id) {
            _agoraService.switchRole(isHost: true);
          }

          // Only announce if the seat state actually changed (ignore pings, refreshes, duplicate socket packets)
          if (!isUnchangedSeat) {
            if (previousSeat != null) {
              sendSystemMessage('🎙️ ${occupantUser.name} moved to Mic ${seatIndex + 1}.');
            } else {
              sendSystemMessage('🎙️ ${occupantUser.name} took Mic ${seatIndex + 1}.');
            }
          }
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
        int pIdx = -1;
        if (seatIndex != null) {
          pIdx = _participants.indexWhere((p) => p.seatNumber == seatIndex);
        }
        if (pIdx == -1 && userId != null) {
          pIdx = _participants.indexWhere((p) => p.user.id == userId);
        }

        if (pIdx != -1) {
          final occupant = _participants[pIdx];
          final isHostOccupant = occupant.role == ParticipantRole.host ||
              occupant.user.id == _activeRoom?.host.id ||
              occupant.user.id == _activeRoom?.creatorUserId ||
              (isHost && occupant.user.id == currentUser.id);

          _participants[pIdx] = occupant.copyWith(
            clearSeat: true,
            role: isHostOccupant ? ParticipantRole.host : ParticipantRole.listener,
            micStatus: MicStatus.muted,
          );

          if (occupant.user.id == currentUser.id) {
            _agoraService.muteLocalAudio(true);
            _agoraService.switchRole(isHost: false);
          }
          final sNum = seatIndex != null ? seatIndex + 1 : (occupant.seatNumber != null ? occupant.seatNumber! + 1 : 1);
          sendSystemMessage('🎙️ ${occupant.user.name} left Mic $sNum and moved to the audience.');
        } else if (seatIndex != null) {
          // Vacate any participant marked on seatIndex
          for (int i = 0; i < _participants.length; i++) {
            if (_participants[i].seatNumber == seatIndex) {
              _participants[i] = _participants[i].copyWith(
                clearSeat: true,
                role: _participants[i].role == ParticipantRole.host ? ParticipantRole.host : ParticipantRole.listener,
                micStatus: MicStatus.muted,
              );
            }
          }
        }
        _deduplicateParticipants();
        notifyListeners();
      } catch (e) {
        debugPrint('[LivePartyProvider] SeatReleased error: $e');
      }
    });

    // 7. Room Closed Stream
    _socketRoomClosedSub?.cancel();
    _socketRoomClosedSub = _socketService.roomClosedStream.listen((data) {
      final reason = data['reason']?.toString() ?? 'Room has been closed.';
      if (reason.contains('absent') || reason.contains('ABSENT')) {
        sendSystemMessage('⏰ Party ended: Host was absent for more than 2 minutes.');
      } else {
        sendSystemMessage('🛑 Room has been closed by host.');
      }
      _roomClosedController.add(Map<String, dynamic>.from(data));
      leaveParty();
    });

    // 8. Gift Sent Stream
    _socketGiftSentSub?.cancel();
    _socketGiftSentSub = _socketService.giftSentStream.listen((data) {
      try {
        final txId = data['transactionId']?.toString() ?? data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
        if (_processedGiftTxIds.contains(txId)) return;
        _processedGiftTxIds.add(txId);

        final inGiftRoomId = (data['roomId'] ?? data['room'] ?? '').toString().trim();
        if (inGiftRoomId.isNotEmpty) {
          String norm(String s) => s.toLowerCase().replaceAll('room:', '').trim();
          final inNorm = norm(inGiftRoomId);
          final currentNorm = norm(_activeRoom?.id ?? _initialRoomId ?? '');
          final initialNorm = norm(_initialRoomId ?? '');
          final validNormIds = <String>{
            if (currentNorm.isNotEmpty) currentNorm,
            if (initialNorm.isNotEmpty) initialNorm,
          };
          if (validNormIds.isNotEmpty) {
            final matches = validNormIds.contains(inNorm) ||
                validNormIds.any((id) => inNorm.contains(id) || id.contains(inNorm));
            if (!matches) return;
          }
        }

        final senderMap = data['sender'] is Map ? Map<String, dynamic>.from(data['sender'] as Map) : <String, dynamic>{};
        final receiverMap = data['receiver'] is Map ? Map<String, dynamic>.from(data['receiver'] as Map) : <String, dynamic>{};

        final sender = UserModel(
          id: data['senderUserId']?.toString() ?? senderMap['id']?.toString() ?? '',
          username: data['senderName']?.toString() ?? senderMap['name']?.toString() ?? senderMap['username']?.toString() ?? 'User',
          name: data['senderName']?.toString() ?? senderMap['name']?.toString() ?? senderMap['displayName']?.toString() ?? 'User',
          avatarUrl: data['senderAvatar']?.toString() ?? senderMap['avatarUrl']?.toString() ?? '',
        );
        final receiver = UserModel(
          id: data['receiverUserId']?.toString() ?? receiverMap['id']?.toString() ?? '',
          username: data['receiverName']?.toString() ?? receiverMap['name']?.toString() ?? receiverMap['username']?.toString() ?? 'Host',
          name: data['receiverName']?.toString() ?? receiverMap['name']?.toString() ?? receiverMap['displayName']?.toString() ?? 'Host',
          avatarUrl: receiverMap['avatarUrl']?.toString() ?? '',
        );

        final giftName = data['giftName']?.toString() ?? 'Gift';
        final giftIcon = data['giftIcon']?.toString() ?? '🎁';
        final quantity = (data['quantity'] is num) ? (data['quantity'] as num).toInt() : int.tryParse(data['quantity']?.toString() ?? '') ?? 1;

        final giftMsg = PartyMessageModel(
          id: 'gift_$txId',
          sender: sender,
          receiver: receiver,
          text: '${sender.name} sent $quantity × $giftName $giftIcon to ${receiver.name}',
          timestamp: DateTime.now(),
          isGiftMessage: true,
          giftId: data['giftId']?.toString() ?? '',
          giftName: giftName,
          giftIcon: giftIcon,
          quantity: quantity,
          transactionId: txId,
          serverTimestamp: DateTime.now(),
        );
        _messages.add(giftMsg);
        if (_messages.length > 100) {
          _messages.removeAt(0);
        }

        // Synchronize Room Sending Coin Total (Item 08)
        final coinAmount = (data['coinAmount'] ?? data['coins'] ?? data['cost'] ?? data['totalCoins'] ?? (quantity * (data['price'] ?? 100))) as num;
        _roomSendingTotal += coinAmount;
        if (_activeRoom != null) {
          RoomConfigManager.instance.saveRoomSendingTotal(_activeRoom!.id, _roomSendingTotal);
        }

        notifyListeners();
      } catch (e) {
        debugPrint('[LivePartyProvider] GiftSent error: $e');
      }
    });

    // 9. Chat Message Stream
    _socketChatMessageSub?.cancel();
    _socketChatMessageSub = _socketService.onRoomChatMessage.listen((data) {
      try {
        final incomingRoomId = (data['roomId'] ?? '').toString().trim();
        final incomingClientRoomId = (data['clientRoomId'] ?? data['room'] ?? '').toString().trim();
        String norm(String s) => s.toLowerCase().replaceAll('room:', '').trim();
        final inNorm = norm(incomingRoomId);
        final inClientNorm = norm(incomingClientRoomId);
        final currentNorm = norm(_activeRoom?.id ?? _initialRoomId ?? '');
        final initialNorm = norm(_initialRoomId ?? '');

        final validNormIds = <String>{
          if (currentNorm.isNotEmpty) currentNorm,
          if (initialNorm.isNotEmpty) initialNorm,
          if (_activeRoom?.agoraChannelName != null && _activeRoom!.agoraChannelName!.isNotEmpty)
            norm(_activeRoom!.agoraChannelName!),
        };

        if (validNormIds.isNotEmpty && inNorm.isNotEmpty) {
          final match = validNormIds.contains(inNorm) ||
              (inClientNorm.isNotEmpty && validNormIds.contains(inClientNorm)) ||
              validNormIds.any((id) => inNorm.contains(id) || id.contains(inNorm));
          if (!match) return;
        }

        final senderMap = data['sender'] is Map
            ? Map<String, dynamic>.from(data['sender'] as Map)
            : (data['user'] is Map
                ? Map<String, dynamic>.from(data['user'] as Map)
                : (data['senderUser'] is Map ? Map<String, dynamic>.from(data['senderUser'] as Map) : <String, dynamic>{}));
        final senderId = (senderMap['id'] ?? senderMap['_id'] ?? data['senderUserId'] ?? data['userId'] ?? '').toString();
        final text = (data['text'] ?? data['message'] ?? data['content'] ?? data['msg'] ?? '').toString().trim();
        if (text.isEmpty) return;

        // Message dropped if created before room feed clear boundary
        final createdAtRaw = data['createdAt'] ?? data['timestamp'];
        if (_feedClearedAt != null && createdAtRaw != null) {
          final msgTime = DateTime.tryParse(createdAtRaw.toString());
          if (msgTime != null && msgTime.isBefore(_feedClearedAt!)) {
            return;
          }
        }

        final msgId = (data['id'] ?? data['_id'] ?? '').toString();
        final clientMsgId = data['clientMessageId']?.toString();

        // 1. Direct ID check
        if (msgId.isNotEmpty && _messages.any((m) => m.id == msgId)) return;
        if (clientMsgId != null && clientMsgId.isNotEmpty && _messages.any((m) => m.id == clientMsgId)) return;

        final senderName = senderMap['displayName']?.toString() ??
            senderMap['name']?.toString() ??
            senderMap['username']?.toString() ??
            data['senderName']?.toString() ??
            'User';

        final senderUsername = senderMap['username']?.toString() ?? '';

        final isCurrentLocalUser = (_currentUser != null && senderId.isNotEmpty && senderId == _currentUser!.id) ||
            (_currentUser != null && _currentUser!.username.isNotEmpty && senderUsername.isNotEmpty && senderUsername.toLowerCase() == _currentUser!.username.toLowerCase());

        // 2. Message deduplication ONLY for the local user's own optimistic message within 8s
        if (isCurrentLocalUser && _messages.isNotEmpty) {
          final recentMatchingIndex = _messages.lastIndexWhere((m) =>
            (m.sender.id == _currentUser!.id || m.sender.username == _currentUser!.username) &&
            m.text.trim() == text &&
            DateTime.now().difference(m.timestamp).inSeconds < 8
          );

          if (recentMatchingIndex != -1) {
            // Update optimistic message with server message ID if provided
            if (msgId.isNotEmpty) {
              final existing = _messages[recentMatchingIndex];
              _messages[recentMatchingIndex] = PartyMessageModel(
                id: msgId,
                sender: existing.sender,
                text: existing.text,
                timestamp: existing.timestamp,
                isSystemMessage: existing.isSystemMessage,
              );
            }
            return;
          }
        }

        final isSystem = data['isSystemMessage'] == true ||
            data['type']?.toString().toUpperCase() == 'SYSTEM' ||
            senderId == 'system' ||
            text.contains('has joined the party') ||
            text.contains('joined the party') ||
            text.contains('entered the room');

        final sender = UserModel(
          id: senderId.isNotEmpty ? senderId : (isSystem ? 'system' : 'user_${DateTime.now().millisecondsSinceEpoch}'),
          username: senderUsername.isNotEmpty ? senderUsername : senderName,
          name: senderName,
          avatarUrl: senderMap['avatarUrl']?.toString() ?? '',
          isVip: senderMap['isVip'] == true || (senderMap['vipLevel'] is num && (senderMap['vipLevel'] as num) > 0),
          nobleTitle: senderMap['nobleTitle']?.toString() ?? senderMap['nobleLevel']?.toString(),
          avatarFrame: senderMap['avatarFrame']?.toString() ?? '',
          badge: senderMap['chatBubble']?.toString() ?? senderMap['badge']?.toString() ?? '',
          wealthLevel: (senderMap['wealthLevel'] is num) ? (senderMap['wealthLevel'] as num).toInt() : 1,
        );

        final msg = PartyMessageModel(
          id: msgId.isNotEmpty ? msgId : 'msg_${DateTime.now().millisecondsSinceEpoch}',
          sender: sender,
          text: text,
          timestamp: DateTime.tryParse(data['timestamp']?.toString() ?? '') ?? DateTime.now(),
          isSystemMessage: isSystem,
        );

        _messages.add(msg);
        if (_messages.length > 100) {
          _messages.removeAt(0);
        }
        notifyListeners();
        debugPrint('[LivePartyProvider] Chat received from ${sender.name}: $text');
      } catch (e) {
        debugPrint('[LivePartyProvider] ChatMessage error: $e');
      }
    });

    // 10. User Kicked Stream
    _socketUserKickedSub?.cancel();
    _socketUserKickedSub = _socketService.onUserKicked.listen((data) {
      final targetUserId = data['targetUserId']?.toString() ?? data['userId']?.toString();
      final isHost = data['isHost'] == true;
      final reason = data['reason']?.toString() ?? 'Removed by platform moderation';

      final isMe = targetUserId != null && (targetUserId == currentUser.id || targetUserId == currentUser.username);
      final isHostMe = isHost && (_activeRoom?.creatorUserId == currentUser.id || _activeRoom?.host.id == currentUser.id);

      if (isMe || isHostMe) {
        _wasKicked = true;
        _kickReason = reason;
        _kickedController.add(reason);
        sendSystemMessage('🚫 You have been removed from this room by moderation: $reason');
        leaveParty();
        notifyListeners();
      } else if (targetUserId != null) {
        final kickedIdx = _participants.indexWhere((p) => p.user.id == targetUserId || p.user.username == targetUserId);
        if (kickedIdx != -1) {
          final kicked = _participants[kickedIdx];
          final kickedName = kicked.user.name;
          final kickedSeat = kicked.seatNumber;
          if (kickedSeat != null) {
            _mutedSeatIndices.remove(kickedSeat);
            _lockedSeatIndices.remove(kickedSeat);
          }
          _participants.removeAt(kickedIdx);
          _deduplicateParticipants();
          sendSystemMessage('🚫 $kickedName was removed from the room by moderation.');
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
      Future.delayed(const Duration(seconds: 10), () {
        if (_activeWarningMessage == msg.toString()) {
          _activeWarningMessage = null;
          notifyListeners();
        }
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

    // 13. Admin moderation: Specific user / seat muted
    _socketRoomUserMutedSub?.cancel();
    _socketRoomUserMutedSub = _socketService.onRoomUserMuted.listen((data) {
      final roomId = data['roomId']?.toString() ?? '';
      if (_activeRoom != null && roomId.isNotEmpty && roomId != _activeRoom!.id) return;
      final targetId = data['targetUserId']?.toString();
      final seatIndex = (data['seatIndex'] is num)
          ? (data['seatIndex'] as num).toInt()
          : int.tryParse(data['seatIndex']?.toString() ?? '');
      final muted = data['isMuted'] == true;

      if (seatIndex != null) {
        if (muted) {
          _mutedSeatIndices.add(seatIndex);
        } else {
          _mutedSeatIndices.remove(seatIndex);
        }
      }

      final selfParticipant = _participants.where((p) => p.user.id == currentUser.id).firstOrNull;
      final isMeTarget = (targetId != null && (targetId == currentUser.id || targetId == currentUser.username)) ||
          (seatIndex != null && selfParticipant?.seatNumber == seatIndex);

      if (isMeTarget) {
        try {
          _agoraService.muteLocalAudio(muted);
        } catch (_) {}
        sendSystemMessage(muted ? '🔇 Your microphone has been MUTED by moderation.' : '🎙️ Your microphone has been UNMUTED.');
      }

      // Update participant list
      for (int i = 0; i < _participants.length; i++) {
        final p = _participants[i];
        if ((targetId != null && (p.user.id == targetId || p.user.username == targetId)) ||
            (seatIndex != null && p.seatNumber == seatIndex)) {
          _participants[i] = p.copyWith(
            micStatus: muted ? MicStatus.muted : MicStatus.on,
          );
        }
      }
      notifyListeners();
    });

    // 14. Room Member Role Updated Stream
    _socketRoleUpdatedSub?.cancel();
    _socketRoleUpdatedSub = _socketService.onRoomRoleUpdated.listen((data) {
      final targetUserId = data['targetUserId']?.toString();
      final newRoleStr = data['role']?.toString().toUpperCase();
      if (targetUserId != null && newRoleStr != null) {
        final idx = _participants.indexWhere((p) => p.user.id == targetUserId);
        if (idx != -1) {
          ParticipantRole newRole = ParticipantRole.listener;
          if (newRoleStr == 'HOST') {
            newRole = ParticipantRole.host;
          } else if (newRoleStr == 'ADMIN') {
            newRole = ParticipantRole.moderator;
          } else {
            newRole = _participants[idx].seatNumber != null ? ParticipantRole.speaker : ParticipantRole.listener;
          }
          _participants[idx] = _participants[idx].copyWith(role: newRole);
          sendSystemMessage('⭐ Role updated for ${_participants[idx].user.name}: $newRoleStr');
          notifyListeners();
        }
      }
    });

    // 15. Mic Invitation Realtime Events (Change 13)
    _socketMicInviteSub?.cancel();
    _socketMicInviteSub = _socketService.onRoomMicInvite.listen((data) {
      final roomId = data['roomId']?.toString();
      final canonicalRoomId = data['canonicalRoomId']?.toString();

      // Flexible room match to prevent ID format or canonical alias divergence drops
      final isMatchingRoom = _activeRoom == null ||
          roomId == null ||
          roomId == _activeRoom!.id ||
          canonicalRoomId == _activeRoom!.id ||
          _activeRoom!.agoraChannelName == roomId ||
          _initialRoomId == roomId ||
          _activeRoom!.id.contains(roomId) ||
          (canonicalRoomId != null && _activeRoom!.id.contains(canonicalRoomId));

      if (!isMatchingRoom) return;

      final targetUserId = data['targetUserId']?.toString();
      final inviteId = data['id']?.toString() ?? 'inv_${DateTime.now().millisecondsSinceEpoch}';

      if (targetUserId != null) {
        _pendingOutgoingInvites[targetUserId] = {
          'id': inviteId,
          'roomId': roomId ?? _activeRoom?.id,
          'targetUserId': targetUserId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        notifyListeners();
      }

      // Normalized target comparison to support numeric IDs, string IDs, and prefixed IDs
      final currentId = _currentUser?.id ?? '';
      final isSelfTarget = currentId.isNotEmpty && targetUserId != null && (
        targetUserId == currentId ||
        targetUserId.toLowerCase() == currentId.toLowerCase() ||
        targetUserId.replaceAll('user_', '') == currentId.replaceAll('user_', '')
      );

      if (isSelfTarget) {
        _incomingMicInviteController.add(Map<String, dynamic>.from(data));
      }
    });

    _socketMicInviteResponseSub?.cancel();
    _socketMicInviteResponseSub = _socketService.onRoomMicInviteResponse.listen((data) {
      final roomId = data['roomId']?.toString();
      final canonicalRoomId = data['canonicalRoomId']?.toString();

      final isMatchingRoom = _activeRoom == null ||
          roomId == null ||
          roomId == _activeRoom!.id ||
          canonicalRoomId == _activeRoom!.id ||
          _activeRoom!.agoraChannelName == roomId ||
          _initialRoomId == roomId ||
          _activeRoom!.id.contains(roomId) ||
          (canonicalRoomId != null && _activeRoom!.id.contains(canonicalRoomId));

      if (!isMatchingRoom) return;

      final targetUserId = data['targetUserId']?.toString();
      if (targetUserId != null) {
        _pendingOutgoingInvites.remove(targetUserId);
        _pendingOutgoingInvites.remove(targetUserId.replaceAll('user_', ''));
        _pendingOutgoingInvites.remove('user_$targetUserId');
        notifyListeners();
      }
    });

    // 16. Room Feed Cleared Stream (Clear Screen action)
    _socketFeedClearedSub?.cancel();
    _socketFeedClearedSub = _socketService.onRoomFeedCleared.listen((data) {
      final incomingRoomId = (data['roomId'] ?? '').toString().trim().toLowerCase();
      final currentRoomId = (_activeRoom?.id ?? _initialRoomId ?? '').trim().toLowerCase();
      if (incomingRoomId.isEmpty || incomingRoomId == currentRoomId) {
        clearRoomFeed();
      }
    });

    // 17. Room Details & DP Update Stream (Item 09)
    _socketDetailsUpdatedSub?.cancel();
    _socketDetailsUpdatedSub = _socketService.onRoomDetailsUpdated.listen((data) {
      final rId = data['roomId']?.toString();
      final currentId = _activeRoom?.id ?? _initialRoomId ?? '';
      if (rId == null || rId == currentId) {
        final title = data['title']?.toString();
        final cover = data['coverUrl']?.toString();
        if (_activeRoom != null) {
          _activeRoom = _activeRoom!.copyWith(
            title: title ?? _activeRoom!.title,
            coverUrl: cover ?? _activeRoom!.coverUrl,
          );
        }
        if (currentId.isNotEmpty) {
          RoomConfigManager.instance.saveRoomProfile(currentId, title: title, coverUrl: cover);
        }
        notifyListeners();
      }
    });

    // 18. Mic Seat Locked Status Stream (Item 04 & 07, Mic 7 & 8)
    _socketSeatLockedSub?.cancel();
    _socketSeatLockedSub = _socketService.onSeatLocked.listen((data) {
      final rId = data['roomId']?.toString();
      final currentId = _activeRoom?.id ?? _initialRoomId ?? '';
      if (rId == null || rId == currentId) {
        final seatIndex = (data['seatIndex'] is num) ? (data['seatIndex'] as num).toInt() : int.tryParse(data['seatIndex']?.toString() ?? '');
        final isLocked = data['isLocked'] == true || data['locked'] == true;
        if (seatIndex != null) {
          if (isLocked) {
            _lockedSeatIndices.add(seatIndex);
          } else {
            _lockedSeatIndices.remove(seatIndex);
          }
          if (currentId.isNotEmpty) {
            RoomConfigManager.instance.setSeatLocked(currentId, seatIndex, isLocked);
          }
          notifyListeners();
        }
      }
    });

    // 19. Room Seat Count & Layout Stream (Item 11)
    _socketLayoutUpdatedSub?.cancel();
    _socketLayoutUpdatedSub = _socketService.onRoomLayoutUpdated.listen((data) {
      final rId = data['roomId']?.toString();
      final currentId = _activeRoom?.id ?? _initialRoomId ?? '';
      if (rId == null || rId == currentId) {
        final capacityRaw = data['capacity'] ?? data['seatCapacity'];
        final capacity = (capacityRaw is num) ? capacityRaw.toInt() : int.tryParse(capacityRaw?.toString() ?? '');
        final roomType = data['roomType']?.toString();
        if (_activeRoom != null && capacity != null) {
          _activeRoom = _activeRoom!.copyWith(
            seatCapacity: capacity,
            roomType: roomType ?? _activeRoom!.roomType,
          );
        }
        if (currentId.isNotEmpty && capacity != null) {
          RoomConfigManager.instance.saveRoomLayout(currentId, capacity: capacity, roomType: roomType ?? _activeRoom?.roomType ?? 'NORMAL');
        }
        notifyListeners();
      }
    });

    // 20. Room Sending Coin Total Stream (Item 08)
    _socketSendingTotalSub?.cancel();
    _socketSendingTotalSub = _socketService.onRoomSendingTotalUpdated.listen((data) {
      final rId = data['roomId']?.toString();
      final currentId = _activeRoom?.id ?? _initialRoomId ?? '';
      if (rId == null || rId == currentId) {
        final total = (data['totalCoins'] is num) ? (data['totalCoins'] as num) : num.tryParse(data['totalCoins']?.toString() ?? '') ?? 0;
        if (total > _roomSendingTotal) {
          _roomSendingTotal = total;
          if (currentId.isNotEmpty) {
            RoomConfigManager.instance.saveRoomSendingTotal(currentId, total);
          }
          notifyListeners();
        }
      }
    });
  }

  /// Clears the room's lower feed messages and records clear timestamp
  void clearRoomFeed() {
    _feedClearedAt = DateTime.now();
    _messages.clear();
    notifyListeners();
  }

  /// Broadcasts Clear Screen event to all room participants via socket and backend
  void broadcastClearScreen() {
    clearRoomFeed();
    final roomId = _activeRoom?.id ?? _initialRoomId;
    if (roomId != null) {
      _socketService.clearRoomFeed(roomId);
      _roomRepository.clearRoomFeed(roomId);
    }
  }

  void dismissWarning() {
    _activeWarningMessage = null;
    notifyListeners();
  }

  Future<void> updateMemberRoleOnBackend(String targetUserId, String newRole) async {
    final roomId = _activeRoom?.id;
    if (roomId == null) return;
    try {
      await _roomRepository.updateMemberRole(roomId, targetUserId, newRole);
      final idx = _participants.indexWhere((p) => p.user.id == targetUserId);
      if (idx != -1) {
        ParticipantRole roleEnum = newRole.toUpperCase() == 'ADMIN'
            ? ParticipantRole.moderator
            : (_participants[idx].seatNumber != null ? ParticipantRole.speaker : ParticipantRole.listener);
        _participants[idx] = _participants[idx].copyWith(role: roleEnum);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[LivePartyProvider] updateMemberRoleOnBackend error: $e');
      rethrow;
    }
  }

  Future<void> unjoinCurrentRoom() async {
    final user = _currentUser;
    if (user != null && _activeRoom != null) {
      final participant = _participants.where((p) => p.user.id == user.id).firstOrNull;
      if (participant != null && participant.seatNumber != null) {
        try {
          await _roomRepository.leaveSeat(_activeRoom!.id, participant.seatNumber!);
        } catch (_) {}
      }
    }
    await leaveParty();
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
    _remoteUsersSub?.cancel();
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
    _socketRoleUpdatedSub?.cancel();
    _socketMicInviteSub?.cancel();
    _socketMicInviteResponseSub?.cancel();
    _socketFeedClearedSub?.cancel();
    _socketDetailsUpdatedSub?.cancel();
    _socketSeatLockedSub?.cancel();
    _socketLayoutUpdatedSub?.cancel();
    _socketSendingTotalSub?.cancel();
    _pendingOutgoingInvites.clear();
    _feedClearedAt = null;
    _pkTimer?.cancel();

    _activeRoom = null;
    _initialRoomId = null;
    _currentUser = null;
    _isPkActive = false;
    _participants = [];
    _messages = [];
    _announcedJoinedUserIds.clear();
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
    final seatLabel = seatIndex == 0 ? 'Host Mic' : (seatIndex == 1 ? 'Co-Host Mic' : 'Mic ${seatIndex - 1}');
    if (isSeatLocked(seatIndex)) {
      return '$seatLabel is locked.';
    }
    if (_activeRoom == null) return 'No active room.';

    final isHostActor = (_activeRoom?.host.id == actor.id) ||
        (_activeRoom?.creatorUserId == actor.id) ||
        (_currentUser?.id == _activeRoom?.host.id) ||
        isHost;
    if (seatIndex == 0 && !isHostActor) {
      return 'Host Mic is reserved exclusively for the host.';
    }

    // Check if target seat is already occupied by someone else
    final occupant = _participants.where((p) => p.seatNumber == seatIndex).firstOrNull;
    if (occupant != null && occupant.user.id != actor.id) {
      return '$seatLabel is already occupied by ${occupant.user.name}.';
    }

    // Clean up any old Guest placeholder entries
    _participants.removeWhere((p) => p.user.id.startsWith('agora_') || p.user.name.startsWith('Guest '));

    // 1. Proactively vacate ANY previous seat held by actor elsewhere across ALL participant entries
    for (int i = 0; i < _participants.length; i++) {
      final p = _participants[i];
      final isActorMatch = p.user.id == actor.id ||
          (actor.username.isNotEmpty && p.user.username.isNotEmpty && p.user.username.toLowerCase() == actor.username.toLowerCase()) ||
          (actor.name.isNotEmpty && p.user.name.isNotEmpty && p.user.name.toLowerCase() == actor.name.toLowerCase());
      if (isActorMatch && p.seatNumber != null && p.seatNumber != seatIndex) {
        final oldSeat = p.seatNumber!;
        try {
          await _roomRepository.leaveSeat(_activeRoom!.id, oldSeat);
        } catch (_) {}
        try {
          _socketService.leaveSeat(_activeRoom!.id, oldSeat);
        } catch (_) {}
        _participants[i] = p.copyWith(
          clearSeat: true,
          role: (p.role == ParticipantRole.host || isHostActor) ? ParticipantRole.host : ParticipantRole.listener,
          micStatus: MicStatus.muted,
        );
      }
    }

    // 2. Proactively vacate ANY other participant who was previously sitting on seatIndex
    for (int i = 0; i < _participants.length; i++) {
      final p = _participants[i];
      final isNotActor = p.user.id != actor.id &&
          (actor.username.isEmpty || p.user.username.toLowerCase() != actor.username.toLowerCase());
      if (p.seatNumber == seatIndex && isNotActor) {
        _participants[i] = p.copyWith(
          clearSeat: true,
          role: p.role == ParticipantRole.host ? ParticipantRole.host : ParticipantRole.listener,
          micStatus: MicStatus.muted,
        );
      }
    }

    try {
      await _roomRepository.occupySeat(_activeRoom!.id, seatIndex);
    } catch (e) {
      debugPrint('[LivePartyProvider] Backend REST occupySeat notice: $e');
    }

    try {
      _socketService.occupySeat(_activeRoom!.id, seatIndex, user: actor.toJson());
    } catch (e) {
      debugPrint('[LivePartyProvider] Socket occupySeat notice: $e');
    }

    // Update local state with real user object
    final existingIdx = _participants.indexWhere(
      (p) => p.user.id == actor.id ||
             (actor.username.isNotEmpty && p.user.username.toLowerCase() == actor.username.toLowerCase()) ||
             (actor.name.isNotEmpty && p.user.name.toLowerCase() == actor.name.toLowerCase())
    );

    if (existingIdx != -1) {
      _participants[existingIdx] = _participants[existingIdx].copyWith(
        user: actor,
        seatNumber: seatIndex,
        role: isHostActor ? ParticipantRole.host : ParticipantRole.speaker,
        micStatus: MicStatus.on,
      );
    } else {
      _participants.add(PartyParticipantModel(
        user: actor,
        role: isHostActor ? ParticipantRole.host : ParticipantRole.speaker,
        seatNumber: seatIndex,
        micStatus: MicStatus.on,
        joinedAt: DateTime.now(),
      ));
    }

    // Promote Agora Role to Broadcaster if actor is current user
    if (actor.id == _currentUser?.id) {
      try {
        await _agoraService.switchRole(isHost: true);
      } catch (_) {}
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
  }

  /// Deduplicate participants so each user is represented exactly once across all seats and lists
  void _deduplicateParticipants() {
    final unique = <PartyParticipantModel>[];
    for (final p in _participants) {
      final id = p.user.id.trim();
      final username = p.user.username.trim().toLowerCase();
      final name = p.user.name.trim().toLowerCase();

      final existingIdx = unique.indexWhere((u) {
        if (id.isNotEmpty && u.user.id.trim() == id) return true;
        if (username.isNotEmpty && u.user.username.trim().toLowerCase() == username) return true;
        if (name.isNotEmpty && u.user.name.trim().toLowerCase() == name) return true;
        return false;
      });

      if (existingIdx == -1) {
        unique.add(p);
      } else {
        final existing = unique[existingIdx];
        if (existing.seatNumber == null && p.seatNumber != null) {
          unique[existingIdx] = p;
        } else if (existing.seatNumber != null && p.seatNumber != null && existing.seatNumber != p.seatNumber) {
          // If both have different seats, keep the most recent seated entry
          unique[existingIdx] = p;
        } else if (p.user.id.isNotEmpty && !p.user.id.startsWith('host_') && existing.user.id.startsWith('host_')) {
          unique[existingIdx] = p;
        }
      }
    }
    _participants.clear();
    _participants.addAll(unique);
  }

  /// Reconcile and synchronize seats state with backend server
  Future<void> syncSeatsWithServer() async {
    if (_activeRoom == null) return;
    try {
      final updatedRoom = await _roomRepository.getRoomDetails(_activeRoom!.id);
      _activeRoom = updatedRoom;
      if (updatedRoom.seats != null && updatedRoom.seats!.isNotEmpty) {
        for (final seatRaw in updatedRoom.seats!) {
          if (seatRaw is! Map) continue;
          final sMap = Map<String, dynamic>.from(seatRaw);
          final sIdx = (sMap['seatIndex'] is num) ? (sMap['seatIndex'] as num).toInt() : int.tryParse(sMap['seatIndex']?.toString() ?? '');
          if (sIdx == null) continue;
          final userRaw = sMap['occupiedUser'] ?? sMap['user'];
          if (userRaw == null || (userRaw is Map && (userRaw['id'] == null || userRaw['id'].toString().isEmpty))) {
            final occIdx = _participants.indexWhere((p) => p.seatNumber == sIdx);
            if (occIdx != -1) {
              final occ = _participants[occIdx];
              final isHostOcc = occ.role == ParticipantRole.host ||
                  occ.user.id == _activeRoom?.host.id ||
                  occ.user.id == _activeRoom?.creatorUserId;
              _participants[occIdx] = occ.copyWith(
                clearSeat: true,
                role: isHostOcc ? ParticipantRole.host : ParticipantRole.listener,
                micStatus: MicStatus.muted,
              );
            }
          }
        }
        _deduplicateParticipants();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[LivePartyProvider] syncSeatsWithServer notice: $e');
    }
  }

  /// Room owner / participant Leave Mic action
  /// Releases the user's current seat and moves the user into the audience as a listener.
  /// Stops microphone audio transmission, keeps room open, preserves owner role and management permissions.
  Future<String?> leaveMicSeat({int? seatIndex, UserModel? user}) async {
    if (_activeRoom == null) return 'No active room';
    final targetUser = user ?? _currentUser;
    if (targetUser == null) return 'No active user';

    // 1. Resolve which seat the target user is currently occupying
    int targetSeatIndex = seatIndex ?? -1;
    if (targetSeatIndex < 0) {
      final p = _participants.where((p) =>
        p.user.id == targetUser.id ||
        (targetUser.username.isNotEmpty && p.user.username.isNotEmpty && p.user.username.toLowerCase() == targetUser.username.toLowerCase())
      ).firstOrNull;
      if (p != null && p.seatNumber != null) {
        targetSeatIndex = p.seatNumber!;
      }
    }

    if (targetSeatIndex < 0) {
      final p0 = _participants.where((p) => p.seatNumber == 0).firstOrNull;
      if (p0 != null && (p0.user.id == targetUser.id || isHost)) {
        targetSeatIndex = 0;
      }
    }

    if (targetSeatIndex < 0) {
      return 'Not currently occupying a microphone seat';
    }

    try {
      // 2. Authoritative backend REST release
      await _roomRepository.leaveSeat(_activeRoom!.id, targetSeatIndex);

      // 3. Broadcast release via socket
      _socketService.leaveSeat(_activeRoom!.id, targetSeatIndex);

      // 4. Update local state immediately
      final isHostUser = isHost ||
          targetUser.id == _activeRoom?.host.id ||
          targetUser.id == _activeRoom?.creatorUserId;

      final pIdx = _participants.indexWhere((p) =>
        p.seatNumber == targetSeatIndex ||
        p.user.id == targetUser.id
      );

      if (pIdx != -1) {
        final currentP = _participants[pIdx];
        _participants[pIdx] = currentP.copyWith(
          clearSeat: true,
          role: isHostUser ? ParticipantRole.host : ParticipantRole.listener,
          micStatus: MicStatus.muted,
        );
      } else {
        _participants.add(PartyParticipantModel(
          user: targetUser,
          role: isHostUser ? ParticipantRole.host : ParticipantRole.listener,
          seatNumber: null,
          micStatus: MicStatus.muted,
          joinedAt: DateTime.now(),
        ));
      }

      // Proactively clear any other participant marked on targetSeatIndex
      for (int i = 0; i < _participants.length; i++) {
        if (_participants[i].seatNumber == targetSeatIndex) {
          _participants[i] = _participants[i].copyWith(
            clearSeat: true,
            role: (_participants[i].role == ParticipantRole.host || isHostUser) ? ParticipantRole.host : ParticipantRole.listener,
            micStatus: MicStatus.muted,
          );
        }
      }

      _deduplicateParticipants();

      // 5. Stop local audio transmission and switch Agora role to audience
      if (targetUser.id == _currentUser?.id) {
        _agoraService.muteLocalAudio(true);
        await _agoraService.switchRole(isHost: false);
      }

      _logMicAudit(
        seatIndex: targetSeatIndex,
        actorId: targetUser.id,
        actorRole: _getRoleString(targetUser.id),
        targetId: targetUser.id,
        action: 'LEAVE_MIC',
        previousState: 'Mic ${targetSeatIndex + 1}',
        newState: 'Audience',
      );

      sendSystemMessage('🎙️ ${targetUser.name} left Mic ${targetSeatIndex + 1} and moved to the audience.');
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('[LivePartyProvider] leaveMicSeat error: $e');
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
        final isHostOccupant = occupant.role == ParticipantRole.host ||
            occupant.user.id == _activeRoom?.host.id ||
            occupant.user.id == _activeRoom?.creatorUserId ||
            (isHost && occupant.user.id == _currentUser?.id);

        final existingIdx = _participants.indexWhere((p) => p.user.id == occupant.user.id);
        if (existingIdx != -1) {
          _participants[existingIdx] = _participants[existingIdx].copyWith(
            clearSeat: true,
            role: isHostOccupant ? ParticipantRole.host : ParticipantRole.listener,
            micStatus: MicStatus.muted,
          );
        }

        if (occupant.user.id == _currentUser?.id) {
          _agoraService.muteLocalAudio(true);
          await _agoraService.switchRole(isHost: false);
        }

        _deduplicateParticipants();

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

    final roomId = _activeRoom?.id ?? _initialRoomId ?? '';
    if (roomId.isNotEmpty) {
      RoomConfigManager.instance.setSeatLocked(roomId, seatIndex, lock);
      _socketService.emitRoomSeatLock(roomId, seatIndex, lock);
    }

    final seatLabel = seatIndex == 0 ? 'Host Mic' : (seatIndex == 1 ? 'Co-Host Mic' : 'Mic ${seatIndex - 1}');

    _logMicAudit(
      seatIndex: seatIndex,
      actorId: actor.id,
      actorRole: _getRoleString(actor.id),
      targetId: null,
      action: lock ? 'LOCK_MIC' : 'UNLOCK_MIC',
      previousState: lock ? 'Unlocked' : 'Locked',
      newState: lock ? 'Locked' : 'Unlocked',
    );

    sendSystemMessage(lock ? '🔒 $seatLabel locked.' : '🔓 $seatLabel unlocked.');
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

  bool isInvitePending(String userId) {
    final invite = _pendingOutgoingInvites[userId];
    if (invite == null) return false;
    final ts = invite['timestamp'] as int? ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - ts > 30000) {
      _pendingOutgoingInvites.remove(userId);
      return false;
    }
    return true;
  }

  int? getFirstAvailableMicSeat() {
    final capacity = _activeRoom?.seatCapacity ?? 8;
    for (int i = 1; i < capacity; i++) {
      if (isSeatLocked(i)) continue;
      final isOccupied = _participants.any((p) => p.seatNumber == i);
      if (!isOccupied) return i;
    }
    return null;
  }

  Future<String?> sendMicInvitation({
    required UserModel targetUser,
    required UserModel inviter,
  }) async {
    if (_activeRoom == null) return 'No active room.';

    // Check if target is already on mic
    final isOnMic = _participants.any((p) => p.user.id == targetUser.id && p.seatNumber != null);
    if (isOnMic) {
      return '${targetUser.name} is already on a mic.';
    }

    // Check if duplicate invitation pending
    if (isInvitePending(targetUser.id)) {
      return 'Invitation is already pending for ${targetUser.name}.';
    }

    // Check if room has an available seat
    final availableSeat = getFirstAvailableMicSeat();
    if (availableSeat == null) {
      return 'No available mic seats in this room.';
    }

    final inviteId = 'inv_${DateTime.now().millisecondsSinceEpoch}_${targetUser.id}';
    _pendingOutgoingInvites[targetUser.id] = {
      'id': inviteId,
      'roomId': _activeRoom!.id,
      'seatIndex': availableSeat,
      'inviter': inviter.toJson(),
      'targetUser': targetUser.toJson(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    notifyListeners();

    // Auto-expire after 30 seconds
    Timer(const Duration(seconds: 30), () {
      if (_pendingOutgoingInvites.containsKey(targetUser.id)) {
        _pendingOutgoingInvites.remove(targetUser.id);
        notifyListeners();
      }
    });

    _socketService.sendMicInvite(
      roomId: _activeRoom!.id,
      roomTitle: _activeRoom!.title,
      targetUserId: targetUser.id,
      invitationId: inviteId,
      inviter: inviter.toJson(),
      targetUser: targetUser.toJson(),
    );

    _logMicAudit(
      seatIndex: availableSeat,
      actorId: inviter.id,
      actorRole: _getRoleString(inviter.id),
      targetId: targetUser.id,
      action: 'INVITE_MIC',
      previousState: 'Audience',
      newState: 'Invited (Mic ${availableSeat + 1})',
    );

    sendSystemMessage('📩 Invited ${targetUser.name} to join the mic.');
    return null;
  }

  Future<String?> respondToMicInvitation({
    required String invitationId,
    required bool accept,
    String? reason,
  }) async {
    if (_activeRoom == null || _currentUser == null) return 'No active room.';

    _socketService.respondMicInvite(
      roomId: _activeRoom!.id,
      invitationId: invitationId,
      targetUserId: _currentUser!.id,
      accepted: accept,
      reason: reason,
    );

    if (!accept) {
      return null;
    }

    // On acceptance: validate room presence, ensure available mic seat exists
    final availableSeat = getFirstAvailableMicSeat();
    if (availableSeat == null) {
      return 'Sorry, all mic seats are currently full.';
    }

    // Assign seat once
    final err = await takeMicSeat(availableSeat, _currentUser!);
    return err;
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

  bool get isLocalMicMuted {
    if (_isRoomMuted) return true;
    final self = _participants.where((p) => p.user.id == _currentUser?.id).firstOrNull;
    return self?.micStatus == MicStatus.muted;
  }

  bool toggleLocalMic() {
    if (_isRoomMuted) return true;
    final newMuted = !isLocalMicMuted;
    muteLocalMic(newMuted);
    return newMuted;
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
    final now = DateTime.now().millisecondsSinceEpoch;
    _recentSystemMessages.removeWhere((_, time) => now - time > 5000);
    if (_recentSystemMessages.containsKey(text)) {
      final prevTime = _recentSystemMessages[text]!;
      if (now - prevTime < 3000) {
        return; // Suppress duplicate message within 3 seconds
      }
    }
    _recentSystemMessages[text] = now;

    _messages.add(PartyMessageModel(
      id: now.toString(),
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

  void sendMessage(UserModel sender, String text, {String? roomId}) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    final targetRoomId = (_activeRoom?.id.isNotEmpty == true)
        ? _activeRoom!.id
        : (_initialRoomId ?? roomId ?? '');

    if (targetRoomId.isEmpty) {
      debugPrint('[LivePartyProvider] Cannot send message: room ID is unavailable');
      return;
    }

    final clientMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${sender.id}';

    _messages.add(PartyMessageModel(
      id: clientMsgId,
      sender: sender,
      text: trimmedText,
      timestamp: DateTime.now(),
    ));
    if (_messages.length > 100) {
      _messages.removeAt(0);
    }

    _socketService.sendRoomChatMessage(
      roomId: targetRoomId,
      text: trimmedText,
      sender: _currentUser?.toJson() ?? sender.toJson(),
      messageId: clientMsgId,
    );
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
        sender: _currentUser?.toJson() ?? sender.toJson(),
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
      RoomConfigManager.instance.saveRoomLayout(_activeRoom!.id, capacity: capacity, roomType: roomType);
      _socketService.emitRoomLayoutUpdate(_activeRoom!.id, capacity, roomType);
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
    final idx = _participants.indexWhere((p) => p.user.id == userId || p.user.username == userId);
    if (idx != -1) {
      final target = _participants[idx];
      final targetName = target.user.name;
      final targetSeat = target.seatNumber;

      if (targetSeat != null) {
        _mutedSeatIndices.remove(targetSeat);
        _lockedSeatIndices.remove(targetSeat);
        if (_activeRoom != null) {
          try {
            _roomRepository.leaveSeat(_activeRoom!.id, targetSeat);
            _socketService.leaveSeat(_activeRoom!.id, targetSeat);
          } catch (_) {}
        }
      }

      _participants.removeAt(idx);
      _deduplicateParticipants();

      if (_activeRoom != null) {
        _socketService.kickUserFromRoom(
          roomId: _activeRoom!.id,
          targetUserId: target.user.id,
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
    } else {
      final actor = _activeRoom?.host ?? UserModel(id: 'host', username: 'host', name: 'Host', avatarUrl: '');
      lockMicSeat(index, !locked, actor: actor);
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
      final updatedCover = coverUrl ?? _activeRoom!.coverUrl;
      final updatedTitle = title ?? _activeRoom!.title;
      final updatedCapacity = capacity ?? _activeRoom!.seatCapacity;
      final updatedRoomType = roomType ?? _activeRoom!.roomType;

      _activeRoom = _activeRoom!.copyWith(
        coverUrl: updatedCover,
        title: updatedTitle,
        category: category ?? _activeRoom!.category,
        nobleTitle: nobleTitle ?? _activeRoom!.nobleTitle,
        roomType: updatedRoomType,
        seatCapacity: updatedCapacity,
      );

      // Persist durable room overrides across rejoining & app restarts (Item 09 & 11)
      RoomConfigManager.instance.saveRoomProfile(_activeRoom!.id, title: updatedTitle, coverUrl: updatedCover);
      RoomConfigManager.instance.saveRoomLayout(_activeRoom!.id, capacity: updatedCapacity, roomType: updatedRoomType);

      // Save into BackendRepository for offline caching
      BackendRepository.instance.addLiveRoom(_activeRoom!);

      // Broadcast to other phones connected to the room via Socket
      if (title != null || coverUrl != null) {
        _socketService.emitRoomDetailsUpdate(_activeRoom!.id, title: updatedTitle, coverUrl: updatedCover);
      }
      if (capacity != null || roomType != null) {
        _socketService.emitRoomLayoutUpdate(_activeRoom!.id, updatedCapacity, updatedRoomType);
      }

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

  bool isAdmin(String userId) {
    if (_activeRoom == null) return false;
    if (_activeRoom!.host.id == userId || _activeRoom!.creatorUserId == userId) return true;
    final index = _participants.indexWhere((p) => p.user.id == userId);
    if (index != -1) {
      final roleStr = _participants[index].role.toString().toUpperCase();
      return roleStr.contains('ADMIN') || roleStr.contains('HOST');
    }
    return false;
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
    if (_messages.length > 100) {
      _messages.removeAt(0);
    }

    // Synchronize Room Sending Coin Total (Item 08)
    final coinAmount = (quantity * 100);
    _roomSendingTotal += coinAmount;
    if (_activeRoom != null) {
      RoomConfigManager.instance.saveRoomSendingTotal(_activeRoom!.id, _roomSendingTotal);
      _socketService.emitRoomSendingTotal(_activeRoom!.id, _roomSendingTotal);
    }

    notifyListeners();

    // Broadcast room gift event to all connected devices in this room
    final targetRoomId = (_activeRoom?.id.isNotEmpty == true)
        ? _activeRoom!.id
        : (_initialRoomId ?? '');
    if (targetRoomId.isNotEmpty) {
      _socketService.sendRoomGift(
        roomId: targetRoomId,
        giftId: giftId ?? '',
        giftName: giftName,
        giftIcon: giftIcon,
        quantity: quantity,
        sender: sender.toJson(),
        receiver: receiver.toJson(),
        transactionId: txId,
      );
    }
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
