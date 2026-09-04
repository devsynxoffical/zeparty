import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../core/constants/dummy_data.dart';
import '../core/utils/firebase_auth_errors.dart';

class AuthProvider extends ChangeNotifier {
  static const String _authPrefKey = 'zeparty_auth_user_id';
  static const String _profileCompletePrefKey = 'zeparty_profile_completed';

  UserModel _currentUser = DummyData.currentUser;
  bool _isAuthenticated = false;
  bool _isGuest = false;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  StreamSubscription<User?>? _authStateSubscription;

  late final Future<void> _initFuture;

  UserModel get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isGuest => _isGuest;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  Future<void> get initFuture => _initFuture;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _initFuture = _restoreSession();
    _listenToAuthState();
  }

  void _listenToAuthState() {
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((User? firebaseUser) {
      if (firebaseUser != null) {
        _isAuthenticated = true;
        _isGuest = false;
        _currentUser = _currentUser.copyWith(
          id: firebaseUser.uid,
          username: firebaseUser.email != null ? firebaseUser.email!.split('@').first : 'user_${firebaseUser.uid.substring(0, 5)}',
          name: (firebaseUser.displayName != null && firebaseUser.displayName!.isNotEmpty) ? firebaseUser.displayName! : _currentUser.name,
          avatarUrl: (firebaseUser.photoURL != null && firebaseUser.photoURL!.isNotEmpty) ? firebaseUser.photoURL! : _currentUser.avatarUrl,
        );
        _saveSession(firebaseUser.uid, _currentUser.profileCompleted);
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString(_authPrefKey);
      final isCompleted = prefs.getBool(_profileCompletePrefKey) ?? true;
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser != null) {
        _isAuthenticated = true;
        _isGuest = false;
        _currentUser = DummyData.currentUser.copyWith(
          id: firebaseUser.uid,
          username: firebaseUser.email != null ? firebaseUser.email!.split('@').first : 'user_${firebaseUser.uid.substring(0, 5)}',
          name: (firebaseUser.displayName != null && firebaseUser.displayName!.isNotEmpty) ? firebaseUser.displayName! : DummyData.currentUser.name,
          avatarUrl: (firebaseUser.photoURL != null && firebaseUser.photoURL!.isNotEmpty) ? firebaseUser.photoURL! : DummyData.currentUser.avatarUrl,
          profileCompleted: isCompleted,
        );
      } else if (savedUserId != null && savedUserId.isNotEmpty) {
        _isAuthenticated = true;
        _isGuest = false;
        _currentUser = DummyData.currentUser.copyWith(
          id: savedUserId,
          profileCompleted: isCompleted,
        );
      }
    } catch (e) {
      debugPrint('Error restoring auth session: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  void enterAsGuest() {
    _isGuest = true;
    _isAuthenticated = false;
    _currentUser = const UserModel(
      id: 'guest_000',
      username: 'guest_user',
      name: 'Guest User',
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
      _isAuthenticated = true;
      _isGuest = false;
      _currentUser = DummyData.currentUser.copyWith(
        id: firebaseUser?.uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
        username: usernameOrEmail.contains('@') ? usernameOrEmail.split('@').first : usernameOrEmail,
        profileCompleted: true,
      );

      await _saveSession(_currentUser.id, true);
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
        await firebaseUser.updateDisplayName(name.trim());
      }

      _isAuthenticated = true;
      _isGuest = false;
      _currentUser = UserModel(
        id: firebaseUser?.uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
        username: email.split('@').first,
        name: name.trim(),
        avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80',
        bio: 'New creator on ZeParty! ✨',
        coins: 1000,
        diamonds: 100,
        role: UserRole.user,
        profileCompleted: false,
      );

      await _saveSession(_currentUser.id, false);
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

  Future<bool> loginWithPhone(String phone, String otp) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    if (otp.length < 4) {
      _errorMessage = 'Invalid OTP code';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _isAuthenticated = true;
    _isGuest = false;
    _currentUser = DummyData.currentUser.copyWith(name: 'Phone User');
    await _saveSession(_currentUser.id, true);
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Clear previous cached session to force fresh account picker
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        _errorMessage = null; // User cancelled, no error message
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

      _isAuthenticated = true;
      _isGuest = false;
      _currentUser = UserModel(
        id: firebaseUser?.uid ?? 'google_${DateTime.now().millisecondsSinceEpoch}',
        username: googleUser.email.contains('@') ? googleUser.email.split('@').first : googleUser.email,
        name: googleUser.displayName ?? 'Google Creator',
        avatarUrl: googleUser.photoUrl ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
        coins: 1000,
        diamonds: 100,
        role: UserRole.user,
        profileCompleted: false,
      );

      await _saveSession(_currentUser.id, false);
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
    await Future.delayed(const Duration(milliseconds: 400));
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

    await Future.delayed(const Duration(milliseconds: 500));

    _currentUser = _currentUser.copyWith(
      username: username.trim(),
      gender: gender,
      dateOfBirth: dateOfBirth,
      avatarUrl: avatarUrl ?? _currentUser.avatarUrl,
      bio: (bio != null && bio.trim().isNotEmpty) ? bio.trim() : _currentUser.bio,
      profileCompleted: true,
    );

    await _saveSession(_currentUser.id, true);
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> _saveSession(String userId, bool profileCompleted) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_authPrefKey, userId);
      await prefs.setBool(_profileCompletePrefKey, profileCompleted);
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _isGuest = true;
    _currentUser = const UserModel(
      id: 'guest_000',
      username: 'guest',
      name: 'Guest User',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
      profileCompleted: true,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authPrefKey);
      await prefs.remove(_profileCompletePrefKey);
    } catch (e) {
      debugPrint('Error clearing auth session: $e');
    }
    notifyListeners();
  }

  void updateAvatar(String newAvatarUrl) {
    _currentUser = _currentUser.copyWith(avatarUrl: newAvatarUrl);
    notifyListeners();
  }

  void updateCoverUrl(String newCoverUrl) {
    _currentUser = _currentUser.copyWith(coverUrl: newCoverUrl);
    notifyListeners();
  }

  void updateProfile({String? name, String? bio, String? gender, String? region}) {
    _currentUser = _currentUser.copyWith(
      name: name ?? _currentUser.name,
      bio: bio ?? _currentUser.bio,
      gender: gender ?? _currentUser.gender,
      region: region ?? _currentUser.region,
    );
    notifyListeners();
  }

  void updateHostApplicationStatus(String status, {String? reason}) {
    _currentUser = _currentUser.copyWith(
      hostApplicationStatus: status,
      hostRejectionReason: reason,
      isHost: status == 'approved' ? true : _currentUser.isHost,
    );
    notifyListeners();
  }

  // CP / Relationship Logic
  void sendCpRequest(String targetUserId) {
    // In a real app, this pushes a request to the backend
    notifyListeners();
  }

  void receiveMockCpRequest(String requesterId) {
    // Helper to simulate receiving a request for testing
    if (!_currentUser.pendingCpRequests.contains(requesterId)) {
      final newPending = List<String>.from(_currentUser.pendingCpRequests)..add(requesterId);
      _currentUser = _currentUser.copyWith(pendingCpRequests: newPending);
      notifyListeners();
    }
  }

  void acceptCpRequest(String partnerId) {
    final newPending = List<String>.from(_currentUser.pendingCpRequests)..remove(partnerId);
    _currentUser = _currentUser.copyWith(
      pendingCpRequests: newPending,
      cpPartnerId: partnerId,
      cpPoints: 0,
    );
    notifyListeners();
  }

  void rejectCpRequest(String requesterId) {
    final newPending = List<String>.from(_currentUser.pendingCpRequests)..remove(requesterId);
    _currentUser = _currentUser.copyWith(pendingCpRequests: newPending);
    notifyListeners();
  }

  void breakUpCp() {
    // Use empty string to represent null since copyWith doesn't handle nullification easily
    _currentUser = _currentUser.copyWith(
      cpPartnerId: '',
      cpPoints: 0,
    );
    notifyListeners();
  }

  // ─── Global Follow System ───
  final Set<String> _followingUserIds = {'user_1002', 'user_1003'};
  final Set<String> _blockedUserIds = {};

  bool isFollowing(String userId) => _followingUserIds.contains(userId);
  Set<String> get followingUserIds => Set.unmodifiable(_followingUserIds);

  bool isBlocked(String userId) => _blockedUserIds.contains(userId);
  Set<String> get blockedUserIds => Set.unmodifiable(_blockedUserIds);

  void followUser(String targetUserId) {
    if (targetUserId == _currentUser.id || _followingUserIds.contains(targetUserId) || isBlocked(targetUserId)) {
      return; // Prevent self-follow, duplicate follow, or following a blocked user
    }
    _followingUserIds.add(targetUserId);
    _currentUser = _currentUser.copyWith(following: _currentUser.following + 1);
    notifyListeners();
  }

  void unfollowUser(String targetUserId) {
    if (!_followingUserIds.contains(targetUserId)) {
      return;
    }
    _followingUserIds.remove(targetUserId);
    _currentUser = _currentUser.copyWith(
      following: _currentUser.following > 0 ? _currentUser.following - 1 : 0,
    );
    notifyListeners();
  }

  void toggleFollow(String targetUserId) {
    if (isFollowing(targetUserId)) {
      unfollowUser(targetUserId);
    } else {
      followUser(targetUserId);
    }
  }

  void blockUser(String targetUserId) {
    if (targetUserId == _currentUser.id) return;
    _blockedUserIds.add(targetUserId);
    unfollowUser(targetUserId);
    notifyListeners();
  }

  void unblockUser(String targetUserId) {
    _blockedUserIds.remove(targetUserId);
    notifyListeners();
  }

  // Fetching user by ID
  Future<UserModel?> getUserById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // If it's the current user, return current user
    if (id == _currentUser.id) {
      return _currentUser;
    }

    // Check popular users from DummyData
    final popularMatch = DummyData.popularUsers.where((u) => u.id == id);
    if (popularMatch.isNotEmpty) {
      final base = popularMatch.first;
      final isF = isFollowing(id);
      return base.copyWith(
        followers: isF ? base.followers + 1 : base.followers,
      );
    }

    // Otherwise return a mock user profile
    final isF = isFollowing(id);
    return UserModel(
      id: id,
      username: 'user_${id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}',
      name: 'Ayan Khan',
      avatarUrl: 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?auto=format&fit=crop&w=300&q=80',
      bio: 'Streamer & Creator ✨ | Let\'s connect and party!',
      role: UserRole.user,
      profileCompleted: true,
      isOnline: true,
      followers: isF ? 48901 : 48900,
      following: 320,
      coins: 45000,
      diamonds: 8500,
      isVip: true,
      region: 'Czech Republic',
    );
  }
}
