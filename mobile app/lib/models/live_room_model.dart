import 'user_model.dart';

class LiveRoomModel {
  final String id;
  final String title;
  final UserModel host;
  final String coverUrl;
  final int viewerCount;
  final String category; // Live, Music, Gaming, Chat, PK
  final bool isPrivate;
  final String announcement;
  final DateTime startTime;
  final String roomType; // Voice Room, Video Room
  final int seatCapacity; // 10, 15, 20, 30
  final String nobleTitle; // Emperor, Duke, Marquis, Earl, Viscount, Knight, SVIP Royalty

  const LiveRoomModel({
    required this.id,
    required this.title,
    required this.host,
    required this.coverUrl,
    required this.viewerCount,
    required this.category,
    this.isPrivate = false,
    this.announcement = 'Welcome to the stream! Enjoy the vibe & stay positive! 🎉',
    required this.startTime,
    this.roomType = 'Voice Room',
    this.seatCapacity = 10,
    this.nobleTitle = 'SVIP Royalty',
  });

  LiveRoomModel copyWith({
    String? id,
    String? title,
    UserModel? host,
    String? coverUrl,
    int? viewerCount,
    String? category,
    bool? isPrivate,
    String? announcement,
    DateTime? startTime,
    String? roomType,
    int? seatCapacity,
    String? nobleTitle,
  }) {
    return LiveRoomModel(
      id: id ?? this.id,
      title: title ?? this.title,
      host: host ?? this.host,
      coverUrl: coverUrl ?? this.coverUrl,
      viewerCount: viewerCount ?? this.viewerCount,
      category: category ?? this.category,
      isPrivate: isPrivate ?? this.isPrivate,
      announcement: announcement ?? this.announcement,
      startTime: startTime ?? this.startTime,
      roomType: roomType ?? this.roomType,
      seatCapacity: seatCapacity ?? this.seatCapacity,
      nobleTitle: nobleTitle ?? this.nobleTitle,
    );
  }
}
