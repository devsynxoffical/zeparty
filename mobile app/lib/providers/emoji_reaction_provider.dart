import 'dart:async';
import 'package:flutter/material.dart';
import '../models/emoji_reaction_model.dart';
import '../core/services/socket_service.dart';

class EmojiReactionProvider extends ChangeNotifier {
  final SocketService _socketService = SocketService.instance;

  String? _activeRoomId;
  String? get activeRoomId => _activeRoomId;

  final List<EmojiReactionModel> _activeReactions = [];
  List<EmojiReactionModel> get activeReactions => List.unmodifiable(_activeReactions);

  final StreamController<EmojiReactionModel> _reactionStreamController =
      StreamController<EmojiReactionModel>.broadcast();
  Stream<EmojiReactionModel> get reactionStream => _reactionStreamController.stream;

  StreamSubscription<Map<String, dynamic>>? _socketEmojiSub;

  final Set<String> _processedReactionIds = {};
  final Map<String, DateTime> _lastUserReactionTimestamp = {};
  final Map<String, GlobalKey> _anchorKeys = {};

  static const int maxReactionsPerUser = 5;
  static const int maxTotalActiveReactions = 20;

  void setActiveRoom(String roomId) {
    if (_activeRoomId != roomId) {
      _activeRoomId = roomId;
      _activeReactions.clear();
      _processedReactionIds.clear();
      _lastUserReactionTimestamp.clear();
      _setupSocketSubscription();
      notifyListeners();
    }
  }

  void clearRoom() {
    _activeRoomId = null;
    _activeReactions.clear();
    _processedReactionIds.clear();
    _lastUserReactionTimestamp.clear();
    _socketEmojiSub?.cancel();
    _socketEmojiSub = null;
    notifyListeners();
  }

  void _setupSocketSubscription() {
    _socketEmojiSub?.cancel();
    _socketEmojiSub = _socketService.onRoomEmoji.listen((data) {
      final roomId = data['roomId']?.toString() ?? '';
      if (_activeRoomId != null && roomId.isNotEmpty && roomId != _activeRoomId) return;

      // Parse and receive the incoming remote emoji reaction
      try {
        final senderId = (data['sender'] is Map ? (data['sender'] as Map)['id'] : data['senderId'])?.toString() ?? '';
        final senderName = (data['sender'] is Map ? (data['sender'] as Map)['displayName'] : data['senderName'])?.toString();
        final emoji = data['emoji']?.toString() ?? '';
        final reactionId = data['id']?.toString() ?? 'remote_${DateTime.now().millisecondsSinceEpoch}';
        final targetUserId = data['targetUserId']?.toString();

        if (emoji.isEmpty || senderId.isEmpty) return;

        final reaction = EmojiReactionModel(
          reactionId: reactionId,
          roomId: roomId.isNotEmpty ? roomId : (_activeRoomId ?? ''),
          senderId: senderId,
          targetUserId: targetUserId ?? senderId,
          emoji: emoji,
          timestamp: DateTime.now(),
          senderName: senderName,
        );
        receiveReaction(reaction);
      } catch (e) {
        debugPrint('[EmojiReactionProvider] Socket emoji parse error: $e');
      }
    });
  }

  void registerAnchor(String keyId, GlobalKey key) {
    _anchorKeys[keyId] = key;
  }

  void unregisterAnchor(String keyId) {
    _anchorKeys.remove(keyId);
  }

  GlobalKey? getAnchorKey(String keyId) => _anchorKeys[keyId];

  Offset? getAnchorPosition(String keyId, {Offset? overlayOrigin}) {
    final key = _anchorKeys[keyId];
    if (key == null || key.currentContext == null) return null;

    final renderBox = key.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return null;

    final globalPos = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final centerPos = Offset(globalPos.dx + size.width / 2, globalPos.dy + size.height / 4);

    if (overlayOrigin != null) {
      return centerPos - overlayOrigin;
    }
    return centerPos;
  }

  bool sendReaction({
    required String roomId,
    required String senderId,
    String? targetUserId,
    required String emoji,
    int? seatId,
    String? senderName,
  }) {
    if (emoji.trim().isEmpty || senderId.trim().isEmpty) return false;
    if (_activeRoomId != null && _activeRoomId != roomId) return false;

    // Rate Limiting: Minimum 250ms interval per user
    final now = DateTime.now();
    final lastTime = _lastUserReactionTimestamp[senderId];
    if (lastTime != null && now.difference(lastTime).inMilliseconds < 250) {
      return false; // Throttled rapid spam
    }

    final userActiveCount = _activeReactions.where((r) => r.senderId == senderId).length;
    if (userActiveCount >= maxReactionsPerUser) {
      final oldestIndex = _activeReactions.indexWhere((r) => r.senderId == senderId);
      if (oldestIndex != -1) {
        _activeReactions.removeAt(oldestIndex);
      }
    }

    if (_activeReactions.length >= maxTotalActiveReactions) {
      _activeReactions.removeAt(0);
    }

    _lastUserReactionTimestamp[senderId] = now;

    final reactionId = 'react_${now.millisecondsSinceEpoch}_${senderId.hashCode.abs()}_${_activeReactions.length}';
    final reaction = EmojiReactionModel(
      reactionId: reactionId,
      roomId: roomId,
      senderId: senderId,
      targetUserId: targetUserId ?? senderId,
      emoji: emoji,
      timestamp: now,
      seatId: seatId,
      senderName: senderName,
    );

    // Broadcast to other room participants via socket BEFORE adding locally
    // (the backend will echo it back via room:emoji, which receiveReaction deduplicates)
    _socketService.sendRoomEmoji(
      roomId: roomId,
      emoji: emoji,
      targetUserId: targetUserId,
    );

    return receiveReaction(reaction);
  }

  bool receiveReaction(EmojiReactionModel reaction) {
    if (reaction.emoji.trim().isEmpty || reaction.senderId.trim().isEmpty) return false;

    if (_activeRoomId != null && reaction.roomId != _activeRoomId) {
      return false;
    }

    if (_processedReactionIds.contains(reaction.reactionId)) {
      return false;
    }

    _processedReactionIds.add(reaction.reactionId);
    if (_processedReactionIds.length > 300) {
      _processedReactionIds.remove(_processedReactionIds.first);
    }

    _activeReactions.add(reaction);
    _reactionStreamController.add(reaction);
    notifyListeners();
    return true;
  }

  List<EmojiReactionModel> getReactionsForUser(String userId) {
    if (userId.isEmpty) return const [];
    return _activeReactions.where((r) => r.targetUserId == userId || r.senderId == userId).toList();
  }

  EmojiReactionModel? getLatestReactionForUser(String userId) {
    final userReactions = getReactionsForUser(userId);
    if (userReactions.isEmpty) return null;
    return userReactions.last;
  }

  void removeReaction(String reactionId) {
    final initialLength = _activeReactions.length;
    _activeReactions.removeWhere((r) => r.reactionId == reactionId);
    if (_activeReactions.length != initialLength) {
      notifyListeners();
    }
  }

  void clearReactions() {
    _activeReactions.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _socketEmojiSub?.cancel();
    _reactionStreamController.close();
    super.dispose();
  }
}
