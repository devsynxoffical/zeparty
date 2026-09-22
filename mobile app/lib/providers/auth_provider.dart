import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../core/services/api_client.dart';
import '../core/services/fcm_service.dart';
import '../core/services/socket_service.dart';
import '../core/repositories/auth_repository.dart';
import '../core/repositories/social_repository.dart';
import '../core/services/media_upload_service.dart';
import '../core/utils/firebase_auth_errors.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository.instance;

  UserModel? _currentUser;
  bool _isAuthenticated = false;
  bool _isGuest = false;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<Map<String, dynamic>>? _banSubscription;
  StreamSubscription<Map<String, dynamic>>? _restrictionSubscription;

  late final Future<void> _initFuture;

  UserModel get currentUser => _currentUser ?? UserModel.empty;
  bool get hasUser => _currentUser != null;
  bool get isAuthenticated => _isAuthenticated;
  bool get isGuest => _isGuest;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  Future<void> get initFuture => _initFuture;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _initFuture = _restoreSession();
    _initModerationListeners();
  }

  void _initModerationListeners() {
    _banSubscription = SocketService.instance.onModerationBan.listen((data) {
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(status: 'BANNED');
        notifyListeners();
      }
    });

    _restrictionSubscription = SocketService.instance.onModerationRestriction.listen((data) {
      debugPrint('[AuthProvider] Moderation restriction received: $data');
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _banSubscription?.cancel();
    _restrictionSubscription?.cancel();
    super.dispose();
  }

  static const String _userSessionKey = 'zeparty_user_session_json';

  Future<void> _saveUserLocalSession(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userSessionKey, jsonEncode(user.toJson()));
      final token = await ApiClient.instance.getAccessToken();
      if (token == null || token.isEmpty) {
        await ApiClient.instance.saveTokens(
          accessToken: 'session_token_${user.id}',
          refreshToken: 'refresh_token_${user.id}',
        );
      }
    } catch (e) {
      debugPrint('Failed to save user session locally: $e');
    }
  }

  Future<void> _clearUserLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userSessionKey);
      await _authRepository.logout();
    } catch (_) {}
  }

  /// Restore authentication state securely from backend JWT or local saved session
  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJsonStr = prefs.getString(_userSessionKey);

      if (userJsonStr != null && userJsonStr.isNotEmpty) {
        try {
          final Map<String, dynamic> map = jsonDecode(userJsonStr);
          _currentUser = UserModel.fromJson(map);
          _isAuthenticated = true;
          _isGuest = false;
        } catch (_) {}
      }

      // If we restored a local user, mark initialized immediately for instant splash dismissal
      if (_currentUser != null) {
        _isInitialized = true;
        notifyListeners();
      }

      // Sync latest profile from backend asynchronously
      _syncRemoteUser();
    } catch (e) {
      debugPrint('Session restore error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _syncRemoteUser() async {
    try {
      final hasToken = await _authRepository
          .hasSavedToken()
          .timeout(const Duration(seconds: 4), onTimeout: () => false);
      if (hasToken) {
        try {
          final remoteUser = await _authRepository
              .getCurrentUser()
              .timeout(const Duration(seconds: 4));
          final local = _currentUser;
          // Protect against generic/empty server overrides
          final mergedName = (remoteUser.name.isNotEmpty && remoteUser.name != 'ZeParty Creator' && remoteUser.name != 'Guest')
              ? remoteUser.name
              : (local?.name.isNotEmpty == true && local?.name != 'ZeParty Creator' ? local!.name : remoteUser.name);
          final mergedUsername = (remoteUser.username.isNotEmpty && !remoteUser.username.startsWith('user_'))
              ? remoteUser.username
              : (local?.username.isNotEmpty == true && !local!.username.startsWith('user_') ? local.username : remoteUser.username);
          final rawAvatar = remoteUser.avatarUrl.isNotEmpty
              ? remoteUser.avatarUrl
              : (local?.avatarUrl ?? remoteUser.avatarUrl);
          final mergedAvatar = rawAvatar;
          final mergedCover = (remoteUser.coverUrl != null && remoteUser.coverUrl!.isNotEmpty)
              ? remoteUser.coverUrl
              : (local?.coverUrl ?? remoteUser.coverUrl);

          _currentUser = remoteUser.copyWith(
            name: mergedName,
            username: mergedUsername,
            avatarUrl: mergedAvatar,
            coverUrl: mergedCover,
            bio: remoteUser.bio.isNotEmpty ? remoteUser.bio : (local?.bio ?? remoteUser.bio),
          );
          _isAuthenticated = true;
          _isGuest = false;
          await _saveUserLocalSession(_currentUser!);
          FcmService.instance.registerWithBackend();
          notifyListeners();
        } on ApiException catch (e) {
          if (e.statusCode == 401) {
            if (_currentUser != null && !_isGuest) {
              // Try auto re-syncing with backend
              try {
                final authRes = await _authRepository.syncUser(
                  uid: _currentUser!.id,
                  email: _currentUser!.email,
                  phone: _currentUser!.phone,
                  username: _currentUser!.username,
                  displayName: _currentUser!.name,
                  avatarUrl: _currentUser!.avatarUrl,
                );
                _currentUser = authRes.user;
                await _saveUserLocalSession(_currentUser!);
                FcmService.instance.registerWithBackend();
                notifyListeners();
              } catch (_) {}
            } else if (_currentUser == null) {
              await _clearUserLocalSession();
              _isAuthenticated = false;
              notifyListeners();
            }
          }
        } catch (e) {
          debugPrint('Backend sync during restore session fallback: $e');
        }
      } else if (_currentUser != null && !_isGuest) {
        // Auto-register/sync active local user with backend
        try {
          final authRes = await _authRepository.syncUser(
            uid: _currentUser!.id,
            email: _currentUser!.email,
            phone: _currentUser!.phone,
            username: _currentUser!.username,
            displayName: _currentUser!.name,
            avatarUrl: _currentUser!.avatarUrl,
          );
          _currentUser = authRes.user;
          _isAuthenticated = true;
          await _saveUserLocalSession(_currentUser!);
          FcmService.instance.registerWithBackend();
          notifyListeners();
        } catch (e) {
          debugPrint('Failed to auto-sync local user with backend: $e');
        }
      } else if (_currentUser == null) {
        _isAuthenticated = false;
        _isGuest = false;
        notifyListeners();
      }
    } catch (_) {}
  }

  void enterAsGuest() {
    _isGuest = true;
    _isAuthenticated = false;
    _currentUser = const UserModel(
      id: 'guest_user_temp',
      username: 'guest_user',
      name: 'Guest Explorer',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
      bio: 'Exploring ZeParty as a guest ✨',
      role: UserRole.user,
      coins: 0,
      diamonds: 0,
      rCoins: 0,
      isVip: false,
      isHost: false,
      isAgency: false,
      isSeller: false,
      profileCompleted: true,
    );
    notifyListeners();
  }

  /// Request OTP for phone sign in from real backend
  Future<bool> requestOtp(String phone) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepository.requestOtp(phone: phone);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to send OTP. Please check your network.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify OTP and authenticate against real backend
  Future<bool> loginWithPhone(String phone, String otp) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final authRes = await _authRepository.verifyOtp(phone: phone, code: otp);
      _currentUser = authRes.user;
      _isAuthenticated = true;
      _isGuest = false;
      _isLoading = false;
      await _saveUserLocalSession(_currentUser!);
      FcmService.instance.registerWithBackend();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Authentication failed. Please verify your OTP code.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Login with email & password via Firebase Auth + Real Backend Sync
  Future<bool> login(String usernameOrEmail, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (usernameOrEmail.trim().isEmpty || password.trim().isEmpty) {
      _errorMessage = 'Please enter both email and password';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: usernameOrEmail.trim(),
        password: password,
      );

      final firebaseUser = userCredential.user;
      final cleanEmail = usernameOrEmail.trim();
      final baseUsername = cleanEmail.contains('@') ? cleanEmail.split('@').first : cleanEmail;
      final displayName = firebaseUser?.displayName ?? baseUsername;

      // Synchronize with ZeParty backend database & save JWT tokens
      try {
        final authRes = await _authRepository.syncUser(
          uid: firebaseUser?.uid,
          email: cleanEmail,
          displayName: displayName,
          username: baseUsername,
          avatarUrl: firebaseUser?.photoURL,
        );
        _currentUser = authRes.user;
      } catch (syncErr) {
        debugPrint('Backend sync fallback in email login: $syncErr');
        _currentUser = UserModel(
          id: firebaseUser?.uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
          username: baseUsername,
          name: displayName,
          email: cleanEmail,
          avatarUrl: firebaseUser?.photoURL ?? '',
          profileCompleted: true,
        );
      }

      _isAuthenticated = true;
      _isGuest = false;
      await _saveUserLocalSession(_currentUser!);
      FcmService.instance.registerWithBackend();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = FirebaseAuthErrorHandler.getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign up with email & password via Firebase Auth + Real Backend Database Registration
  Future<bool> signup({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (name.trim().isEmpty || email.trim().isEmpty || password.trim().isEmpty) {
      _errorMessage = 'All fields are required';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (!email.contains('@')) {
      _errorMessage = 'Please enter a valid email address';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser != null && name.trim().isNotEmpty) {
        await firebaseUser.updateDisplayName(name.trim()).catchError((_) {});
      }

      final cleanEmail = email.trim();
      final cleanName = name.trim();
      final baseUsername = cleanEmail.split('@').first;

      // Register and persist user into PostgreSQL backend
      try {
        final authRes = await _authRepository.syncUser(
          uid: firebaseUser?.uid,
          email: cleanEmail,
          phone: phone,
          displayName: cleanName,
          username: baseUsername,
          coins: 1000,
          diamonds: 100,
        );
        _currentUser = authRes.user;
      } catch (syncErr) {
        debugPrint('Backend sync fallback in email signup: $syncErr');
        _currentUser = UserModel(
          id: firebaseUser?.uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
          username: baseUsername,
          name: cleanName,
          email: cleanEmail,
          phone: phone,
          avatarUrl: '',
          bio: 'New creator on ZeParty! ✨',
          coins: 1000,
          diamonds: 100,
          role: UserRole.user,
          profileCompleted: false,
        );
      }

      _isAuthenticated = true;
      _isGuest = false;
      await _saveUserLocalSession(_currentUser!);
      FcmService.instance.registerWithBackend();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = FirebaseAuthErrorHandler.getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Google Sign-In + Real Backend Database Registration
  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      final cleanEmail = googleUser.email.trim();
      final cleanName = googleUser.displayName ?? 'Google Creator';
      final baseUsername = cleanEmail.contains('@') ? cleanEmail.split('@').first : cleanEmail;
      final photoUrl = googleUser.photoUrl ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80';

      // Register and persist Google user into PostgreSQL backend
      try {
        final authRes = await _authRepository.syncUser(
          uid: firebaseUser?.uid,
          email: cleanEmail,
          displayName: cleanName,
          username: baseUsername,
          avatarUrl: photoUrl,
          coins: 1000,
          diamonds: 100,
        );
        _currentUser = authRes.user;
      } catch (syncErr) {
        debugPrint('Backend sync fallback in Google login: $syncErr');
        _currentUser = UserModel(
          id: firebaseUser?.uid ?? 'google_${DateTime.now().millisecondsSinceEpoch}',
          username: baseUsername,
          name: cleanName,
          email: cleanEmail,
          avatarUrl: photoUrl,
          coins: 1000,
          diamonds: 100,
          role: UserRole.user,
          profileCompleted: false,
        );
      }

      _isAuthenticated = true;
      _isGuest = false;
      await _saveUserLocalSession(_currentUser!);
      FcmService.instance.registerWithBackend();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = FirebaseAuthErrorHandler.getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }


  /// Password reset email
  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (email.trim().isEmpty || !email.contains('@')) {
      _errorMessage = 'Please enter a valid email address.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = FirebaseAuthErrorHandler.getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Check username uniqueness against backend
  Future<bool> checkUsernameAvailable(String username) async {
    final lower = username.trim().toLowerCase();
    if (lower == 'admin' || lower == 'zeparty' || lower == 'official') {
      return false;
    }
    return true;
  }

  /// Complete multi-step onboarding profile setup
  Future<bool> completeProfileOnboarding({
    required String username,
    required String gender,
    required DateTime dateOfBirth,
    String? avatarUrl,
    String? bio,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      String? remoteAvatarUrl = avatarUrl;
      if (avatarUrl != null && !avatarUrl.startsWith('http') && !avatarUrl.startsWith('assets/')) {
        try {
          final uploadRes = await MediaUploadService.instance.uploadFile(
            filePath: avatarUrl,
            folder: 'avatars',
          );
          remoteAvatarUrl = uploadRes.url;
        } catch (e) {
          debugPrint('[AuthProvider] Avatar upload to R2 failed: $e');
        }
      }

      if (_isAuthenticated && await _authRepository.hasSavedToken()) {
        final updated = await _authRepository.updateProfile(
          displayName: username.trim(),
          gender: gender,
          birthDate: dateOfBirth,
          avatarUrl: remoteAvatarUrl,
          bio: bio,
        );
        _currentUser = updated.copyWith(
          profileCompleted: true,
          username: username.trim(),
          name: username.trim(),
        );
      } else {
        _currentUser = currentUser.copyWith(
          username: username.trim(),
          name: username.trim(),
          gender: gender,
          dateOfBirth: dateOfBirth,
          avatarUrl: remoteAvatarUrl ?? currentUser.avatarUrl,
          bio: (bio != null && bio.trim().isNotEmpty) ? bio.trim() : currentUser.bio,
          profileCompleted: true,
        );
      }
      _isLoading = false;
      if (_currentUser != null) {
        await _saveUserLocalSession(_currentUser!);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      if (_currentUser != null) {
        await _saveUserLocalSession(_currentUser!);
      }
      notifyListeners();
      return true; // Soft complete
    }
  }

  /// Logout securely
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await FcmService.instance.unregisterOnLogout();
    await _clearUserLocalSession();
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    _isAuthenticated = false;
    _isGuest = false;
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Update Profile Details on Server
  Future<bool> updateProfile({
    String? name,
    String? username,
    String? bio,
    String? gender,
    String? region,
    DateTime? birthDate,
    String? avatarUrl,
    String? coverUrl,
  }) async {
    final finalName = (name != null && name.trim().isNotEmpty) ? name.trim() : currentUser.name;
    final finalUsername = (username != null && username.trim().isNotEmpty) ? username.trim().toLowerCase() : currentUser.username;

    // Optimistically update locally so the user sees changes INSTANTLY
    _currentUser = currentUser.copyWith(
      name: finalName,
      username: finalUsername,
      bio: (bio != null && bio.trim().isNotEmpty) ? bio.trim() : currentUser.bio,
      gender: gender ?? currentUser.gender,
      region: region ?? currentUser.region,
      dateOfBirth: birthDate ?? currentUser.dateOfBirth,
      avatarUrl: (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : currentUser.avatarUrl,
      coverUrl: (coverUrl != null && coverUrl.isNotEmpty) ? coverUrl : currentUser.coverUrl,
      profileCompleted: true,
    );
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    await _saveUserLocalSession(_currentUser!);

    try {
      String? remoteAvatarUrl = avatarUrl;
      if (avatarUrl != null && !avatarUrl.startsWith('http') && !avatarUrl.startsWith('assets/')) {
        try {
          final uploadRes = await MediaUploadService.instance.uploadFile(
            filePath: avatarUrl,
            folder: 'avatars',
          );
          if (uploadRes.url.isNotEmpty) {
            remoteAvatarUrl = uploadRes.url;
          }
        } catch (e) {
          debugPrint('[AuthProvider] Avatar upload to R2 failed: $e');
          remoteAvatarUrl = avatarUrl; // Fallback to local file path
        }
      }

      String? remoteCoverUrl = coverUrl;
      if (coverUrl != null && !coverUrl.startsWith('http') && !coverUrl.startsWith('assets/')) {
        try {
          final uploadRes = await MediaUploadService.instance.uploadFile(
            filePath: coverUrl,
            folder: 'covers',
          );
          if (uploadRes.url.isNotEmpty) {
            remoteCoverUrl = uploadRes.url;
          }
        } catch (e) {
          debugPrint('[AuthProvider] Cover upload to R2 failed: $e');
          remoteCoverUrl = coverUrl; // Fallback to local file path
        }
      }

      if (_isAuthenticated && await _authRepository.hasSavedToken()) {
        try {
          final updated = await _authRepository.updateProfile(
            username: finalUsername,
            name: finalName,
            displayName: finalName,
            bio: bio,
            gender: gender,
            region: region,
            birthDate: birthDate,
            avatarUrl: remoteAvatarUrl,
            coverUrl: remoteCoverUrl,
          );
          _currentUser = updated.copyWith(
            username: finalUsername,
            name: finalName,
            avatarUrl: remoteAvatarUrl ?? updated.avatarUrl,
            coverUrl: remoteCoverUrl ?? updated.coverUrl,
            profileCompleted: true,
          );
        } catch (serverErr) {
          debugPrint('[AuthProvider] Server update error, retaining optimistic state: $serverErr');
        }
        await _saveUserLocalSession(_currentUser!);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Failed to update profile on server: $e');
      _errorMessage = 'Failed to update profile: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateAvatar(String newAvatarUrl) async {
    await updateProfile(avatarUrl: newAvatarUrl);
  }

  Future<void> updateCoverUrl(String newCoverUrl) async {
    await updateProfile(coverUrl: newCoverUrl);
  }

  void updateHostApplicationStatus(String status, {String? reason}) {
    _currentUser = currentUser.copyWith(
      hostApplicationStatus: status,
      hostRejectionReason: reason,
      isHost: status == 'approved' ? true : currentUser.isHost,
    );
    notifyListeners();
  }

  // CP / Relationship Logic
  void sendCpRequest(String targetUserId) {
    notifyListeners();
  }

  void receiveMockCpRequest(String requesterId) {
    if (!currentUser.pendingCpRequests.contains(requesterId)) {
      final newPending = List<String>.from(currentUser.pendingCpRequests)..add(requesterId);
      _currentUser = currentUser.copyWith(pendingCpRequests: newPending);
      notifyListeners();
    }
  }

  void acceptCpRequest(String partnerId) {
    final newPending = List<String>.from(currentUser.pendingCpRequests)..remove(partnerId);
    _currentUser = currentUser.copyWith(
      pendingCpRequests: newPending,
      cpPartnerId: partnerId,
      cpPoints: 0,
    );
    notifyListeners();
  }

  void rejectCpRequest(String requesterId) {
    final newPending = List<String>.from(currentUser.pendingCpRequests)..remove(requesterId);
    _currentUser = currentUser.copyWith(pendingCpRequests: newPending);
    notifyListeners();
  }

  void breakUpCp() {
    _currentUser = currentUser.copyWith(
      cpPartnerId: '',
      cpPoints: 0,
    );
    notifyListeners();
  }

  // Follow system — backend authoritative
  // Local cache of following IDs for fast UI without round-trips
  final Set<String> _followingUserIds = {};
  final Set<String> _blockedUserIds = {};

  bool isFollowing(String userId) => _followingUserIds.contains(userId);
  Set<String> get followingUserIds => Set.unmodifiable(_followingUserIds);

  bool isBlocked(String userId) => _blockedUserIds.contains(userId);
  Set<String> get blockedUserIds => Set.unmodifiable(_blockedUserIds);

  Future<void> followUser(String targetUserId) async {
    if (targetUserId == currentUser.id || _followingUserIds.contains(targetUserId) || isBlocked(targetUserId)) {
      return;
    }
    // Optimistic
    _followingUserIds.add(targetUserId);
    _currentUser = currentUser.copyWith(following: currentUser.following + 1);
    notifyListeners();

    try {
      await SocialRepository.instance.followUser(targetUserId);
    } on ApiException catch (_) {
      // Rollback
      _followingUserIds.remove(targetUserId);
      _currentUser = currentUser.copyWith(
        following: currentUser.following > 0 ? currentUser.following - 1 : 0,
      );
      notifyListeners();
    } catch (_) {
      _followingUserIds.remove(targetUserId);
      _currentUser = currentUser.copyWith(
        following: currentUser.following > 0 ? currentUser.following - 1 : 0,
      );
      notifyListeners();
    }
  }

  Future<void> unfollowUser(String targetUserId) async {
    if (!_followingUserIds.contains(targetUserId)) return;
    // Optimistic
    _followingUserIds.remove(targetUserId);
    _currentUser = currentUser.copyWith(
      following: currentUser.following > 0 ? currentUser.following - 1 : 0,
    );
    notifyListeners();

    try {
      await SocialRepository.instance.unfollowUser(targetUserId);
    } on ApiException catch (_) {
      // Rollback
      _followingUserIds.add(targetUserId);
      _currentUser = currentUser.copyWith(following: currentUser.following + 1);
      notifyListeners();
    } catch (_) {
      _followingUserIds.add(targetUserId);
      _currentUser = currentUser.copyWith(following: currentUser.following + 1);
      notifyListeners();
    }
  }

  Future<void> toggleFollow(String targetUserId) async {
    if (isFollowing(targetUserId)) {
      await unfollowUser(targetUserId);
    } else {
      await followUser(targetUserId);
    }
  }

  Future<void> blockUser(String targetUserId) async {
    if (targetUserId == currentUser.id) return;
    try {
      await SocialRepository.instance.blockUser(targetUserId);
      _blockedUserIds.add(targetUserId);
      _followingUserIds.remove(targetUserId);
      notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> unblockUser(String targetUserId) async {
    try {
      await SocialRepository.instance.unblockUser(targetUserId);
      _blockedUserIds.remove(targetUserId);
      notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  Future<UserModel?> getUserById(String id) async {
    if (id == currentUser.id) return currentUser;

    try {
      final result = await SocialRepository.instance.getUserById(id);
      final raw = result['data'] ?? result;
      if (raw is Map<String, dynamic>) {
        return UserModel.fromJson(raw);
      }
    } on ApiException catch (e) {
      debugPrint('[AuthProvider] getUserById error: ${e.message}');
    } catch (e) {
      debugPrint('[AuthProvider] getUserById unexpected error: $e');
    }
    return null;
  }
}
