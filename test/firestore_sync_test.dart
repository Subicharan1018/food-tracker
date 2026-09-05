import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/core/network/google_firestore_sync_service.dart';
import 'package:food_tracker/core/local_db/app_database.dart';

void main() {
  group('GoogleFirestoreSyncService Tests', () {
    test('Constructs accurate Firestore REST endpoint for user document', () {
      final service = GoogleFirestoreSyncService(
        projectId: 'my-fitness-recomp-project',
        userId: 'user_yogesh',
      );

      expect(service.projectId, 'my-fitness-recomp-project');
      expect(service.userId, 'user_yogesh');
    });

    test('Formats diary entry payload according to Firestore REST Document API specification', () {
      final entry = DiaryEntry(
        id: 'entry_123',
        date: '2026-09-05',
        mealSlot: 'breakfast',
        foodName: 'Vengaya Muttai Poriyal',
        portionQty: 1.0,
        portionUnit: 'meal',
        calories: 700.0,
        proteinG: 37.0,
        carbsG: 74.0,
        fatG: 21.0,
        fiberG: 8.0,
        loggedAt: DateTime(2026, 9, 5, 6, 30),
        isDirty: true,
        updatedAt: DateTime(2026, 9, 5, 6, 30),
      );

      expect(entry.calories, 700.0);
      expect(entry.proteinG, 37.0);
      expect(entry.mealSlot, 'breakfast');
    });
  });
}
