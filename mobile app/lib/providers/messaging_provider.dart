import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../core/constants/dummy_data.dart';

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
    this.unreadCount = 1,
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
  final Map<String, List<MessageModel>> _chatThreads = {
    'user_1002': [
      MessageModel(
        id: 'm1',
        senderId: 'user_1002',
        receiverId: 'user_1001',
        text: 'Hey Danial! Will you be streaming tonight?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        isRead: false,
      ),
      MessageModel(
        id: 'm2',
        senderId: 'user_1001',
        receiverId: 'user_1002',
        text: 'Yes! Starting live stream around 8 PM EST! 🎙️',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        isRead: true,
      ),
    ],
    'user_1003': [
      MessageModel(
        id: 'm3',
        senderId: 'user_1003',
        receiverId: 'user_1001',
        text: 'GG on that PK match earlier! Let’s rematches tomorrow!',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: false,
      ),
    ],
  };

  final Map<String, ConversationThreadMeta> _threadMeta = {
    'user_1002': ConversationThreadMeta(userId: 'user_1002', unreadCount: 1),
    'user_1003': ConversationThreadMeta(userId: 'user_1003', unreadCount: 1),
  };

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

  // Getters
  List<UserModel> get chatUsers => List.unmodifiable(DummyData.popularUsers);
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

  /// Combined total unread count combining System Messages, Activity Rewards, Activity Helper & Direct Messages
  int get totalCombinedUnreadCount {
    return systemUnreadCount + rewardsUnreadCount + helperUnreadCount + directUnreadCount;
  }

  ConversationThreadMeta getMetaForUser(String userId) {
    return _threadMeta.putIfAbsent(userId, () => ConversationThreadMeta(userId: userId, unreadCount: 0));
  }

  List<MessageModel> getMessagesForUser(String userId, {int limit = 30}) {
    final list = _chatThreads[userId] ?? [];
    if (list.length <= limit) return List.unmodifiable(list);
    return List.unmodifiable(list.sublist(list.length - limit));
  }

  void sendMessage(String receiverId, String text, {String type = 'text', String? mediaUrl}) {
    if (text.trim().isEmpty && (mediaUrl == null || mediaUrl.isEmpty)) return;

    if (!_chatThreads.containsKey(receiverId)) {
      _chatThreads[receiverId] = [];
    }
    _chatThreads[receiverId]!.add(
      MessageModel(
        id: 'm_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'user_1001',
        receiverId: receiverId,
        text: text,
        type: type,
        mediaUrl: mediaUrl,
        timestamp: DateTime.now(),
        isRead: true,
      ),
    );
    notifyListeners();
  }

  // Conversation Actions
  void togglePin(String userId) {
    final meta = getMetaForUser(userId);
    meta.isPinned = !meta.isPinned;
    notifyListeners();
  }

  void toggleMute(String userId) {
    final meta = getMetaForUser(userId);
    meta.isMuted = !meta.isMuted;
    notifyListeners();
  }

  void toggleArchive(String userId) {
    final meta = getMetaForUser(userId);
    meta.isArchived = !meta.isArchived;
    notifyListeners();
  }

  void toggleBlock(String userId) {
    final meta = getMetaForUser(userId);
    meta.isBlocked = !meta.isBlocked;
    notifyListeners();
  }

  void markThreadAsRead(String userId) {
    final meta = getMetaForUser(userId);
    meta.unreadCount = 0;
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
    }
    notifyListeners();
  }

  void markAllRewardsRead() {
    for (var r in _activityRewards) {
      r.isRead = true;
    }
    notifyListeners();
  }

  void markAllHelpersRead() {
    for (var h in _activityHelpers) {
      h.isRead = true;
    }
    notifyListeners();
  }

  bool claimActivityReward(String rewardId) {
    final index = _activityRewards.indexWhere((r) => r.id == rewardId);
    if (index != -1) {
      final reward = _activityRewards[index];
      if (reward.status == 'Claimable') {
        reward.status = 'Claimed';
        reward.isRead = true;
        notifyListeners();
        return true;
      }
    }
    return false;
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
}

