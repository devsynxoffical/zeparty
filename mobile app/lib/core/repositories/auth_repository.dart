import 'dart:io';
import '../services/api_client.dart';
import '../../models/user_model.dart';

class AuthResponse {
  final String token;
  final String refreshToken;
  final bool isNewUser;
  final UserModel user;

  AuthResponse({
    required this.token,
    required this.refreshToken,
    required this.isNewUser,
    required this.user,
  });
}

class AuthRepository {
  static final AuthRepository instance = AuthRepository._internal();
  final ApiClient _apiClient = ApiClient.instance;

  AuthRepository._internal();

  /// Request OTP for mobile authentication
  Future<Map<String, dynamic>> requestOtp({
    required String phone,
    String purpose = 'LOGIN',
  }) async {
    final response = await _apiClient.post(
      '/v1/auth/request-otp',
      data: {
        'phone': phone.replaceAll(' ', ''),
        'purpose': purpose,
      },
    );

    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }

  /// Verify OTP and obtain JWT tokens + User profile
  Future<AuthResponse> verifyOtp({
    required String phone,
    required String code,
    String purpose = 'LOGIN',
  }) async {
    final normalizedPhone = phone.replaceAll(' ', '');
    final platformName = Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'Flutter');

    final response = await _apiClient.post(
      '/v1/auth/verify-otp',
      data: {
        'phone': normalizedPhone,
        'code': code.trim(),
        'purpose': purpose,
        'device': {
          'deviceId': 'mobile_device_${normalizedPhone.hashCode}',
          'platform': platformName,
          'appVersion': '1.0.0',
        },
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    final refreshToken = data['refreshToken'] as String;
    final isNewUser = data['isNewUser'] == true;
    final userData = data['user'] as Map<String, dynamic>;

    await _apiClient.saveTokens(
      accessToken: token,
      refreshToken: refreshToken,
    );

    final user = UserModel.fromJson(userData);

    return AuthResponse(
      token: token,
      refreshToken: refreshToken,
      isNewUser: isNewUser,
      user: user,
    );
  }

  /// Fetch currently authenticated user's self profile from backend
  Future<UserModel> getCurrentUser() async {
    final response = await _apiClient.get('/v1/users/me');
    final data = response.data?['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  /// Update user's profile on backend
  Future<UserModel> updateProfile({
    String? username,
    String? name,
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? coverUrl,
    String? gender,
    String? countryCode,
    String? region,
    DateTime? birthDate,
  }) async {
    final payload = <String, dynamic>{};
    if (username != null && username.trim().isNotEmpty) payload['username'] = username.trim();
    if (name != null && name.trim().isNotEmpty) payload['displayName'] = name.trim();
    if (displayName != null && displayName.trim().isNotEmpty) payload['displayName'] = displayName.trim();
    if (bio != null) payload['bio'] = bio;
    if (avatarUrl != null) payload['avatarUrl'] = avatarUrl;
    if (coverUrl != null) payload['coverUrl'] = coverUrl;
    if (gender != null) payload['gender'] = gender;
    if (countryCode != null) payload['countryCode'] = countryCode;
    if (region != null) payload['region'] = region;
    if (birthDate != null) payload['birthDate'] = birthDate.toIso8601String();

    final response = await _apiClient.put(
      '/v1/users/profile',
      data: payload,
    );

    final data = response.data?['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  /// Perform server logout and clear local secure tokens
  Future<void> logout() async {
    try {
      await _apiClient.post('/v1/auth/logout');
    } catch (_) {
      // Best-effort logout on backend
    } finally {
      await _apiClient.clearTokens();
    }
  }

  /// Check whether an active session exists in secure storage
  Future<bool> hasSavedToken() async {
    final token = await _apiClient.getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
