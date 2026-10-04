import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../core/di/providers.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/domain/meal_slots.dart';
import '../../../../shared/widgets/scoreboard.dart';
import '../widgets/meal_schedule.dart';
import '../../../food_logging/presentation/screens/log_food_screen.dart';
import '../../../macro_breakdown/presentation/screens/macro_source_screen.dart';
import '../../../steps_activity/presentation/screens/steps_screen.dart';
import '../../../ai_digest/weekly_digest_card.dart';
import '../../../ai_planner/meal_plan_card.dart';
import '../../../workouts/progression_card.dart';
import '../../../nutrition/nutrient_pace_card.dart';
import '../../../food_logging/repeat_meal.dart';
import '../../../checkin/checkin_screen.dart';

String _fmt(num v) => NumberFormat.decimalPattern().format(v.round());

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

    final steps = ref.watch(todayStepsProvider).value ?? 0;
    final kcalLeft = targetKcal + totalBurnedKcal - totalConsumedKcal;
    final over = kcalLeft < 0;

    Future<void> addWater(int ml) => ref.read(databaseProvider).addWaterLog(
          WaterLogsCompanion.insert(id: const Uuid().v4(), date: dateStr, mlAdded: ml, loggedAt: Value(DateTime.now())),
        );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppShapes.gutter,
        title: Text('KINETIK', style: AppTypography.titleLarge.copyWith(letterSpacing: 2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
            tooltip: 'Choose date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2025),
                lastDate: DateTime(2030),
              );
              if (picked != null) ref.read(selectedDateProvider.notifier).state = picked;
            },
          ),
          IconButton(
            icon: const Icon(Icons.donut_large_outlined, size: 20),
            tooltip: 'Where your macros came from',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MacroSourceScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.brandPrimary,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: () async {
          ref.invalidate(diaryEntriesProvider);
          ref.invalidate(dailyWaterProvider);
          ref.invalidate(dailyWorkoutsProvider);
          ref.invalidate(todayStepsProvider);
          ref.invalidate(dailyPaceProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // Day switcher: the date is the context for every number below.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous day',
                    onPressed: () => ref.read(selectedDateProvider.notifier).state =
                        selectedDate.subtract(const Duration(days: 1)),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      (isToday ? 'Today · ${DateFormat('EEE d MMM').format(selectedDate)}' : DateFormat('EEEE d MMMM').format(selectedDate))
                          .toUpperCase(),
                      textAlign: TextAlign.center,
                      style: AppTypography.label.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next day',
                    onPressed: () => ref.read(selectedDateProvider.notifier).state =
                        selectedDate.add(const Duration(days: 1)),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),

            // 1. Calories — the headline number.
            Board(
              label: over ? 'Over budget' : 'Calories left',
              trailing: Text('TARGET ${_fmt(targetKcal)}', style: AppTypography.dataSmall),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BigNumber(
                    _fmt(kcalLeft.abs()),
                    unit: 'kcal',
                    color: over ? AppColors.attention : AppColors.textPrimary,
                  ),
                  const SizedBox(height: 16),
                  SegmentMeter(
                    fraction: totalConsumedKcal / (targetKcal + totalBurnedKcal),
                    color: AppColors.brandPrimary,
                    overColor: AppColors.attention,
                    segments: 30,
                    height: 12,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'EATEN ${_fmt(totalConsumedKcal)}   ·   BURNED ${_fmt(totalBurnedKcal)}',
                    style: AppTypography.dataSmall,
                  ),
                ],
              ),
            ),

            // 2. Macros — protein leads; it's the recomp priority.
            Board(
              label: 'Macros',
              child: Column(
                children: [
                  StatLine(label: 'Protein', value: totalP, target: targetP, unit: 'g', color: AppColors.brandPrimary),
                  StatLine(label: 'Carbs', value: totalC, target: targetC, unit: 'g', overColor: AppColors.attention),
                  StatLine(label: 'Fat', value: totalF, target: targetF, unit: 'g', overColor: AppColors.attention),
                  StatLine(label: 'Fiber', value: totalFiber, target: 30, unit: 'g'),
                ],
              ),
            ),

            if (_checkInDue(ref))
              Board(
                label: 'Check-in due',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckInScreen())),
                trailing: Text('START', style: AppTypography.label.copyWith(color: AppColors.brandPrimary)),
                child: Text('Weigh in before food and water, then a progress photo.', style: AppTypography.bodyMedium),
              ),

            // 3. Micronutrient pace (server-computed).
            NutrientPaceCard(status: paceAsync.value, unreachable: paceAsync.hasError),

            // 4. Today's vitals.
            Board(
              label: 'Today',
              trailing: Text('LOG STREAK $loggingStreak · TRAIN $workoutStreak', style: AppTypography.dataSmall),
              child: Column(
                children: [
                  StatLine(label: 'Water', value: currentWater, target: targetWater, unit: 'ml', color: AppColors.textPrimary),
                  Row(
                    children: [
                      for (final ml in const [250, 500])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: OutlinedButton(onPressed: () => addWater(ml), child: Text('+ $ml ML')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StepsScreen())),
                    child: StatLine(label: 'Steps', value: steps, target: targetSteps, unit: 'steps'),
                  ),
                ],
              ),
            ),

            // 5. Meals as a timetable.
            Board(
              label: 'Meals',
              trailing: TextButton(
                onPressed: () => _requestMealPlan(context, ref),
                child: Text('PLAN MY EVENING', style: AppTypography.label.copyWith(color: AppColors.brandPrimary)),
              ),
              child: MealSchedule(
                entries: entries,
                usual: usual,
                repeatLabels: {for (final e in lastMeals.entries) e.key: repeatLabel(e.value)},
                onAdd: (slot) => _navigateLogFood(context, slot),
                onDelete: (id) => ref.read(databaseProvider).deleteDiaryEntry(id),
                onRepeat: (slot) async {
                  final meal = lastMeals[slot];
                  if (meal == null) return;
                  final report = await repeatMeal(ref.read(databaseProvider), meal, date: dateStr);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(['Logged ${mealSlot(slot).label}.', ?report.summary].join(' '))),
                    );
                  }
                },
              ),
            ),

            // AI weekly digest (Sun/Mon) and progression (weekends).
            const WeeklyDigestCard(),
            const Padding(padding: EdgeInsets.symmetric(horizontal: AppShapes.gutter), child: WorkoutProgressionCard()),
          ],
        ),
      ),
    );
  }
}
