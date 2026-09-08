import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:food_tracker/core/auth/firebase_auth_rest_service.dart';
import 'package:food_tracker/core/local_db/app_database.dart';
import 'package:food_tracker/core/network/google_firestore_sync_service.dart';
import 'package:food_tracker/core/sync/sync_scheduler.dart';

class MockAuthService extends FirebaseAuthRestService {
  AuthResult mockState;

  MockAuthService({required this.mockState}) : super(apiKey: 'TEST_KEY');

  @override
  Future<AuthResult> getAuthState() async => mockState;

  @override
  Future<String?> getValidIdToken() async =>
      mockState is AuthSuccess ? (mockState as AuthSuccess).idToken : null;

  @override
  Future<String?> getUserId() async =>
      mockState is AuthSuccess ? (mockState as AuthSuccess).userId : null;
}

class FakeFirestoreSyncService extends GoogleFirestoreSyncService {
  int syncAllCallCount = 0;
  bool shouldSucceed;

  FakeFirestoreSyncService({
    required super.authService,
    this.shouldSucceed = true,
  }) : super(projectId: 'test-proj', userId: 'test-user');

  @override
  Future<SyncResult> syncAll(AppDatabase db) async {
    syncAllCallCount++;
    if (!shouldSucceed) {
      return SyncResult(
        pushedCount: 0,
        pulledCount: 0,
        success: false,
        errorMessage: 'Simulated network failure',
        timestamp: DateTime.now(),
      );
    }
    // Clean dirty rows on success
    final dirtyMeals = await db.getDirtyDiaryEntries();
    if (dirtyMeals.isNotEmpty) {
      await db.markDiaryEntriesClean(dirtyMeals.map((e) => e.id).toList());
    }
    return SyncResult(
      pushedCount: dirtyMeals.length,
      pulledCount: 0,
      success: true,
      timestamp: DateTime.now(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockAuthService authService;
  late FakeFirestoreSyncService syncService;
  late SyncScheduler scheduler;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    authService = MockAuthService(
      mockState: AuthSuccess(
        userId: 'test_user_123',
        idToken: 'valid_test_token',
        refreshToken: 'valid_refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    syncService = FakeFirestoreSyncService(authService: authService);
    scheduler = SyncScheduler(
      syncService: syncService,
      authService: authService,
      db: db,
      debounceDuration: const Duration(milliseconds: 100),
    );
    db.attachSyncScheduler(scheduler);
  });

  tearDown(() async {
    scheduler.dispose();
    await db.close();
  });

  group('SyncScheduler Tests', () {
    test('Debouncing: 5 rapid scheduleSync calls within debounce window execute syncAll exactly once', () async {
      // 5 rapid calls within 20ms
      for (int i = 0; i < 5; i++) {
        scheduler.scheduleSync();
      }

      // Before debounce window expires, no call should have been made
      expect(syncService.syncAllCallCount, 0);

      // Wait past debounce duration (100ms)
      await Future.delayed(const Duration(milliseconds: 180));

      expect(syncService.syncAllCallCount, 1);
    });

    test('Auth guard: scheduleSync no-ops when authState is AuthFailure', () async {
      authService.mockState = const AuthFailure(
        reason: 'anonymous_auth_disabled',
        message: 'Anonymous auth disabled',
      );

      scheduler.scheduleSync();
      await Future.delayed(const Duration(milliseconds: 180));

      // syncAll was never called because auth guard stopped it
      expect(syncService.syncAllCallCount, 0);
      expect(scheduler.status.authReason, 'anonymous_auth_disabled');
    });

    test('Database mutation hook: inserting diary entry triggers debounced sync', () async {
      await db.addDiaryEntry(
        DiaryEntriesCompanion.insert(
          id: 'meal_auto_1',
          date: '2026-09-08',
          mealSlot: 'breakfast',
          foodName: 'Oats with Almond Milk',
          portionQty: 1.0,
          portionUnit: 'bowl',
          calories: 350.0,
          proteinG: 12.0,
          carbsG: 55.0,
          fatG: 7.0,
          isDirty: const Value(true),
        ),
      );

      // Should have scheduled a sync
      expect(syncService.syncAllCallCount, 0);

      await Future.delayed(const Duration(milliseconds: 180));

      expect(syncService.syncAllCallCount, 1);

      // Successfully synced item is marked clean
      final dirty = await db.getDirtyDiaryEntries();
      expect(dirty.isEmpty, true);
    });

    test('Error retention: Failed sync preserves isDirty == true for subsequent retry', () async {
      syncService.shouldSucceed = false;

      await db.addDiaryEntry(
        DiaryEntriesCompanion.insert(
          id: 'meal_dirty_test',
          date: '2026-09-08',
          mealSlot: 'lunch',
          foodName: 'Chicken Rice',
          portionQty: 1.0,
          portionUnit: 'plate',
          calories: 600.0,
          proteinG: 45.0,
          carbsG: 70.0,
          fatG: 12.0,
          isDirty: const Value(true),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 180));

      expect(syncService.syncAllCallCount, 1);

      // Record remains dirty in SQLite because sync failed
      final dirty = await db.getDirtyDiaryEntries();
      expect(dirty.length, 1);
      expect(dirty.first.id, 'meal_dirty_test');
      expect(scheduler.status.error, isNotNull);
    });
  });
}
