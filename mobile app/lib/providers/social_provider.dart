import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../models/short_video_model.dart';
import '../models/user_model.dart';
import '../core/constants/dummy_data.dart';

class SocialComment {
  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String text;
  final DateTime createdAt;
  final int likesCount;
  final bool isLiked;

  SocialComment({
    required this.id,
    this.authorId = '',
    required this.authorName,
    required this.authorAvatar,
    required this.text,
    required this.createdAt,
    this.likesCount = 0,
    this.isLiked = false,
  });

  String get authorAvatarUrl => authorAvatar;
}

class SocialProvider extends ChangeNotifier {
  final List<PostModel> _posts = List.from(DummyData.posts);
  final List<ShortVideoModel> _shortVideos = List.from(DummyData.shortVideos);
  final Map<String, List<SocialComment>> _videoComments = {};

  List<PostModel> get posts => List.unmodifiable(_posts);
  List<ShortVideoModel> get shortVideos => List.unmodifiable(_shortVideos);

  List<SocialComment> getCommentsForVideo(String videoId) {
    return List.unmodifiable(_videoComments[videoId] ?? []);
  }

  void toggleLikePost(String postId) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _posts[index];
      final newIsLiked = !post.isLiked;
      final newLikes = newIsLiked ? post.likes + 1 : post.likes - 1;
      _posts[index] = PostModel(
        id: post.id,
        author: post.author,
        content: post.content,
        imageUrls: post.imageUrls,
        likes: newLikes,
        comments: post.comments,
        shares: post.shares,
        isLiked: newIsLiked,
        createdAt: post.createdAt,
      );
      notifyListeners();
    }
  }

  void toggleLikeShortVideo(String videoId) {
    final index = _shortVideos.indexWhere((v) => v.id == videoId);
    if (index != -1) {
      final video = _shortVideos[index];
      final newIsLiked = !video.isLiked;
      final newLikes = newIsLiked ? video.likes + 1 : video.likes - 1;
      _shortVideos[index] = ShortVideoModel(
        id: video.id,
        creator: video.creator,
        videoUrl: video.videoUrl,
        caption: video.caption,
        musicTitle: video.musicTitle,
        likes: newLikes,
        comments: video.comments,
        gifts: video.gifts,
        isLiked: newIsLiked,
      );
      notifyListeners();
    }
  }

  void addCommentToShortVideo(String videoId, String text, UserModel author) {
    if (_videoComments[videoId] == null) {
      _videoComments[videoId] = [];
    }
    _videoComments[videoId]!.insert(
      0,
      SocialComment(
        id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
        authorName: author.name,
        authorAvatar: author.avatarUrl,
        text: text,
        createdAt: DateTime.now(),
      ),
    );

    // Update comment count on model
    final index = _shortVideos.indexWhere((v) => v.id == videoId);
    if (index != -1) {
      final video = _shortVideos[index];
      _shortVideos[index] = ShortVideoModel(
        id: video.id,
        creator: video.creator,
        videoUrl: video.videoUrl,
        caption: video.caption,
        musicTitle: video.musicTitle,
        likes: video.likes,
        comments: video.comments + 1,
        gifts: video.gifts,
        isLiked: video.isLiked,
      );
    }
    notifyListeners();
  }

  void addPost(String content, List<String> imageUrls, UserModel author) {
    _posts.insert(
      0,
      PostModel(
        id: 'post_${DateTime.now().millisecondsSinceEpoch}',
        author: author,
        content: content,
        imageUrls: imageUrls,
        likes: 0,
        comments: 0,
        shares: 0,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void addShortVideo(ShortVideoModel video) {
    _shortVideos.insert(0, video);
    notifyListeners();
  }
}
