import 'user_model.dart';

class PostModel {
  final String id;
  final UserModel author;
  final String content;
  final List<String> imageUrls; // mediaUrls from backend
  final int likes;              // likesCount from backend
  final int comments;           // commentsCount from backend
  final int shares;
  final bool isLiked;           // server-derived for viewer
  final DateTime createdAt;
  final String visibility;

  const PostModel({
    required this.id,
    required this.author,
    required this.content,
    required this.imageUrls,
    required this.likes,
    required this.comments,
    this.shares = 0,
    this.isLiked = false,
    required this.createdAt,
    this.visibility = 'PUBLIC',
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    // Backend may return mediaUrls or imageUrls
    List<String> media = [];
    final rawMedia = json['mediaUrls'] ?? json['imageUrls'];
    if (rawMedia is List) {
      media = rawMedia.map((e) => e.toString()).toList();
    }

    // Author can be nested as `user` or `author`
    final rawAuthor = json['user'] ?? json['author'];
    UserModel author;
    if (rawAuthor is Map<String, dynamic>) {
      author = UserModel.fromJson(rawAuthor);
    } else {
      author = const UserModel(
        id: '',
        username: 'unknown',
        name: 'Unknown User',
        avatarUrl: '',
        profileCompleted: false,
      );
    }

    return PostModel(
      id: json['id']?.toString() ?? '',
      author: author,
      content: json['content']?.toString() ?? '',
      imageUrls: media,
      likes: _parseInt(json['likesCount'] ?? json['likes']),
      comments: _parseInt(json['commentsCount'] ?? json['comments']),
      shares: _parseInt(json['shares']),
      isLiked: json['isLiked'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      visibility: json['visibility']?.toString() ?? 'PUBLIC',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'mediaUrls': imageUrls,
        'visibility': visibility,
        'likesCount': likes,
        'commentsCount': comments,
        'shares': shares,
        'isLiked': isLiked,
        'createdAt': createdAt.toIso8601String(),
      };

  PostModel copyWith({
    String? id,
    UserModel? author,
    String? content,
    List<String>? imageUrls,
    int? likes,
    int? comments,
    int? shares,
    bool? isLiked,
    DateTime? createdAt,
    String? visibility,
  }) {
    return PostModel(
      id: id ?? this.id,
      author: author ?? this.author,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
      visibility: visibility ?? this.visibility,
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}
