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
  final String roomType; // AUDIO_PARTY, LIVE_VIDEO, Voice Room, Video Room
  final int seatCapacity; // 8 seats standard
  final String nobleTitle;
  final String? agoraChannelName;
  final String? creatorUserId;
  final String status; // LIVE, ENDED, CLOSED_BY_ADMIN
  final bool isPinnedTop;
  final bool isMuted;
  final List<dynamic>? seats;

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
    this.roomType = 'AUDIO_PARTY',
    this.seatCapacity = 8,
    this.nobleTitle = 'SVIP Royalty',
    this.agoraChannelName,
    this.creatorUserId,
    this.status = 'LIVE',
    this.isPinnedTop = false,
    this.isMuted = false,
    this.seats,
  });

  factory LiveRoomModel.fromJson(Map<String, dynamic> json) {
    final hostData = json['creator'] is Map
        ? Map<String, dynamic>.from(json['creator'] as Map)
        : (json['host'] is Map ? Map<String, dynamic>.from(json['host'] as Map) : <String, dynamic>{});

    final hostUser = hostData.isNotEmpty
        ? UserModel.fromJson(hostData)
        : UserModel(
            id: json['creatorUserId']?.toString() ?? 'host_unknown',
            username: 'host_streamer',
            name: 'Stream Host',
            avatarUrl: json['coverImageUrl']?.toString() ??
                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
          );

    final id = json['id']?.toString() ?? '';
    final title = json['title']?.toString() ?? 'ZeParty Live';
    final coverUrl = json['coverImageUrl']?.toString() ??
        json['coverUrl']?.toString() ??
        'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=600&q=80';
    final viewerCount = int.tryParse(json['viewerCount']?.toString() ?? '') ?? 0;
    final category = json['category']?.toString() ?? 'Live';
    final roomType = json['roomType']?.toString() ?? 'AUDIO_PARTY';
    final startTime = json['createdAt'] != null
        ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
        : DateTime.now();

    return LiveRoomModel(
      id: id,
      title: title,
      host: hostUser,
      coverUrl: coverUrl,
      viewerCount: viewerCount,
      category: category,
      isPrivate: json['isPrivate'] == true,
      announcement: json['announcement']?.toString() ?? 'Welcome to the party room! 🎉',
      startTime: startTime,
      roomType: roomType,
      seatCapacity: 8,
      nobleTitle: json['nobleTitle']?.toString() ?? 'SVIP Royalty',
      agoraChannelName: json['agoraChannelName']?.toString(),
      creatorUserId: json['creatorUserId']?.toString() ?? hostUser.id,
      status: json['status']?.toString() ?? 'LIVE',
      isPinnedTop: json['isPinnedTop'] == true,
      isMuted: json['isMuted'] == true,
      seats: json['seats'] is List ? json['seats'] as List : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'coverImageUrl': coverUrl,
      'viewerCount': viewerCount,
      'category': category,
      'isPrivate': isPrivate,
      'announcement': announcement,
      'roomType': roomType,
      'seatCapacity': seatCapacity,
      'agoraChannelName': agoraChannelName,
      'creatorUserId': creatorUserId,
      'status': status,
      'isPinnedTop': isPinnedTop,
      'isMuted': isMuted,
    };
  }

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
    String? agoraChannelName,
    String? creatorUserId,
    String? status,
    bool? isPinnedTop,
    bool? isMuted,
    List<dynamic>? seats,
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
      agoraChannelName: agoraChannelName ?? this.agoraChannelName,
      creatorUserId: creatorUserId ?? this.creatorUserId,
      status: status ?? this.status,
      isPinnedTop: isPinnedTop ?? this.isPinnedTop,
      isMuted: isMuted ?? this.isMuted,
      seats: seats ?? this.seats,
    );
  }
}
