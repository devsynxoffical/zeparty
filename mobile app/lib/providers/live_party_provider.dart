import 'dart:async';
import 'package:flutter/material.dart';
import '../core/services/agora_rtc_service.dart';
import '../core/repositories/local_party_repository.dart';
import '../models/live_room_model.dart';
import '../models/party_participant_model.dart';
import '../models/party_message_model.dart';
import '../models/user_model.dart';

class LivePartyProvider extends ChangeNotifier {
  final AgoraRtcService _agoraService = AgoraRtcService();
  final LocalPartyRepository _repository = LocalPartyRepository.instance;

  LiveRoomModel? _activeRoom;
  LiveRoomModel? get activeRoom => _activeRoom;

  List<PartyParticipantModel> _participants = [];
  List<PartyParticipantModel> get participants => _participants;

  List<PartyMessageModel> _messages = [];
  List<PartyMessageModel> get messages => _messages;

  StreamSubscription? _participantsSub;
  StreamSubscription? _messagesSub;
  StreamSubscription? _speakerSub;

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

  // Effects Settings Toggles (Reference 4)
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

  void sendGlobalFlyingMessage(String text, UserModel sender) {
    final flyingMsg = PartyMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: sender,
      text: '🚀 [GLOBAL FLYING MESSAGE]: $text',
      timestamp: DateTime.now(),
    );
    _repository.sendMessage(flyingMsg);
    notifyListeners();
  }

  Future<void> initialize() async {
    await _agoraService.initialize();
  }

  Future<void> joinParty(LiveRoomModel room, UserModel currentUser) async {
    _activeRoom = room;

    _participantsSub = _repository.participantsStream.listen((data) {
      _participants = List.from(data);
      notifyListeners();
    });

    _messagesSub = _repository.messagesStream.listen((data) {
      _messages = List.from(data);
      notifyListeners();
    });

    _repository.joinRoom(room, PartyParticipantModel(
      user: currentUser,
      role: room.host.id == currentUser.id ? ParticipantRole.host : ParticipantRole.listener,
      joinedAt: DateTime.now(),
    ));

    _speakerSub = _agoraService.activeSpeakerStream.listen((uid) {
      _repository.setActiveSpeaker(uid, true);
      Future.delayed(const Duration(seconds: 1), () {
        _repository.setActiveSpeaker(uid, false);
      });
    });

    // Join RTC
    await _agoraService.joinChannel("mock_token", room.id, 0, isHost: room.host.id == currentUser.id);
    notifyListeners();
  }

  Future<void> leaveParty() async {
    await _agoraService.leaveChannel();
    _repository.leaveRoom();
    
    _participantsSub?.cancel();
    _messagesSub?.cancel();
    _speakerSub?.cancel();
    _pkTimer?.cancel();
    
    _activeRoom = null;
    _isPkActive = false;
    _participants = [];
    _messages = [];
    notifyListeners();
  }

  bool _isSpeakerMuted = false;
  bool get isSpeakerMuted => _isSpeakerMuted;

  final Set<int> _lockedSeatIndices = {};
  Set<int> get lockedSeatIndices => _lockedSeatIndices;

  void updateRoomDetails({
    String? title,
    String? coverUrl,
    String? announcement,
    String? category,
    String? nobleTitle,
  }) {
    if (_activeRoom != null) {
      _activeRoom = _activeRoom!.copyWith(
        title: title,
        coverUrl: coverUrl,
        announcement: announcement,
        category: category,
        nobleTitle: nobleTitle,
      );
      if (nobleTitle != null) {
        sendSystemMessage('👑 Host activated Noble Title "$nobleTitle" for room!');
      }
      notifyListeners();
    }
  }

  void updateRoomTypeAndCapacity(String roomType, int seatCapacity) {
    if (_activeRoom != null) {
      _activeRoom = _activeRoom!.copyWith(
        roomType: roomType,
        seatCapacity: seatCapacity,
      );
      sendSystemMessage('Host updated room type to "$roomType" with $seatCapacity seats layout.');
      notifyListeners();
    }
  }

  void toggleSpeakerOutput() {
    _isSpeakerMuted = !_isSpeakerMuted;
    notifyListeners();
  }

  void toggleSeatLock(int seatIndex) {
    if (_lockedSeatIndices.contains(seatIndex)) {
      _lockedSeatIndices.remove(seatIndex);
    } else {
      _lockedSeatIndices.add(seatIndex);
      // If someone is on that seat and not host, kick them to audience
      final onSeat = _participants.where((p) => p.seatNumber == seatIndex && p.role != ParticipantRole.host).firstOrNull;
      if (onSeat != null) {
        kickFromSeat(onSeat.user.id);
      }
    }
    notifyListeners();
  }

  bool isSeatLocked(int seatIndex) => _lockedSeatIndices.contains(seatIndex);

  void sendSystemMessage(String text) {
    _repository.sendMessage(PartyMessageModel(
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
  }

  void sendMessage(UserModel sender, String text) {
    _repository.sendMessage(PartyMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: sender,
      text: text,
      timestamp: DateTime.now(),
    ));
  }

  /// Module 05: Send Server-Confirmed Gift Activity Message with Receiver & Transaction Deduplication
  void sendGiftActivityMessage({
    required UserModel sender,
    required UserModel receiver,
    required String giftId,
    required String giftName,
    required String giftIcon,
    required int quantity,
    required String transactionId,
  }) {
    // Transaction ID Deduplication: Protect against double tap, socket reconnect, API retries
    if (_processedGiftTxIds.contains(transactionId)) {
      return;
    }
    _processedGiftTxIds.add(transactionId);

    final giftMsg = PartyMessageModel(
      id: 'msg_gift_$transactionId',
      sender: sender,
      receiver: receiver,
      text: '${sender.name} sent $quantity × $giftName $giftIcon to ${receiver.name}',
      timestamp: DateTime.now(),
      isGiftMessage: true,
      giftId: giftId,
      giftName: giftName,
      giftIcon: giftIcon,
      quantity: quantity,
      transactionId: transactionId,
      serverTimestamp: DateTime.now(),
    );

    _messages.add(giftMsg);
    _repository.sendMessage(giftMsg);
    notifyListeners();
  }

  // ── Module 06: Room Lock Access Control ──
  void configureRoomLock({
    required bool isLocked,
    String mode = 'PIN',
    String pin = '1234',
  }) {
    _isRoomLocked = isLocked;
    _roomLockMode = mode;
    _roomPinCode = pin;
    sendSystemMessage(
      isLocked
          ? '🔒 Room locked by Host ($mode Mode active).'
          : '🔓 Room unlocked by Host.',
    );
    notifyListeners();
  }

  bool validateRoomPin(String pin) {
    return _roomPinCode == pin;
  }

  void requestJoinRoom(UserModel user) {
    if (_pendingJoinRequests.any((r) => r['userId'] == user.id)) return;
    _pendingJoinRequests.add({
      'userId': user.id,
      'userName': user.name,
      'userAvatar': user.avatarUrl,
    });
    sendSystemMessage('🔑 ${user.name} requested permission to join room.');
    notifyListeners();
  }

  void handleJoinRequest(String userId, bool approve) {
    _pendingJoinRequests.removeWhere((r) => r['userId'] == userId);
    sendSystemMessage(approve ? '✅ Join request approved for user.' : '❌ Join request rejected.');
    notifyListeners();
  }

  // ── Module 06: YouTube Shared Player Sync ──
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

  // ── Module 06: Server-Controlled Super Wheel ──
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

    // Server side deterministic index based on timestamp & sessionId
    final winningIdx = (sessionId.hashCode.abs() + DateTime.now().millisecondsSinceEpoch) % prizes.length;
    final prize = prizes[winningIdx];

    _lastSuperWheelResult = {
      'sessionId': sessionId,
      'userId': userId,
      'prize': prize,
      'timestamp': DateTime.now().toIso8601String(),
    };

    sendSystemMessage('🎰 Super Wheel spun! User won: ${prize['name']}!');
    _isSuperWheelActive = false;
    notifyListeners();
    return _lastSuperWheelResult!;
  }

  // ── Module 06: Server-Controlled Lucky Bag ──
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

    // Duplicate claim check per user
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

  void takeSeat(UserModel user, int seatIndex) {
    takeMicSeat(seatIndex, user);
  }

  // ── Module 07: Atomic Room Mic Seat Management ──
  String? takeMicSeat(int seatIndex, UserModel actor) {
    if (isSeatLocked(seatIndex)) {
      return 'Mic ${seatIndex + 1} is locked.';
    }

    // Atomic Move: Safely release previous seat if actor occupies another mic
    final previousPart = _participants.where((p) => p.user.id == actor.id && p.seatNumber != null).firstOrNull;
    if (previousPart != null && previousPart.seatNumber != seatIndex) {
      _repository.kickFromSeat(actor.id);
    }

    _repository.requestSeat(PartyParticipantModel(
      user: actor,
      role: ParticipantRole.speaker,
      joinedAt: DateTime.now(),
    ), seatIndex);

    final existingIdx = _participants.indexWhere((p) => p.user.id == actor.id);
    if (existingIdx != -1) {
      _participants[existingIdx] = _participants[existingIdx].copyWith(
        seatNumber: seatIndex,
        role: ParticipantRole.speaker,
      );
    } else {
      _participants.add(PartyParticipantModel(
        user: actor,
        role: ParticipantRole.speaker,
        seatNumber: seatIndex,
        joinedAt: DateTime.now(),
      ));
    }

    _logMicAudit(
      seatIndex: seatIndex,
      actorId: actor.id,
      actorRole: _getRoleString(actor.id),
      targetId: actor.id,
      action: 'TAKE_MIC',
      previousState: previousPart != null ? 'Mic ${previousPart.seatNumber! + 1}' : 'Audience',
      newState: 'Mic ${seatIndex + 1}',
    );

    sendSystemMessage('🎙️ ${actor.name} took Mic ${seatIndex + 1}.');
    notifyListeners();
    return null;
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

  void lockMicSeat(int seatIndex, bool lock, {required UserModel actor}) {
    if (lock) {
      if (!_lockedSeatIndices.contains(seatIndex)) {
        _lockedSeatIndices.add(seatIndex);
        // Kick current occupant if not host
        final onSeat = _participants.where((p) => p.seatNumber == seatIndex && p.role != ParticipantRole.host).firstOrNull;
        if (onSeat != null) kickFromSeat(onSeat.user.id);
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

    final occupant = _participants.where((p) => p.seatNumber == seatIndex).firstOrNull;
    if (occupant != null) {
      _repository.updateMicStatus(occupant.user.id, mute ? MicStatus.muted : MicStatus.on);
    }

    _logMicAudit(
      seatIndex: seatIndex,
      actorId: actor.id,
      actorRole: _getRoleString(actor.id),
      targetId: occupant?.user.id,
      action: mute ? 'MUTE_MIC' : 'UNMUTE_MIC',
      previousState: mute ? 'Active' : 'Muted',
      newState: mute ? 'Muted' : 'Active',
    );

    sendSystemMessage(mute ? '🔇 Mic ${seatIndex + 1} muted.' : '🔊 Mic ${seatIndex + 1} unmuted.');
    notifyListeners();
  }

  void clearMicSeat(int seatIndex, {required UserModel actor}) {
    final occupant = _participants.where((p) => p.seatNumber == seatIndex).firstOrNull;
    if (occupant != null) {
      _repository.kickFromSeat(occupant.user.id);

      final existingIdx = _participants.indexWhere((p) => p.user.id == occupant.user.id);
      if (existingIdx != -1) {
        _participants[existingIdx] = _participants[existingIdx].copyWith(
          seatNumber: null,
          role: ParticipantRole.listener,
          micStatus: MicStatus.muted,
        );
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
    if (_activeRoom?.host.id == userId) return 'Host';
    final p = _participants.where((pt) => pt.user.id == userId).firstOrNull;
    if (p?.role == ParticipantRole.moderator) return 'Admin';
    return 'User';
  }

  // ── Module 08: Mic Reaction Anchoring & Rate Limiting ──
  bool sendMicReaction({
    required String reactionAsset,
    required String category,
    required UserModel sender,
  }) {
    // 1. Resolve sender's occupied mic seat
    final occupant = _participants.where((p) => p.user.id == sender.id && p.seatNumber != null).firstOrNull;
    if (occupant == null || occupant.seatNumber == null) {
      return false; // User not seated on mic
    }

    // 2. Throttle rapid spams (Rate limit: max 1 reaction per 1.5 seconds)
    final lastTime = _lastUserReactionTimestamp[sender.id];
    if (lastTime != null && DateTime.now().difference(lastTime).inMilliseconds < 1500) {
      return false; // Throttled
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

    // Auto-disappear after configured duration (2-3s)
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

  void muteLocalMic(bool muted) {
    _agoraService.muteLocalAudio(muted);
    // In a real app, match the current user ID
    if (_participants.isNotEmpty) {
      _repository.updateMicStatus(_participants.first.user.id, muted ? MicStatus.muted : MicStatus.on);
    }
  }

  // ── Host Management Controls ─────────────────────────────────────────────────

  /// Host/moderator can remotely mute a participant
  void muteParticipant(String userId) {
    _repository.updateMicStatus(userId, MicStatus.muted);
  }

  /// Host/moderator can unmute a participant (they still have to accept mic)
  void unmuteParticipant(String userId) {
    _repository.updateMicStatus(userId, MicStatus.on);
  }

  /// Host removes a participant from the room entirely
  void removeParticipant(String userId) {
    _repository.removeParticipant(userId);
  }

  /// Host promotes a listener to moderator
  void promoteToModerator(String userId) {
    _repository.promoteToModerator(userId);
  }

  /// Host demotes a moderator to listener
  void demoteModerator(String userId) {
    _repository.demoteModerator(userId);
  }

  /// Host removes a speaker from their seat back to audience
  void kickFromSeat(String userId) {
    _repository.kickFromSeat(userId);
  }

  // PK Logic
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

  @override
  void dispose() {
    leaveParty();
    _agoraService.dispose();
    super.dispose();
  }
}
