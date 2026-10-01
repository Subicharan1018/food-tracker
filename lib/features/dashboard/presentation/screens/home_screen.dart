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
import '../widgets/vitals_strip.dart';
import '../widgets/meal_rail.dart';
import '../widgets/streak_card.dart';
import '../../../ai_digest/weekly_digest_card.dart';
import '../../../ai_planner/meal_plan_card.dart';
import '../../../workouts/progression_card.dart';
import '../../../nutrition/nutrient_pace_card.dart';
import '../../../food_logging/repeat_meal.dart';
import '../../../checkin/checkin_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Sunday without a weigh-in yet, or a week or more since the last one.
  static bool _checkInDue(WidgetRef ref) {
    final weighIns = ref.watch(weighInsStreamProvider).value;
    if (weighIns == null) return false;
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final last = weighIns.isEmpty ? null : DateTime.parse(weighIns.first.date);
    if (last != null && weighIns.first.date == today) return false;
    return now.weekday == DateTime.sunday || last == null || now.difference(last).inDays >= 7;
  }

  void _navigateLogFood(BuildContext context, String mealSlot) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LogFoodScreen(initialMealSlot: mealSlot),
      ),
    );
  }

  void _requestMealPlan(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (ctx, modalRef, _) {
            final user = modalRef.watch(userProfileProvider).value;
            final userId = user?.id ?? 'default_user';
            final planAsync = modalRef.watch(mealPlanProvider(userId));

            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: SafeArea(
                child: planAsync.when(
                  data: (data) {
                    final items = (data['plan'] as List<dynamic>?) ?? [];
                    return SingleChildScrollView(
                      child: MealPlanCard(
                        planItems: items,
                        rawText: data['raw_text']?.toString(),
                        onDismiss: () => Navigator.pop(ctx),
                      ),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.brandPrimary),
                        SizedBox(height: 20),
                        Text(
                          'Kinetik is planning your evening... (~60 seconds)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Analyzing today\'s macros, remaining protein, and pantry recipes',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, color: AppColors.destructive, size: 40),
                        const SizedBox(height: 14),
                        const Text(
                          'Server unavailable. Check your connection.',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.surfaceElevated),
                          onPressed: () {
                            modalRef.invalidate(mealPlanProvider(userId));
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
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
    final paceAsync = ref.watch(dailyPaceProvider);
    final targetKcal = user?.calorieTarget ?? 2350;
    final targetP = user?.proteinTargetG ?? 155.0;
    final targetC = user?.carbTargetG ?? 260.0;
    final targetF = user?.fatTargetG ?? 70.0;
    final targetWater = user?.waterTargetMl ?? 3000;
    final targetSteps = user?.stepsTarget ?? 10000;

    final entries = entriesAsync.value ?? [];
    final usual = ref.watch(usualFoodsProvider).value ?? const <String, List<String>>{};
    final lastMeals = ref.watch(lastMealsProvider).value ?? const <String, List<DiaryEntry>>{};
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
                    style: const TextStyle(fontSize: 11, color: AppColors.brandPrimary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Keep the app bar compact on narrow phones. Date navigation lives
          // in the first dashboard card below.
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: AppColors.textPrimary),
            tooltip: 'Choose date',
            onPressed: () async {
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
          ),
          IconButton(
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
          ref.invalidate(dailyPaceProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Date navigation is deliberately outside the AppBar so the
            // title and actions cannot overflow on small screens.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous day',
                    onPressed: () => ref.read(selectedDateProvider.notifier).state =
                        selectedDate.subtract(const Duration(days: 1)),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      isToday ? 'Today' : DateFormat('EEEE, MMM d').format(selectedDate),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next day',
                    onPressed: () => ref.read(selectedDateProvider.notifier).state =
                        selectedDate.add(const Duration(days: 1)),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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

            if (_checkInDue(ref)) ...[
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckInScreen())),
                borderRadius: AppShapes.information,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: AppShapes.information,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Check-in', style: AppTypography.titleMedium),
                            SizedBox(height: 2),
                            Text('Weigh in before food and water, then a progress photo.',
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Text('Start', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.brandPrimary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            NutrientPaceCard(status: paceAsync.value, unreachable: paceAsync.hasError),

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

            VitalsStrip(
              waterMl: currentWater,
              waterTargetMl: targetWater,
              steps: ref.watch(todayStepsProvider).value ?? 0,
              stepsTarget: targetSteps,
              onAddWater: (ml) async => ref.read(databaseProvider).addWaterLog(WaterLogsCompanion.insert(id: const Uuid().v4(), date: dateStr, mlAdded: ml, loggedAt: Value(DateTime.now()))),
              onStepsTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StepsScreen())),
            ),

            const SizedBox(height: 24),
            MealRail(
              onAdd: (slot) => _navigateLogFood(context, slot),
              onDelete: (id) => ref.read(databaseProvider).deleteDiaryEntry(id),
              items: [
                for (final (key, title, time, icon) in const [
                  ('breakfast', 'Breakfast', '6:00 AM', Icons.wb_sunny_outlined),
                  ('lunch', 'Lunch', '1:00 PM', Icons.lunch_dining_outlined),
                  ('shake', 'Shake', '4:30 PM', Icons.local_cafe_outlined),
                  ('pre_workout', 'Pre-workout', '6:00 PM', Icons.bolt_outlined),
                  ('dinner', 'Dinner', '8:15 PM', Icons.dinner_dining_outlined),
                  ('snack', 'Snack', 'Anytime', Icons.cookie_outlined),
                ])
                  MealRailItem(
                    keyName: key,
                    title: title,
                    subtitle: usual[key] == null ? 'Nothing logged here in the last 2 weeks' : 'Usually ${usual[key]!.join(' + ')}',
                    time: time,
                    icon: icon,
                    entries: entries.where((e) => e.mealSlot == key).toList(),
                    repeatLabel: lastMeals[key] == null ? null : repeatLabel(lastMeals[key]!),
                    onRepeat: lastMeals[key] == null
                        ? null
                        : () async {
                            final report = await repeatMeal(ref.read(databaseProvider), lastMeals[key]!, date: dateStr);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(['Logged $title.', ?report.summary].join(' '))),
                              );
                            }
                          },
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // AI Meal Planning Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome_rounded, color: Colors.black, size: 20),
                label: const Text(
                  'Plan my evening',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  shape: RoundedRectangleBorder(borderRadius: AppShapes.action),
                ),
                onPressed: () => _requestMealPlan(context, ref),
              ),
            ),

            const SizedBox(height: 16),

            // AI Weekly Digest on Sunday/Monday
            const WeeklyDigestCard(),

            const SizedBox(height: 16),

            // AI Workout Progression Card on Weekends
            const WorkoutProgressionCard(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
