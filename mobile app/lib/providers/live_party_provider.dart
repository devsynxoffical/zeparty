import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/services/agora_rtc_service.dart';
import '../core/services/socket_service.dart';
import '../core/services/api_client.dart';
import '../core/repositories/room_repository.dart';
import '../core/repositories/backend_repository.dart';
import '../core/repositories/pk_repository.dart';
import '../models/live_room_model.dart';
import '../models/party_participant_model.dart';
import '../models/party_message_model.dart';
import '../models/user_model.dart';
import '../models/pk_battle_model.dart';
import '../models/gift_model.dart';
import '../models/live_cohost_invitation_model.dart';
import '../core/services/room_config_manager.dart';

int deriveAgoraUid(String userId) {
  final numVal = int.tryParse(userId);
  if (numVal != null && numVal > 0 && numVal <= 2147483640) {
    return numVal;
  }
  final bytes = sha256.convert(utf8.encode(userId)).bytes;
  final rawUint = ((bytes[0] & 0xFF) << 24) |
      ((bytes[1] & 0xFF) << 16) |
      ((bytes[2] & 0xFF) << 8) |
      (bytes[3] & 0xFF);
  final unsigned = rawUint & 0xFFFFFFFF;
  return (unsigned % 2147483640) + 1;
}

int? parseAgoraUid(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) {
    final v = raw.toInt();
    return v > 0 ? v : null;
  }
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  final parsed = int.tryParse(s);
  return (parsed != null && parsed > 0) ? parsed : null;
}

class LivePartyProvider extends ChangeNotifier {
  final AgoraRtcService _agoraService = AgoraRtcService();
  final RoomRepository _roomRepository = RoomRepository.instance;
  final SocketService _socketService = SocketService.instance;
  final ApiClient _apiClient = ApiClient.instance;

  // Authoritative Agora UID Mapping Stores
  final Map<int, String> _agoraUidToUserId = {};
  final Map<String, int> _userIdToAgoraUid = {};
  final Set<int> _activeRemoteAgoraUids = {};

  Map<int, String> get agoraUidToUserId => Map.unmodifiable(_agoraUidToUserId);
  Map<String, int> get userIdToAgoraUid => Map.unmodifiable(_userIdToAgoraUid);
  Set<int> get activeRemoteAgoraUids => Set.unmodifiable(_activeRemoteAgoraUids);

  void registerAgoraUidMapping(dynamic agoraUidRaw, String? userId) {
    if (userId == null || userId.trim().isEmpty) return;
    final cleanUserId = userId.trim();
    final parsed = parseAgoraUid(agoraUidRaw);
    if (parsed != null && parsed > 0) {
      _agoraUidToUserId[parsed] = cleanUserId;
      _userIdToAgoraUid[cleanUserId] = parsed;
    }
  }

  void unregisterAgoraUidMapping({dynamic agoraUidRaw, String? userId}) {
    if (userId != null && userId.trim().isNotEmpty) {
      final cleanUserId = userId.trim();
      final uid = _userIdToAgoraUid.remove(cleanUserId);
      if (uid != null) {
        _agoraUidToUserId.remove(uid);
      }
    }
    if (agoraUidRaw != null) {
      final parsed = parseAgoraUid(agoraUidRaw);
      if (parsed != null) {
        final uId = _agoraUidToUserId.remove(parsed);
        if (uId != null) {
          _userIdToAgoraUid.remove(uId);
        }
      }
    }
  }

  final Map<int, UserModel> _agoraUidToUser = {};
  Map<int, UserModel> get agoraUidMap => Map.unmodifiable(_agoraUidToUser);

  void _applyAgoraUidMap(dynamic mapRaw) {
    if (mapRaw is! Map) return;
    mapRaw.forEach((k, v) {
      if (v is Map) {
        final uMap = Map<String, dynamic>.from(v);
        final parsedUid = int.tryParse(k.toString()) ?? parseAgoraUid(uMap['agoraUid'] ?? uMap['uid']);
        if (parsedUid != null && parsedUid > 0) {
          final user = UserModel.fromJson(uMap);
          _agoraUidToUser[parsedUid] = user;
          if (user.id.isNotEmpty) {
            registerAgoraUidMapping(parsedUid, user.id);
          }
        }
      }
    });
  }

  void _resolveMissingAgoraIdentity(int remoteUid) {
    if (remoteUid <= 0 || _activeRoom == null) return;
    if (_agoraUidToUser.containsKey(remoteUid)) return;

    _socketService.resolveIdentity(
      roomId: _activeRoom!.id,
      agoraUid: remoteUid,
      onResolved: (data) {
        if (data['agoraUidMap'] != null) {
          _applyAgoraUidMap(data['agoraUidMap']);
        }
        if (data['resolvedIdentity'] is Map) {
          final user = UserModel.fromJson(Map<String, dynamic>.from(data['resolvedIdentity'] as Map));
          _agoraUidToUser[remoteUid] = user;
          registerAgoraUidMapping(remoteUid, user.id);
          notifyListeners();
        }
      },
    );

    _roomRepository.getRoomIdentities(_activeRoom!.id, agoraUid: remoteUid).then((data) {
      if (data['agoraUidMap'] != null) {
        _applyAgoraUidMap(data['agoraUidMap']);
      }
      if (data['resolvedIdentity'] is Map) {
        final user = UserModel.fromJson(Map<String, dynamic>.from(data['resolvedIdentity'] as Map));
        _agoraUidToUser[remoteUid] = user;
        registerAgoraUidMapping(remoteUid, user.id);
        notifyListeners();
      }
    }).catchError((_) {});
  }

  String? getUserIdForAgoraUid(int agoraUid) => _agoraUidToUserId[agoraUid];
  int? getAgoraUidForUserId(String userId) => _userIdToAgoraUid[userId.trim()];

  /// Validates whether an incoming socket event belongs to the currently active room
  bool matchesCurrentRoom(dynamic incoming) {
    if (incoming == null) return true;
    dynamic rawRoomId;
    dynamic rawClientRoomId;
    if (incoming is Map) {
      rawRoomId = incoming['roomId'] ?? incoming['room_id'] ?? (incoming['room'] is Map ? incoming['room']['id'] : incoming['room']);
      rawClientRoomId = incoming['clientRoomId'];
    } else {
      rawRoomId = incoming;
    }

    if (rawRoomId == null && rawClientRoomId == null) return true;

    final inRoomId = rawRoomId?.toString().trim() ?? '';
    final inClientRoomId = rawClientRoomId?.toString().trim() ?? '';
    if (inRoomId.isEmpty && inClientRoomId.isEmpty) return true;

    String norm(String s) => s.toLowerCase().replaceAll('room:', '').trim();
    final inNorm = norm(inRoomId);
    final inClientNorm = norm(inClientRoomId);
    final currentNorm = norm(_activeRoom?.id ?? _initialRoomId ?? '');
    final initialNorm = norm(_initialRoomId ?? '');
    final agoraNorm = (_activeRoom?.agoraChannelName != null && _activeRoom!.agoraChannelName!.isNotEmpty)
        ? norm(_activeRoom!.agoraChannelName!)
        : '';
    final numericNorm = (_activeRoom?.numericRoomId != null && _activeRoom!.numericRoomId!.isNotEmpty)
        ? norm(_activeRoom!.numericRoomId!)
        : '';
    final shortNorm = (_activeRoom?.shortId != null && _activeRoom!.shortId!.isNotEmpty)
        ? norm(_activeRoom!.shortId!)
        : '';

    final validNormIds = <String>{
      if (currentNorm.isNotEmpty) currentNorm,
      if (initialNorm.isNotEmpty) initialNorm,
      if (agoraNorm.isNotEmpty) agoraNorm,
      if (numericNorm.isNotEmpty) numericNorm,
      if (shortNorm.isNotEmpty) shortNorm,
    };
    if (validNormIds.isEmpty) return true;

    final matches = validNormIds.contains(inNorm) ||
        (inClientNorm.isNotEmpty && validNormIds.contains(inClientNorm)) ||
        validNormIds.any((id) =>
            (inNorm.isNotEmpty && (inNorm == id || inNorm.contains(id) || id.contains(inNorm))) ||
            (inClientNorm.isNotEmpty && (inClientNorm == id || inClientNorm.contains(id) || id.contains(inClientNorm))));
    if (!matches) {
      debugPrint('[LivePartyProvider] matchesCurrentRoom FALSE: incoming(roomId: $inRoomId, clientRoomId: $inClientRoomId) vs validNormIds: $validNormIds');
    }
    return matches;
  }

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
  final Map<int, double> _seatVoiceLevels = {};
  Map<int, double> get seatVoiceLevels => _seatVoiceLevels;
  double getSeatVoiceLevel(int seatIndex) => _seatVoiceLevels[seatIndex] ?? 0.0;
  StreamSubscription? _volumeIndicationSub;
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
  StreamSubscription? _socketCoHostInviteSub;
  StreamSubscription? _socketCoHostInviteResponseSub;
  StreamSubscription? _socketRoomBackgroundSub;
  StreamSubscription? _socketRoomEmojiSub;
  StreamSubscription? _socketRoomLockSub;
  StreamSubscription? _socketRoomHostAbsentSub;
  StreamSubscription? _socketRoomHostReturnedSub;
  StreamSubscription? _socketPkActiveSub;
  StreamSubscription? _socketConnectionSub;

  bool get isSocketConnected => _socketService.isConnected;

  DateTime? _feedClearedAt;
  DateTime? get feedClearedAt => _feedClearedAt;

  final _incomingMicInviteController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onIncomingMicInvite => _incomingMicInviteController.stream;

  final _incomingCoHostInviteController = StreamController<LiveCoHostInvitationModel>.broadcast();
  Stream<LiveCoHostInvitationModel> get onIncomingCoHostInvite => _incomingCoHostInviteController.stream;

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

  // PK Battle State (1v1 Audio Room PK - Spec 13 October 2026)
  PKBattleModel? _activePkBattle;
  PKBattleModel? get activePkBattle => _activePkBattle;
  bool _isPkActive = false;
  bool get isPkActive => _isPkActive && _activePkBattle != null && _activePkBattle!.isStarted;
  int _pkScoreA = 0;
  int _pkScoreB = 0;
  int get pkScoreA => _pkScoreA;
  int get pkScoreB => _pkScoreB;
  int _pkTimerRemaining = 300;
  int get pkTimerRemaining => _pkTimerRemaining;
  Timer? _pkTimer;
  UserModel? _pkOpponent;
  UserModel? get pkOpponent => _pkOpponent;
  int _pkCountdown = 0;
  int get pkCountdown => _pkCountdown;
  bool get isPkCountdown => _pkCountdown > 0;
  bool _isPkOpponentDisconnected = false;
  int _pkDisconnectGrace = 30;
  bool get isPkOpponentDisconnected => _isPkOpponentDisconnected;
  int get pkDisconnectGrace => _pkDisconnectGrace;
  bool _isOpponentAudioMuted = false;
  bool get isOpponentAudioMuted => _isOpponentAudioMuted;

  StreamSubscription? _socketPkInviteSub;
  StreamSubscription? _socketPkPreparingSub;
  StreamSubscription? _socketPkCountdownSub;
  StreamSubscription? _socketPkMatchStartedSub;
  StreamSubscription? _socketPkScoreUpdatedSub;
  StreamSubscription? _socketPkHostConnectionSub;
  StreamSubscription? _socketPkMatchFinishedSub;
  StreamSubscription? _socketPkForfeitedSub;
  StreamSubscription? _socketPkAbortedSub;

  final _pkInvitationController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onPkInvitation => _pkInvitationController.stream;

  final _pkResultController = StreamController<PKBattleModel>.broadcast();
  Stream<PKBattleModel> get onPkResult => _pkResultController.stream;

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

  bool isSeatMutedByModerator(int seatIndex) {
    if (_mutedSeatIndices.contains(seatIndex)) return true;
    final occupant = _participants.where((p) => p.seatNumber == seatIndex).firstOrNull;
    return occupant?.isMutedByModerator ?? false;
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

  // Issue 53: Persistent Room Membership & Roles independent of presence and mic seats
  final Map<String, List<PartyParticipantModel>> _savedRoomMembers = {};
  final Map<String, Map<String, ParticipantRole>> _savedRoomRoles = {};

  List<PartyParticipantModel> getSavedRoomMembers(String roomId) {
    return List.unmodifiable(_savedRoomMembers[roomId] ?? []);
  }

  int getSavedRoomMemberCount(String roomId) {
    return (_savedRoomMembers[roomId] ?? []).length;
  }

  bool isUserRoomMember(String roomId, String userId) {
    return (_savedRoomMembers[roomId] ?? []).any((p) => p.user.id == userId);
  }

  void saveExplicitMembership(String roomId, UserModel user, {ParticipantRole role = ParticipantRole.listener}) {
    final list = _savedRoomMembers.putIfAbsent(roomId, () => []);
    final existingIdx = list.indexWhere((p) => p.user.id == user.id);
    final effectiveRole = _savedRoomRoles[roomId]?[user.id] ?? role;
    if (existingIdx != -1) {
      list[existingIdx] = list[existingIdx].copyWith(role: effectiveRole);
    } else {
      list.add(PartyParticipantModel(
        user: user,
        role: effectiveRole,
        joinedAt: DateTime.now(),
      ));
    }
    notifyListeners();
  }

  void removeExplicitMembership(String roomId, String userId) {
    if (_savedRoomMembers.containsKey(roomId)) {
      _savedRoomMembers[roomId]!.removeWhere((p) => p.user.id == userId);
      notifyListeners();
    }
  }

  void updateSavedMemberRole(String roomId, String userId, ParticipantRole newRole) {
    final rolesMap = _savedRoomRoles.putIfAbsent(roomId, () => {});
    rolesMap[userId] = newRole;

    if (_savedRoomMembers.containsKey(roomId)) {
      final list = _savedRoomMembers[roomId]!;
      final idx = list.indexWhere((p) => p.user.id == userId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(role: newRole);
      }
    }
    notifyListeners();
  }

  ParticipantRole? getSavedMemberRole(String roomId, String userId) {
    return _savedRoomRoles[roomId]?[userId];
  }

  /// Item #52: Preserve admin and host roles across mic seat taking, vacating and moving
  ParticipantRole _resolveRoleForUser({
    required UserModel user,
    required bool isHost,
    ParticipantRole? currentRole,
    bool isSeated = false,
  }) {
    final roomId = _activeRoom?.id;
    final roomRoles = (roomId != null) ? _savedRoomRoles[roomId] : null;
    final savedRole = (roomRoles != null) ? roomRoles[user.id] : null;

    if (isHost ||
        currentRole == ParticipantRole.host ||
        savedRole == ParticipantRole.host ||
        (_activeRoom != null &&
            (_activeRoom!.host.id == user.id || _activeRoom!.creatorUserId == user.id))) {
      return ParticipantRole.host;
    }
    if (savedRole == ParticipantRole.moderator ||
        currentRole == ParticipantRole.moderator ||
        user.role == UserRole.admin) {
      return ParticipantRole.moderator;
    }
    return isSeated ? ParticipantRole.speaker : ParticipantRole.listener;
  }

  Future<void> fetchRoomMembers(String roomId) async {
    try {
      final membersRes = await _roomRepository.getRoomMembers(roomId);
      final membersList = membersRes['data'] is List
          ? (membersRes['data'] as List)
          : (membersRes['members'] is List ? (membersRes['members'] as List) : []);

      final savedList = _savedRoomMembers.putIfAbsent(roomId, () => []);

      for (final m in membersList) {
        if (m is! Map) continue;
        final participant = PartyParticipantModel.fromMemberJson(Map<String, dynamic>.from(m));
        final idx = savedList.indexWhere((p) => p.user.id == participant.user.id);
        if (idx != -1) {
          savedList[idx] = participant;
        } else {
          savedList.add(participant);
        }
        if (participant.role == ParticipantRole.moderator || participant.role == ParticipantRole.host) {
          _savedRoomRoles.putIfAbsent(roomId, () => {})[participant.user.id] = participant.role;
        }
      }
      notifyListeners();
    } catch (err) {
      debugPrint('[LivePartyProvider] fetchRoomMembers error: $err');
    }
  }

  bool _isHostAbsent = false;
  bool get isHostAbsent => _isHostAbsent;

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
    if (roomId != null && roomId.isNotEmpty) {
      _initialRoomId = roomId;
    }
    final targetId = _activeRoom?.id ?? _initialRoomId ?? roomId;
    if (targetId != null && targetId.isNotEmpty) {
      _socketService.joinRoom(targetId, user: user.toJson());
      _setupSocketSubscriptions(user);
      if (_activePkBattle != null && isHost) {
        _socketService.emitPkHostReconnect(roomId: targetId, matchId: _activePkBattle!.id);
      }
    }
  }

  @visibleForTesting
  void updateRankingSendingTotalForTesting(Map<String, dynamic> res) {
    final rawServerCoins = res['periodTotalCoins'] ?? res['totalCoins'] ?? res['roomSendingTotal'];
    final serverDailyTotal = (rawServerCoins is num)
        ? rawServerCoins
        : (num.tryParse(rawServerCoins?.toString() ?? '') ?? 0);
    if (serverDailyTotal > _roomSendingTotal) {
      _roomSendingTotal = serverDailyTotal;
      final currentTargetId = _activeRoom?.id ?? _initialRoomId ?? '';
      if (currentTargetId.isNotEmpty) {
        RoomConfigManager.instance.saveRoomSendingTotal(currentTargetId, serverDailyTotal);
      }
      notifyListeners();
    }
  }

  @visibleForTesting
  void setRoomSendingTotalForTesting(num total) {
    _roomSendingTotal = total;
  }

  @visibleForTesting
  void setActiveRoomForTesting(LiveRoomModel room) {
    _activeRoom = room;
    _initialRoomId = room.id;
  }

  @visibleForTesting
  void setRoomMutedForTesting(bool muted) {
    _isRoomMuted = muted;
    notifyListeners();
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
  int _joinAttemptCounter = 0;

  Future<bool> joinParty(LiveRoomModel room, UserModel currentUser, {String? password}) async {
    final currentAttempt = ++_joinAttemptCounter;
    final myGeneration = ++_sessionGeneration;
    // Let a previous leave finish its Agora teardown before joining a channel again.
    final pendingLeave = _pendingLeave;
    if (pendingLeave != null) {
      try {
        await pendingLeave;
      } catch (_) {}
      if (myGeneration != _sessionGeneration) return false;
    }
    _isLoading = true;
    _errorMessage = null;
    final isDifferentRoom = (_activeRoom != null && _activeRoom!.id != room.id);
    if (isDifferentRoom) {
      _roomSendingTotal = 0;
    }
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
      if (myGeneration != _sessionGeneration) return false; // superseded by a newer join/leave
      _socketService.joinRoom(room.id, user: currentUser.toJson());
      _setupSocketSubscriptions(currentUser);

      // 2. Perform backend REST join (graceful fallback for guest mode / transient network)
      try {
        final joinResult = await _roomRepository.joinRoom(room.id, password: password);
        final roomData = joinResult['room'] ?? joinResult;
        if (roomData is Map<String, dynamic> && roomData.isNotEmpty) {
          _activeRoom = LiveRoomModel.fromJson(roomData);
          _socketService.joinRoom(_activeRoom!.id, user: currentUser.toJson());
        }
      } catch (restJoinErr) {
        debugPrint('[LivePartyProvider] REST join warning (proceeding with socket subscription): $restJoinErr');
        if (restJoinErr is ApiException && (restJoinErr.code == 'ROOM_LOCKED_PIN_REQUIRED' || (restJoinErr.statusCode == 403 && (restJoinErr.message.toLowerCase().contains('pin') || restJoinErr.message.toLowerCase().contains('lock'))))) {
          rethrow;
        }
      }

      // Re-fetch authoritative room details with seats state
      try {
        final details = await _roomRepository.getRoomDetails(room.id);
        if (myGeneration != _sessionGeneration) return false;
        _activeRoom = details;
      } catch (_) {}
      if (myGeneration != _sessionGeneration) return false;

      // Apply persistent room configuration overrides (Item 09, 11, 04, 08)
      if (_activeRoom != null) {
        _activeRoom = RoomConfigManager.instance.applyOverrides(_activeRoom!);
        _lockedSeatIndices.addAll(RoomConfigManager.instance.getLockedSeats(_activeRoom!.id));
        _roomSendingTotal = RoomConfigManager.instance.getRoomSendingTotal(_activeRoom!.id);

        // Synchronize Daily sending total with backend rankings (Item 30 monotonic guard)
        RoomRepository.instance.getRoomSendingRankings(_activeRoom!.id, period: 'daily').then((res) {
          final rawServerCoins = res['periodTotalCoins'] ?? res['totalCoins'] ?? res['roomSendingTotal'];
          final serverDailyTotal = (rawServerCoins is num)
              ? rawServerCoins
              : (num.tryParse(rawServerCoins?.toString() ?? '') ?? 0);
          if (serverDailyTotal > _roomSendingTotal) {
            _roomSendingTotal = serverDailyTotal;
            RoomConfigManager.instance.saveRoomSendingTotal(_activeRoom!.id, serverDailyTotal);
            notifyListeners();
          }
        }).catchError((_) {});

        // Reconnect / Recovery: Check active PK match for this room (Section 5)
        try {
          final activePk = await PKRepository.instance.getActiveMatchForRoom(_activeRoom!.id);
          if (activePk != null && activePk.isStarted) {
            _activePkBattle = activePk;
            _isPkActive = true;
            _pkScoreA = activePk.scoreA;
            _pkScoreB = activePk.scoreB;
            _pkTimerRemaining = activePk.remainingSeconds;
            _setupAudioPkRelay(activePk);
            _startPkAuthoritativeTimer();
          }
        } catch (_) {}
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
      final seatedAgoraUids = <int, int?>{};

      if (seatsList != null && seatsList.isNotEmpty) {
        for (final sRaw in seatsList) {
          if (sRaw is! Map) continue;
          final sMap = Map<String, dynamic>.from(sRaw);
          final sIdx = (sMap['seatIndex'] is num) ? (sMap['seatIndex'] as num).toInt() : int.tryParse(sMap['seatIndex']?.toString() ?? '');
          if (sIdx == null) continue;
          final occUserRaw = sMap['occupiedUser'] ?? sMap['user'];
          final occUserId = sMap['occupiedUserId']?.toString() ?? sMap['userId']?.toString() ?? (occUserRaw is Map ? occUserRaw['id']?.toString() : null);

          final rawSeatAgoraUid = parseAgoraUid(sMap['agoraUid'] ?? sMap['uid'] ?? (occUserRaw is Map ? (occUserRaw['agoraUid'] ?? occUserRaw['uid']) : null));

          if (occUserId != null && occUserId.isNotEmpty) {
            final effectiveAgoraUid = rawSeatAgoraUid ?? deriveAgoraUid(occUserId);
            registerAgoraUidMapping(effectiveAgoraUid, occUserId);
            seatedAgoraUids[sIdx] = effectiveAgoraUid;

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

      final hostAgoraUid = deriveAgoraUid(hostUserModel.id);
      if (hostUserModel.id.isNotEmpty) {
        registerAgoraUidMapping(hostAgoraUid, hostUserModel.id);
      }

      // Add Host participant
      _participants.add(PartyParticipantModel(
        user: hostUserModel,
        role: ParticipantRole.host,
        seatNumber: hostSeatIndex,
        joinedAt: room.startTime,
        micStatus: hostSeatIndex != null ? MicStatus.on : MicStatus.muted,
        agoraUid: hostAgoraUid,
      ));

      // Add any other seated speakers
      seatedUsers.forEach((sIdx, seatedUser) {
        if (seatedUser.id != hostUserModel.id) {
          final sAgoraUid = seatedAgoraUids[sIdx] ?? deriveAgoraUid(seatedUser.id);
          _participants.add(PartyParticipantModel(
            user: seatedUser,
            role: ParticipantRole.speaker,
            seatNumber: sIdx,
            joinedAt: DateTime.now(),
            micStatus: MicStatus.on,
            agoraUid: sAgoraUid,
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

        // Issue 53: Populate authoritative persistent room members
        final savedList = _savedRoomMembers.putIfAbsent(room.id, () => []);
        if (!savedList.any((p) => p.user.id == room.host.id)) {
          savedList.add(PartyParticipantModel(
            user: room.host,
            role: ParticipantRole.host,
            joinedAt: DateTime.now(),
          ));
        }

        for (final m in membersList) {
          if (m is! Map) continue;
          final mJson = Map<String, dynamic>.from(m);
          final participantModel = PartyParticipantModel.fromMemberJson(mJson);
          final uId = participantModel.user.id;
          final uUsername = participantModel.user.username;
          final isHostUser = (uId.isNotEmpty && (uId == room.host.id || uId == room.creatorUserId)) ||
              (room.host.username.isNotEmpty && uUsername.isNotEmpty && uUsername.toLowerCase() == room.host.username.toLowerCase());
          if (uId.isEmpty || uId == currentUser.id || isHostUser) continue;

          final savedIdx = savedList.indexWhere((p) => p.user.id == uId);
          if (savedIdx != -1) {
            savedList[savedIdx] = participantModel;
          } else {
            savedList.add(participantModel);
          }

          if (participantModel.role == ParticipantRole.moderator || participantModel.role == ParticipantRole.host) {
            _savedRoomRoles.putIfAbsent(room.id, () => {})[uId] = participantModel.role;
          }

          final existing = _participants.any((p) =>
              p.user.id == uId ||
              (uUsername.isNotEmpty && p.user.username.isNotEmpty && p.user.username.toLowerCase() == uUsername.toLowerCase()));
          if (!existing && participantModel.inRoom) {
            _participants.add(participantModel);
          }
        }
      } catch (err) {
        debugPrint('[LivePartyProvider] Fetch members notice: $err');
      }

      _deduplicateParticipants();

      // 3. Acquire short-lived Agora RTC token from backend
      try {
        final isSelfSeated = _participants.any((p) => p.user.id == currentUser.id && p.seatNumber != null);
        final agoraData = await _roomRepository.getAgoraToken(room.id);
        if (agoraData['token'] != null) {
          final token = agoraData['token'] as String;
          final channelName = agoraData['channelName'] as String? ?? room.agoraChannelName ?? room.id;
          final rawUid = parseAgoraUid(agoraData['agoraUid'] ?? agoraData['uid']);
          final uid = (rawUid != null && rawUid > 0) ? rawUid : AgoraRtcService.deriveUid(currentUser.id);
          final appId = agoraData['appId'] as String?;

          if (agoraData['agoraUidMap'] != null) {
            _applyAgoraUidMap(agoraData['agoraUidMap']);
          }

          if (currentUser.id.isNotEmpty) {
            registerAgoraUidMapping(uid, currentUser.id);
            _agoraUidToUser[uid] = currentUser;
          }

          await _agoraService.initialize(appId: appId, enableVideo: false);
          await _agoraService.joinChannel(
            token,
            channelName,
            uid,
            isHost: isSelfSeated,
            isVideo: false,
          );
        }
      } catch (agoraErr) {
        debugPrint('[LivePartyProvider] Agora token/channel join warning: $agoraErr');
      }
      if (myGeneration != _sessionGeneration) return false;

      // 4. Listen to Agora Active Speaker stream
      _speakerSub?.cancel();
      _speakerSub = _agoraService.activeSpeakerStream.listen((uid) {
        if (uid <= 0) return;
        final resolvedUserId = _agoraUidToUserId[uid];
        final speakerParticipant = _participants.where((p) {
          if (p.seatNumber == null) return false;
          if (resolvedUserId != null && p.user.id == resolvedUserId) return true;
          return p.agoraUid == uid || p.user.id == uid.toString() || deriveAgoraUid(p.user.id) == uid;
        }).firstOrNull;
        if (speakerParticipant != null) {
          // Temporarily pulse active speaking
        }
      });

      // Volume indication listener for internal microphone voice animation
      _volumeIndicationSub?.cancel();
      _volumeIndicationSub = _agoraService.volumeIndicationStream.listen((speakers) {
        bool changed = false;
        final detectedSeats = <int>{};

        for (final info in speakers) {
          int? targetSeat;
          final isLocal = (info.uid == 0 ||
              info.uid == _agoraService.currentUid ||
              (currentUser.id.isNotEmpty && _userIdToAgoraUid[currentUser.id] == info.uid));

          if (isLocal) {
            if (!isLocalMicMuted) {
              final self = _participants.where((p) => p.user.id == currentUser.id && p.seatNumber != null).firstOrNull;
              if (self != null) {
                targetSeat = self.seatNumber;
              } else if (isHost) {
                targetSeat = 0;
              }
            }
          } else {
            final resolvedUserId = _agoraUidToUserId[info.uid];
            PartyParticipantModel? remotePart;
            if (resolvedUserId != null && resolvedUserId.isNotEmpty) {
              remotePart = _participants.where((p) => (p.user.id == resolvedUserId || p.agoraUid == info.uid) && p.seatNumber != null).firstOrNull;
            }

            remotePart ??= _participants.where((p) {
              if (p.seatNumber == null) return false;
              if (p.agoraUid == info.uid) return true;
              if (p.user.id == info.uid.toString()) return true;
              return deriveAgoraUid(p.user.id) == info.uid;
            }).firstOrNull;

            if (remotePart != null && !remotePart.isMuted) {
              targetSeat = remotePart.seatNumber;
            } else {
              final hostId = _activeRoom?.host.id ?? _activeRoom?.creatorUserId;
              final isHostSpeaker = (resolvedUserId != null && resolvedUserId == hostId) ||
                  (hostId != null && (hostId == info.uid.toString() || deriveAgoraUid(hostId) == info.uid));
              if (isHostSpeaker) {
                final hostPart = _participants.where((p) => p.seatNumber == 0).firstOrNull;
                if (hostPart == null || !hostPart.isMuted) {
                  targetSeat = 0;
                }
              }
            }
          }

          if (targetSeat != null) {
            detectedSeats.add(targetSeat);
            double level = 0.0;
            final v = info.volume ?? 0;
            if (v >= 6) {
              level = (v / 160.0).clamp(0.15, 1.0);
            }
            if ((_seatVoiceLevels[targetSeat] ?? 0.0) != level) {
              _seatVoiceLevels[targetSeat] = level;
              changed = true;
            }
          }
        }

        final toReset = <int>[];
        _seatVoiceLevels.forEach((seat, vol) {
          if (!detectedSeats.contains(seat) && vol > 0.0) {
            toReset.add(seat);
          }
        });
        for (final seat in toReset) {
          _seatVoiceLevels[seat] = 0.0;
          changed = true;
        }

        if (changed) {
          notifyListeners();
        }
      });

      // 5. Listen to Agora Remote Users (Authoritative Identity Mapping)
      _remoteUsersSub?.cancel();
      _remoteUsersSub = _agoraService.remoteUsersStream.listen((uids) {
        for (final uid in uids) {
          _activeRemoteAgoraUids.add(uid);
          if (!_agoraUidToUser.containsKey(uid) || !_agoraUidToUserId.containsKey(uid)) {
            final matching = _participants.where((p) =>
              p.agoraUid == uid || p.user.id == uid.toString() || deriveAgoraUid(p.user.id) == uid
            ).firstOrNull;
            if (matching != null) {
              registerAgoraUidMapping(uid, matching.user.id);
              _agoraUidToUser[uid] = matching.user;
            } else {
              _resolveMissingAgoraIdentity(uid);
            }
          }
        }
        _activeRemoteAgoraUids.removeWhere((id) => !uids.contains(id));
        notifyListeners();
      });

      final displayName = currentUser.displayName.isNotEmpty
          ? currentUser.displayName
          : (currentUser.name.isNotEmpty ? currentUser.name : currentUser.username);
      _announcedJoinedUserIds.add(currentUser.id.toLowerCase());
      _announcedJoinedUserIds.add(currentUser.id);
      if (currentUser.username.isNotEmpty) _announcedJoinedUserIds.add(currentUser.username.toLowerCase());
      if (displayName.isNotEmpty) _announcedJoinedUserIds.add(displayName.toLowerCase());
      if (currentAttempt != _joinAttemptCounter) {
        debugPrint('[LivePartyProvider] Superseded join attempt $currentAttempt discarded');
        return false;
      }
      sendSystemMessage('👋 Welcome to ${room.title}! Please follow community guidelines.');
      return true;
    } catch (e) {
      if (currentAttempt != _joinAttemptCounter) {
        return false;
      }
      if (e is ApiException && (e.code == 'ROOM_LOCKED_PIN_REQUIRED' || (e.statusCode == 403 && (e.message.toLowerCase().contains('pin') || e.message.toLowerCase().contains('lock'))))) {
        _lastJoinFailureReason = 'ROOM_LOCKED_PIN_REQUIRED';
        _errorMessage = 'ROOM_LOCKED_PIN_REQUIRED';
        return false;
      }
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
  StreamSubscription? _socketPresenceSyncSub;
  StreamSubscription? _socketStageSyncSub;
  StreamSubscription? _socketSeatUpdatedSub;
  StreamSubscription? _socketPkSnapshotSub;

  void _setupSocketSubscriptions(UserModel currentUser) {
    _currentUser = currentUser;

    _socketConnectionSub?.cancel();
    _socketConnectionSub = _socketService.onConnectionStateChanged.listen((connected) {
      debugPrint('[LivePartyProvider] Socket connection state changed: $connected');
      if (connected && _activeRoom != null) {
        _socketService.joinRoom(_activeRoom!.id, user: _currentUser?.toJson());
        _socketService.requestRoomSnapshot(_activeRoom!.id);
        _socketService.requestPkSync(_activeRoom!.id);
        _syncRoomStateOnReconnect();
      }
      notifyListeners();
    });

    // 1. Room Snapshot Subscription (Authoritative Seat & Participant State)
    _socketRoomSnapshotSub?.cancel();
    _socketRoomSnapshotSub = _socketService.roomSnapshotStream.listen((data) {
      try {
        final roomObj = data['room'] is Map ? Map<String, dynamic>.from(data['room'] as Map) : <String, dynamic>{};
        if (roomObj.isNotEmpty) {
          _activeRoom = LiveRoomModel.fromJson(roomObj);
        }

        if (data['agoraUidMap'] != null) {
          _applyAgoraUidMap(data['agoraUidMap']);
        } else if (roomObj['agoraUidMap'] != null) {
          _applyAgoraUidMap(roomObj['agoraUidMap']);
        }

        final hostAgoraUid = parseAgoraUid(data['agoraHostUid'] ?? roomObj['agoraHostUid']);
        final hostId = roomObj['host'] is Map ? (roomObj['host']['id']?.toString() ?? roomObj['host']['userId']?.toString()) : _activeRoom?.host.id;
        if (hostId != null && hostId.isNotEmpty) {
          registerAgoraUidMapping(hostAgoraUid ?? deriveAgoraUid(hostId), hostId);
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
              final rawId = userMap['id']?.toString() ?? userMap['_id']?.toString() ?? '';
              final rawUsername = userMap['username']?.toString() ?? 'User';
              final rawName = userMap['displayName']?.toString() ?? userMap['name']?.toString() ?? userMap['username']?.toString() ?? 'User';
              final rawAvatar = userMap['avatarUrl']?.toString() ?? userMap['avatar']?.toString() ?? '';
              final rawFrame = userMap['avatarFrame']?.toString() ??
                  userMap['equippedFrame']?.toString() ??
                  userMap['frameUrl']?.toString() ??
                  (userMap['profile'] is Map ? (userMap['profile']['avatarFrame'] ?? userMap['profile']['equippedFrame'])?.toString() : null) ?? '';
              final rawNoble = userMap['nobleTitle']?.toString() ?? userMap['nobleRank']?.toString() ?? userMap['nobleLevel']?.toString();
              final rawVip = userMap['isVip'] == true;
              final userObj = UserModel(
                id: rawId,
                username: rawUsername,
                name: rawName,
                avatarUrl: rawAvatar,
                avatarFrame: rawFrame,
                nobleTitle: rawNoble,
                isVip: rawVip,
              );
              if (userObj.id.isNotEmpty) {
                final rawSeatAgoraUid = parseAgoraUid(userMap['agoraUid'] ?? userMap['uid'] ?? seatMap['agoraUid'] ?? seatMap['uid']);
                final effectiveSeatAgoraUid = rawSeatAgoraUid ?? deriveAgoraUid(userObj.id);
                registerAgoraUidMapping(effectiveSeatAgoraUid, userObj.id);

                final isSeatHost = (_activeRoom != null && (_activeRoom!.host.id == userObj.id || _activeRoom!.creatorUserId == userObj.id)) ||
                    (isHost && _currentUser?.id == userObj.id);
                final existingIdx = _participants.indexWhere((p) => p.user.id == userObj.id || p.seatNumber == seatIndex);
                final currentRole = existingIdx != -1 ? _participants[existingIdx].role : null;
                final resolvedRole = _resolveRoleForUser(
                  user: userObj,
                  isHost: isSeatHost,
                  currentRole: currentRole,
                  isSeated: true,
                );
                if (existingIdx != -1) {
                  _participants[existingIdx] = _participants[existingIdx].copyWith(
                    user: userObj,
                    seatNumber: seatIndex,
                    role: resolvedRole,
                    micStatus: seatMap['isMuted'] == true ? MicStatus.muted : MicStatus.on,
                    agoraUid: effectiveSeatAgoraUid,
                  );
                } else {
                  _participants.add(PartyParticipantModel(
                    user: userObj,
                    role: resolvedRole,
                    seatNumber: seatIndex,
                    micStatus: seatMap['isMuted'] == true ? MicStatus.muted : MicStatus.on,
                    joinedAt: DateTime.now(),
                    agoraUid: effectiveSeatAgoraUid,
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
                avatarFrame: userMap['avatarFrame']?.toString() ??
                    userMap['equippedFrame']?.toString() ??
                    userMap['frameUrl']?.toString() ??
                    (userMap['profile'] is Map ? (userMap['profile']['avatarFrame'] ?? userMap['profile']['equippedFrame'])?.toString() : null) ?? '',
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

        // Reconcile room gifting total from snapshot (Item 30)
        final rawSnapshotTotal = data['roomSendingTotal'] ??
            data['dailySendingTotal'] ??
            data['periodTotalCoins'] ??
            data['trophyCoins'] ??
            roomObj['roomSendingTotal'] ??
            roomObj['dailySendingTotal'] ??
            roomObj['periodTotalCoins'] ??
            roomObj['trophyCoins'];
        final snapshotTotal = (rawSnapshotTotal is num)
            ? rawSnapshotTotal
            : (num.tryParse(rawSnapshotTotal?.toString() ?? '') ?? 0);
        final currentTargetId = _activeRoom?.id ?? _initialRoomId ?? '';
        if (snapshotTotal > _roomSendingTotal) {
          _roomSendingTotal = snapshotTotal;
          if (currentTargetId.isNotEmpty) {
            RoomConfigManager.instance.saveRoomSendingTotal(currentTargetId, snapshotTotal);
          }
        }

        // Process recent gifts snapshot (Issue 01: snapshot recovery on join/reconnect)
        final recentGiftsList = data['recentGifts'] is List
            ? (data['recentGifts'] as List)
            : (roomObj['recentGifts'] is List ? (roomObj['recentGifts'] as List) : []);
        for (final g in recentGiftsList) {
          if (g is! Map) continue;
          final gMap = Map<String, dynamic>.from(g);
          final txId = (gMap['transactionId'] ?? gMap['id'] ?? gMap['_id'] ?? '').toString();
          if (txId.isNotEmpty && _processedGiftTxIds.contains(txId)) continue;
          if (txId.isNotEmpty) _processedGiftTxIds.add(txId);

          final senderMap = gMap['sender'] is Map ? Map<String, dynamic>.from(gMap['sender'] as Map) : <String, dynamic>{};
          final receiverMap = (gMap['receiver'] is Map
              ? Map<String, dynamic>.from(gMap['receiver'] as Map)
              : (gMap['recipient'] is Map ? Map<String, dynamic>.from(gMap['recipient'] as Map) : <String, dynamic>{}));

          final sender = UserModel(
            id: gMap['senderUserId']?.toString() ?? senderMap['id']?.toString() ?? '',
            username: gMap['senderName']?.toString() ?? senderMap['name']?.toString() ?? senderMap['username']?.toString() ?? 'User',
            name: gMap['senderName']?.toString() ?? senderMap['name']?.toString() ?? senderMap['displayName']?.toString() ?? 'User',
            avatarUrl: gMap['senderAvatar']?.toString() ?? senderMap['avatarUrl']?.toString() ?? '',
          );
          final receiver = UserModel(
            id: gMap['receiverUserId']?.toString() ?? gMap['recipientUserId']?.toString() ?? receiverMap['id']?.toString() ?? '',
            username: gMap['receiverName']?.toString() ?? gMap['recipientName']?.toString() ?? receiverMap['name']?.toString() ?? receiverMap['username']?.toString() ?? 'Host',
            name: gMap['receiverName']?.toString() ?? gMap['recipientName']?.toString() ?? receiverMap['name']?.toString() ?? receiverMap['displayName']?.toString() ?? 'Host',
            avatarUrl: receiverMap['avatarUrl']?.toString() ?? '',
          );

          final giftName = gMap['giftName']?.toString() ?? (gMap['gift'] is Map ? (gMap['gift'] as Map)['name']?.toString() : null) ?? 'Gift';
          final giftIcon = gMap['giftIcon']?.toString() ?? (gMap['gift'] is Map ? (gMap['gift'] as Map)['icon']?.toString() : null) ?? '🎁';
          final quantity = (gMap['quantity'] is num) ? (gMap['quantity'] as num).toInt() : int.tryParse(gMap['quantity']?.toString() ?? '') ?? 1;
          final cleanIcon = (giftIcon.startsWith('assets/') || giftIcon.startsWith('http')) ? '🎁' : giftIcon;

          _messages.add(PartyMessageModel(
            id: 'snapshot_gift_$txId',
            sender: sender,
            receiver: receiver,
            text: '${sender.name} sent $quantity × $giftName $cleanIcon to ${receiver.name}',
            timestamp: DateTime.now(),
            isGiftMessage: true,
            giftId: gMap['giftId']?.toString() ?? '',
            giftName: giftName,
            giftIcon: giftIcon,
            quantity: quantity,
            transactionId: txId,
            serverTimestamp: DateTime.now(),
          ));
        }
        if (_messages.length > 100) {
          _messages.removeRange(0, _messages.length - 100);
        }

        notifyListeners();
      } catch (e) {
        debugPrint('[LivePartyProvider] Snapshot processing error: $e');
      }
    });

    // 1b. Presence Sync Subscription (Authoritative Realtime Viewer Count & Agora Map)
    _socketPresenceSyncSub?.cancel();
    _socketPresenceSyncSub = _socketService.onRoomPresenceSync.listen((data) {
      if (!matchesCurrentRoom(data)) return;
      try {
        final rawCount = data['viewerCount'] ?? data['count'] ?? data['currentViewersCount'];
        final parsedCount = (rawCount is num) ? rawCount.toInt() : int.tryParse(rawCount?.toString() ?? '');
        if (parsedCount != null && _activeRoom != null) {
          _activeRoom = _activeRoom!.copyWith(viewerCount: parsedCount >= 0 ? parsedCount : 0);
        }
        if (data['agoraUidMap'] != null) {
          _applyAgoraUidMap(data['agoraUidMap']);
        }
        final usersList = data['users'] is List ? (data['users'] as List) : (data['participants'] is List ? (data['participants'] as List) : []);
        for (final uRaw in usersList) {
          if (uRaw is Map) {
            final uMap = Map<String, dynamic>.from(uRaw);
            final user = UserModel.fromJson(uMap);
            final aUid = parseAgoraUid(uMap['agoraUid'] ?? uMap['uid']) ?? deriveAgoraUid(user.id);
            _agoraUidToUser[aUid] = user;
            registerAgoraUidMapping(aUid, user.id);
          }
        }
        notifyListeners();
      } catch (e) {
        debugPrint('[LivePartyProvider] PresenceSync error: $e');
      }
    });

    // 1c. Stage Sync Subscription (Authoritative 10-Seat Layout & Host Seat 0)
    _socketStageSyncSub?.cancel();
    _socketStageSyncSub = _socketService.onRoomStageSync.listen((data) {
      if (!matchesCurrentRoom(data)) return;
      try {
        if (data['agoraUidMap'] != null) {
          _applyAgoraUidMap(data['agoraUidMap']);
        }
        final stageObj = data['stage'] is Map ? Map<String, dynamic>.from(data['stage'] as Map) : data;
        final hostObj = stageObj['host'] is Map ? stageObj['host'] as Map : (data['host'] is Map ? data['host'] as Map : null);
        if (hostObj != null) {
          final hostUser = UserModel.fromJson(Map<String, dynamic>.from(hostObj));
          final hostAgoraUid = parseAgoraUid(data['agoraHostUid'] ?? hostObj['agoraUid'] ?? hostObj['uid']) ?? deriveAgoraUid(hostUser.id);
          _agoraUidToUser[hostAgoraUid] = hostUser;
          registerAgoraUidMapping(hostAgoraUid, hostUser.id);
        }

        final seatsList = stageObj['seats'] is List
            ? (stageObj['seats'] as List)
            : (data['seats'] is List ? (data['seats'] as List) : []);

        for (final seatRaw in seatsList) {
          if (seatRaw is! Map) continue;
          final seatMap = Map<String, dynamic>.from(seatRaw);
          final rawIdx = seatMap['seatIndex'] ?? seatMap['seatNumber'];
          final seatIndex = (rawIdx is num) ? rawIdx.toInt() : int.tryParse(rawIdx?.toString() ?? '');
          if (seatIndex == null) continue;

          final userRaw = seatMap['user'] ?? seatMap['occupiedUser'];
          if (userRaw is Map && userRaw['id'] != null && userRaw['id'].toString().isNotEmpty) {
            final userObj = UserModel.fromJson(Map<String, dynamic>.from(userRaw));
            final effectiveSeatAgoraUid = parseAgoraUid(userRaw['agoraUid'] ?? userRaw['uid'] ?? seatMap['agoraUid'] ?? seatMap['uid']) ?? deriveAgoraUid(userObj.id);
            _agoraUidToUser[effectiveSeatAgoraUid] = userObj;
            registerAgoraUidMapping(effectiveSeatAgoraUid, userObj.id);

            final isSeatHost = seatIndex == 0 || (_activeRoom != null && (_activeRoom!.host.id == userObj.id || _activeRoom!.creatorUserId == userObj.id));
            final existingIdx = _participants.indexWhere((p) => p.user.id == userObj.id || p.seatNumber == seatIndex);
            final resolvedRole = isSeatHost ? ParticipantRole.host : ParticipantRole.speaker;

            if (existingIdx != -1) {
              _participants[existingIdx] = _participants[existingIdx].copyWith(
                user: userObj,
                seatNumber: seatIndex,
                role: resolvedRole,
                micStatus: seatMap['isMuted'] == true ? MicStatus.muted : MicStatus.on,
                agoraUid: effectiveSeatAgoraUid,
              );
            } else {
              _participants.add(PartyParticipantModel(
                user: userObj,
                role: resolvedRole,
                seatNumber: seatIndex,
                micStatus: seatMap['isMuted'] == true ? MicStatus.muted : MicStatus.on,
                joinedAt: DateTime.now(),
                agoraUid: effectiveSeatAgoraUid,
              ));
            }
          } else {
            // Vacate this seat
            final occupantIdx = _participants.indexWhere((p) => p.seatNumber == seatIndex);
            if (occupantIdx != -1) {
              final occupant = _participants[occupantIdx];
              _participants[occupantIdx] = occupant.copyWith(
                clearSeat: true,
                role: occupant.user.id == _activeRoom?.host.id ? ParticipantRole.host : ParticipantRole.listener,
                micStatus: MicStatus.muted,
              );
            }
          }
        }
        _deduplicateParticipants();
        notifyListeners();
      } catch (e) {
        debugPrint('[LivePartyProvider] StageSync error: $e');
      }
    });

    // 1d. Seat Updated Subscription
    _socketSeatUpdatedSub?.cancel();
    _socketSeatUpdatedSub = _socketService.onSeatUpdated.listen((data) {
      if (!matchesCurrentRoom(data)) return;
      try {
        final rawIdx = data['seatIndex'] ?? data['seatNumber'];
        final seatIndex = (rawIdx is num) ? rawIdx.toInt() : int.tryParse(rawIdx?.toString() ?? '');
        if (seatIndex == null) return;

        final userRaw = data['user'] ?? data['occupiedUser'];
        if (userRaw is Map && userRaw['id'] != null && userRaw['id'].toString().isNotEmpty) {
          final userObj = UserModel.fromJson(Map<String, dynamic>.from(userRaw));
          final aUid = parseAgoraUid(userRaw['agoraUid'] ?? userRaw['uid'] ?? data['agoraUid']) ?? deriveAgoraUid(userObj.id);
          _agoraUidToUser[aUid] = userObj;
          registerAgoraUidMapping(aUid, userObj.id);

          final existingIdx = _participants.indexWhere((p) => p.user.id == userObj.id || p.seatNumber == seatIndex);
          if (existingIdx != -1) {
            _participants[existingIdx] = _participants[existingIdx].copyWith(
              user: userObj,
              seatNumber: seatIndex,
              role: seatIndex == 0 ? ParticipantRole.host : ParticipantRole.speaker,
              micStatus: data['isMuted'] == true ? MicStatus.muted : MicStatus.on,
              agoraUid: aUid,
            );
          } else {
            _participants.add(PartyParticipantModel(
              user: userObj,
              role: seatIndex == 0 ? ParticipantRole.host : ParticipantRole.speaker,
              seatNumber: seatIndex,
              micStatus: data['isMuted'] == true ? MicStatus.muted : MicStatus.on,
              joinedAt: DateTime.now(),
              agoraUid: aUid,
            ));
          }
        } else if (data['isVacant'] == true || userRaw == null) {
          final occupantIdx = _participants.indexWhere((p) => p.seatNumber == seatIndex);
          if (occupantIdx != -1) {
            _participants[occupantIdx] = _participants[occupantIdx].copyWith(
              clearSeat: true,
              role: ParticipantRole.listener,
              micStatus: MicStatus.muted,
            );
          }
        }
        _deduplicateParticipants();
        notifyListeners();
      } catch (e) {
        debugPrint('[LivePartyProvider] SeatUpdated error: $e');
      }
    });

    // 1e. PK Snapshot Subscription
    _socketPkSnapshotSub?.cancel();
    _socketPkSnapshotSub = _socketService.onPkSnapshot.listen((data) {
      if (!matchesCurrentRoom(data)) return;
      try {
        final matchData = data['match'] is Map ? Map<String, dynamic>.from(data['match'] as Map) : data;
        final pkMatch = PKBattleModel.fromJson(matchData);
        _activePkBattle = pkMatch;
        if (data['agoraUidMap'] != null) {
          _applyAgoraUidMap(data['agoraUidMap']);
        }
        notifyListeners();
      } catch (e) {
        debugPrint('[LivePartyProvider] PkSnapshot error: $e');
      }
    });

    // 2. User Joined Stream
    _socketUserJoinedSub?.cancel();
    _socketUserJoinedSub = _socketService.userJoinedStream.listen((data) {
      if (!matchesCurrentRoom(data)) return;
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
          final rawJoinedAgoraUid = parseAgoraUid(userObj['agoraUid'] ?? userObj['uid'] ?? data['agoraUid'] ?? data['uid']);
          final effectiveJoinedAgoraUid = rawJoinedAgoraUid ?? deriveAgoraUid(joinedUserId);
          registerAgoraUidMapping(effectiveJoinedAgoraUid, joinedUserId);

          final existingIdx = _participants.indexWhere((p) =>
              p.user.id == joinedUserId ||
              (uUsername.isNotEmpty && p.user.username.isNotEmpty && p.user.username.toLowerCase() == uUsername.toLowerCase()));
          if (existingIdx == -1) {
            final joinedUser = UserModel(
              id: joinedUserId,
              username: uUsername.isNotEmpty ? uUsername : displayName,
              name: displayName,
              avatarUrl: userObj['avatarUrl']?.toString() ?? data['avatarUrl']?.toString() ?? '',
              avatarFrame: userObj['avatarFrame']?.toString() ??
                  userObj['equippedFrame']?.toString() ??
                  userObj['frameUrl']?.toString() ??
                  data['avatarFrame']?.toString() ??
                  data['equippedFrame']?.toString() ?? '',
              nobleTitle: userObj['nobleTitle']?.toString() ?? userObj['nobleLevel']?.toString() ?? data['nobleLevel']?.toString() ?? data['nobleTitle']?.toString(),
              vipLevel: userObj['vipLevel']?.toString() ?? data['vipLevel']?.toString() ?? 'None',
              isVip: userObj['isVip'] == true || data['isVip'] == true,
              wealthLevel: (userObj['wealthLevel'] is num) ? (userObj['wealthLevel'] as num).toInt() : (int.tryParse(userObj['wealthLevel']?.toString() ?? '') ?? 1),
            );
            _participants.add(PartyParticipantModel(
              user: joinedUser,
              role: ParticipantRole.listener,
              seatNumber: null,
              joinedAt: DateTime.now(),
              agoraUid: effectiveJoinedAgoraUid,
            ));
          } else {
            _participants[existingIdx] = _participants[existingIdx].copyWith(agoraUid: effectiveJoinedAgoraUid);
          }
        }

        final entrantUserModel = UserModel(
          id: joinedUserId ?? '',
          username: uUsername.isNotEmpty ? uUsername : displayName,
          name: displayName,
          avatarUrl: userObj['avatarUrl']?.toString() ?? data['avatarUrl']?.toString() ?? '',
          avatarFrame: userObj['avatarFrame']?.toString() ??
              userObj['equippedFrame']?.toString() ??
              userObj['frameUrl']?.toString() ??
              data['avatarFrame']?.toString() ??
              data['equippedFrame']?.toString() ?? '',
          nobleTitle: userObj['nobleTitle']?.toString() ?? userObj['nobleLevel']?.toString() ?? data['nobleLevel']?.toString() ?? data['nobleTitle']?.toString(),
          vipLevel: userObj['vipLevel']?.toString() ?? data['vipLevel']?.toString() ?? 'None',
          isVip: userObj['isVip'] == true || data['isVip'] == true,
          wealthLevel: (userObj['wealthLevel'] is num) ? (userObj['wealthLevel'] as num).toInt() : (int.tryParse(userObj['wealthLevel']?.toString() ?? '') ?? 1),
        );

        // Announce join in room chat (only if not already announced)
        final announceKey = (joinedUserId != null && joinedUserId.isNotEmpty)
            ? joinedUserId.toLowerCase()
            : displayName.toLowerCase();
        final alreadyAnnounced = _announcedJoinedUserIds.contains(announceKey);

        if (!alreadyAnnounced) {
          _announcedJoinedUserIds.add(announceKey);
          if (uUsername.isNotEmpty) _announcedJoinedUserIds.add(uUsername.toLowerCase());
          if (displayName.isNotEmpty) _announcedJoinedUserIds.add(displayName.toLowerCase());
          if (!isSelf) {
            sendSystemMessage(
              '🎉 $displayName has joined the party! 🔥',
              entrantUser: entrantUserModel,
              eventId: data['eventId']?.toString() ?? data['id']?.toString(),
            );
          }
        }

        final rawCount = data['viewerCount'] ?? data['count'] ?? data['currentViewersCount'];
        final parsedViewerCount = (rawCount is num) ? rawCount.toInt() : int.tryParse(rawCount?.toString() ?? '');
        final currentAudienceCount = _participants.where((p) => p.role != ParticipantRole.host && p.user.id != _activeRoom?.host.id && p.user.id != _activeRoom?.creatorUserId).length;
        // Authoritative backend count: use parsed count directly if provided
        final effectiveViewerCount = parsedViewerCount != null ? (parsedViewerCount >= 0 ? parsedViewerCount : 0) : currentAudienceCount;
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
      if (!matchesCurrentRoom(data)) return;
      final leftUserId = data['userId']?.toString() ?? data['id']?.toString();
      if (leftUserId != null && leftUserId.isNotEmpty) {
        final leftIdLower = leftUserId.toLowerCase();
        final leftIdClean = leftIdLower.replaceFirst(RegExp(r'^user_'), '');
        // Capture departing participant to clean up associated name/username keys
        final departing = _participants.where((p) =>
            p.user.id == leftUserId ||
            p.user.id.toLowerCase() == leftIdLower ||
            p.user.id.toLowerCase().replaceFirst(RegExp(r'^user_'), '') == leftIdClean
        ).firstOrNull;

        _announcedJoinedUserIds.remove(leftUserId);
        _announcedJoinedUserIds.remove(leftIdLower);
        _announcedJoinedUserIds.remove(leftIdClean);
        if (departing != null) {
          if (departing.user.name.isNotEmpty) {
            _announcedJoinedUserIds.remove(departing.user.name.toLowerCase());
          }
          if (departing.user.username.isNotEmpty) {
            _announcedJoinedUserIds.remove(departing.user.username.toLowerCase());
          }
          // Reset voice level if departing was on a seat
          if (departing.seatNumber != null) {
            _seatVoiceLevels[departing.seatNumber!] = 0.0;
          }
          unregisterAgoraUidMapping(agoraUidRaw: departing.agoraUid, userId: leftUserId);
        } else {
          unregisterAgoraUidMapping(userId: leftUserId);
        }

        // Also check if payload specifies vacated seat
        final vacatedSeatRaw = data['seatIndex'] ?? data['vacatedSeatIndex'];
        final vacatedSeat = (vacatedSeatRaw is num) ? vacatedSeatRaw.toInt() : int.tryParse(vacatedSeatRaw?.toString() ?? '');
        if (vacatedSeat != null) {
          _seatVoiceLevels[vacatedSeat] = 0.0;
        }

        final leftName = data['name']?.toString() ?? data['displayName']?.toString() ?? (data['user'] is Map ? (data['user'] as Map)['displayName']?.toString() : null);
        if (leftName != null && leftName.isNotEmpty) {
          _announcedJoinedUserIds.remove(leftName.toLowerCase());
        }
        final leftUsername = data['username']?.toString() ?? (data['user'] is Map ? (data['user'] as Map)['username']?.toString() : null);
        if (leftUsername != null && leftUsername.isNotEmpty) {
          _announcedJoinedUserIds.remove(leftUsername.toLowerCase());
        }

        _pendingOutgoingInvites.remove(leftUserId);

        final isHostUser = leftUserId == _activeRoom?.host.id || leftUserId == _activeRoom?.creatorUserId;
        if (isHostUser) {
          // Host left or is away: vacate Host Seat 0, but keep Party Room open for remaining users
          for (int i = 0; i < _participants.length; i++) {
            if (_participants[i].role == ParticipantRole.host || _participants[i].seatNumber == 0) {
              _participants[i] = _participants[i].copyWith(
                clearSeat: true,
                micStatus: MicStatus.muted,
              );
            }
          }
          _seatVoiceLevels[0] = 0.0;
        }
        _participants.removeWhere((p) =>
            p.user.id == leftUserId ||
            p.user.id.toLowerCase() == leftIdLower ||
            p.user.id.toLowerCase().replaceFirst(RegExp(r'^user_'), '') == leftIdClean);

        final rawCount = data['viewerCount'] ?? data['count'] ?? data['currentViewersCount'];
        final parsedViewerCount = (rawCount is num) ? rawCount.toInt() : int.tryParse(rawCount?.toString() ?? '');
        final currentAudienceCount = _participants.where((p) => p.role != ParticipantRole.host && p.user.id != _activeRoom?.host.id && p.user.id != _activeRoom?.creatorUserId).length;
        // Authoritative backend count: use parsed count directly if provided, without speculative bump
        final effectiveCount = parsedViewerCount != null ? (parsedViewerCount >= 0 ? parsedViewerCount : 0) : currentAudienceCount;
        if (_activeRoom != null) {
          _activeRoom = _activeRoom!.copyWith(viewerCount: effectiveCount);
        }
        notifyListeners();
      }
    });

    // 4. Viewer Count Changed Stream
    _socketViewerCountSub?.cancel();
    _socketViewerCountSub = _socketService.viewerCountStream.listen((data) {
      if (!matchesCurrentRoom(data)) return;
      final rawCount = data['viewerCount'] ?? data['count'] ?? data['currentViewersCount'];
      final count = (rawCount is num) ? rawCount.toInt() : int.tryParse(rawCount?.toString() ?? '');
      if (_activeRoom != null) {
        final currentAudienceCount = _participants.where((p) => p.role != ParticipantRole.host && p.user.id != _activeRoom?.host.id && p.user.id != _activeRoom?.creatorUserId).length;
        // Authoritative backend count: never overwrite server count with math.max or speculative calculations
        final effectiveCount = count != null ? (count >= 0 ? count : 0) : currentAudienceCount;
        debugPrint('[LivePartyProvider] Authoritative viewer count updated: $effectiveCount (raw: $rawCount, audience: $currentAudienceCount)');
        _activeRoom = _activeRoom!.copyWith(viewerCount: effectiveCount);
        notifyListeners();
      }
    });

    // 5. Seat Occupied Stream
    _socketSeatOccupiedSub?.cancel();
    _socketSeatOccupiedSub = _socketService.seatOccupiedStream.listen((data) {
      if (!matchesCurrentRoom(data)) return;
      try {
        final seatIndex = (data['seatIndex'] is num) ? (data['seatIndex'] as num).toInt() : int.tryParse(data['seatIndex']?.toString() ?? '');
        final userMap = data['user'] is Map ? Map<String, dynamic>.from(data['user'] as Map) : null;
        if (seatIndex != null && userMap != null) {
          final rawUserId = userMap['id']?.toString() ?? userMap['_id']?.toString() ?? userMap['userId']?.toString() ?? '';
          final rawUsername = userMap['username']?.toString() ?? userMap['name']?.toString() ?? 'Speaker';
          final rawName = userMap['displayName']?.toString() ?? userMap['name']?.toString() ?? userMap['username']?.toString() ?? 'Speaker';
          final rawAvatar = userMap['avatarUrl']?.toString() ?? userMap['avatar']?.toString() ?? '';

          // Look up existing participant to preserve frame & VIP/noble if socket passed minimal user map
          final existing = _participants.where((p) =>
              p.user.id == rawUserId ||
              (rawUsername.isNotEmpty && p.user.username.isNotEmpty && p.user.username.toLowerCase() == rawUsername.toLowerCase())
          ).firstOrNull;

          final rawFrame = userMap['avatarFrame']?.toString() ??
              userMap['equippedFrame']?.toString() ??
              userMap['frameUrl']?.toString() ??
              userMap['frame']?.toString() ??
              (userMap['profile'] is Map ? (userMap['profile']['avatarFrame'] ?? userMap['profile']['equippedFrame'])?.toString() : null) ??
              existing?.user.avatarFrame ?? '';

          final rawNoble = userMap['nobleTitle']?.toString() ??
              userMap['nobleRank']?.toString() ??
              userMap['nobleLevel']?.toString() ??
              existing?.user.nobleTitle;

          final rawVipLevel = userMap['vipLevel']?.toString() ?? existing?.user.vipLevel ?? 'None';
          final bool rawIsVip = userMap['isVip'] == true || (existing?.user.isVip ?? false);
          final int rawSvip = (userMap['svipLevel'] is num)
              ? (userMap['svipLevel'] as num).toInt()
              : (int.tryParse(userMap['svipLevel']?.toString() ?? '') ?? (existing?.user.svipLevel ?? 0));
          final int rawWealth = (userMap['wealthLevel'] is num)
              ? (userMap['wealthLevel'] as num).toInt()
              : (int.tryParse(userMap['wealthLevel']?.toString() ?? '') ?? (existing?.user.wealthLevel ?? 1));

          final occupantUser = UserModel(
            id: rawUserId,
            username: rawUsername,
            name: rawName,
            avatarUrl: rawAvatar.isNotEmpty ? rawAvatar : (existing?.user.avatarUrl ?? ''),
            avatarFrame: rawFrame,
            nobleTitle: rawNoble,
            isVip: rawIsVip,
            vipLevel: rawSvip > 0 ? 'SVIP $rawSvip' : rawVipLevel,
            wealthLevel: rawWealth,
          );

          final isHostUser = occupantUser.id == _activeRoom?.host.id ||
              occupantUser.id == _activeRoom?.creatorUserId ||
              (isHost && occupantUser.id == currentUser.id) ||
              (_activeRoom != null && _activeRoom!.host.username.isNotEmpty && occupantUser.username.isNotEmpty && occupantUser.username.toLowerCase() == _activeRoom!.host.username.toLowerCase());

          // Seat change processed

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
                role: _resolveRoleForUser(
                  user: p.user,
                  isHost: false,
                  currentRole: p.role,
                  isSeated: false,
                ),
                micStatus: MicStatus.muted,
              );
            }
          }

          final rawSeatAgoraUid = parseAgoraUid(data['agoraUid'] ?? data['uid'] ?? userMap['agoraUid'] ?? userMap['uid']);
          final effectiveSeatAgoraUid = rawSeatAgoraUid ?? (occupantUser.id.isNotEmpty ? deriveAgoraUid(occupantUser.id) : null);
          if (occupantUser.id.isNotEmpty) {
            registerAgoraUidMapping(effectiveSeatAgoraUid, occupantUser.id);
          }

          final pIdx = _participants.indexWhere((p) =>
              p.user.id == occupantUser.id ||
              (occupantUser.username.isNotEmpty && p.user.username.isNotEmpty && p.user.username.toLowerCase() == occupantUser.username.toLowerCase()));
          final currentRole = pIdx != -1 ? _participants[pIdx].role : null;
          final resolvedRole = _resolveRoleForUser(
            user: occupantUser,
            isHost: isHostUser,
            currentRole: currentRole,
            isSeated: true,
          );
          if (pIdx != -1) {
            _participants[pIdx] = _participants[pIdx].copyWith(
              user: occupantUser,
              seatNumber: seatIndex,
              role: resolvedRole,
              micStatus: MicStatus.on,
              agoraUid: effectiveSeatAgoraUid,
            );
          } else {
            _participants.add(PartyParticipantModel(
              user: occupantUser,
              role: resolvedRole,
              seatNumber: seatIndex,
              micStatus: MicStatus.on,
              joinedAt: DateTime.now(),
              agoraUid: effectiveSeatAgoraUid,
            ));
          }

          _pendingOutgoingInvites.remove(occupantUser.id);

          if (occupantUser.id == currentUser.id) {
            _agoraService.switchRole(isHost: true);
            _agoraService.muteLocalAudio(false);
          }

          // Mic joining messages removed to keep chat clean and focused
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[LivePartyProvider] SeatOccupied error: $e');
      }
    });

    // 6. Seat Released Stream
    _socketSeatReleasedSub?.cancel();
    _socketSeatReleasedSub = _socketService.seatReleasedStream.listen((data) {
      if (!matchesCurrentRoom(data)) return;
      try {
        final seatIndex = (data['seatIndex'] is num) ? (data['seatIndex'] as num).toInt() : int.tryParse(data['seatIndex']?.toString() ?? '');
        final userId = data['userId']?.toString() ?? data['releasedByUserId']?.toString();
        int pIdx = -1;
        if (seatIndex != null) {
          pIdx = _participants.indexWhere((p) => p.seatNumber == seatIndex);
        }
        if (pIdx == -1 && userId != null) {
          final uClean = userId.toLowerCase().replaceFirst(RegExp(r'^user_'), '');
          pIdx = _participants.indexWhere((p) =>
              p.user.id == userId ||
              p.user.id.toLowerCase() == userId.toLowerCase() ||
              p.user.id.toLowerCase().replaceFirst(RegExp(r'^user_'), '') == uClean);
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

          if (occupant.seatNumber != null) {
            _seatVoiceLevels[occupant.seatNumber!] = 0.0;
          }

          if (occupant.user.id == currentUser.id) {
            _agoraService.muteLocalAudio(true);
            _agoraService.switchRole(isHost: false);
          }
          // Left mic message removed to keep chat clean
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
        if (seatIndex != null) {
          _seatVoiceLevels[seatIndex] = 0.0;
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
      if (!matchesCurrentRoom(data)) return;
      final isSleeping = data['isSleeping'] == true;
      final roomStaysOpen = data['roomStaysOpen'] == true || data['keepOpen'] == true;
      final isPartyRoom = _activeRoom?.roomType == 'AUDIO_PARTY' || _activeRoom?.roomType == 'PARTY';
      final status = data['status']?.toString().toUpperCase();

      // If persistent party room stays open for listeners or is in sleep mode, do not terminate session
      if (roomStaysOpen || isSleeping || (isPartyRoom && status != 'ENDED')) {
        debugPrint('[LivePartyProvider] Room is persistent/sleeping, ignoring room closed event.');
        return;
      }

      final reason = data['reason']?.toString() ?? 'Room has been closed.';
      if (reason.contains('absent') || reason.contains('ABSENT')) {
        sendSystemMessage('⏰ Party ended: Host was absent for more than 2 minutes.');
      } else {
        sendSystemMessage('🛑 Room has been closed.');
      }
      _roomClosedController.add(Map<String, dynamic>.from(data));
      leaveParty();
    });

    // 8. Gift Sent Stream
    _socketGiftSentSub?.cancel();
    _socketGiftSentSub = _socketService.giftSentStream.listen((data) {
      if (!matchesCurrentRoom(data)) return;
      try {
        final txId = (data['transactionId'] ?? data['id'] ?? data['eventId'] ?? '').toString().trim();
        if (txId.isNotEmpty) {
          if (_processedGiftTxIds.contains(txId)) return;
          _processedGiftTxIds.add(txId);
          if (_processedGiftTxIds.length > 500) {
            _processedGiftTxIds.remove(_processedGiftTxIds.first);
          }
        }

        final senderMap = data['sender'] is Map ? Map<String, dynamic>.from(data['sender'] as Map) : <String, dynamic>{};
        final receiverMap = data['receiver'] is Map
            ? Map<String, dynamic>.from(data['receiver'] as Map)
            : (data['recipient'] is Map ? Map<String, dynamic>.from(data['recipient'] as Map) : <String, dynamic>{});

        final senderUserId = (data['senderUserId'] ?? senderMap['id'] ?? senderMap['userId'] ?? data['userId'] ?? '').toString();
        final senderName = (data['senderName'] ?? senderMap['name'] ?? senderMap['displayName'] ?? senderMap['username'] ?? 'User').toString();
        final sender = UserModel(
          id: senderUserId.isNotEmpty ? senderUserId : 'user_${DateTime.now().millisecondsSinceEpoch}',
          username: (senderMap['username'] ?? senderName).toString(),
          name: senderName,
          avatarUrl: (data['senderAvatar'] ?? senderMap['avatarUrl'] ?? senderMap['avatar'] ?? '').toString(),
        );

        final receiverUserId = (data['recipientUserId'] ?? data['receiverUserId'] ?? receiverMap['id'] ?? receiverMap['userId'] ?? '').toString();
        final receiverName = (data['receiverName'] ?? receiverMap['name'] ?? receiverMap['displayName'] ?? receiverMap['username'] ?? 'Host').toString();
        final receiver = UserModel(
          id: receiverUserId.isNotEmpty ? receiverUserId : 'receiver_${DateTime.now().millisecondsSinceEpoch}',
          username: (receiverMap['username'] ?? receiverName).toString(),
          name: receiverName,
          avatarUrl: (receiverMap['avatarUrl'] ?? receiverMap['avatar'] ?? '').toString(),
        );

        final rawGiftId = data['giftId']?.toString() ?? (data['gift'] is Map ? (data['gift'] as Map)['id']?.toString() : '') ?? '';
        final rawGiftName = data['giftName']?.toString() ?? (data['gift'] is Map ? (data['gift'] as Map)['name']?.toString() : null) ?? 'Gift';
        final rawGiftIcon = data['giftIcon']?.toString() ?? (data['gift'] is Map ? (data['gift'] as Map)['icon']?.toString() : null) ?? '🎁';

        // Authoritative resolution against catalog to prevent codes like 'CG11' or 'CG23'
        final catalogGift = GiftModel.findById(rawGiftId) ?? GiftModel.findById(rawGiftName);
        final giftName = catalogGift?.name ?? rawGiftName;
        final giftIcon = catalogGift?.icon ?? rawGiftIcon;
        final quantity = (data['quantity'] is num) ? (data['quantity'] as num).toInt() : int.tryParse(data['quantity']?.toString() ?? '') ?? 1;

        final cleanIcon = (giftIcon.startsWith('assets/') || giftIcon.startsWith('http')) ? '🎁' : giftIcon;

        // Deduplication against locally generated optimistic gift messages ONLY for the local sender
        final isLocalSender = _currentUser != null &&
            ( (sender.id.isNotEmpty && sender.id == _currentUser!.id) ||
              (_currentUser!.username.isNotEmpty && sender.username.toLowerCase() == _currentUser!.username.toLowerCase()) );

        if (isLocalSender) {
          final isOptimisticDuplicate = _messages.any((m) =>
              m.isGiftMessage &&
              ( (txId.isNotEmpty && (m.transactionId == txId || m.id == 'gift_$txId' || m.id == txId)) ||
                ( m.giftName?.toLowerCase() == giftName.toLowerCase() &&
                  m.quantity == quantity &&
                  DateTime.now().difference(m.timestamp).inSeconds.abs() <= 5 )
              ));
          if (isOptimisticDuplicate) return;
        }

        final effectiveMsgId = txId.isNotEmpty ? 'gift_$txId' : 'gift_${DateTime.now().millisecondsSinceEpoch}';

        final giftMsg = PartyMessageModel(
          id: effectiveMsgId,
          sender: sender,
          receiver: receiver,
          text: '${sender.name} sent $quantity × $giftName $cleanIcon to ${receiver.name}',
          timestamp: DateTime.now(),
          isGiftMessage: true,
          giftId: catalogGift?.id ?? data['giftId']?.toString() ?? '',
          giftName: giftName,
          giftIcon: giftIcon,
          quantity: quantity,
          transactionId: txId.isNotEmpty ? txId : null,
          serverTimestamp: DateTime.now(),
        );
        _messages.add(giftMsg);
        if (_messages.length > 100) {
          _messages.removeAt(0);
        }

        // Synchronize Room Sending Coin Total (Item 08, 30)
        final rawCoinVal = data['coinAmount'] ?? data['coins'] ?? data['cost'] ?? data['totalCoins'];
        num coinAmount;
        if (rawCoinVal is num) {
          coinAmount = rawCoinVal;
        } else if (rawCoinVal != null) {
          final parsed = num.tryParse(rawCoinVal.toString());
          coinAmount = parsed ?? (quantity * (catalogGift?.priceCoins ?? (data['price'] is num ? (data['price'] as num).toInt() : (int.tryParse(data['price']?.toString() ?? '') ?? 100))));
        } else {
          final fallbackPrice = (catalogGift?.priceCoins ?? 0) > 0
              ? catalogGift!.priceCoins
              : (data['price'] is num ? (data['price'] as num).toInt() : (int.tryParse(data['price']?.toString() ?? '') ?? 100));
          coinAmount = quantity * fallbackPrice;
        }
        _roomSendingTotal += coinAmount;
        final targetRoomId = _activeRoom?.id ?? _initialRoomId ?? '';
        if (targetRoomId.isNotEmpty) {
          RoomConfigManager.instance.saveRoomSendingTotal(targetRoomId, _roomSendingTotal);
        }

        notifyListeners();
      } catch (e) {
        debugPrint('[LivePartyProvider] GiftSent error: $e');
      }
    });

    // 9. Chat Message Stream
    _socketChatMessageSub?.cancel();
    _socketChatMessageSub = _socketService.onRoomChatMessage.listen((data) {
      if (!matchesCurrentRoom(data)) return;
      try {

        final senderMap = data['sender'] is Map
            ? Map<String, dynamic>.from(data['sender'] as Map)
            : (data['user'] is Map
                ? Map<String, dynamic>.from(data['user'] as Map)
                : (data['senderUser'] is Map ? Map<String, dynamic>.from(data['senderUser'] as Map) : <String, dynamic>{}));
        final senderId = (senderMap['id'] ?? senderMap['_id'] ?? data['senderUserId'] ?? data['userId'] ?? '').toString();
        final text = (data['text'] ?? data['message'] ?? data['content'] ?? data['msg'] ?? '').toString().trim();
        if (text.isEmpty) return;

        // Message dropped if created before room feed clear boundary
        // Apply clock skew grace window (30s) and distinguish live socket comments from historical playback
        // so valid live messages from other devices are not discarded due to clock skew.
        // Distinguish live socket comments from historical playback:
        // Live socket messages (arriving over active realtime connection) must NEVER be dropped by clock-skew.
        final createdAtRaw = data['createdAt'] ?? data['timestamp'];
        final isHistorical = data['isHistorical'] == true || data['playbackType'] == 'HISTORY_ONLY';
        if (_feedClearedAt != null && isHistorical) {
          if (createdAtRaw != null) {
            final msgTime = DateTime.tryParse(createdAtRaw.toString())?.toUtc();
            final clearTimeUtc = _feedClearedAt!.toUtc();
            if (msgTime != null && msgTime.isBefore(clearTimeUtc)) {
              return;
            }
          } else {
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

        final isJoinAnnouncement = text.contains('has joined the party') ||
            text.contains('joined the party') ||
            text.contains('entered the room');

        if (isJoinAnnouncement) {
          final alreadyShown = _messages.any((m) =>
              m.isSystemMessage &&
              (m.text.contains(senderName) || (senderUsername.isNotEmpty && m.text.contains(senderUsername))) &&
              (m.text.contains('joined') || m.text.contains('entered') || m.text.contains('Welcome')) &&
              DateTime.now().difference(m.timestamp).inSeconds < 6);
          if (alreadyShown) {
            return; // Suppress duplicate join message
          }
        }

        final isSystem = data['isSystemMessage'] == true ||
            data['type']?.toString().toUpperCase() == 'SYSTEM' ||
            senderId == 'system' ||
            isJoinAnnouncement;

        final sender = UserModel(
          id: senderId.isNotEmpty ? senderId : (isSystem ? 'system' : 'user_${DateTime.now().millisecondsSinceEpoch}'),
          username: senderUsername.isNotEmpty ? senderUsername : senderName,
          name: senderName,
          avatarUrl: senderMap['avatarUrl']?.toString() ?? '',
          isVip: senderMap['isVip'] == true || (senderMap['vipLevel'] is num && (senderMap['vipLevel'] as num) > 0),
          nobleTitle: senderMap['nobleTitle']?.toString() ?? senderMap['nobleLevel']?.toString(),
          avatarFrame: senderMap['avatarFrame']?.toString() ??
              senderMap['equippedFrame']?.toString() ??
              senderMap['frameUrl']?.toString() ??
              (senderMap['profile'] is Map ? senderMap['profile']['avatarFrame']?.toString() : null) ?? '',
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
      if (!matchesCurrentRoom(data)) return;
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
        final kickedClean = targetUserId.toLowerCase().replaceFirst(RegExp(r'^user_'), '');
        final kickedIdx = _participants.indexWhere((p) =>
            p.user.id == targetUserId ||
            p.user.id.toLowerCase() == targetUserId.toLowerCase() ||
            p.user.id.toLowerCase().replaceFirst(RegExp(r'^user_'), '') == kickedClean ||
            (targetUserId.isNotEmpty && p.user.username.isNotEmpty && p.user.username.toLowerCase() == targetUserId.toLowerCase()));
        if (kickedIdx != -1) {
          final kicked = _participants[kickedIdx];
          final kickedName = kicked.user.name;
          final kickedSeat = kicked.seatNumber;
          if (kickedSeat != null) {
            _mutedSeatIndices.remove(kickedSeat);
            _lockedSeatIndices.remove(kickedSeat);
            _seatVoiceLevels[kickedSeat] = 0.0;
          }
          unregisterAgoraUidMapping(agoraUidRaw: kicked.agoraUid, userId: kicked.user.id);
          _announcedJoinedUserIds.remove(kicked.user.id);
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
      if (!isHost) {
        try {
          _agoraService.muteLocalAudio(muted);
        } catch (_) {}
      }
      sendSystemMessage(muted ? '🔇 Room audio has been MUTED by platform moderation.' : '🎙️ Room audio has been UNMUTED.');
      notifyListeners();
    });

    // 13. Admin moderation: Specific user / seat muted
    _socketRoomUserMutedSub?.cancel();
    _socketRoomUserMutedSub = _socketService.onRoomUserMuted.listen((data) {
      final roomId = data['roomId']?.toString() ?? '';
      if (_activeRoom != null && roomId.isNotEmpty && roomId != _activeRoom!.id) return;
      final targetId = data['targetUserId']?.toString() ?? data['userId']?.toString();
      final seatIndex = (data['seatIndex'] is num)
          ? (data['seatIndex'] as num).toInt()
          : int.tryParse(data['seatIndex']?.toString() ?? data['seatNumber']?.toString() ?? '');
      final muted = data['isMuted'] == true;
      final isModAction = data['isMutedByModerator'] == true ||
          data['moderatedByUserId'] != null ||
          data['reason'] != null;

      if (seatIndex != null) {
        if (muted) {
          if (isModAction) _mutedSeatIndices.add(seatIndex);
        } else {
          _mutedSeatIndices.remove(seatIndex);
        }
      }

      final selfParticipant = _participants.where((p) => p.user.id == currentUser.id).firstOrNull;
      final isMeTarget = (targetId != null && (targetId == currentUser.id || targetId == currentUser.username)) ||
          (seatIndex != null && selfParticipant?.seatNumber == seatIndex);

      if (isMeTarget) {
        if (!isHost && muted) {
          try {
            _agoraService.muteLocalAudio(true);
          } catch (_) {}
          sendSystemMessage('🔇 Your microphone has been MUTED by moderation.');
        } else if (!isHost && !muted) {
          sendSystemMessage('🎙️ Your microphone restriction has been lifted by moderation.');
          // When a moderator restriction is removed:
          // Do not automatically turn on the microphone if the user had chosen to self-mute.
          // Keep personal mute preference separate from the moderator restriction.
          if (!_isLocalSelfMuted) {
            try {
              _agoraService.muteLocalAudio(false);
            } catch (_) {}
          }
        }
      }

      // Update participant list
      for (int i = 0; i < _participants.length; i++) {
        final p = _participants[i];
        if ((targetId != null && (p.user.id == targetId || p.user.username == targetId)) ||
            (seatIndex != null && p.seatNumber == seatIndex)) {
          final isTargetMe = currentUser.id == p.user.id || currentUser.username == p.user.username;
          if (muted) {
            _participants[i] = p.copyWith(
              micStatus: MicStatus.muted,
              isMutedByModerator: isModAction,
            );
          } else {
            final shouldBeMuted = isTargetMe && _isLocalSelfMuted;
            _participants[i] = p.copyWith(
              micStatus: shouldBeMuted ? MicStatus.muted : MicStatus.on,
              isMutedByModerator: false,
            );
          }
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
            if (_activeRoom != null) {
              updateSavedMemberRole(_activeRoom!.id, targetUserId, ParticipantRole.host);
            }
          } else if (newRoleStr == 'ADMIN' || newRoleStr == 'MODERATOR') {
            newRole = ParticipantRole.moderator;
            if (_activeRoom != null) {
              updateSavedMemberRole(_activeRoom!.id, targetUserId, ParticipantRole.moderator);
            }
          } else {
            if (_activeRoom != null) {
              updateSavedMemberRole(_activeRoom!.id, targetUserId, ParticipantRole.listener);
            }
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

      final targetUserId = data['targetUserId']?.toString() ??
          data['targetUser']?['id']?.toString() ??
          data['userId']?.toString();
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

      // Normalized target comparison to support numeric IDs, string IDs, username, and prefixed IDs
      final currentId = _currentUser?.id ?? '';
      final currentUsername = _currentUser?.username ?? '';
      final isSelfTarget = currentId.isNotEmpty && targetUserId != null && (
        targetUserId == currentId ||
        targetUserId.toLowerCase() == currentId.toLowerCase() ||
        targetUserId.replaceAll('user_', '') == currentId.replaceAll('user_', '') ||
        (currentUsername.isNotEmpty && targetUserId.toLowerCase() == currentUsername.toLowerCase())
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

    // 15b. Co-Host Invitation Realtime Events (NEW-039)
    _socketCoHostInviteSub?.cancel();
    _socketCoHostInviteSub = _socketService.onCoHostInvitationReceived.listen((invitation) {
      final roomId = invitation.roomId;
      final isMatchingRoom = _activeRoom == null ||
          roomId.isEmpty ||
          roomId == _activeRoom!.id ||
          _activeRoom!.agoraChannelName == roomId ||
          _initialRoomId == roomId ||
          _activeRoom!.id.contains(roomId);

      if (!isMatchingRoom) return;

      final currentId = _currentUser?.id ?? '';
      final targetUserId = invitation.inviteeUserId;
      final isSelfTarget = currentId.isNotEmpty && (
        targetUserId == currentId ||
        targetUserId.toLowerCase() == currentId.toLowerCase() ||
        targetUserId.replaceAll('user_', '') == currentId.replaceAll('user_', '')
      );

      if (isSelfTarget) {
        _incomingCoHostInviteController.add(invitation);
      }
    });

    _socketCoHostInviteResponseSub?.cancel();
    _socketCoHostInviteResponseSub = _socketService.onCoHostInvitationResponse.listen((data) {
      debugPrint('[LivePartyProvider] Co-Host invite response received: $data');
      notifyListeners();
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
      if (!matchesCurrentRoom(data)) return;
      final rawTotal = data['roomSendingTotal'] ??
          data['dailySendingTotal'] ??
          data['totalCoins'] ??
          data['trophyCoins'] ??
          data['total'];
      final total = (rawTotal is num)
          ? rawTotal
          : (num.tryParse(rawTotal?.toString() ?? '') ?? 0);
      final currentId = _activeRoom?.id ?? _initialRoomId ?? '';
      if (total >= 0) {
        _roomSendingTotal = total;
        if (currentId.isNotEmpty) {
          RoomConfigManager.instance.saveRoomSendingTotal(currentId, total);
        }
        notifyListeners();
      }
    });

    // 21. Room Background Image Stream (Item 34)
    _socketRoomBackgroundSub?.cancel();
    _socketRoomEmojiSub?.cancel();
    _activeMicReactions.clear();
    _socketRoomBackgroundSub = _socketService.onRoomBackgroundUpdated.listen((data) {
      final rId = data['roomId']?.toString() ?? data['id']?.toString();
      final currentId = _activeRoom?.id ?? _initialRoomId ?? '';
      if (rId == null || rId == currentId) {
        final bg = data['backgroundImageUrl']?.toString() ?? data['background']?.toString();
        if (_activeRoom != null && bg != null) {
          _activeRoom = _activeRoom!.copyWith(backgroundImageUrl: bg);
        }
        if (currentId.isNotEmpty && bg != null) {
          RoomConfigManager.instance.saveRoomBackground(currentId, bg);
        }
        notifyListeners();
      }
    });

    // Room Lock Status Stream (Issue 07)
    _socketRoomLockSub?.cancel();
    _socketRoomLockSub = _socketService.onRoomLockUpdated.listen((data) {
      if (!matchesCurrentRoom(data)) return;
      _isRoomLocked = data['isLocked'] == true;
      if (data['lockMode'] != null) _roomLockMode = data['lockMode'].toString();
      notifyListeners();
    });

    // Host Presence & Grace Period Stream (Bug 06)
    _socketRoomHostAbsentSub?.cancel();
    _socketRoomHostAbsentSub = _socketService.onRoomHostAbsent.listen((data) {
      if (!matchesCurrentRoom(data)) return;
      _isHostAbsent = true;
      notifyListeners();
    });

    _socketRoomHostReturnedSub?.cancel();
    _socketRoomHostReturnedSub = _socketService.onRoomHostReturned.listen((data) {
      if (!matchesCurrentRoom(data)) return;
      _isHostAbsent = false;
      notifyListeners();
    });

    // Room Animated Emojis Stream (Section 4)
    _socketRoomEmojiSub?.cancel();
    _socketRoomEmojiSub = _socketService.onRoomEmoji.listen((data) {
      if (!matchesCurrentRoom(data)) return;
      try {
        final rId = (data['roomId'] ?? '').toString().trim();
        final currentId = (_activeRoom?.id ?? _initialRoomId ?? '').trim();
        final emoji = (data['emoji'] ?? '').toString().trim();
        if (emoji.isEmpty) return;

        final senderMap = data['sender'] is Map ? (data['sender'] as Map) : null;
        final senderId = (senderMap != null ? (senderMap['id'] ?? senderMap['userId']) : data['senderId'])?.toString() ?? '';
        final senderName = (senderMap != null ? (senderMap['displayName'] ?? senderMap['name']) : data['senderName'])?.toString() ?? 'User';

        int? seatId = data['seatId'] is num
            ? (data['seatId'] as num).toInt()
            : int.tryParse(data['seatId']?.toString() ?? '');

        // Fallback: If backend broadcast stripped seatId, resolve seat from participants or host
        if (seatId == null && senderId.isNotEmpty) {
          final occupant = _participants.where((p) =>
              (p.user.id == senderId ||
               (p.user.username.isNotEmpty && p.user.username == (senderMap?['username']?.toString() ?? ''))) &&
              p.seatNumber != null
          ).firstOrNull;
          seatId = occupant?.seatNumber;

          if (seatId == null) {
            final isRoomHost = (_activeRoom?.host.id == senderId) ||
                (_activeRoom?.creatorUserId == senderId) ||
                (senderMap?['username'] != null && _activeRoom?.host.username.toLowerCase() == senderMap!['username'].toString().toLowerCase()) ||
                (senderMap?['publicUserId'] != null && _activeRoom?.host.publicUserId == senderMap!['publicUserId'].toString());
            if (isRoomHost) {
              seatId = 0;
            }
          }
        }

        if (seatId != null) {
          int? gameResult = data['gameResult'] is num
              ? (data['gameResult'] as num).toInt()
              : int.tryParse(data['gameResult']?.toString() ?? '');

          if (gameResult == null) {
            if (emoji == 'dice') {
              gameResult = math.Random().nextInt(6) + 1;
            } else if (emoji == 'number') {
              gameResult = math.Random().nextInt(1000);
            }
          }

          final reactionId = data['id']?.toString() ?? 'react_${DateTime.now().millisecondsSinceEpoch}_$seatId';
          final reactionEvent = {
            'id': reactionId,
            'senderUserId': senderId,
            'senderName': senderName,
            'roomId': rId.isNotEmpty ? rId : currentId,
            'micIndex': seatId,
            'reactionAsset': emoji,
            'category': data['category']?.toString() ?? 'illustrated',
            'gameResult': gameResult,
            'timestamp': data['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
          };

          _activeMicReactions[seatId] = reactionEvent;
          notifyListeners();

          final capturedSeat = seatId;
          Future.delayed(Duration(seconds: _reactionDurationSeconds), () {
            if (_activeMicReactions[capturedSeat]?['id'] == reactionId) {
              _activeMicReactions.remove(capturedSeat);
              notifyListeners();
            }
          });
        } else {
          // Audience viewer reaction without a mic seat: notify listeners so UI updates
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[LivePartyProvider] onRoomEmoji incoming event error: $e');
      }
    });

    // 21. PK Battle: Invitation Received (Section 1)
    _socketPkInviteSub?.cancel();
    _socketPkInviteSub = _socketService.onPkInvitationReceived.listen((data) {
      if (isHost || _activeRoom?.creatorUserId == currentUser.id) {
        _pkInvitationController.add(data);
      }
    });

    // 22. PK Battle: Preparing (15s Window - Section 1)
    _socketPkPreparingSub?.cancel();
    _socketPkPreparingSub = _socketService.onPkPreparing.listen((data) {
      try {
        _activePkBattle = PKBattleModel.fromJson(data);
        _isPkActive = true;
        notifyListeners();
        if (isHost && _activePkBattle != null) {
          PKRepository.instance.setOperatorReady(matchId: _activePkBattle!.id, mediaPrepared: true);
        }
      } catch (_) {}
    });

    // 23. PK Battle: 3-Second Countdown (Section 1)
    _socketPkCountdownSub?.cancel();
    _socketPkCountdownSub = _socketService.onPkCountdownStarted.listen((data) {
      _pkCountdown = 3;
      if (_activePkBattle != null) {
        _activePkBattle = _activePkBattle!.copyWith(status: 'COUNTDOWN');
      }
      debugPrint('[LivePartyProvider] PK Countdown started (3s)!');
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

    // 24. PK Battle: Active match listener for new / reconnecting viewers (Bug 1 & 8)
    _socketPkActiveSub?.cancel();
    _socketPkActiveSub = _socketService.onPkActive.listen((data) {
      try {
        _activePkBattle = PKBattleModel.fromJson(data);
        _isPkActive = true;
        _pkCountdown = 0;
        _isPkOpponentDisconnected = false;
        _pkScoreA = _activePkBattle!.scoreA;
        _pkScoreB = _activePkBattle!.scoreB;
        _pkTimerRemaining = _activePkBattle!.remainingSeconds;

        _setupAudioPkRelay(_activePkBattle!);
        _startPkAuthoritativeTimer();
        notifyListeners();
      } catch (_) {}
    });

    // 24. PK Battle: Match Started (Active - Section 2)
    _socketPkMatchStartedSub?.cancel();
    _socketPkMatchStartedSub = _socketService.onPkStarted.listen((data) {
      try {
        _activePkBattle = PKBattleModel.fromJson(data);
        _isPkActive = true;
        _pkCountdown = 0;
        _isPkOpponentDisconnected = false;
        _pkScoreA = _activePkBattle!.scoreA;
        _pkScoreB = _activePkBattle!.scoreB;
        _pkTimerRemaining = _activePkBattle!.remainingSeconds;

        _setupAudioPkRelay(_activePkBattle!);
        _startPkAuthoritativeTimer();
        notifyListeners();
      } catch (_) {}
    });

    // 25. PK Battle: Authoritative Score Updated (Section 4)
    _socketPkScoreUpdatedSub?.cancel();
    _socketPkScoreUpdatedSub = _socketService.onPkScoreUpdated.listen((data) {
      final sA = int.tryParse(data['scoreA']?.toString() ?? '') ?? _pkScoreA;
      final sB = int.tryParse(data['scoreB']?.toString() ?? '') ?? _pkScoreB;
      _pkScoreA = sA;
      _pkScoreB = sB;
      if (_activePkBattle != null) {
        _activePkBattle = _activePkBattle!.copyWith(scoreA: sA, scoreB: sB);
      }
      notifyListeners();
    });

    // 26. PK Battle: Host Connection Changed (30s Grace - Section 5)
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

    // 27. PK Battle: Match Finished (Section 4 & 5)
    _socketPkMatchFinishedSub?.cancel();
    _socketPkMatchFinishedSub = _socketService.onPkMatchFinished.listen((data) {
      try {
        _activePkBattle = PKBattleModel.fromJson(data);
        _isPkActive = false;
        _pkTimer?.cancel();
        _agoraService.leaveOpponentPKChannel();
        _pkResultController.add(_activePkBattle!);
        notifyListeners();
      } catch (_) {}
    });

    // 28. PK Battle: Forfeited or Aborted (Section 5)
    _socketPkForfeitedSub?.cancel();
    _socketPkForfeitedSub = _socketService.onPkMatchForfeited.listen((data) {
      try {
        _activePkBattle = PKBattleModel.fromJson(data);
        _isPkActive = false;
        _pkTimer?.cancel();
        _agoraService.leaveOpponentPKChannel();
        sendSystemMessage('⚔️ PK Match ended: ${data['endReason'] ?? "Opponent forfeited."}');
        _pkResultController.add(_activePkBattle!);
        notifyListeners();
      } catch (_) {}
    });
    _socketPkAbortedSub?.cancel();
    _socketPkAbortedSub = _socketService.onPkMatchAborted.listen((data) {
      try {
        _activePkBattle = PKBattleModel.fromJson(data);
        _isPkActive = false;
        _pkTimer?.cancel();
        _agoraService.leaveOpponentPKChannel();
        sendSystemMessage('⚠️ PK Match aborted: ${data['endReason'] ?? "System incident."}');
        notifyListeners();
      } catch (_) {}
    });
  }

  /// Clears the room's lower feed messages and records clear timestamp
  void clearRoomFeed() {
    _feedClearedAt = DateTime.now().toUtc();
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
      ParticipantRole roleEnum = newRole.toUpperCase() == 'ADMIN'
          ? ParticipantRole.moderator
          : ParticipantRole.listener;

      // Update in saved room members
      updateSavedMemberRole(roomId, targetUserId, roleEnum);

      final idx = _participants.indexWhere((p) => p.user.id == targetUserId);
      if (idx != -1) {
        if (_participants[idx].seatNumber != null && roleEnum == ParticipantRole.listener) {
          roleEnum = ParticipantRole.speaker;
        }
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

  bool _isLeaving = false;

  Future<void> leaveParty() async {
    // Idempotent: socket events (room:closed, kicked, ...) can arrive several times in a
    // burst; re-entering here used to emit `room:leave` and POST /leave once per event,
    // tripping the server rate limiter.
    if (_isLeaving) return;
    _isLeaving = true;
    try {
      await _leavePartyInternal();
    } finally {
      _isLeaving = false;
    }
  }

  /// Generation counter: every joinParty() / leaveParty() bumps it, and any join still in
  /// flight from an older generation gives up instead of writing into the newer session.
  int _sessionGeneration = 0;

  /// Network + Agora part of the last leave; the next join waits for it before joining Agora.
  Future<void>? _pendingLeave;

  Future<void> _leavePartyInternal() async {
    // Root cause of "host sees nothing until re-entering": this used to await the REST leave
    // and the Agora leave FIRST and cancel the socket subscriptions / wipe state AFTERWARDS.
    // The party screen's dispose() calls leaveParty() without awaiting it, so when the user
    // re-entered within a few seconds the new joinParty() had already subscribed, and this
    // continuation then cancelled those fresh subscriptions and emptied participants/messages.
    // Order now: synchronous teardown first, network/Agora last, no state writes after awaits.
    _sessionGeneration++;
    final roomId = _activeRoom?.id;
    _activeRoom = null;
    if (roomId != null) {
      try {
        _socketService.leaveRoom(roomId);
      } catch (_) {}
    }


    _volumeIndicationSub?.cancel();
    _speakerSub?.cancel();
    _remoteUsersSub?.cancel();
    _socketConnectionSub?.cancel();
    _socketRoomSnapshotSub?.cancel();
    _socketPresenceSyncSub?.cancel();
    _socketStageSyncSub?.cancel();
    _socketSeatUpdatedSub?.cancel();
    _socketPkSnapshotSub?.cancel();
    _agoraUidToUser.clear();
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
    _socketCoHostInviteSub?.cancel();
    _socketCoHostInviteResponseSub?.cancel();
    _socketRoomEmojiSub?.cancel();
    _socketRoomLockSub?.cancel();
    _socketRoomHostAbsentSub?.cancel();
    _socketRoomHostReturnedSub?.cancel();
    _socketPkActiveSub?.cancel();
    _socketFeedClearedSub?.cancel();
    _socketDetailsUpdatedSub?.cancel();
    _socketSeatLockedSub?.cancel();
    _socketLayoutUpdatedSub?.cancel();
    _socketSendingTotalSub?.cancel();
    _socketRoomBackgroundSub?.cancel();
    _socketPkInviteSub?.cancel();
    _socketPkPreparingSub?.cancel();
    _socketPkCountdownSub?.cancel();
    _socketPkMatchStartedSub?.cancel();
    _socketPkScoreUpdatedSub?.cancel();
    _socketPkHostConnectionSub?.cancel();
    _socketPkMatchFinishedSub?.cancel();
    _socketPkForfeitedSub?.cancel();
    _socketPkAbortedSub?.cancel();
    _agoraService.leaveOpponentPKChannel();
    _pendingOutgoingInvites.clear();
    _feedClearedAt = null;
    _pkTimer?.cancel();
    _activePkBattle = null;
    _isPkOpponentDisconnected = false;
    _pkCountdown = 0;

    _activeRoom = null;
    _initialRoomId = null;
    _currentUser = null;
    _isPkActive = false;
    _roomSendingTotal = 0;
    _participants = [];
    _messages = [];
    _activeRemoteAgoraUids.clear();
    _agoraUidToUserId.clear();
    _userIdToAgoraUid.clear();
    _seatVoiceLevels.clear();
    _announcedJoinedUserIds.clear();
    _recentSystemMessages.clear();
    _activeRoom = null;
    notifyListeners();

    final leaveWork = () async {
      if (roomId != null) {
        try {
          await _roomRepository.leaveRoom(roomId);
        } catch (_) {}
      }
      try {
        await _agoraService.leaveChannel();
      } catch (_) {}
    }();
    _pendingLeave = leaveWork;
    try {
      await leaveWork;
    } finally {
      if (identical(_pendingLeave, leaveWork)) _pendingLeave = null;
    }
  }

  Future<void> closeRoom() async {
    final roomId = _activeRoom?.id;
    if (roomId != null) {
      try {
        await _roomRepository.closeRoom(roomId);
        // CR 14: Never clear room sending total locally on room close to guarantee persistence across reopenings
      } catch (_) {}
      await leaveParty();
    }
  }

  // ── Seat Management ────────────────────────────────────────────────────────
  /// Helper to get the correct user-facing seat label (0=Host Mic, 1=Co-Host Mic, 2..N=Seat 1..N-1)
  String formatSeatLabel(int seatIndex) {
    if (seatIndex == 0) return 'Host Mic';
    if (seatIndex == 1) return 'Co-Host Mic';
    final capacity = _activeRoom?.seatCapacity ?? 10;
    if (capacity == 15 && seatIndex == 2) return 'VIP Mic';
    return 'Seat ${seatIndex - 1}';
  }

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
          role: _resolveRoleForUser(
            user: p.user,
            isHost: false,
            currentRole: p.role,
            isSeated: false,
          ),
          micStatus: MicStatus.muted,
        );
      }
    }

    try {
      _socketService.occupySeat(_activeRoom!.id, seatIndex, user: actor.toJson());
    } catch (e) {
      debugPrint('[LivePartyProvider] Socket occupySeat notice: $e');
    }

    try {
      await _roomRepository.occupySeat(_activeRoom!.id, seatIndex);
    } catch (e) {
      debugPrint('[LivePartyProvider] Backend REST occupySeat notice: $e');
    }

    // Update local state with real user object
    final existingIdx = _participants.indexWhere(
      (p) => p.user.id == actor.id ||
             (actor.username.isNotEmpty && p.user.username.toLowerCase() == actor.username.toLowerCase()) ||
             (actor.name.isNotEmpty && p.user.name.toLowerCase() == actor.name.toLowerCase())
    );

    final currentRole = existingIdx != -1 ? _participants[existingIdx].role : null;
    final resolvedRole = _resolveRoleForUser(
      user: actor,
      isHost: isHostActor,
      currentRole: currentRole,
      isSeated: true,
    );

    if (existingIdx != -1) {
      _participants[existingIdx] = _participants[existingIdx].copyWith(
        user: actor,
        seatNumber: seatIndex,
        role: resolvedRole,
        micStatus: MicStatus.on,
      );
    } else {
      _participants.add(PartyParticipantModel(
        user: actor,
        role: resolvedRole,
        seatNumber: seatIndex,
        micStatus: MicStatus.on,
        joinedAt: DateTime.now(),
      ));
    }

    // Promote Agora Role to Broadcaster and unmute local audio if actor is current user (Fix 31.1)
    if (actor.id == _currentUser?.id) {
      _isLocalSelfMuted = false;
      try {
        await _agoraService.switchRole(isHost: true);
        await _agoraService.muteLocalAudio(false);
      } catch (_) {}
    }

    final seatName = formatSeatLabel(seatIndex);
    _logMicAudit(
      seatIndex: seatIndex,
      actorId: actor.id,
      actorRole: _getRoleString(actor.id),
      targetId: actor.id,
      action: 'TAKE_MIC',
      previousState: 'Audience',
      newState: seatName,
    );

    // sendSystemMessage mic joining message removed
    notifyListeners();
    return null;
  }

  /// Deduplicate participants so each user is represented exactly once across all seats and lists
  void _deduplicateParticipants() {
    final unique = <PartyParticipantModel>[];
    for (final p in _participants) {
      final id = p.user.id.trim();
      final idLower = id.toLowerCase();
      final idClean = idLower.replaceFirst(RegExp(r'^user_'), '');
      final username = p.user.username.trim().toLowerCase();

      final existingIdx = unique.indexWhere((u) {
        final uId = u.user.id.trim().toLowerCase();
        final uIdClean = uId.replaceFirst(RegExp(r'^user_'), '');
        if (id.isNotEmpty && (uId == idLower || uIdClean == idClean)) return true;
        if (p.agoraUid != null && u.agoraUid != null && p.agoraUid == u.agoraUid) return true;
        if (username.isNotEmpty &&
            !username.startsWith('guest_') &&
            !username.startsWith('user_') &&
            username != 'guest' &&
            username != 'user' &&
            username != 'speaker' &&
            u.user.username.trim().toLowerCase() == username) {
          return true;
        }
        return false;
      });

      if (existingIdx == -1) {
        unique.add(p);
      } else {
        final existing = unique[existingIdx];
        final seat = p.seatNumber ?? existing.seatNumber;
        final role = (p.role == ParticipantRole.host || existing.role == ParticipantRole.host)
            ? ParticipantRole.host
            : (seat != null ? ParticipantRole.speaker : (p.role != ParticipantRole.listener ? p.role : existing.role));
        final agoraUid = p.agoraUid ?? existing.agoraUid;
        final effectiveUser = p.user.avatarUrl.isNotEmpty ? p.user : existing.user;

        unique[existingIdx] = existing.copyWith(
          user: effectiveUser,
          seatNumber: seat,
          role: role,
          agoraUid: agoraUid,
          micStatus: seat != null ? (p.micStatus == MicStatus.on || existing.micStatus == MicStatus.on ? MicStatus.on : MicStatus.muted) : existing.micStatus,
        );
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
      // 2. Broadcast release via socket immediately
      _socketService.leaveSeat(_activeRoom!.id, targetSeatIndex);
    } catch (e) {
      debugPrint('[LivePartyProvider] Socket leaveSeat notice: $e');
    }

    try {
      // 3. Authoritative backend REST release
      await _roomRepository.leaveSeat(_activeRoom!.id, targetSeatIndex);
    } catch (e) {
      debugPrint('[LivePartyProvider] Backend REST leaveSeat notice: $e');
    }

    try {
      // 4. Update local state immediately
      final isHostUser = isHost ||
          targetUser.id == _activeRoom?.host.id ||
          targetUser.id == _activeRoom?.creatorUserId;

      final pIdx = _participants.indexWhere((p) =>
        p.seatNumber == targetSeatIndex ||
        p.user.id == targetUser.id
      );

      final currentRole = pIdx != -1 ? _participants[pIdx].role : null;
      final resolvedRole = _resolveRoleForUser(
        user: targetUser,
        isHost: isHostUser,
        currentRole: currentRole,
        isSeated: false,
      );

      if (pIdx != -1) {
        final currentP = _participants[pIdx];
        _participants[pIdx] = currentP.copyWith(
          clearSeat: true,
          role: resolvedRole,
          micStatus: MicStatus.muted,
        );
      } else {
        _participants.add(PartyParticipantModel(
          user: targetUser,
          role: resolvedRole,
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
            role: _resolveRoleForUser(
              user: _participants[i].user,
              isHost: false,
              currentRole: _participants[i].role,
              isSeated: false,
            ),
            micStatus: MicStatus.muted,
          );
        }
      }

      _deduplicateParticipants();

      // 5. Stop local audio transmission and switch Agora role to audience
      if (targetUser.id == _currentUser?.id) {
        _isLocalSelfMuted = false;
        _agoraService.muteLocalAudio(true);
        await _agoraService.switchRole(isHost: false);
      }

      final seatName = formatSeatLabel(targetSeatIndex);
      _logMicAudit(
        seatIndex: targetSeatIndex,
        actorId: targetUser.id,
        actorRole: _getRoleString(targetUser.id),
        targetId: targetUser.id,
        action: 'LEAVE_MIC',
        previousState: seatName,
        newState: 'Audience',
      );

      // sendSystemMessage left mic message removed
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

        final seatName = formatSeatLabel(seatIndex);
        _logMicAudit(
          seatIndex: seatIndex,
          actorId: actor.id,
          actorRole: _getRoleString(actor.id),
          targetId: occupant.user.id,
          action: 'CLEAR_MIC_SEAT',
          previousState: 'Occupied (${occupant.user.name}) on $seatName',
          newState: 'Empty',
        );

        sendSystemMessage('🚫 ${occupant.user.name} was moved off $seatName.');
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

    final seatLabel = formatSeatLabel(seatIndex);

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
    String? targetUserId;
    if (occupantIdx != -1) {
      targetUserId = _participants[occupantIdx].user.id;
      _participants[occupantIdx] = _participants[occupantIdx].copyWith(
        micStatus: mute ? MicStatus.muted : MicStatus.on,
        isMutedByModerator: mute,
      );
      if (_participants[occupantIdx].user.id == _currentUser?.id) {
        _agoraService.muteLocalAudio(mute);
      }
    }

    final roomId = _activeRoom?.id ?? _initialRoomId ?? '';
    if (roomId.isNotEmpty) {
      _socketService.emitRoomSeatMute(
        roomId,
        seatIndex,
        mute,
        targetUserId: targetUserId,
        reason: 'moderator_seat_action',
      );
    }

    final seatLabel = formatSeatLabel(seatIndex);

    _logMicAudit(
      seatIndex: seatIndex,
      actorId: actor.id,
      actorRole: _getRoleString(actor.id),
      targetId: occupantIdx != -1 ? _participants[occupantIdx].user.id : null,
      action: mute ? 'MUTE_MIC' : 'UNMUTE_MIC',
      previousState: mute ? 'Active' : 'Muted',
      newState: mute ? 'Muted' : 'Active',
    );

    sendSystemMessage(mute ? '🔇 $seatLabel muted.' : '🔊 $seatLabel unmuted.');
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

    final seatLabel = formatSeatLabel(seatIndex);

    _logMicAudit(
      seatIndex: seatIndex,
      actorId: inviter.id,
      actorRole: _getRoleString(inviter.id),
      targetId: targetUser.id,
      action: 'INVITE_MIC',
      previousState: 'Available',
      newState: 'Invited',
    );

    sendSystemMessage('📩 ${inviter.name} invited ${targetUser.name} to take $seatLabel.');
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

  bool _isLocalSelfMuted = false;
  bool get isLocalSelfMuted => _isLocalSelfMuted;

  bool isSpeaker(String userId) => _participants.any((p) => p.user.id == userId && p.seatNumber != null);

  bool isSeatLocked(int seatIndex) => _lockedSeatIndices.contains(seatIndex);

  bool get isLocalMicMuted {
    if (!isHost && _isRoomMuted) return true;
    final self = _participants.where((p) => p.user.id == _currentUser?.id).firstOrNull;
    if (!isHost && self?.isMutedByModerator == true) return true;
    if (!isHost && self?.seatNumber != null && isSeatMutedByModerator(self!.seatNumber!)) return true;
    return _isLocalSelfMuted || (self?.micStatus == MicStatus.muted);
  }

  bool toggleLocalMic() {
    if (!isHost && _isRoomMuted) return true;
    final self = _participants.where((p) => p.user.id == _currentUser?.id).firstOrNull;
    if (!isHost && self?.isMutedByModerator == true) return true;
    if (!isHost && self?.seatNumber != null && isSeatMutedByModerator(self!.seatNumber!)) return true;
    final newMuted = !isLocalMicMuted;
    muteLocalMic(newMuted);
    return newMuted;
  }

  void muteLocalMic(bool muted) {
    _isLocalSelfMuted = muted;
    _agoraService.muteLocalAudio(muted);
    final selfIdx = _participants.indexWhere((p) => p.user.id == _currentUser?.id);
    if (selfIdx != -1) {
      _participants[selfIdx] = _participants[selfIdx].copyWith(
        micStatus: muted ? MicStatus.muted : MicStatus.on,
      );
      notifyListeners();
    }
  }

  /// Cleans up deduplication keys for a departed user so reentry can trigger a join announcement.
  void cleanupDepartedUser(String userId, {String? username, String? name}) {
    _announcedJoinedUserIds.remove(userId);
    _announcedJoinedUserIds.remove(userId.toLowerCase());
    if (username != null && username.isNotEmpty) {
      _announcedJoinedUserIds.remove(username.toLowerCase());
      _recentSystemMessages.removeWhere((k, _) => k.toLowerCase().contains(username.toLowerCase()));
    }
    if (name != null && name.isNotEmpty) {
      _announcedJoinedUserIds.remove(name.toLowerCase());
      _recentSystemMessages.removeWhere((k, _) => k.toLowerCase().contains(name.toLowerCase()));
    }
  }

  // ── Chat & Messages ────────────────────────────────────────────────────────
  void sendSystemMessage(String text, {UserModel? entrantUser, String? eventId}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _recentSystemMessages.removeWhere((_, time) => now - time > 5000);
    if (_recentSystemMessages.containsKey(text)) {
      final prevTime = _recentSystemMessages[text]!;
      if (now - prevTime < 3000) {
        return; // Suppress duplicate message within 3 seconds
      }
    }
    _recentSystemMessages[text] = now;

    final isJoinMsg = text.contains('joined the party') || text.contains('to the party') || text.contains('entered the room');
    if (isJoinMsg) {
      final entrantId = entrantUser?.id.trim().toLowerCase() ?? '';
      final duplicateJoin = _messages.any((m) {
        if (!m.isSystemMessage) return false;
        final isOtherJoin = m.text.contains('joined the party') || m.text.contains('to the party') || m.text.contains('entered the room');
        if (!isOtherJoin) return false;

        final mSenderId = m.sender.id.trim().toLowerCase();
        final sameUser = (entrantId.isNotEmpty && mSenderId == entrantId) || (m.text == text);
        if (!sameUser) return false;

        return DateTime.now().difference(m.timestamp).inSeconds < 6;
      });
      if (duplicateJoin) {
        return;
      }
    }

    _messages.add(PartyMessageModel(
      id: eventId ?? now.toString(),
      sender: entrantUser ??
          const UserModel(
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
    int? gameResult,
  }) {
    final occupant = _participants.where((p) => p.user.id == sender.id && p.seatNumber != null).firstOrNull;
    int? micIndex = occupant?.seatNumber;
    if (micIndex == null) {
      final isHost = (_activeRoom?.host.id == sender.id) ||
          (_activeRoom?.creatorUserId == sender.id) ||
          (sender.username.isNotEmpty && _activeRoom?.host.username.toLowerCase() == sender.username.toLowerCase()) ||
          (sender.publicUserId.isNotEmpty && _activeRoom?.host.publicUserId == sender.publicUserId);
      if (isHost) {
        micIndex = 0;
      }
    }
    if (micIndex == null) {
      return false;
    }

    final lastTime = _lastUserReactionTimestamp[sender.id];
    if (lastTime != null && DateTime.now().difference(lastTime).inMilliseconds < 1500) {
      return false;
    }
    _lastUserReactionTimestamp[sender.id] = DateTime.now();

    final reactionEvent = {
      'id': 'react_${DateTime.now().millisecondsSinceEpoch}',
      'senderUserId': sender.id,
      'senderName': sender.name,
      'roomId': _activeRoom?.id ?? 'room_101',
      'micIndex': micIndex,
      'reactionAsset': reactionAsset,
      'category': category,
      'gameResult': gameResult,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _activeMicReactions[micIndex] = reactionEvent;
    notifyListeners();

    _socketService.sendRoomEmoji(
      roomId: _activeRoom?.id ?? _initialRoomId ?? 'room_101',
      emoji: reactionAsset,
      seatId: micIndex,
      senderName: sender.name,
      senderAvatar: sender.avatarUrl,
      gameResult: gameResult,
      reactionId: reactionEvent['id'] as String?,
    );

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

  Future<void> _setupAudioPkRelay(PKBattleModel battle) async {
    if (battle.agoraRelay == null) return;
    final relay = battle.agoraRelay!;
    final currentRoomId = _activeRoom?.id ?? '';
    final isRoomB = currentRoomId == battle.roomBId || currentRoomId == relay.channelB;
    final opponentChannel = isRoomB ? relay.channelA : relay.channelB;
    final opponentUid = isRoomB ? relay.hostAUid : relay.hostBUid;
    final opponentRoomId = isRoomB ? battle.roomAId : battle.roomBId;

    String? token;
    try {
      if (opponentRoomId.isNotEmpty) {
        final agoraData = await _roomRepository.getAgoraToken(opponentRoomId);
        token = agoraData['token'] as String?;
      }
    } catch (e) {
      debugPrint('[LivePartyProvider] Fetch opponent Agora token notice: $e');
    }

    final localUid = _agoraService.currentUid ?? 0;
    await _agoraService.joinOpponentPKChannel(
      opponentChannel: opponentChannel,
      localUid: localUid,
      opponentUid: opponentUid,
      token: token,
      isVideo: false,
    );
  }

  void _startPkAuthoritativeTimer() {
    _pkTimer?.cancel();
    _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_pkTimerRemaining > 0) {
        _pkTimerRemaining--;
        if (_isPkOpponentDisconnected && _pkDisconnectGrace > 0) {
          _pkDisconnectGrace--;
        }
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> respondToPkInvitation({required String invitationId, required bool accept}) async {
    try {
      await PKRepository.instance.respondInvitation(
        invitationId: invitationId,
        action: accept ? 'ACCEPT' : 'REJECT',
        targetRoomId: _activeRoom?.id,
      );
    } catch (e) {
      debugPrint('[LivePartyProvider] respondToPkInvitation error: $e');
    }
  }

  Future<void> cancelPkInvitation(String invitationId) async {
    try {
      await PKRepository.instance.cancelInvitation(invitationId);
    } catch (e) {
      debugPrint('[LivePartyProvider] cancelPkInvitation error: $e');
    }
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
      sendSystemMessage('⚔️ Rematch invitation sent!');
    } catch (e) {
      debugPrint('[LivePartyProvider] requestPkRematch error: $e');
    }
  }

  void endPk() {
    _isPkActive = false;
    _pkTimer?.cancel();
    _agoraService.leaveOpponentPKChannel();
    notifyListeners();
  }

  void startPk(UserModel opponent, {String? matchId}) {
    _pkOpponent = opponent;
    _isPkActive = true;
    _pkScoreA = 0;
    _pkScoreB = 0;
    _pkTimerRemaining = 300;
    _startPkAuthoritativeTimer();

    // Broadcast to room via socket so all room viewers see the PK match (Bug 1 & 8)
    if (_activeRoom != null) {
      final payload = {
        'id': matchId ?? 'pk_${DateTime.now().millisecondsSinceEpoch}',
        'matchId': matchId ?? 'pk_${DateTime.now().millisecondsSinceEpoch}',
        'roomId': _activeRoom!.id,
        'roomAId': _activeRoom!.id,
        'roomBId': 'room_${opponent.id}',
        'status': 'ACTIVE',
        'remainingSeconds': 300,
        'scoreA': 0,
        'scoreB': 0,
        'hostA': (_currentUser ?? _activeRoom!.host).toJson(),
        'hostB': opponent.toJson(),
        'opponent': opponent.toJson(),
      };
      _socketService.emit('pk:start', payload);
      _socketService.emit('room:pk_started', payload);
      try {
        _activePkBattle = PKBattleModel.fromJson(payload);
      } catch (_) {}
    }
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
      _roomRepository.updateRoomLayout(_activeRoom!.id, seatCapacity: capacity, roomType: roomType).catchError((err) {
        debugPrint('[LivePartyProvider] updateRoomLayout API notice: $err');
        return <String, dynamic>{};
      });
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
        _participants[idx] = p.copyWith(
          micStatus: MicStatus.muted,
          isMutedByModerator: true,
        );
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
        _participants[idx] = p.copyWith(
          micStatus: MicStatus.on,
          isMutedByModerator: false,
        );
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
        _roomRepository.updateRoomLayout(_activeRoom!.id, seatCapacity: updatedCapacity, roomType: updatedRoomType).catchError((_) => <String, dynamic>{});
      }

      // Persist to backend database via REST API (Issue 09)
      if (title != null || coverUrl != null || category != null) {
        try {
          _apiClient.put(
            '/rooms/${_activeRoom!.id}/profile',
            data: {
              'title': updatedTitle,
              'coverImageUrl': updatedCover,
              if (category != null || _activeRoom!.category.isNotEmpty) 'category': category ?? _activeRoom!.category,
              'roomType': updatedRoomType,
            },
          );
        } catch (err) {
          debugPrint('[LivePartyProvider] Room profile REST update error: $err');
        }
      }

      sendSystemMessage('✏️ Room details updated.');
      notifyListeners();
    }
  }

  /// Synchronize equipped avatar frame across party room seats (Bug 4)
  void syncUserFrame(String userId, String frame) {
    bool updated = false;
    for (int i = 0; i < _participants.length; i++) {
      if (_participants[i].user.id == userId) {
        _participants[i] = _participants[i].copyWith(
          user: _participants[i].user.copyWith(avatarFrame: frame),
        );
        updated = true;
      }
    }
    if (updated) {
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

  Future<bool> updateRoomLockSettings({required bool isLocked, String? mode, String? pin}) async {
    final roomId = _activeRoom?.id ?? _initialRoomId;
    if (roomId == null || roomId.isEmpty) return false;
    try {
      await _roomRepository.updateLockSettings(roomId, isLocked: isLocked, lockMode: mode, pin: pin);
      configureRoomLock(isLocked: isLocked, mode: mode, pin: pin);
      return true;
    } catch (e) {
      debugPrint('[LivePartyProvider] updateRoomLockSettings error: $e');
      return false;
    }
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
    final savedRole = _savedRoomRoles[_activeRoom!.id]?[userId];
    if (savedRole == ParticipantRole.moderator || savedRole == ParticipantRole.host) return true;
    final index = _participants.indexWhere((p) => p.user.id == userId);
    if (index != -1) {
      final pRole = _participants[index].role;
      return pRole == ParticipantRole.moderator || pRole == ParticipantRole.host;
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
    bool emitSocket = false,
  }) {
    final catalogGift = GiftModel.findById(giftId) ?? GiftModel.findById(giftName);
    final resolvedGiftName = catalogGift?.name ?? giftName;
    final resolvedGiftIcon = catalogGift?.icon ?? giftIcon;

    final txId = transactionId ?? DateTime.now().millisecondsSinceEpoch.toString();
    if (_processedGiftTxIds.contains(txId)) return;
    _processedGiftTxIds.add(txId);
    if (_processedGiftTxIds.length > 500) {
      _processedGiftTxIds.remove(_processedGiftTxIds.first);
    }

    final cleanIcon = (resolvedGiftIcon.startsWith('assets/') || resolvedGiftIcon.startsWith('http')) ? '🎁' : resolvedGiftIcon;

    final giftMsg = PartyMessageModel(
      id: 'gift_$txId',
      sender: sender,
      receiver: receiver,
      text: '${sender.name} sent $quantity × $resolvedGiftName $cleanIcon to ${receiver.name}',
      timestamp: DateTime.now(),
      isGiftMessage: true,
      giftId: catalogGift?.id ?? giftId ?? '',
      giftName: resolvedGiftName,
      giftIcon: resolvedGiftIcon,
      quantity: quantity,
      transactionId: txId,
      serverTimestamp: DateTime.now(),
    );
    _messages.add(giftMsg);
    if (_messages.length > 100) {
      _messages.removeAt(0);
    }

    // Synchronize Room Sending Coin Total (Item 08, 30)
    final unitPrice = (catalogGift?.priceCoins ?? 0) > 0
        ? catalogGift!.priceCoins
        : ((catalogGift?.diamondPrice ?? 0) > 0 ? catalogGift!.diamondPrice : 100);
    final coinAmount = (quantity * unitPrice);
    _roomSendingTotal += coinAmount;
    final targetRoomId = _activeRoom?.id ?? _initialRoomId ?? '';
    if (targetRoomId.isNotEmpty) {
      RoomConfigManager.instance.saveRoomSendingTotal(targetRoomId, _roomSendingTotal);
      _socketService.emitRoomSendingTotal(targetRoomId, _roomSendingTotal);
    }

    notifyListeners();

    // Broadcast room gift event to all connected devices in this room ONLY if requested
    // (REST /v1/gifts/send already broadcasts room:gift_sent server-side to avoid duplicate transactions)
    if (emitSocket && targetRoomId.isNotEmpty) {
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

  // ── Co-Host Invitation Methods (NEW-039) ──
  void sendCoHostInvite(String targetUserId) {
    if (_activeRoom == null || _currentUser == null) return;
    _socketService.sendCoHostInvite(
      roomId: _activeRoom!.id,
      targetUserId: targetUserId,
      inviter: {
        'id': _currentUser!.id,
        'name': _currentUser!.displayName,
        'avatarUrl': _currentUser!.avatarUrl,
      },
      roomTitle: _activeRoom!.title,
    );
  }

  void respondToCoHostInvitation(String hostUserId, bool accept, {String? invitationId}) {
    if (_activeRoom == null || _currentUser == null) return;
    _socketService.respondCoHostInvite(
      roomId: _activeRoom!.id,
      invitationId: invitationId ?? 'cohost_${_activeRoom!.id}_${_currentUser!.id}',
      targetUserId: _currentUser!.id,
      accepted: accept,
    );
  }

  // ── Agora RTC Music Mixing Delegation (NEW-033) ──
  Future<void> startMusicMixing(String filePath, {double volume = 0.8}) =>
      _agoraService.startAudioMixing(filePath: filePath, volume: volume);
  Future<void> pauseMusicMixing() => _agoraService.pauseAudioMixing();
  Future<void> resumeMusicMixing() => _agoraService.resumeAudioMixing();
  Future<void> stopMusicMixing() => _agoraService.stopAudioMixing();
  Future<void> setMusicMixingVolume(double volume) => _agoraService.setAudioMixingVolume(volume);
  bool get isAudioMixing => _agoraService.isAudioMixing;
  bool get isAudioMixingPaused => _agoraService.isAudioMixingPaused;
  double get audioMixingVolume => _agoraService.audioMixingVolume;

  Future<void> _syncRoomStateOnReconnect() async {
    final roomId = _activeRoom?.id;
    if (roomId == null || roomId.isEmpty) return;
    try {
      final details = await _roomRepository.getRoomDetails(roomId);
      _activeRoom = details;
      await fetchRoomMembers(roomId);
      notifyListeners();
    } catch (e) {
      debugPrint('[LivePartyProvider] Reconnect sync error: $e');
    }
  }

  @override
  void dispose() {
    leaveParty();
    if (!_incomingMicInviteController.isClosed) _incomingMicInviteController.close();
    if (!_incomingCoHostInviteController.isClosed) _incomingCoHostInviteController.close();
    if (!_roomClosedController.isClosed) _roomClosedController.close();
    if (!_kickedController.isClosed) _kickedController.close();
    if (!_pkInvitationController.isClosed) _pkInvitationController.close();
    if (!_pkResultController.isClosed) _pkResultController.close();
    _agoraService.dispose();
    super.dispose();
  }
}
