import 'dart:async';
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../models/short_video_model.dart';
import '../models/user_model.dart';
import '../core/repositories/social_repository.dart';
import '../core/services/socket_service.dart';
import '../core/services/api_client.dart';

// ─── Comment Model (for post & video comments) ────────────────────────────────

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

  factory SocialComment.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'] ?? json['author'];
    String name = '';
    String avatar = '';
    String authorId = '';
    if (rawUser is Map<String, dynamic>) {
      final profile = rawUser['profile'];
      if (profile is Map<String, dynamic>) {
        name = profile['displayName']?.toString() ?? '';
      }
      if (name.isEmpty) {
        name = rawUser['displayName']?.toString() ??
            rawUser['name']?.toString() ??
            rawUser['username']?.toString() ??
            '';
      }
      avatar = rawUser['avatarUrl']?.toString() ?? (profile is Map ? profile['avatarUrl']?.toString() ?? '' : '');
      authorId = rawUser['id']?.toString() ?? '';
    }

    if (name.isEmpty) {
      name = json['authorName']?.toString() ??
          json['authorDisplayName']?.toString() ??
          json['authorUsername']?.toString() ??
          'User';
    }
    if (avatar.isEmpty) {
      avatar = json['authorAvatar']?.toString() ?? json['avatarUrl']?.toString() ?? '';
    }
    if (authorId.isEmpty) {
      authorId = json['authorId']?.toString() ?? json['userId']?.toString() ?? '';
    }

    return SocialComment(
      id: json['id']?.toString() ?? json['commentId']?.toString() ?? '',
      authorId: authorId,
      authorName: name.isNotEmpty ? name : 'User',
      authorAvatar: avatar,
      text: json['content']?.toString() ?? json['text']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      likesCount: json['likesCount'] is int ? json['likesCount'] : (json['_count']?['likes'] ?? 0),
      isLiked: json['isLiked'] == true,
    );
  }
}

// ─── SocialProvider ───────────────────────────────────────────────────────────

class SocialProvider extends ChangeNotifier {
  final SocialRepository _repo = SocialRepository.instance;

  // Posts (feed)
  final List<PostModel> _posts = [];
  bool _feedLoading = false;
  bool _feedLoaded = false;
  String? _feedError;
  int _feedPage = 1;
  bool _feedHasMore = true;

  // Short videos (empty initial list — short video streaming backend is deferred)
  final List<ShortVideoModel> _shortVideos = [];

  // Post comments cache
  final Map<String, List<SocialComment>> _postComments = {};
  final Map<String, bool> _postCommentsLoading = {};

  // Socket subscriptions
  final List<StreamSubscription> _socketSubs = [];

  // ─── Getters ──────────────────────────────────────────────────────────────

  List<PostModel> get posts => List.unmodifiable(_posts);
  List<ShortVideoModel> get shortVideos => List.unmodifiable(_shortVideos);
  bool get feedLoading => _feedLoading;
  bool get feedLoaded => _feedLoaded;
  String? get feedError => _feedError;
  bool get feedHasMore => _feedHasMore;

  List<SocialComment> getCommentsForPost(String postId) =>
      List.unmodifiable(_postComments[postId] ?? []);

  bool isPostCommentsLoading(String postId) =>
      _postCommentsLoading[postId] == true;

  // Legacy: for short-video comments
  List<SocialComment> getCommentsForVideo(String videoId) {
    return List.unmodifiable(_postComments[videoId] ?? []);
  }

  // ─── Initialise (called once when provider is attached) ───────────────────

  SocialProvider() {
    _listenToSocketEvents();
  }

  @override
  void dispose() {
    for (final sub in _socketSubs) {
      sub.cancel();
    }
    super.dispose();
  }

  void _listenToSocketEvents() {
    final socket = SocketService.instance;

    _socketSubs.add(socket.onPostCreated.listen((data) {
      try {
        final post = PostModel.fromJson(Map<String, dynamic>.from(data));
        if (!_posts.any((p) => p.id == post.id)) {
          _posts.insert(0, post);
          notifyListeners();
        }
      } catch (_) {}
    }));

    _socketSubs.add(socket.onPostDeleted.listen((data) {
      final postId = data['postId']?.toString() ?? data['id']?.toString();
      if (postId != null) {
        _posts.removeWhere((p) => p.id == postId);
        notifyListeners();
      }
    }));

    _socketSubs.add(socket.onPostLiked.listen((data) {
      _updatePostLike(data, isLiked: true);
    }));

    _socketSubs.add(socket.onPostUnliked.listen((data) {
      _updatePostLike(data, isLiked: false);
    }));

    _socketSubs.add(socket.onCommentCreated.listen((data) {
      try {
        final postId = data['postId']?.toString();
        if (postId != null) {
          final comment = SocialComment.fromJson(Map<String, dynamic>.from(data));
          if (comment.text.trim().isEmpty) return;
          final current = _postComments[postId] ?? [];

          // Deduplicate if already present (e.g. from local optimistic insert)
          final exists = current.any((c) =>
              (comment.id.isNotEmpty && c.id == comment.id) ||
              (c.text == comment.text && c.authorId == comment.authorId && DateTime.now().difference(c.createdAt).inSeconds.abs() < 4));

          if (!exists) {
            _postComments[postId] = [comment, ...current];
            // Increment comment count on post
            final idx = _posts.indexWhere((p) => p.id == postId);
            if (idx != -1) {
              _posts[idx] = _posts[idx].copyWith(comments: _posts[idx].comments + 1);
            }
            notifyListeners();
          }
        }
      } catch (_) {}
    }));

    _socketSubs.add(socket.onCommentDeleted.listen((data) {
      final commentId = data['commentId']?.toString() ?? data['id']?.toString();
      final postId = data['postId']?.toString();
      if (commentId != null && postId != null) {
        final current = _postComments[postId];
        if (current != null) {
          _postComments[postId] = current.where((c) => c.id != commentId).toList();
        }
        final idx = _posts.indexWhere((p) => p.id == postId);
        if (idx != -1 && _posts[idx].comments > 0) {
          _posts[idx] = _posts[idx].copyWith(comments: _posts[idx].comments - 1);
        }
        notifyListeners();
      }
    }));
  }

  void _updatePostLike(Map<String, dynamic> data, {required bool isLiked}) {
    final postId = data['postId']?.toString() ?? data['id']?.toString();
    final rawLikesCount = data['likesCount'];
    if (postId == null) return;
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      final newCount = rawLikesCount is int
          ? rawLikesCount
          : (rawLikesCount != null
              ? int.tryParse(rawLikesCount.toString()) ?? (_posts[idx].likes + (isLiked ? 1 : -1))
              : (_posts[idx].likes + (isLiked ? 1 : -1))).clamp(0, 999999999);
      _posts[idx] = _posts[idx].copyWith(likes: newCount);
      notifyListeners();
    }
  }

  // ─── Feed Loading ─────────────────────────────────────────────────────────

  Future<void> loadFeed({bool refresh = false}) async {
    if (_feedLoading) return;
    if (refresh) {
      _feedPage = 1;
      _feedHasMore = true;
      _feedError = null;
    } else if (!_feedHasMore) {
      return;
    }

    _feedLoading = true;
    if (refresh) _posts.clear();
    notifyListeners();

    try {
      final result = await _repo.fetchFeed(page: _feedPage, limit: 20);
      final List<dynamic> rawPosts = result['data'] ?? [];
      final posts = rawPosts
          .whereType<Map<String, dynamic>>()
          .map(PostModel.fromJson)
          .toList();

      if (refresh) {
        _posts.clear();
      }
      _posts.addAll(posts);
      _feedPage++;
      _feedHasMore = posts.length == 20;
      _feedLoaded = true;
      _feedError = null;
    } on ApiException catch (e) {
      _feedError = e.message;
    } catch (e) {
      _feedError = 'Failed to load feed. Please try again.';
    } finally {
      _feedLoading = false;
      notifyListeners();
    }
  }

  // ─── Like / Unlike (optimistic + backend reconcile) ───────────────────────

  // ─── Like / Unlike (optimistic + backend reconcile) ───────────────────────

  Future<void> toggleLikePost(String postId) async {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final post = _posts[idx];
    final wasLiked = post.isLiked;

    // Optimistic update
    _posts[idx] = post.copyWith(
      isLiked: !wasLiked,
      likes: wasLiked
          ? (post.likes > 0 ? post.likes - 1 : 0)
          : post.likes + 1,
    );
    notifyListeners();

    try {
      final result = wasLiked
          ? await _repo.unlikePost(postId)
          : await _repo.likePost(postId);
      final serverCount = result['data']?['likesCount'];
      if (serverCount != null && idx < _posts.length) {
        _posts[idx] = _posts[idx].copyWith(
          likes: serverCount is int ? serverCount : int.tryParse(serverCount.toString()) ?? _posts[idx].likes,
        );
        notifyListeners();
      }
    } catch (_) {
      // Retain optimistic like status even if network/unauth error occurs
    }
  }

  // ─── Create Post ──────────────────────────────────────────────────────────

  Future<PostModel?> createPost({
    required String content,
    List<String>? mediaUrls,
    String visibility = 'PUBLIC',
  }) async {
    try {
      final result = await _repo.createPost(
        content: content,
        mediaUrls: mediaUrls,
        visibility: visibility,
      );
      final raw = result['data'];
      if (raw is Map<String, dynamic>) {
        final post = PostModel.fromJson(raw);
        _posts.insert(0, post);
        notifyListeners();
        return post;
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      rethrow;
    }
    return null;
  }

  /// Insert or update a post locally (for instant UI feedback when uploading stories or shorts)
  void addPostLocally(PostModel post) {
    _posts.removeWhere((p) => p.id == post.id);
    _posts.insert(0, post);
    notifyListeners();
  }

  // ─── Delete Post ──────────────────────────────────────────────────────────

  Future<void> deletePost(String postId) async {
    await _repo.deletePost(postId);
    _posts.removeWhere((p) => p.id == postId);
    notifyListeners();
  }

  // ─── Comments ─────────────────────────────────────────────────────────────

  Future<void> loadCommentsForPost(String postId, {bool refresh = false}) async {
    if (_postCommentsLoading[postId] == true) return;
    if (!refresh && _postComments.containsKey(postId) && _postComments[postId]!.isNotEmpty) return;

    _postCommentsLoading[postId] = true;
    notifyListeners();

    try {
      final result = await _repo.fetchComments(postId);
      final List<dynamic> rawComments = result['data'] ?? [];
      final fetched = rawComments
          .whereType<Map<String, dynamic>>()
          .map(SocialComment.fromJson)
          .toList();

      final existing = _postComments[postId] ?? [];
      final set = <String>{};
      final combined = <SocialComment>[];

      for (final c in existing) {
        if (set.add(c.id)) combined.add(c);
      }
      for (final c in fetched) {
        if (set.add(c.id)) combined.add(c);
      }
      _postComments[postId] = combined;
    } catch (_) {
      _postComments.putIfAbsent(postId, () => []);
    } finally {
      _postCommentsLoading[postId] = false;
      notifyListeners();
    }
  }

  Future<SocialComment> addCommentToPost(String postId, String text, UserModel author) async {
    final localComment = SocialComment(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      authorId: author.id,
      authorName: author.displayName.isNotEmpty
          ? author.displayName
          : (author.name.isNotEmpty ? author.name : author.username),
      authorAvatar: author.avatarUrl,
      text: text,
      createdAt: DateTime.now(),
      likesCount: 0,
      isLiked: false,
    );

    // Optimistically insert locally into provider cache
    final current = _postComments[postId] ?? [];
    _postComments[postId] = [localComment, ...current];

    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      _posts[idx] = _posts[idx].copyWith(comments: _posts[idx].comments + 1);
    }
    notifyListeners();

    // Async sync with backend
    try {
      final result = await _repo.createComment(postId: postId, content: text);
      final raw = result['data'];
      if (raw is Map<String, dynamic>) {
        final serverComment = SocialComment.fromJson(raw);
        final list = _postComments[postId];
        if (list != null) {
          final cIdx = list.indexWhere((c) => c.id == localComment.id);
          if (cIdx != -1) {
            list[cIdx] = serverComment;
            notifyListeners();
          }
        }
      }
    } catch (_) {
      // Preserve localComment on network/backend error
    }

    return localComment;
  }

  // Legacy: short video comment method preserved for compatibility
  void addCommentToShortVideo(String videoId, String text, UserModel author) {
    if (_postComments[videoId] == null) {
      _postComments[videoId] = [];
    }
    _postComments[videoId]!.insert(
      0,
      SocialComment(
        id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
        authorName: author.name,
        authorAvatar: author.avatarUrl,
        text: text,
        createdAt: DateTime.now(),
      ),
    );

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

  // ─── Short Videos (local — deferred) ─────────────────────────────────────

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

  void addShortVideo(ShortVideoModel video) {
    _shortVideos.insert(0, video);
    notifyListeners();
  }

  // Legacy: addPost is now a no-op — use createPost() instead
  @Deprecated('Use createPost() which calls the backend')
  void addPost(String content, List<String> imageUrls, UserModel author) {
    // No-op: callers should migrate to createPost()
    debugPrint('[SocialProvider] addPost() is deprecated; use createPost() instead');
  }
}
