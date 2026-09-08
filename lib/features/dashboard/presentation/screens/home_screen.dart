import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../core/di/providers.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/calorie_ring.dart';
import '../../../../shared/widgets/macro_bars.dart';
import '../../../food_logging/presentation/screens/log_food_screen.dart';
import '../../../macro_breakdown/presentation/screens/macro_source_screen.dart';
import '../../../steps_activity/presentation/screens/steps_screen.dart';
import '../widgets/meal_slot_card.dart';
import '../widgets/water_card.dart';
import '../widgets/steps_card.dart';
import '../widgets/streak_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _navigateLogFood(BuildContext context, String mealSlot) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LogFoodScreen(initialMealSlot: mealSlot),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final dateStr = ref.watch(formattedSelectedDateProvider);
    final userAsync = ref.watch(userProfileProvider);
    final entriesAsync = ref.watch(diaryEntriesProvider);
    final waterAsync = ref.watch(dailyWaterProvider);
    final workoutsAsync = ref.watch(dailyWorkoutsProvider);
    final logStreakAsync = ref.watch(loggingStreakProvider);
    final workStreakAsync = ref.watch(workoutStreakProvider);

    final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr;

    final user = userAsync.value;
    final targetKcal = user?.calorieTarget ?? 2350;
    final targetP = user?.proteinTargetG ?? 155.0;
    final targetC = user?.carbTargetG ?? 260.0;
    final targetF = user?.fatTargetG ?? 70.0;
    final targetWater = user?.waterTargetMl ?? 3000;
    final targetSteps = user?.stepsTarget ?? 10000;

    final entries = entriesAsync.value ?? [];
    final totalConsumedKcal = entries.fold<double>(0, (sum, e) => sum + e.calories).toInt();
    final totalP = entries.fold<double>(0, (sum, e) => sum + e.proteinG);
    final totalC = entries.fold<double>(0, (sum, e) => sum + e.carbsG);
    final totalF = entries.fold<double>(0, (sum, e) => sum + e.fatG);
    final totalFiber = entries.fold<double>(0, (sum, e) => sum + e.fiberG);

    final workouts = workoutsAsync.value ?? [];
    final totalBurnedKcal = workouts.fold<double>(0, (sum, w) => sum + w.caloriesBurned).toInt();

    final currentWater = waterAsync.value ?? 0;
    final loggingStreak = logStreakAsync.value?.currentCount ?? 1;
    final workoutStreak = workStreakAsync.value?.currentCount ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icons/app_icon.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'KINETIK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Recomp · Phase 1',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.positive, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Date Selector
          IconButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () {
              ref.read(selectedDateProvider.notifier).state =
                  selectedDate.subtract(const Duration(days: 1));
            },
          ),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2025),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                ref.read(selectedDateProvider.notifier).state = picked;
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                isToday ? 'Today' : DateFormat('MMM d').format(selectedDate),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () {
              ref.read(selectedDateProvider.notifier).state =
                  selectedDate.add(const Duration(days: 1));
            },
          ),
          // Macro source button
          IconButton(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.only(right: 8),
            icon: const Icon(Icons.pie_chart_rounded, color: AppColors.textPrimary),
            tooltip: 'Macro Source Breakdown',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MacroSourceScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.textPrimary,
        backgroundColor: AppColors.cardElevated,
        onRefresh: () async {
          ref.invalidate(diaryEntriesProvider);
          ref.invalidate(dailyWaterProvider);
          ref.invalidate(dailyWorkoutsProvider);
          ref.invalidate(todayStepsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Calorie Hero Ring
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  CalorieRing(
                    targetCalories: targetKcal,
                    consumedCalories: totalConsumedKcal,
                    burnedCalories: totalBurnedKcal,
                  ),
                  if (totalBurnedKcal > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cardElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🔥 +$totalBurnedKcal kcal burned in workouts offset budget',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.attention),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Macro Quadrant Bars
            MacroBarsGrid(
              proteinConsumed: totalP,
              proteinTarget: targetP,
              carbsConsumed: totalC,
              carbsTarget: targetC,
              fatConsumed: totalF,
              fatTarget: targetF,
              fiberConsumed: totalFiber,
              fiberTarget: 30.0,
            ),

            const SizedBox(height: 16),

            // Macro Source Attribution Shortcut Card
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MacroSourceScreen()),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hub_rounded, color: AppColors.textPrimary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Macro Source Attribution', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          Text('See which specific foods supplied your protein & carbs', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. Streaks
            StreaksCard(
              loggingStreak: loggingStreak,
              workoutStreak: workoutStreak,
            ),

            const SizedBox(height: 16),

            // 4. Water Tracker
            WaterTrackingCard(
              currentMl: currentWater,
              targetMl: targetWater,
              onAddWater: (ml) async {
                final db = ref.read(databaseProvider);
                await db.addWaterLog(
                  WaterLogsCompanion.insert(
                    id: const Uuid().v4(),
                    date: dateStr,
                    mlAdded: ml,
                    loggedAt: Value(DateTime.now()),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // 5. Steps Card
            StepsCard(
              currentSteps: ref.watch(todayStepsProvider).value ?? 0,
              targetSteps: targetSteps,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StepsScreen()),
                );
              },
              onSimulateStepAdd: () {
                ref.invalidate(todayStepsProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Synced steps from Health Connect / Pedometer!')),
                );
              },
            ),

            const SizedBox(height: 24),
            const Text(
              'MEAL SCHEDULE & SLOTS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

            // Meal Slots from refeerece.html
            MealSlotCard(
              slotKey: 'breakfast',
              title: 'Breakfast',
              subtitle: '4 whole eggs + 4 chapatis (~700 kcal / 37g P)',
              timeRange: '6:00 – 6:30 AM',
              entries: entries.where((e) => e.mealSlot == 'breakfast').toList(),
              onAddTap: () => _navigateLogFood(context, 'breakfast'),
              onDeleteEntry: (id) => ref.read(databaseProvider).deleteDiaryEntry(id),
            ),

            MealSlotCard(
              slotKey: 'lunch',
              title: 'Lunch (Packed Dry Box)',
              subtitle: 'Chicken/Soya/Sundal/Paneer + Rice + Poriyal (~530 kcal)',
              timeRange: '1:00 PM',
              entries: entries.where((e) => e.mealSlot == 'lunch').toList(),
              onAddTap: () => _navigateLogFood(context, 'lunch'),
              onDeleteEntry: (id) => ref.read(databaseProvider).deleteDiaryEntry(id),
            ),

            MealSlotCard(
              slotKey: 'shake',
              title: 'Protein Shake (Bus Stop)',
              subtitle: '1 scoop whey + water (~120 kcal / 24g P)',
              timeRange: '4:30 – 5:00 PM',
              entries: entries.where((e) => e.mealSlot == 'shake').toList(),
              onAddTap: () => _navigateLogFood(context, 'shake'),
              onDeleteEntry: (id) => ref.read(databaseProvider).deleteDiaryEntry(id),
            ),

            MealSlotCard(
              slotKey: 'pre_workout',
              title: 'Pre-Workout Snack',
              subtitle: '2 bananas on reaching home (~210 kcal / 3g P)',
              timeRange: '6:00 PM',
              entries: entries.where((e) => e.mealSlot == 'pre_workout').toList(),
              onAddTap: () => _navigateLogFood(context, 'pre_workout'),
              onDeleteEntry: (id) => ref.read(databaseProvider).deleteDiaryEntry(id),
            ),

            MealSlotCard(
              slotKey: 'dinner',
              title: 'Dinner (Country Chicken & Chapati)',
              subtitle: '220g chicken + 3 chapatis (~820 kcal / 55g P)',
              timeRange: '8:15 – 8:30 PM',
              entries: entries.where((e) => e.mealSlot == 'dinner').toList(),
              onAddTap: () => _navigateLogFood(context, 'dinner'),
              onDeleteEntry: (id) => ref.read(databaseProvider).deleteDiaryEntry(id),
            ),

            MealSlotCard(
              slotKey: 'snack',
              title: 'Extra Snacks / Additions',
              subtitle: 'Handful peanuts, fruits, extra chapati',
              timeRange: 'Anytime',
              entries: entries.where((e) => e.mealSlot == 'snack').toList(),
              onAddTap: () => _navigateLogFood(context, 'snack'),
              onDeleteEntry: (id) => ref.read(databaseProvider).deleteDiaryEntry(id),
            ),
          ],
        ),
      ),
    );
  }
}
