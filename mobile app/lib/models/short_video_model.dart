import 'user_model.dart';

class ShortVideoModel {
  final String id;
  final UserModel creator;
  final String videoUrl;
  final String caption;
  final String musicTitle;
  final int likes;
  final int comments;
  final int gifts;
  final bool isLiked;

  const ShortVideoModel({
    required this.id,
    required this.creator,
    required this.videoUrl,
    required this.caption,
    required this.musicTitle,
    required this.likes,
    required this.comments,
    required this.gifts,
    this.isLiked = false,
  });

  ShortVideoModel copyWith({
    String? id,
    UserModel? creator,
    String? videoUrl,
    String? caption,
    String? musicTitle,
    int? likes,
    int? comments,
    int? gifts,
    bool? isLiked,
  }) {
    return ShortVideoModel(
      id: id ?? this.id,
      creator: creator ?? this.creator,
      videoUrl: videoUrl ?? this.videoUrl,
      caption: caption ?? this.caption,
      musicTitle: musicTitle ?? this.musicTitle,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      gifts: gifts ?? this.gifts,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

