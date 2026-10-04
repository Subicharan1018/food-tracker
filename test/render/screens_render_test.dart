import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/core/di/providers.dart';
import 'package:food_tracker/features/dashboard/presentation/screens/home_screen.dart';
import 'package:food_tracker/features/food_logging/presentation/screens/log_food_screen.dart';
import 'package:food_tracker/features/weight_progress/presentation/screens/weight_screen.dart';
import 'package:food_tracker/features/workouts/presentation/screens/workouts_screen.dart';
import 'package:food_tracker/shared/screens/main_nav_screen.dart';
import 'package:food_tracker/features/shopping_cart/shopping_cart_screen.dart';
import 'package:food_tracker/features/pantry/pantry_screen.dart';
import 'package:food_tracker/features/checkin/checkin_screen.dart';
import 'package:food_tracker/features/sleep/presentation/screens/sleep_screen.dart';
import 'package:food_tracker/features/recipes/presentation/screens/recipes_screen.dart';
import 'package:food_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:food_tracker/features/steps_activity/presentation/screens/steps_screen.dart';

import 'render_harness.dart';

final _aiOverrides = [
  weeklyDigestProvider.overrideWith((ref, week) async => null),
  workoutProgressionProvider.overrideWith((ref, id) async => <String, dynamic>{}),
  weeklyShoppingListProvider.overrideWith((ref) async => null),
];

void main() {
  final screens = {
    'home': (const HomeScreen(), 2600.0),
    'log': (const LogFoodScreen(initialMealSlot: 'lunch'), 1400.0),
    'train': (const WorkoutsScreen(), 2400.0),
    'progress': (const WeightProgressScreen(), 2000.0),
    'more': (const MoreMenuScreen(), 1300.0),
    'shopping': (const ShoppingCartScreen(), 1600.0),
    'pantry': (const PantryScreen(), 1000.0),
    'checkin': (const CheckInScreen(), 1300.0),
    'sleep': (const SleepScreen(), 1200.0),
    'recipes': (const RecipesScreen(), 1800.0),
    'settings': (const SettingsScreen(), 2200.0),
    'steps': (const StepsScreen(), 1600.0),
  };
  for (final entry in screens.entries) {
    testWidgets(entry.key, (tester) async {
      final db = await seededDb();
      await renderScreen(tester, entry.key, entry.value.$1, db: db, height: entry.value.$2, overrides: _aiOverrides);
      await db.close();
    }, skip: !renderEnabled);
  }
}
