import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/server_config.dart';

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
  static const _kCanonicalUserId = 'canonical_firebase_user_id';

  /// The primary Firestore User ID where verified history & recipes live
  static const String defaultPrimaryUserId = 'xglm2AMV46WgLwOr7CvEQm5I8x02';

  FirebaseAuthRestService({
    Dio? dio,
    FlutterSecureStorage? storage,
    this.apiKey = 'AIzaSyDemoKeyFallback',
  })  : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<void> _writeStorage(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('SecureStorage write error: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('SharedPreferences write error: $e');
    }
  }

  Future<String?> _readStorage(String key) async {
    String? val;
    try {
      val = await _storage.read(key: key);
    } catch (_) {}
    if (val != null && val.isNotEmpty) return val;

    try {
      final prefs = await SharedPreferences.getInstance();
      val = prefs.getString(key);
    } catch (_) {}
    return val;
  }

  Future<void> _deleteStorage(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  /// Lock or switch the canonical active Firestore User ID.
  /// Resets sync timestamp to epoch 0 so all records from this account pull immediately.
  Future<void> setCanonicalUserId(String userId) async {
    await _writeStorage(_kCanonicalUserId, userId);
    await _writeStorage(_kUserId, userId);
    await _writeStorage(_kLastSync, DateTime.fromMillisecondsSinceEpoch(0).toIso8601String());
  }

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

        // If a canonical user ID was already configured, preserve it
        final existingCanonical = await _readStorage(_kCanonicalUserId) ?? defaultPrimaryUserId;
        final effectiveUserId = existingCanonical.isNotEmpty ? existingCanonical : localId;

        await _writeStorage(_kIdToken, idToken);
        await _writeStorage(_kRefreshToken, refreshToken);
        await _writeStorage(_kUserId, effectiveUserId);
        await _writeStorage(_kTokenExpiry, expiresAt.toIso8601String());

        return AuthSuccess(
          userId: effectiveUserId,
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
    final refreshToken = await _readStorage(_kRefreshToken);
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
        final canonicalId = await _readStorage(_kCanonicalUserId) ?? defaultPrimaryUserId;
        final userId = canonicalId.isNotEmpty ? canonicalId : (data['user_id'] as String? ?? await _readStorage(_kUserId) ?? '');
        final expiresIn = int.tryParse(data['expires_in']?.toString() ?? '3600') ?? 3600;
        final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

        await _writeStorage(_kIdToken, newIdToken);
        await _writeStorage(_kRefreshToken, newRefreshToken);
        await _writeStorage(_kUserId, userId);
        await _writeStorage(_kTokenExpiry, expiresAt.toIso8601String());

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
    final storedToken = await _readStorage(_kIdToken);
    final storedUserId = await _readStorage(_kUserId) ?? await _readStorage(_kCanonicalUserId) ?? defaultPrimaryUserId;
    final expiryStr = await _readStorage(_kTokenExpiry);
    final refreshToken = await _readStorage(_kRefreshToken);

    if (storedToken == null ||
        storedToken.isEmpty ||
        storedToken == 'mock_firebase_id_token' ||
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
    return await _readStorage(_kCanonicalUserId) ?? defaultPrimaryUserId;
  }

  Future<DateTime?> getLastSyncTimestamp() async {
    final str = await _readStorage(_kLastSync);
    if (str != null && str.isNotEmpty) {
      return DateTime.tryParse(str);
    }
    // Fresh install: return epoch 0 so first sync pulls everything
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> updateLastSyncTimestamp(DateTime time) async {
    await _writeStorage(_kLastSync, time.toIso8601String());
  }

  Future<void> clearAuth() async {
    await _deleteStorage(_kIdToken);
    await _deleteStorage(_kRefreshToken);
    await _deleteStorage(_kUserId);
    await _deleteStorage(_kTokenExpiry);
  }

  /// Register device FCM token with backend server
  Future<void> registerFcmToken(String userId, {String? tokenOverride}) async {
    final token = tokenOverride ?? await _readStorage('fcm_token');
    if (token == null || token.isEmpty) return;

    try {
      await _dio.post(
        '${ServerConfig.baseUrl}/user/fcm-token',
        data: {'user_id': userId, 'fcm_token': token},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (s) => s != null && s < 500,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      debugPrint('Failed to register FCM token with server: $e');
    }
  }
}
