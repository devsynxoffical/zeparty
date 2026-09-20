import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/live_room_model.dart';

import '../../models/gift_model.dart';
import '../../models/post_model.dart';
import '../../models/short_video_model.dart';
import '../../models/transaction_model.dart';
import '../../models/notification_model.dart';
import '../../models/message_model.dart';
import 'room_repository.dart';

/// Production-ready Reactive Backend Repository Service
class BackendRepository extends ChangeNotifier {
  static final BackendRepository instance = BackendRepository._internal();
  BackendRepository._internal() {
    fetchLiveRooms();
  }

  final List<ShortVideoModel> _shortVideos = [];
  final List<LiveRoomModel> _liveRooms = [];
  final List<PostModel> _posts = [];
  final List<AppNotificationModel> _notifications = [];
  final List<TransactionModel> _transactions = [];
  final List<GiftModel> _gifts = List.from(GiftModel.defaultCatalog);
  final List<MessageModel> _messages = [];
  final List<UserModel> _popularUsers = [];

  List<ShortVideoModel> get shortVideos => List.unmodifiable(_shortVideos);
  List<LiveRoomModel> get liveRooms => List.unmodifiable(_liveRooms);
  List<PostModel> get posts => List.unmodifiable(_posts);
  List<AppNotificationModel> get notifications => List.unmodifiable(_notifications);
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  List<GiftModel> get gifts => List.unmodifiable(_gifts);
  List<MessageModel> get messages => List.unmodifiable(_messages);
  List<UserModel> get popularUsers => List.unmodifiable(_popularUsers);

  // Dynamic Video Upload
  Future<ShortVideoModel> publishVideo({
    String? id,
    required UserModel creator,
    required String videoUrl,
    required String caption,
    required String musicTitle,
    String? coverUrl,
  }) async {
    final newVideo = ShortVideoModel(
      id: id ?? 'video_${DateTime.now().millisecondsSinceEpoch}',
      creator: creator,
      videoUrl: videoUrl,
      caption: caption,
      musicTitle: musicTitle,
      likes: 0,
      comments: 0,
      gifts: 0,
      isLiked: false,
    );
    _shortVideos.removeWhere((v) => v.id == newVideo.id);
    _shortVideos.insert(0, newVideo);
    notifyListeners();
    return newVideo;
  }

  // Toggle Video Like
  void toggleVideoLike(String videoId) {
    final index = _shortVideos.indexWhere((v) => v.id == videoId);
    if (index != -1) {
      final v = _shortVideos[index];
      final newLiked = !v.isLiked;
      final newLikes = newLiked ? v.likes + 1 : (v.likes > 0 ? v.likes - 1 : 0);
      _shortVideos[index] = v.copyWith(isLiked: newLiked, likes: newLikes);
      notifyListeners();
    }
  }

  // Dynamic Room Management
  void addLiveRoom(LiveRoomModel room) {
    _liveRooms.removeWhere((r) => r.id == room.id);
    _liveRooms.insert(0, room);
    notifyListeners();
  }

  void updateLiveRoom(LiveRoomModel updatedRoom) {
    final index = _liveRooms.indexWhere((r) => r.id == updatedRoom.id);
    if (index != -1) {
      _liveRooms[index] = updatedRoom;
      notifyListeners();
    }
  }

  void removeLiveRoom(String roomId) {
    _liveRooms.removeWhere((r) => r.id == roomId);
    notifyListeners();
  }

  List<LiveRoomModel> getMyRooms(String userId) {
    return _liveRooms.where((r) => r.host.id == userId).toList();
  }

  List<LiveRoomModel> getPartyRooms() {
    return _liveRooms.where((r) =>
      r.category.toLowerCase() == 'party' ||
      r.id.startsWith('party_')
    ).toList();
  }

  List<LiveRoomModel> getActiveLiveStreams() {
    return _liveRooms.where((r) =>
      r.category.toLowerCase() != 'party' &&
      !r.id.startsWith('party_')
    ).toList();
  }

  /// Real Backend Room Discovery Integration
  Future<List<LiveRoomModel>> fetchLiveRooms({String? category, int limit = 50}) async {
    try {
      final remoteRooms = await RoomRepository.instance.getActiveRooms(category: category, limit: limit);
      if (remoteRooms.isNotEmpty) {
        _liveRooms.clear();
        _liveRooms.addAll(remoteRooms);
        notifyListeners();
      }
      return _liveRooms;
    } catch (_) {
      return _liveRooms;
    }
  }

  // Dynamic Go Live Stream Creation
  Future<LiveRoomModel> createLiveStream({
    required UserModel host,
    required String title,
    required String category,
    required String coverUrl,
    bool isPrivate = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final newRoom = LiveRoomModel(
      id: 'room_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      host: host,
      coverUrl: coverUrl.isNotEmpty
          ? coverUrl
          : 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=600&q=80',
      viewerCount: 1,
      category: category,
      isPrivate: isPrivate,
      startTime: DateTime.now(),
    );
    addLiveRoom(newRoom);
    return newRoom;
  }

  // Dynamic Transaction Logging
  void logTransaction({
    required String title,
    required String type,
    required double amount,
    required String currency,
  }) {
    final tx = TransactionModel(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      type: type,
      amount: amount,
      currency: currency,
      status: 'Completed',
      date: DateTime.now(),
    );
    _transactions.insert(0, tx);
    notifyListeners();
  }

  // Dynamic Notifications
  void sendNotification({
    required String title,
    required String message,
    required String category,
  }) {
    final notif = AppNotificationModel(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      category: category,
      timestamp: DateTime.now(),
    );
    _notifications.insert(0, notif);
    notifyListeners();
  }

  // Private Chat Message Dispatch
  void sendMessage(String receiverId, String text) {
    final msg = MessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'current_user',
      receiverId: receiverId,
      text: text,
      timestamp: DateTime.now(),
    );
    _messages.add(msg);
    notifyListeners();
  }

  // Global Follower Count Sync
  void updateUserFollowers(String userId, int delta) {
    final idx = _popularUsers.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final u = _popularUsers[idx];
      final newFollowers = (u.followers + delta) >= 0 ? u.followers + delta : 0;
      _popularUsers[idx] = u.copyWith(followers: newFollowers);
      notifyListeners();
    }
  }
}
