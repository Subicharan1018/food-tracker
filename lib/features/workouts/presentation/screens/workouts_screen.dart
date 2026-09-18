import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../streaks/services/streak_service.dart';
import '../../data/workout_routines_provider.dart';
import '../../hiit/hiit_timer_screen.dart';
import '../../set_timer/set_rest_timer_service.dart';
import '../../set_timer/set_rest_timer_widget.dart';

String _categoryFor(String exerciseName) {
  const compound = [
    'Barbell Squat', 'Barbell bench press', 'Bench Press', 'Overhead press', 'Overhead Press',
    'Romanian deadlift', 'Romanian Deadlift', 'Sumo Deadlift', 'Barbell back squat', 'Goblet Squat', 'Goblet squat finisher'
  ];
  const bodyweight = ['Pull-ups', 'Dips', 'Push-ups', 'Push-up burnout'];
  if (compound.any((c) => exerciseName.toLowerCase().contains(c.toLowerCase()))) return 'compound';
  if (bodyweight.any((b) => exerciseName.toLowerCase().contains(b.toLowerCase()))) return 'bodyweight';
  if (exerciseName.toLowerCase().contains('hiit')) return 'hiit';
  if (exerciseName.toLowerCase().contains('plank') || exerciseName.toLowerCase().contains('raise')) return 'core';
  return 'accessory';
}

class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showActivityLoggerDialog() {
    final searchCtrl = TextEditingController();
    List<Activity> filteredActivities = [];
    Activity? selectedActivity;
    int durationMin = 30;
    String intensity = 'moderate'; // light, moderate, vigorous

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final userWeight = ref.read(userProfileProvider).value?.weightKg ?? 62.0;

            double intensityMult = 1.0;
            if (intensity == 'light') intensityMult = 0.85;
            if (intensity == 'vigorous') intensityMult = 1.25;

            final effectiveMet = (selectedActivity?.metValue ?? 5.0) * intensityMult;
            final caloriesBurned = (effectiveMet * userWeight * (durationMin / 60)).round();

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Log Activity & Cardio', style: AppTypography.titleLarge),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search activities from Drift DB
                    if (selectedActivity == null) ...[
                      TextField(
                        controller: searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Search activity (running, cycling, elliptical...)',
                          prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
                        ),
                        onChanged: (q) async {
                          final db = ref.read(databaseProvider);
                          final results = await db.searchActivities(q);
                          setModalState(() {
                            filteredActivities = results;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      if (filteredActivities.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: filteredActivities.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final act = filteredActivities[idx];
                              return ListTile(
                                title: Text(act.name, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                                subtitle: Text('MET: ${act.metValue} · ${act.category.toUpperCase()}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                onTap: () {
                                  setModalState(() {
                                    selectedActivity = act;
                                    durationMin = act.defaultDurationMin;
                                    filteredActivities.clear();
                                  });
                                },
                              );
                            },
                          ),
                        ),
                    ] else ...[
                      // Selected Activity Chip
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.textPrimary),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.positive, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedActivity!.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setModalState(() => selectedActivity = null),
                              child: const Text('Change', style: TextStyle(color: AppColors.textSecondary)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Duration Slider / Stepper
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Duration (minutes)', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              color: AppColors.textPrimary,
                              onPressed: durationMin > 5 ? () => setModalState(() => durationMin -= 5) : null,
                            ),
                            Text('$durationMin min', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              color: AppColors.textPrimary,
                              onPressed: () => setModalState(() => durationMin += 5),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Intensity Selector
                    const Text('Intensity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      children: ['light', 'moderate', 'vigorous'].map((lvl) {
                        final sel = intensity == lvl;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(lvl.toUpperCase()),
                              selected: sel,
                              onSelected: (_) => setModalState(() => intensity = lvl),
                              selectedColor: AppColors.brandPrimary,
                              backgroundColor: AppColors.card,
                              side: BorderSide(color: sel ? AppColors.brandPrimary : AppColors.border),
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: sel ? AppColors.textInverse : AppColors.textSecondary,
                              ),
                              showCheckmark: false,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Summary Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Estimated Calorie Burn', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text('$caloriesBurned kcal', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                              ],
                            ),
                          ),
                          const Icon(Icons.local_fire_department_rounded, color: AppColors.textPrimary, size: 28),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary,
                          foregroundColor: AppColors.textInverse,
                        ),
                        onPressed: () async {
                          final db = ref.read(databaseProvider);
                          final dateStr = ref.read(formattedSelectedDateProvider);
                          final actName = selectedActivity?.name ?? 'Workout Session';

                          await db.addWorkoutSession(
                            WorkoutSessionsCompanion.insert(
                              id: const Uuid().v4(),
                              date: dateStr,
                              activityId: Value(selectedActivity?.id),
                              activityName: actName,
                              durationMin: durationMin,
                              intensity: Value(intensity),
                              caloriesBurned: caloriesBurned.toDouble(),
                              source: const Value('manual'),
                              loggedAt: Value(DateTime.now()),
                            ),
                          );

                          // Update workout streak
                          final currentStreak = await db.getStreak('workout');
                          final streakRes = StreakEngine.processActivity(
                            currentCount: currentStreak?.currentCount ?? 0,
                            longestCount: currentStreak?.longestCount ?? 0,
                            lastActiveDate: currentStreak?.lastActiveDate,
                            today: DateTime.now(),
                          );
                          await db.updateStreak(
                            StreaksCompanion.insert(
                              type: 'workout',
                              currentCount: Value(streakRes.currentCount),
                              longestCount: Value(streakRes.longestCount),
                              lastActiveDate: Value(streakRes.lastActiveDate),
                              updatedAt: Value(DateTime.now()),
                            ),
                          );

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Logged: $actName ($caloriesBurned kcal)')),
                            );
                          }
                        },
                        child: const Text('Save Workout', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final workoutsAsync = ref.watch(dailyWorkoutsProvider);
    final setLogsAsync = ref.watch(dailySetLogsProvider);
    final dailyBurnTarget = ref.watch(dailyBurnTargetProvider);
    final routines = ref.watch(workoutRoutinesProvider);

    final workouts = workoutsAsync.value ?? [];
    final totalBurnedKcal = workouts.fold<double>(0, (sum, w) => sum + w.caloriesBurned).toInt();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: const Text('Workout Tracker'),
              pinned: true,
              floating: false,
              actions: [
                // Date picker
                IconButton(
                  icon: const Icon(Icons.calendar_today_rounded, size: 20),
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
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // 1. Calorie Burn Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceElevated,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.directions_run_rounded, color: AppColors.textPrimary, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '$totalBurnedKcal of $dailyBurnTarget',
                                    style: AppTypography.displayMedium.copyWith(fontSize: 22, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                const Text(
                                  'Cal Burnt',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.bar_chart_rounded, color: AppColors.textSecondary),
                            onPressed: () {},
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.textPrimary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add_rounded, color: AppColors.textInverse, size: 22),
                              onPressed: _showActivityLoggerDialog,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 2. Health Connect Auto-Sync Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.cardElevated,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(Icons.watch_rounded, color: AppColors.textSecondary, size: 22),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Others (Health Connect)',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                FutureBuilder<int>(
                                  future: ref.read(healthSyncServiceProvider).fetchTodaySteps(),
                                  builder: (context, snapshot) {
                                    final steps = snapshot.data ?? 0;
                                    return Text(
                                      steps > 0
                                          ? '$steps Steps, Other Activities'
                                          : '0 Steps, Sync via Health Connect',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.cardElevated,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('AUTO', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 3. My Workout Routine Section (Dynamic ListView over routines)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('My Workout Routine', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        Text('VIEW ALL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Horizontal Cards Carousel (Dynamic)
                    SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: routines.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final routine = routines[index];
                          return InkWell(
                            onTap: () {
                              if (index == 0) {
                                _tabController.animateTo(0);
                              } else {
                                _showActivityLoggerDialog();
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 240,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: routine.isCustom ? AppColors.brandPrimary.withValues(alpha: 0.55) : AppColors.border,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    routine.icon,
                                    color: routine.isCustom ? AppColors.brandPrimary : AppColors.textMuted,
                                    size: 24,
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        routine.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        routine.subtitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: routine.isCustom ? AppColors.textPrimary : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.brandPrimary,
                  labelColor: AppColors.brandPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  tabs: const [
                    Tab(text: 'Recomp Split'),
                    Tab(text: 'Activity History'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Recomp Split
            _RecompSplitTab(setLogs: setLogsAsync.value ?? []),

            // Tab 2: Activity Log History
            _WorkoutHistoryTab(
              workouts: workouts,
              onLogActivityTap: _showActivityLoggerDialog,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: AppColors.textInverse,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log Activity', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: _showActivityLoggerDialog,
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class _RecompSplitTab extends ConsumerStatefulWidget {
  final List<WorkoutSetLog> setLogs;

  const _RecompSplitTab({required this.setLogs});

  @override
  ConsumerState<_RecompSplitTab> createState() => _RecompSplitTabState();
}

class _RecompSplitTabState extends ConsumerState<_RecompSplitTab> {
  // DateTime.weekday is Monday=1 ... Sunday=7, matching the split list below.
  int _selectedDay = DateTime.now().weekday - 1;

  @override
  Widget build(BuildContext context) {
    final splitDays = [
      _SplitDay(
        day: 'Mon',
        title: 'Upper A',
        focus: 'Push emphasis · Chest, Shoulders, Triceps primary',
        length: '~50–60 min',
        exercises: [
          _SplitExercise('Barbell bench press', '4 × 8–10', 'Long bar (~16–22 kg to start). 3-sec lowering. Last set: stop 1 rep before failure.', 120, 22.0, 'Retract shoulder blades, bar touches mid-chest'),
          _SplitExercise('Incline DB press', '3 × 10–12', 'Bench at 30–45°, dumbbells ~8–9 kg/hand', 90, 9.0, 'Don\'t flare elbows >75° from torso'),
          _SplitExercise('Overhead press (seated)', '3 × 10–12', 'EZ bar or long bar, bench upright', 90, 16.0, 'Chin back on the way up, don\'t arch lower back'),
          _SplitExercise('Barbell bent-over row', '3 × 10–12', 'Long bar, hinge to ~45°, pull to lower ribs', 90, 20.0, 'Row for back, not biceps — lead with elbow'),
          _SplitExercise('EZ bar skullcrusher', '3 × 12–15', 'Light load on EZ bar, elbows stay fixed', 60, 8.0, 'Keep upper arms perpendicular to floor'),
          _SplitExercise('DB lateral raise', '3 × 15', '2–3 kg/hand only, strict form', 45, 2.5, 'Slight forward lean, lead with pinkies'),
          _SplitExercise('Push-up burnout', '1 × failure', 'Bodyweight; feet on bench when easy', 0, 0.0, 'Full ROM — chest touches floor each rep'),
        ],
      ),
      _SplitDay(
        day: 'Tue',
        title: 'Lower A + Core',
        focus: 'Quad emphasis · Squat pattern',
        length: '~50–60 min',
        exercises: [
          _SplitExercise('Barbell back squat', '4 × 8–10', 'Long bar on upper back, up to ~22–26 kg. Squat to parallel or below.', 120, 24.0, 'Knees track over toes, chest stays up'),
          _SplitExercise('Romanian deadlift', '3 × 10–12', 'Long bar, hinge from hips, soft knee bend', 90, 24.0, 'Bar skims legs, feel hamstring stretch'),
          _SplitExercise('DB walking lunge', '3 × 12/leg', 'Dumbbells ~8–9 kg/hand', 75, 9.0, 'Rear knee almost touches floor each rep'),
          _SplitExercise('Standing calf raise', '4 × 20–25', 'Bodyweight, hold dumbbell once easy, full range', 45, 0.0, 'Pause 1s at top and bottom each rep'),
          _SplitExercise('Plank', '3 × 45–60s', 'Mat, neutral spine', 45, 0.0, 'Squeeze glutes and abs simultaneously'),
          _SplitExercise('Hanging leg raises', '3 × 10–15', 'Pull-up bar', 60, 0.0, 'No swing — control the lowering'),
        ],
      ),
      _SplitDay(
        day: 'Wed',
        title: 'Zone 2 Conditioning',
        focus: 'Aerobic base · Active recovery',
        length: '~30–35 min',
        exercises: [
          _SplitExercise('Elliptical steady state', '30 min continuous', 'Level 2–3, conversational pace (120–140 bpm). Flushes soreness and builds aerobic base.', 0, 0.0, 'Continuous conversational pace, 120–140 bpm. Active recovery.'),
        ],
      ),
      _SplitDay(
        day: 'Thu',
        title: 'Upper B',
        focus: 'Pull emphasis · Back, Biceps primary',
        length: '~50–60 min',
        exercises: [
          _SplitExercise('Pull-ups', '4 × max (stop 2 short of failure)', 'Dead hang start, chin clears bar. Log every set: e.g. 8/6/5/4', 120, 0.0, 'Don\'t kip; scapular retraction at the top'),
          _SplitExercise('DB bicep curl (supinated)', '3 × 10–12', 'Dumbbells ~8–9 kg/hand', 60, 9.0, 'Full extension at bottom — don\'t cut ROM'),
          _SplitExercise('Hammer curl', '3 × 10–12', 'EZ bar or neutral-grip DBs', 60, 9.0, 'Builds brachialis — adds arm thickness'),
          _SplitExercise('Resistance band pull-apart', '3 × 20', 'Band at chest height, arms straight', 30, 0.0, 'Rear deltoid and rotator cuff health'),
          _SplitExercise('Incline DB chest press (lighter)', '3 × 12–15', 'Lower load than Mon — maintain volume, not max load', 75, 8.0, 'This is Upper B — chest still gets frequency'),
          _SplitExercise('Overhead press (standing)', '3 × 10–12', 'EZ bar or light bar, strict form', 90, 14.0, 'Brace core; don\'t lean back'),
          _SplitExercise('Wrist curl + reverse curl', '2+2 × 15–20', 'Light dumbbell, wrist only moves', 30, 4.0, 'Forearm strength — matches 30 cm forearm goal'),
        ],
      ),
      _SplitDay(
        day: 'Fri',
        title: 'Lower B + HIIT + Core',
        focus: 'Hinge pattern emphasis + Conditioning',
        length: '~50 min',
        exercises: [
          _SplitExercise('Goblet squat', '3 × 15–20', 'Single dumbbell ~15–19 kg at chest — quad endurance', 75, 19.0, 'Elbows inside knees at bottom'),
          _SplitExercise('Sumo DB deadlift', '3 × 10–12', 'One heavy dumbbell held with both hands, wide stance', 90, 19.0, 'Hinge at hips, not a squat'),
          _SplitExercise('Reverse lunge', '3 × 12/leg', 'Bodyweight or light dumbbells', 60, 9.0, 'Variation from Tue\'s walking lunge'),
          _SplitExercise('Calf raise single-leg', '3 × 15/leg', 'Hold wall for balance, bodyweight', 30, 0.0, 'More load per calf than both-leg version'),
          _SplitExercise('HIIT — elliptical', '6–8 rounds', '2 min warm-up (L2) → 30s sprint (L6–7) : 30s recovery (L1). Total ~10 min', 30, 0.0, 'Sprint is actually sprinting — feel it'),
          _SplitExercise('Plank holds', '3 × max', 'Mat', 60, 0.0, 'Goal: eventually 2 min continuous'),
          _SplitExercise('Bicycle crunch', '3 × 20', 'Mat, controlled rotation', 45, 0.0, 'Don\'t yank neck — rotate from core'),
        ],
      ),
      _SplitDay(
        day: 'Sat',
        title: 'Active Recovery Walk',
        focus: 'NEAT + Weekly Grocery Run',
        length: '~20–30 min',
        exercises: [
          _SplitExercise('Active recovery walk', '20–30 min', 'Easy walking for NEAT and weekly fresh grocery run', 0, 0.0, 'Buy chicken, curd, and fresh vegetables'),
        ],
      ),
      _SplitDay(
        day: 'Sun',
        title: 'Full Rest + Meal Prep',
        focus: 'Recovery + Batch Cooking',
        length: '~20–30 min',
        exercises: [
          _SplitExercise('Weekly weigh-in & photo', '1 check-in', 'Morning weigh-in after wake-up, same lighting, record waist and biceps', 0, 0.0, 'Log weekly progress in Progress tab'),
          _SplitExercise('Batch meal prep', 'Cook batch', 'Cook and portion chicken for weekday lunches, soak legumes overnight', 0, 0.0, 'Pre-measure 1-tsp oil portions for the week'),
        ],
      ),
    ];

    final dayPlan = splitDays[_selectedDay];
    final isFriday = dayPlan.day == 'Fri';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SetRestTimerWidget(),
        const SizedBox(height: 12),
        const Text('RECOMP SPLIT (V3 BLUEPRINT)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8, color: AppColors.textMuted)),
        const SizedBox(height: 10),
        SizedBox(
          height: 54,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: splitDays.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final active = index == _selectedDay;
              return ChoiceChip(
                label: Text(splitDays[index].day),
                selected: active,
                onSelected: (_) => setState(() => _selectedDay = index),
                selectedColor: AppColors.brandPrimary,
                backgroundColor: AppColors.card,
                side: BorderSide(color: active ? AppColors.brandPrimary : AppColors.border),
                labelStyle: TextStyle(fontWeight: FontWeight.w800, color: active ? AppColors.textInverse : AppColors.textSecondary),
                showCheckmark: false,
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          backgroundColor: AppColors.card,
          collapsedBackgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: AppShapes.information,
            side: const BorderSide(color: AppColors.border),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: AppShapes.information,
            side: const BorderSide(color: AppColors.border),
          ),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              dayPlan.day,
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 14),
            ),
          ),
          title: Text(dayPlan.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          subtitle: Text('${dayPlan.focus} · ${dayPlan.length}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          children: [
            if (isFriday)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.timer_outlined, color: Colors.black, size: 18),
                    label: const Text('Launch HIIT Sprint Timer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.positive,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HiitTimerScreen()),
                      );
                    },
                  ),
                ),
              ),
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dayPlan.exercises.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (ctx, exIndex) {
                final ex = dayPlan.exercises[exIndex];
                final isHiitEx = ex.name.toLowerCase().contains('hiit');

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(ex.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          ),
                          if (ex.restSec > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('${ex.restSec}s rest', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(ex.setsReps, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brandPrimary)),
                      const SizedBox(height: 2),
                      Text(ex.setup, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      if (ex.cue.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text('💡 Cue: ${ex.cue}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted)),
                      ],
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: isHiitEx
                            ? ElevatedButton.icon(
                                icon: const Icon(Icons.timer_outlined, size: 16),
                                label: const Text('Launch HIIT timer'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary, foregroundColor: AppColors.textInverse, minimumSize: const Size.fromHeight(38)),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HiitTimerScreen())),
                              )
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(foregroundColor: AppColors.brandPrimary, side: const BorderSide(color: AppColors.brandPrimary), minimumSize: const Size.fromHeight(38)),
                                onPressed: () => _showQuickSetLogger(context, ref, dayPlan.day, ex),
                                child: const Text('Log sets', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Progression Rules Accordion
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          backgroundColor: AppColors.card,
          collapsedBackgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: AppShapes.information,
            side: const BorderSide(color: AppColors.border),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: AppShapes.information,
            side: const BorderSide(color: AppColors.border),
          ),
          leading: const Icon(Icons.trending_up_rounded, color: AppColors.brandPrimary, size: 20),
          title: const Text('Progression Rules (Manual v3)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: const [
                  _ProgressionRuleRow(condition: 'Form is rough on any lift', action: 'Stay at current load — form first, always'),
                  _ProgressionRuleRow(condition: 'Hit top of rep range on all sets (2 sessions in a row)', action: 'Add smallest plate available (+2 kg) next session'),
                  _ProgressionRuleRow(condition: 'Bar maxed (26 kg) and reps still easy', action: 'Add 3-sec lowering → 2-sec pause → extra set → single-arm/single-leg variant'),
                  _ProgressionRuleRow(condition: 'Pull-ups: 4 × 10 strict reps clean', action: 'Add +2 kg via loaded backpack'),
                  _ProgressionRuleRow(condition: 'Push-ups: 3 × 25 easy', action: 'Feet on bench (decline) → one-arm negative → archer push-up'),
                  _ProgressionRuleRow(condition: '3+ weeks without strength progress', action: 'Check sleep and calorie intake first before adding volume'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showQuickSetLogger(BuildContext context, WidgetRef ref, String day, _SplitExercise ex) {
    int reps = 10;
    double weight = ex.defaultWeight;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Log: ${ex.name}', style: AppTypography.titleLarge),
                  Text('Target: ${ex.setsReps} · Rest: ${ex.restSec}s', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (ex.cue.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('💡 ${ex.cue}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted)),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Weight (kg)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: AppColors.textPrimary,
                            onPressed: weight >= 2.0 ? () => setModalState(() => weight -= 2.0) : null,
                          ),
                          Text('${weight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            color: AppColors.textPrimary,
                            onPressed: () => setModalState(() => weight += 2.0),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Reps Completed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: AppColors.textPrimary,
                            onPressed: reps > 1 ? () => setModalState(() => reps -= 1) : null,
                          ),
                          Text('$reps reps', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            color: AppColors.textPrimary,
                            onPressed: () => setModalState(() => reps += 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.textInverse,
                      ),
                      onPressed: () async {
                        final db = ref.read(databaseProvider);
                        final dateStr = ref.read(formattedSelectedDateProvider);

                        await db.addWorkoutSetLogs([
                          WorkoutSetLogsCompanion.insert(
                            id: const Uuid().v4(),
                            sessionId: 'recomp_$day',
                            date: dateStr,
                            exerciseName: ex.name,
                            setIndex: 1,
                            weightKg: weight,
                            reps: reps,
                            targetReps: Value(ex.setsReps),
                            completed: const Value(true),
                            loggedAt: Value(DateTime.now()),
                          ),
                        ]);

                        // Auto-start rest timer based on exercise category and recomp v3 blueprint rest seconds
                        ref.read(setRestTimerProvider.notifier).startFor(
                          _categoryFor(ex.name),
                          overrideSeconds: ex.restSec > 0 ? ex.restSec : null,
                        );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Logged ${ex.name} — ${weight}kg × $reps reps (${ex.restSec > 0 ? "${ex.restSec}s" : ""} Rest timer started)')),
                          );
                        }
                      },
                      child: const Text('Save Set', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProgressionRuleRow extends StatelessWidget {
  final String condition;
  final String action;

  const _ProgressionRuleRow({required this.condition, required this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.brandPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                children: [
                  TextSpan(text: '$condition: ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  TextSpan(text: action),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutHistoryTab extends StatelessWidget {
  final List<WorkoutSession> workouts;
  final VoidCallback onLogActivityTap;

  const _WorkoutHistoryTab({required this.workouts, required this.onLogActivityTap});

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center_rounded, size: 54, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('No workout sessions logged for this day.', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.textInverse,
              ),
              onPressed: onLogActivityTap,
              icon: const Icon(Icons.add),
              label: const Text('Log Workout Session', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: workouts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final w = workouts[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_run_rounded, color: AppColors.textSecondary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.activityName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Text('${w.durationMin} min · ${w.intensity.toUpperCase()} intensity · ${w.source}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${w.caloriesBurned.toInt()} kcal', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const Text('burned', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SplitDay {
  final String day;
  final String title;
  final String focus;
  final String length;
  final List<_SplitExercise> exercises;

  _SplitDay({required this.day, required this.title, required this.focus, required this.length, required this.exercises});
}

class _SplitExercise {
  final String name;
  final String setsReps;
  final String setup;
  final int restSec;
  final double defaultWeight;
  final String cue;

  _SplitExercise(this.name, this.setsReps, this.setup, this.restSec, this.defaultWeight, [this.cue = '']);
}
