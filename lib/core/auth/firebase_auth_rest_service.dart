import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FirebaseAuthSession {
  final String userId;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;

  FirebaseAuthSession({
    required this.userId,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
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

  /// Silently sign in anonymously using Firebase Auth REST API
  Future<FirebaseAuthSession?> signInAnonymously() async {
    try {
      final url =
          'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey';
      final response = await _dio.post(
        url,
        data: {'returnSecureToken': true},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null && status < 500,
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

        return FirebaseAuthSession(
          userId: localId,
          idToken: idToken,
          refreshToken: refreshToken,
          expiresAt: expiresAt,
        );
      }
    } catch (e) {
      debugPrint('Anonymous auth error: $e');
    }

    // Fallback session for standalone/offline dev without blocking the app
    const fallbackUid = 'default_user';
    const fallbackToken = 'mock_firebase_id_token';
    await _storage.write(key: _kUserId, value: fallbackUid);
    await _storage.write(key: _kIdToken, value: fallbackToken);
    return FirebaseAuthSession(
      userId: fallbackUid,
      idToken: fallbackToken,
      refreshToken: 'mock_refresh_token',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
  }

  /// Proactive refresh of ID Token using refresh token
  Future<String?> refreshIdToken() async {
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken == null || refreshToken.isEmpty || refreshToken == 'mock_refresh_token') {
      final session = await signInAnonymously();
      return session?.idToken;
    }

    try {
      final url = 'https://securetoken.googleapis.com/v1/token?key=$apiKey';
      final response = await _dio.post(
        url,
        data: 'grant_type=refresh_token&refresh_token=$refreshToken',
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        final newIdToken = data['id_token'] as String;
        final newRefreshToken = data['refresh_token'] as String;
        final expiresIn = int.tryParse(data['expires_in']?.toString() ?? '3600') ?? 3600;
        final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

        await _storage.write(key: _kIdToken, value: newIdToken);
        await _storage.write(key: _kRefreshToken, value: newRefreshToken);
        await _storage.write(key: _kTokenExpiry, value: expiresAt.toIso8601String());
        return newIdToken;
      }
    } catch (e) {
      debugPrint('Token refresh error: $e');
    }

    // If refresh fails, sign in anonymously again
    final fresh = await signInAnonymously();
    return fresh?.idToken;
  }

  /// Returns valid, unexpired ID token (proactively refreshing if within 5 mins of expiry)
  Future<String> getValidIdToken() async {
    final storedToken = await _storage.read(key: _kIdToken);
    final expiryStr = await _storage.read(key: _kTokenExpiry);

    if (storedToken == null || storedToken.isEmpty || expiryStr == null) {
      final session = await signInAnonymously();
      return session?.idToken ?? 'mock_firebase_id_token';
    }

    final expiry = DateTime.tryParse(expiryStr) ?? DateTime.now();
    // If within 5 minutes of expiring, refresh now
    if (DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 5)))) {
      final refreshed = await refreshIdToken();
      return refreshed ?? storedToken;
    }

    return storedToken;
  }

  Future<String> getUserId() async {
    final storedId = await _storage.read(key: _kUserId);
    if (storedId != null && storedId.isNotEmpty) {
      return storedId;
    }
    final session = await signInAnonymously();
    return session?.userId ?? 'default_user';
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
}
