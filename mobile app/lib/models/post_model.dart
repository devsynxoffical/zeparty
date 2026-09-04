import 'user_model.dart';

class PostModel {
  final String id;
  final UserModel author;
  final String content;
  final List<String> imageUrls;
  final int likes;
  final int comments;
  final int shares;
  final bool isLiked;
  final DateTime createdAt;

  const PostModel({
    required this.id,
    required this.author,
    required this.content,
    required this.imageUrls,
    required this.likes,
    required this.comments,
    required this.shares,
    this.isLiked = false,
    required this.createdAt,
  });
}
