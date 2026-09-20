import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Standard Normalized API Exception for Mobile App
class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final dynamic details;

  ApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.details,
  });

  @override
  String toString() => 'ApiException [$code] ($statusCode): $message';
}

/// Production-Ready Mobile API Client
/// Responsible strictly for HTTP concerns, secure JWT tokens, and token refresh.
class ApiClient {
  static final ApiClient instance = ApiClient._internal();
  late final Dio dio;
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  static const String _tokenKey = 'zeparty_access_token';
  static const String _refreshTokenKey = 'zeparty_refresh_token';

  // Default Base URL points to active backend
  String _baseUrl = 'http://192.168.18.113:8080/api';

  Completer<String?>? _refreshCompleter;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 35),
        receiveTimeout: const Duration(seconds: 35),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  void initialize({required String baseUrl}) {
    _baseUrl = baseUrl;
    dio.options.baseUrl = baseUrl;
  }

  /// Returns the current server base URL (strips /api suffix for socket connections)
  static String get baseUrl {
    final url = instance._baseUrl;
    // Socket.IO connects to the root server URL, not the /api sub-path
    if (url.endsWith('/api')) {
      return url.substring(0, url.length - 4);
    }
    return url;
  }

  void _setupInterceptors() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Attach Access Token if available
          final token = await getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // Handle 401 Unauthorized for Token Refresh
          if (error.response?.statusCode == 401) {
            // Avoid refresh loop if the failed request was the refresh endpoint itself
            final requestPath = error.requestOptions.path;
            if (requestPath.contains('/auth/refresh') || requestPath.contains('/auth/login')) {
              await clearTokens();
              return handler.reject(error);
            }

            try {
              final newAccessToken = await _performTokenRefresh();
              if (newAccessToken != null) {
                // Retry the original request with the new access token
                final options = error.requestOptions;
                options.headers['Authorization'] = 'Bearer $newAccessToken';
                final response = await dio.fetch(options);
                return handler.resolve(response);
              }
            } catch (refreshErr) {
              await clearTokens();
              return handler.reject(error);
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  /// Concurrency-safe token refresh mechanism
  Future<String?> _performTokenRefresh() async {
    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      final currentRefreshToken = await getRefreshToken();
      if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
        _refreshCompleter!.complete(null);
        return null;
      }

      // Use a clean Dio instance to avoid interceptor recursion
      final cleanDio = Dio(BaseOptions(baseUrl: dio.options.baseUrl));
      final response = await cleanDio.post(
        '/v1/auth/refresh',
        data: {'refreshToken': currentRefreshToken},
      );

      if (response.statusCode == 200 && response.data?['success'] == true) {
        final data = response.data['data'];
        final newAccessToken = data['accessToken'] as String?;
        final newRefreshToken = data['refreshToken'] as String?;

        if (newAccessToken != null) {
          await saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken ?? currentRefreshToken,
          );
          _refreshCompleter!.complete(newAccessToken);
          return newAccessToken;
        }
      }

      _refreshCompleter!.complete(null);
      return null;
    } catch (e) {
      _refreshCompleter!.complete(null);
      return null;
    }
  }

  /// Public token refresh accessor for realtime services and sockets
  Future<String?> refreshToken() => _performTokenRefresh();

  // ---- Token Storage Helpers with Dual Secure & SharedPreferences Persistence ----

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    try {
      await secureStorage.write(key: _tokenKey, value: accessToken);
      await secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, accessToken);
      await prefs.setString(_refreshTokenKey, refreshToken);
    } catch (_) {}
  }

  Future<String?> getAccessToken() async {
    try {
      final secure = await secureStorage.read(key: _tokenKey);
      if (secure != null && secure.isNotEmpty) return secure;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (_) {}
    return null;
  }

  Future<String?> getRefreshToken() async {
    try {
      final secure = await secureStorage.read(key: _refreshTokenKey);
      if (secure != null && secure.isNotEmpty) return secure;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_refreshTokenKey);
    } catch (_) {}
    return null;
  }

  Future<void> clearTokens() async {
    try {
      await secureStorage.delete(key: _tokenKey);
      await secureStorage.delete(key: _refreshTokenKey);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshTokenKey);
    } catch (_) {}
  }

  // ---- Generic HTTP Methods with Clean Error Normalization ----

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.get<T>(path, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _normalizeError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.post<T>(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _normalizeError(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.put<T>(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _normalizeError(e);
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.patch<T>(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _normalizeError(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.delete<T>(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _normalizeError(e);
    }
  }

  ApiException _normalizeError(DioException error) {
    final response = error.response;
    if (response != null) {
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final msg = data['message'] ?? data['error']?['message'] ?? error.message ?? 'Unknown API error';
        final code = data['error']?['code']?.toString() ?? 'HTTP_${response.statusCode}';
        return ApiException(
          message: msg.toString(),
          code: code,
          statusCode: response.statusCode,
          details: data['error']?['details'],
        );
      }
      return ApiException(
        message: 'Server returned HTTP ${response.statusCode}: ${response.statusMessage ?? error.message}',
        code: 'HTTP_${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    return ApiException(
      message: error.message ?? 'Network connection error: cannot reach ${dio.options.baseUrl}',
      code: 'NETWORK_ERROR',
      statusCode: response?.statusCode,
    );
  }
}
