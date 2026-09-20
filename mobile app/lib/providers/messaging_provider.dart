import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../core/repositories/social_repository.dart';
import '../core/services/socket_service.dart';

class SystemMessageItem {
  final String id;
  final String title;
  final String content;
  final String category; // 'Official', 'Security', 'Moderation', 'Wallet', 'Policy', 'Support'
  final DateTime timestamp;
  bool isRead;

  SystemMessageItem({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.timestamp,
    this.isRead = false,
  });
}

class ActivityRewardItem {
  final String id;
  final String title;
  final String description;
  final int rewardCoins;
  final DateTime claimDeadline;
  final String transactionRef;
  String status; // 'Claimable', 'Claimed', 'Expired'
  bool isRead;

  ActivityRewardItem({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardCoins,
    required this.claimDeadline,
    required this.transactionRef,
    this.status = 'Claimable',
    this.isRead = false,
  });
}

class ActivityHelperItem {
  final String id;
  final String title;
  final String tips;
  final String eventGuidance;
  final DateTime timestamp;
  bool isRead;

  ActivityHelperItem({
    required this.id,
    required this.title,
    required this.tips,
    required this.eventGuidance,
    required this.timestamp,
    this.isRead = false,
  });
}

class ConversationThreadMeta {
  final String userId;
  bool isPinned;
  bool isMuted;
  bool isArchived;
  bool isBlocked;
  int unreadCount;

  ConversationThreadMeta({
    required this.userId,
    this.isPinned = false,
    this.isMuted = false,
    this.isArchived = false,
    this.isBlocked = false,
    this.unreadCount = 0,
  });
}

class AdminBroadcastItem {
  final String id;
  final String targetType; // 'System Messages', 'Activity Rewards', 'Activity Helper'
  final String title;
  final String content;
  final String targetCountry;
  final String targetRole;
  final DateTime createdAt;
  int deliveryCount;
  int readCount;
  int claimCount;

  AdminBroadcastItem({
    required this.id,
    required this.targetType,
    required this.title,
    required this.content,
    required this.targetCountry,
    required this.targetRole,
    required this.createdAt,
    this.deliveryCount = 1500,
    this.readCount = 920,
    this.claimCount = 410,
  });
}

class MessagingProvider extends ChangeNotifier {
  static const String _prefsReadSystemIds = 'zeparty_read_system_ids';
  static const String _prefsReadRewardIds = 'zeparty_read_reward_ids';
  static const String _prefsClaimedRewardIds = 'zeparty_claimed_reward_ids';
  static const String _prefsReadHelperIds = 'zeparty_read_helper_ids';
  static const String _prefsPinnedUserIds = 'zeparty_pinned_chat_users';
  static const String _prefsMutedUserIds = 'zeparty_muted_chat_users';
  static const String _prefsArchivedUserIds = 'zeparty_archived_chat_users';
  static const String _prefsBlockedUserIds = 'zeparty_blocked_chat_users';

  final SocialRepository _socialRepo = SocialRepository.instance;
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  final Set<String> _readSystemIds = {};
  final Set<String> _readRewardIds = {};
  final Set<String> _claimedRewardIds = {};
  final Set<String> _readHelperIds = {};
  final Set<String> _pinnedUserIds = {};
  final Set<String> _mutedUserIds = {};
  final Set<String> _archivedUserIds = {};
  final Set<String> _blockedUserIds = {};

  List<UserModel> _chatUsers = [];
  final Map<String, List<MessageModel>> _chatThreads = {};
  final Map<String, ConversationThreadMeta> _threadMeta = {};
  bool _isLoadingConversations = false;
  bool _isLoadingMessages = false;

  final List<SystemMessageItem> _systemMessages = [
    SystemMessageItem(
      id: 'sys_1',
      title: 'ZeParty Security Notice',
      content: 'Your account login from a new device was verified successfully.',
      category: 'Security',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    SystemMessageItem(
      id: 'sys_2',
      title: 'Wallet Payout Processed',
      content: 'Host settlement payout of \$3,200 USD has been deposited to your wallet.',
      category: 'Wallet',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
  ];

  final List<ActivityRewardItem> _activityRewards = [
    ActivityRewardItem(
      id: 'rew_1',
      title: 'Weekly Voice Party Champion',
      description: 'You earned Top 3 Host Ranking reward for Week 34!',
      rewardCoins: 50000,
      claimDeadline: DateTime.now().add(const Duration(days: 3)),
      transactionRef: 'REF_REWARD_9921',
      status: 'Claimable',
    ),
  ];

  final List<ActivityHelperItem> _activityHelpers = [
    ActivityHelperItem(
      id: 'help_1',
      title: 'Super Wheel Event Guidelines',
      tips: 'Spin during Happy Hour to double your multiplier odds!',
      eventGuidance: 'Active until Sunday midnight UTC.',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  final List<AdminBroadcastItem> _adminBroadcasts = [];
  final List<String> _reportLogs = [];

  final Map<String, bool> _typingUsers = {};
  StreamSubscription<Map<String, dynamic>>? _typingSub;

  MessagingProvider() {
    _loadPersistentStates();
    _initSocketListener();
    loadConversations();
  }

  Future<void> _loadPersistentStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _readSystemIds.addAll(prefs.getStringList(_prefsReadSystemIds) ?? []);
      _readRewardIds.addAll(prefs.getStringList(_prefsReadRewardIds) ?? []);
      _claimedRewardIds.addAll(prefs.getStringList(_prefsClaimedRewardIds) ?? []);
      _readHelperIds.addAll(prefs.getStringList(_prefsReadHelperIds) ?? []);
      _pinnedUserIds.addAll(prefs.getStringList(_prefsPinnedUserIds) ?? []);
      _mutedUserIds.addAll(prefs.getStringList(_prefsMutedUserIds) ?? []);
      _archivedUserIds.addAll(prefs.getStringList(_prefsArchivedUserIds) ?? []);
      _blockedUserIds.addAll(prefs.getStringList(_prefsBlockedUserIds) ?? []);

      _applyPersistentStates();
      notifyListeners();
    } catch (_) {}
  }

  void _applyPersistentStates() {
    for (var m in _systemMessages) {
      if (_readSystemIds.contains(m.id)) {
        m.isRead = true;
      }
    }
    for (var r in _activityRewards) {
      if (_readRewardIds.contains(r.id)) {
        r.isRead = true;
      }
      if (_claimedRewardIds.contains(r.id)) {
        r.status = 'Claimed';
        r.isRead = true;
      }
    }
    for (var h in _activityHelpers) {
      if (_readHelperIds.contains(h.id)) {
        h.isRead = true;
      }
    }
    for (var userId in _pinnedUserIds) {
      getMetaForUser(userId).isPinned = true;
    }
    for (var userId in _mutedUserIds) {
      getMetaForUser(userId).isMuted = true;
    }
    for (var userId in _archivedUserIds) {
      getMetaForUser(userId).isArchived = true;
    }
    for (var userId in _blockedUserIds) {
      getMetaForUser(userId).isBlocked = true;
    }
  }

  void _initSocketListener() {
    _socketSub = SocketService.instance.onDirectMessage.listen((data) {
      _handleIncomingSocketMessage(data);
    });
    _typingSub = SocketService.instance.onChatTyping.listen((data) {
      final senderId = data['senderId']?.toString();
      final isTyping = data['isTyping'] == true;
      if (senderId != null) {
        _typingUsers[senderId] = isTyping;
        notifyListeners();
      }
    });
  }

  void _handleIncomingSocketMessage(Map<String, dynamic> data) {
    try {
      final id = data['id']?.toString() ?? 'm_${DateTime.now().millisecondsSinceEpoch}';
      final senderId = data['senderId']?.toString() ?? '';
      final recipientId = data['recipientId']?.toString() ?? '';
      final content = data['content']?.toString() ?? '';
      final createdAtRaw = data['createdAt']?.toString();
      final timestamp = createdAtRaw != null ? DateTime.tryParse(createdAtRaw) ?? DateTime.now() : DateTime.now();
      final isRead = data['isRead'] == true;

      final otherUserId = senderId;
      if (otherUserId.isEmpty) return;

      final newMsg = MessageModel(
        id: id,
        senderId: senderId,
        receiverId: recipientId,
        text: content,
        timestamp: timestamp,
        isRead: isRead,
      );

      final thread = _chatThreads.putIfAbsent(otherUserId, () => []);
      if (!thread.any((m) => m.id == id)) {
        thread.add(newMsg);
      }

      final meta = getMetaForUser(otherUserId);
      if (!isRead) {
        meta.unreadCount += 1;
      }

      // Check if user is in _chatUsers, if not add if sender info exists
      if (!_chatUsers.any((u) => u.id == otherUserId) && data['sender'] is Map) {
        final senderMap = Map<String, dynamic>.from(data['sender'] as Map);
        _chatUsers.insert(
          0,
          UserModel(
            id: otherUserId,
            username: senderMap['username']?.toString() ?? 'user_$otherUserId',
            name: senderMap['displayName']?.toString() ?? senderMap['name']?.toString() ?? 'ZeParty User',
            avatarUrl: senderMap['avatarUrl']?.toString() ?? '',
          ),
        );
      } else if (_chatUsers.any((u) => u.id == otherUserId)) {
        // Move to top
        final existing = _chatUsers.firstWhere((u) => u.id == otherUserId);
        _chatUsers.removeWhere((u) => u.id == otherUserId);
        _chatUsers.insert(0, existing);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[MessagingProvider] Error handling socket message: $e');
    }
  }

  // Getters
  List<UserModel> get chatUsers => List.unmodifiable(_chatUsers);
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingMessages => _isLoadingMessages;

  List<SystemMessageItem> get systemMessages => List.unmodifiable(_systemMessages);
  List<ActivityRewardItem> get activityRewards => List.unmodifiable(_activityRewards);
  List<ActivityHelperItem> get activityHelpers => List.unmodifiable(_activityHelpers);
  List<AdminBroadcastItem> get adminBroadcasts => List.unmodifiable(_adminBroadcasts);
  List<String> get reportLogs => List.unmodifiable(_reportLogs);

  int get systemUnreadCount => _systemMessages.where((m) => !m.isRead).length;
  int get rewardsUnreadCount => _activityRewards.where((r) => !r.isRead).length;
  int get helperUnreadCount => _activityHelpers.where((h) => !h.isRead).length;

  int get directUnreadCount {
    int sum = 0;
    for (var meta in _threadMeta.values) {
      if (!meta.isBlocked) {
        sum += meta.unreadCount;
      }
    }
    return sum;
  }

  int get totalCombinedUnreadCount {
    return systemUnreadCount + rewardsUnreadCount + helperUnreadCount + directUnreadCount;
  }

  ConversationThreadMeta getMetaForUser(String userId) {
    return _threadMeta.putIfAbsent(userId, () => ConversationThreadMeta(userId: userId, unreadCount: 0));
  }

  List<MessageModel> getMessagesForUser(String userId, {int limit = 100}) {
    final list = _chatThreads[userId] ?? [];
    if (list.length <= limit) return List.unmodifiable(list);
    return List.unmodifiable(list.sublist(list.length - limit));
  }

  /// Load conversations from backend
  Future<void> loadConversations() async {
    _isLoadingConversations = true;
    notifyListeners();

    try {
      final list = await _socialRepo.fetchConversations();
      final List<UserModel> users = [];

      for (final item in list) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final otherUserMap = map['otherUser'] is Map ? Map<String, dynamic>.from(map['otherUser'] as Map) : null;
        final otherUserId = map['otherUserId']?.toString() ?? otherUserMap?['id']?.toString() ?? '';
        if (otherUserId.isEmpty) continue;

        final userModel = UserModel(
          id: otherUserId,
          username: otherUserMap?['username']?.toString() ?? 'user_$otherUserId',
          name: otherUserMap?['displayName']?.toString() ?? otherUserMap?['name']?.toString() ?? 'ZeParty User',
          avatarUrl: otherUserMap?['avatarUrl']?.toString() ?? '',
          bio: otherUserMap?['bio']?.toString() ?? '',
          gender: otherUserMap?['gender']?.toString() ?? 'Not Specified',
        );
        users.add(userModel);

        final meta = getMetaForUser(otherUserId);
        meta.unreadCount = int.tryParse(map['unreadCount']?.toString() ?? '0') ?? 0;

        if (map['lastMessage'] is Map) {
          final lastMsgMap = Map<String, dynamic>.from(map['lastMessage'] as Map);
          final msgId = lastMsgMap['id']?.toString() ?? '';
          final text = lastMsgMap['content']?.toString() ?? '';
          final senderId = lastMsgMap['senderId']?.toString() ?? '';
          final recipientId = lastMsgMap['recipientId']?.toString() ?? '';
          final createdAtRaw = lastMsgMap['createdAt']?.toString();
          final timestamp = createdAtRaw != null ? DateTime.tryParse(createdAtRaw) ?? DateTime.now() : DateTime.now();
          final isRead = lastMsgMap['isRead'] == true;

          final msg = MessageModel(
            id: msgId,
            senderId: senderId,
            receiverId: recipientId,
            text: text,
            timestamp: timestamp,
            isRead: isRead,
          );

          final thread = _chatThreads.putIfAbsent(otherUserId, () => []);
          if (!thread.any((m) => m.id == msgId)) {
            thread.clear();
            thread.add(msg);
          }
        }
      }

      _chatUsers = users;
    } catch (e) {
      debugPrint('[MessagingProvider] Error loading conversations: $e');
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  /// Load chat history for a target user from backend
  Future<void> loadMessagesForUser(String targetUserId) async {
    _isLoadingMessages = true;
    notifyListeners();

    try {
      final res = await _socialRepo.fetchMessages(targetUserId, limit: 100);
      final rawList = res['data'] as List<dynamic>? ?? [];

      final List<MessageModel> loaded = [];
      for (final item in rawList) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final id = map['id']?.toString() ?? '';
        final senderId = map['senderId']?.toString() ?? '';
        final recipientId = map['recipientId']?.toString() ?? '';
        final text = map['content']?.toString() ?? '';
        final createdAtRaw = map['createdAt']?.toString();
        final timestamp = createdAtRaw != null ? DateTime.tryParse(createdAtRaw) ?? DateTime.now() : DateTime.now();
        final isRead = map['isRead'] == true;

        loaded.add(
          MessageModel(
            id: id,
            senderId: senderId,
            receiverId: recipientId,
            text: text,
            timestamp: timestamp,
            isRead: isRead,
          ),
        );
      }

      _chatThreads[targetUserId] = loaded;
      final meta = getMetaForUser(targetUserId);
      meta.unreadCount = 0;
    } catch (e) {
      debugPrint('[MessagingProvider] Error loading messages for user $targetUserId: $e');
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  /// Send message to target user via backend API
  Future<void> sendMessage(
    String receiverId,
    String text, {
    String type = 'text',
    String? mediaUrl,
    String? currentUserId,
  }) async {
    if (text.trim().isEmpty && (mediaUrl == null || mediaUrl.isEmpty)) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final senderId = currentUserId ?? 'current_user';

    final optimisticMsg = MessageModel(
      id: tempId,
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      type: type,
      mediaUrl: mediaUrl,
      timestamp: DateTime.now(),
      isRead: true,
    );

    if (!_chatThreads.containsKey(receiverId)) {
      _chatThreads[receiverId] = [];
    }
    _chatThreads[receiverId]!.add(optimisticMsg);

    // Update conversation order
    if (!_chatUsers.any((u) => u.id == receiverId)) {
      _chatUsers.insert(
        0,
        UserModel(
          id: receiverId,
          username: 'user_$receiverId',
          name: 'ZeParty User',
          avatarUrl: '',
        ),
      );
    } else {
      final existing = _chatUsers.firstWhere((u) => u.id == receiverId);
      _chatUsers.removeWhere((u) => u.id == receiverId);
      _chatUsers.insert(0, existing);
    }

    notifyListeners();

    try {
      final response = await _socialRepo.sendMessage(receiverId, content: text);
      final data = response['data'];
      if (data is Map) {
        final serverId = data['id']?.toString();
        if (serverId != null) {
          final index = _chatThreads[receiverId]!.indexWhere((m) => m.id == tempId);
          if (index != -1) {
            _chatThreads[receiverId]![index] = MessageModel(
              id: serverId,
              senderId: senderId,
              receiverId: receiverId,
              text: text,
              type: type,
              mediaUrl: mediaUrl,
              timestamp: DateTime.now(),
              isRead: true,
            );
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('[MessagingProvider] Error sending message to $receiverId: $e');
    }
  }

  /// Search real users from backend
  Future<List<UserModel>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final list = await _socialRepo.searchUsers(query.trim());
      return list.map((item) => UserModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    } catch (e) {
      debugPrint('[MessagingProvider] Error searching users: $e');
      return [];
    }
  }

  // Conversation Actions
  void togglePin(String userId) {
    final meta = getMetaForUser(userId);
    meta.isPinned = !meta.isPinned;
    if (meta.isPinned) {
      _pinnedUserIds.add(userId);
    } else {
      _pinnedUserIds.remove(userId);
    }
    _saveStringList(_prefsPinnedUserIds, _pinnedUserIds);
    notifyListeners();
  }

  void toggleMute(String userId) {
    final meta = getMetaForUser(userId);
    meta.isMuted = !meta.isMuted;
    if (meta.isMuted) {
      _mutedUserIds.add(userId);
    } else {
      _mutedUserIds.remove(userId);
    }
    _saveStringList(_prefsMutedUserIds, _mutedUserIds);
    notifyListeners();
  }

  void toggleArchive(String userId) {
    final meta = getMetaForUser(userId);
    meta.isArchived = !meta.isArchived;
    if (meta.isArchived) {
      _archivedUserIds.add(userId);
    } else {
      _archivedUserIds.remove(userId);
    }
    _saveStringList(_prefsArchivedUserIds, _archivedUserIds);
    notifyListeners();
  }

  void toggleBlock(String userId) {
    final meta = getMetaForUser(userId);
    meta.isBlocked = !meta.isBlocked;
    if (meta.isBlocked) {
      _blockedUserIds.add(userId);
    } else {
      _blockedUserIds.remove(userId);
    }
    _saveStringList(_prefsBlockedUserIds, _blockedUserIds);
    notifyListeners();
  }

  void markThreadAsRead(String userId) {
    final meta = getMetaForUser(userId);
    meta.unreadCount = 0;
    _socialRepo.markMessagesAsRead(userId).catchError((_) {});
    notifyListeners();
  }

  void markThreadAsUnread(String userId) {
    final meta = getMetaForUser(userId);
    meta.unreadCount = 1;
    notifyListeners();
  }

  void deleteThreadLocally(String userId) {
    _chatThreads.remove(userId);
    _threadMeta.remove(userId);
    _chatUsers.removeWhere((u) => u.id == userId);
    notifyListeners();
  }

  void reportUser(String userId, String reason, String metadata) {
    _reportLogs.add('${DateTime.now().toIso8601String()} | REPORT user: $userId | reason: $reason | meta: $metadata');
    notifyListeners();
  }

  // Top Activity Actions
  void markAllSystemMessagesRead() {
    for (var m in _systemMessages) {
      m.isRead = true;
      _readSystemIds.add(m.id);
    }
    _saveStringList(_prefsReadSystemIds, _readSystemIds);
    notifyListeners();
  }

  void markSystemMessageRead(String id) {
    for (var m in _systemMessages) {
      if (m.id == id) {
        m.isRead = true;
        _readSystemIds.add(id);
      }
    }
    _saveStringList(_prefsReadSystemIds, _readSystemIds);
    notifyListeners();
  }

  void markAllRewardsRead() {
    for (var r in _activityRewards) {
      r.isRead = true;
      _readRewardIds.add(r.id);
    }
    _saveStringList(_prefsReadRewardIds, _readRewardIds);
    notifyListeners();
  }

  void markRewardRead(String id) {
    for (var r in _activityRewards) {
      if (r.id == id) {
        r.isRead = true;
        _readRewardIds.add(id);
      }
    }
    _saveStringList(_prefsReadRewardIds, _readRewardIds);
    notifyListeners();
  }

  void markAllHelpersRead() {
    for (var h in _activityHelpers) {
      h.isRead = true;
      _readHelperIds.add(h.id);
    }
    _saveStringList(_prefsReadHelperIds, _readHelperIds);
    notifyListeners();
  }

  void markHelperRead(String id) {
    for (var h in _activityHelpers) {
      if (h.id == id) {
        h.isRead = true;
        _readHelperIds.add(id);
      }
    }
    _saveStringList(_prefsReadHelperIds, _readHelperIds);
    notifyListeners();
  }

  bool claimActivityReward(String rewardId) {
    final index = _activityRewards.indexWhere((r) => r.id == rewardId);
    if (index != -1) {
      final reward = _activityRewards[index];
      if (reward.status == 'Claimable') {
        reward.status = 'Claimed';
        reward.isRead = true;
        _claimedRewardIds.add(rewardId);
        _readRewardIds.add(rewardId);
        _saveStringList(_prefsClaimedRewardIds, _claimedRewardIds);
        _saveStringList(_prefsReadRewardIds, _readRewardIds);
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  void _saveStringList(String key, Set<String> set) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, set.toList());
    } catch (_) {}
  }

  // Admin Broadcast Composer
  void createAdminBroadcast({
    required String targetType,
    required String title,
    required String content,
    required String country,
    required String role,
  }) {
    final id = 'admin_broad_${DateTime.now().millisecondsSinceEpoch}';
    _adminBroadcasts.insert(
      0,
      AdminBroadcastItem(
        id: id,
        targetType: targetType,
        title: title,
        content: content,
        targetCountry: country,
        targetRole: role,
        createdAt: DateTime.now(),
      ),
    );

    if (targetType == 'System Messages') {
      _systemMessages.insert(
        0,
        SystemMessageItem(
          id: 'sys_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          content: content,
          category: 'Official Notice',
          timestamp: DateTime.now(),
        ),
      );
    } else if (targetType == 'Activity Rewards') {
      _activityRewards.insert(
        0,
        ActivityRewardItem(
          id: 'rew_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          description: content,
          rewardCoins: 10000,
          claimDeadline: DateTime.now().add(const Duration(days: 7)),
          transactionRef: 'ADMIN_REWARD_REF',
        ),
      );
    } else {
      _activityHelpers.insert(
        0,
        ActivityHelperItem(
          id: 'help_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          tips: content,
          eventGuidance: 'Official Platform Event Guidelines',
          timestamp: DateTime.now(),
        ),
      );
    }
    notifyListeners();
  }

  bool isUserTyping(String userId) => _typingUsers[userId] == true;

  void sendTyping(String targetUserId, bool isTyping) {
    SocketService.instance.sendTyping(targetUserId: targetUserId, isTyping: isTyping);
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _typingSub?.cancel();
    super.dispose();
  }
}
