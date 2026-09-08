import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

sealed class AuthResult {
  const AuthResult();
}

class AuthSuccess extends AuthResult {
  final String userId;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;

  const AuthSuccess({
    required this.userId,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
  });
}

class AuthFailure extends AuthResult {
  final String reason; // 'anonymous_auth_disabled', 'network_error', 'invalid_api_key', 'unauthenticated', 'auth_error'
  final String message;

  const AuthFailure({
    required this.reason,
    required this.message,
  });
}

class FirebaseAuthRestService {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  final String apiKey;

  static const _kIdToken = 'firebase_id_token';
  static const _kRefreshToken = 'firebase_refresh_token';
  static const _kUserId = 'firebase_user_id';
  static const _kTokenExpiry = 'firebase_token_expiry';
  static const _kLastSync = 'last_sync_timestamp';

  FirebaseAuthRestService({
    Dio? dio,
    FlutterSecureStorage? storage,
    this.apiKey = 'AIzaSyDemoKeyFallback',
  })  : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage();

  /// Silently sign in anonymously using Firebase Auth REST API.
  /// Returns typed [AuthSuccess] or [AuthFailure]. Never returns a fake fallback token.
  Future<AuthResult> signInAnonymously() async {
    try {
      final url =
          'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey';
      final response = await _dio.post(
        url,
        data: {'returnSecureToken': true},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        final idToken = data['idToken'] as String;
        final refreshToken = data['refreshToken'] as String;
        final localId = data['localId'] as String;
        final expiresIn = int.tryParse(data['expiresIn']?.toString() ?? '3600') ?? 3600;
        final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

        await _storage.write(key: _kIdToken, value: idToken);
        await _storage.write(key: _kRefreshToken, value: refreshToken);
        await _storage.write(key: _kUserId, value: localId);
        await _storage.write(key: _kTokenExpiry, value: expiresAt.toIso8601String());

        return AuthSuccess(
          userId: localId,
          idToken: idToken,
          refreshToken: refreshToken,
          expiresAt: expiresAt,
        );
      }

      // Handle non-200 responses from Google Identity Toolkit
      final errorData = response.data;
      String errMessage = 'Authentication failed with status ${response.statusCode}';
      String errCode = '';

      if (errorData is Map && errorData['error'] != null) {
        final err = errorData['error'];
        errMessage = err['message']?.toString() ?? errMessage;
        errCode = errMessage.toUpperCase();
      } else if (errorData is String) {
        try {
          final parsed = jsonDecode(errorData);
          if (parsed is Map && parsed['error'] != null) {
            errMessage = parsed['error']['message']?.toString() ?? errMessage;
            errCode = errMessage.toUpperCase();
          }
        } catch (_) {}
      }

      if (errCode.contains('OPERATION_NOT_ALLOWED') || errCode.contains('ADMIN_ONLY_OPERATION')) {
        return const AuthFailure(
          reason: 'anonymous_auth_disabled',
          message: 'Anonymous sign-in is disabled in Firebase Console. Enable it in Authentication > Sign-in method.',
        );
      } else if (errCode.contains('API_KEY_INVALID') || errCode.contains('API KEY NOT VALID')) {
        return const AuthFailure(
          reason: 'invalid_api_key',
          message: 'Firebase API key is invalid. Check FirebaseConfig.apiKey.',
        );
      }

      return AuthFailure(
        reason: 'auth_error',
        message: errMessage,
      );
    } on DioException catch (e) {
      debugPrint('Anonymous auth network error: $e');
      return AuthFailure(
        reason: 'network_error',
        message: 'Network error connecting to Firebase Auth: ${e.message ?? e.toString()}',
      );
    } catch (e) {
      debugPrint('Anonymous auth unexpected error: $e');
      return AuthFailure(
        reason: 'auth_error',
        message: 'Unexpected authentication error: $e',
      );
    }
  }

  /// Proactive refresh of ID Token using refresh token
  Future<AuthResult> refreshIdToken() async {
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken == null || refreshToken.isEmpty || refreshToken == 'mock_refresh_token') {
      return signInAnonymously();
    }

    try {
      final url = 'https://securetoken.googleapis.com/v1/token?key=$apiKey';
      final response = await _dio.post(
        url,
        data: 'grant_type=refresh_token&refresh_token=$refreshToken',
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        final newIdToken = data['id_token'] as String;
        final newRefreshToken = data['refresh_token'] as String;
        final userId = data['user_id'] as String? ?? await _storage.read(key: _kUserId) ?? '';
        final expiresIn = int.tryParse(data['expires_in']?.toString() ?? '3600') ?? 3600;
        final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

        await _storage.write(key: _kIdToken, value: newIdToken);
        await _storage.write(key: _kRefreshToken, value: newRefreshToken);
        await _storage.write(key: _kTokenExpiry, value: expiresAt.toIso8601String());

        return AuthSuccess(
          userId: userId,
          idToken: newIdToken,
          refreshToken: newRefreshToken,
          expiresAt: expiresAt,
        );
      }
    } catch (e) {
      debugPrint('Token refresh error: $e');
    }

    // If refresh fails, attempt fresh anonymous sign-in
    return signInAnonymously();
  }

  /// Returns current [AuthResult], proactively refreshing if within 5 mins of expiry
  Future<AuthResult> getAuthState() async {
    final storedToken = await _storage.read(key: _kIdToken);
    final storedUserId = await _storage.read(key: _kUserId);
    final expiryStr = await _storage.read(key: _kTokenExpiry);
    final refreshToken = await _storage.read(key: _kRefreshToken);

    if (storedToken == null ||
        storedToken.isEmpty ||
        storedToken == 'mock_firebase_id_token' ||
        storedUserId == null ||
        storedUserId.isEmpty ||
        expiryStr == null) {
      return signInAnonymously();
    }

    final expiry = DateTime.tryParse(expiryStr) ?? DateTime.now();
    // If within 5 minutes of expiring, refresh now
    if (DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 5)))) {
      return refreshIdToken();
    }

    return AuthSuccess(
      userId: storedUserId,
      idToken: storedToken,
      refreshToken: refreshToken ?? '',
      expiresAt: expiry,
    );
  }

  /// Returns valid, unexpired ID token if authenticated, or null if unauthenticated
  Future<String?> getValidIdToken() async {
    final state = await getAuthState();
    if (state is AuthSuccess) {
      return state.idToken;
    }
    return null;
  }

  /// Returns active Firebase User ID if authenticated, or null
  Future<String?> getUserId() async {
    final state = await getAuthState();
    if (state is AuthSuccess) {
      return state.userId;
    }
    return null;
  }

  Future<DateTime?> getLastSyncTimestamp() async {
    final str = await _storage.read(key: _kLastSync);
    if (str != null && str.isNotEmpty) {
      return DateTime.tryParse(str);
    }
    // Fresh install: return epoch 0 so first sync pulls everything
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> updateLastSyncTimestamp(DateTime time) async {
    await _storage.write(key: _kLastSync, value: time.toIso8601String());
  }

  Future<void> clearAuth() async {
    await _storage.delete(key: _kIdToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kTokenExpiry);
  }
}
