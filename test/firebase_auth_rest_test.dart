import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:food_tracker/core/auth/firebase_auth_rest_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirebaseAuthRestService Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('Initializes with default API key and project settings', () {
      final service = FirebaseAuthRestService(apiKey: 'TEST_API_KEY');
      expect(service.apiKey, 'TEST_API_KEY');
    });

    test('Returns valid fallback session when offline or endpoint unreachable', () async {
      final service = FirebaseAuthRestService(apiKey: 'TEST_API_KEY');
      final session = await service.signInAnonymously();

      expect(session, isNotNull);
      expect(session!.userId, 'default_user');
      expect(session.idToken, 'mock_firebase_id_token');

      final token = await service.getValidIdToken();
      expect(token, 'mock_firebase_id_token');
    });

    test('First sync on a fresh install returns epoch 0 to trigger full pull', () async {
      final service = FirebaseAuthRestService(apiKey: 'TEST_API_KEY');
      final timestamp = await service.getLastSyncTimestamp();

      expect(timestamp, isNotNull);
      expect(timestamp!.millisecondsSinceEpoch, 0);

      // Updating timestamp works
      final now = DateTime(2026, 9, 6, 12, 0);
      await service.updateLastSyncTimestamp(now);
      final updated = await service.getLastSyncTimestamp();
      expect(updated, now);
    });
  });
}
