import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../streaks/services/streak_service.dart';

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
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.cardElevated,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Log Activity / Cardio', style: AppTypography.titleLarge),
                  const SizedBox(height: 4),
                  const Text(
                    'Computes MET-based calorie burn using your 62kg weight.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  // Search Activities
                  TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search activity (elliptical, walking, bench, etc.)',
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
                    ),
                    onChanged: (val) async {
                      final db = ref.read(databaseProvider);
                      final res = await db.searchActivities(val);
                      setModalState(() => filteredActivities = res);
                    },
                  ),
                  const SizedBox(height: 10),

                  // Activity Selection List
                  if (filteredActivities.isNotEmpty && selectedActivity == null)
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
                        itemBuilder: (context, index) {
                          final act = filteredActivities[index];
                          return ListTile(
                            title: Text(act.name, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                            subtitle: Text('MET: ${act.metValue} · ${act.category.toUpperCase()}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            onTap: () {
                              setModalState(() {
                                selectedActivity = act;
                                durationMin = act.defaultDurationMin;
                              });
                            },
                          );
                        },
                      ),
                    ),

                  if (selectedActivity != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.emerald),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedActivity!.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setModalState(() => selectedActivity = null),
                            child: const Text('Change', style: TextStyle(color: AppColors.emerald)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Duration selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Duration (minutes)', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              color: AppColors.emerald,
                              onPressed: durationMin > 5 ? () => setModalState(() => durationMin -= 5) : null,
                            ),
                            Text('$durationMin min', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              color: AppColors.emerald,
                              onPressed: () => setModalState(() => durationMin += 5),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Intensity selector
                    const SizedBox(height: 10),
                    const Text('Intensity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      children: ['light', 'moderate', 'vigorous'].map((level) {
                        final sel = intensity == level;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Center(child: Text(level.toUpperCase())),
                              selected: sel,
                              onSelected: (_) => setModalState(() => intensity = level),
                              selectedColor: AppColors.emerald,
                              backgroundColor: AppColors.card,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: sel ? Colors.black : AppColors.textSecondary,
                              ),
                              showCheckmark: false,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),
                    // Calculated burn card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardElevated,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Estimated Calorie Burn', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              Text('$caloriesBurned kcal', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.emeraldLight)),
                            ],
                          ),
                          const Icon(Icons.local_fire_department_rounded, color: AppColors.amber, size: 28),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          final db = ref.read(databaseProvider);
                          final dateStr = ref.read(formattedSelectedDateProvider);

                          await db.addWorkoutSession(
                            WorkoutSessionsCompanion.insert(
                              id: const Uuid().v4(),
                              date: dateStr,
                              activityId: Value(selectedActivity!.id),
                              activityName: selectedActivity!.name,
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
                              SnackBar(content: Text('Logged ${selectedActivity!.name} ($caloriesBurned kcal)')),
                            );
                          }
                        },
                        child: const Text('Log Workout Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final workoutsAsync = ref.watch(dailyWorkoutsProvider);
    final setLogsAsync = ref.watch(dailySetLogsProvider);
    final dateStr = ref.watch(formattedSelectedDateProvider);
    final workouts = workoutsAsync.value ?? [];
    final totalBurnedKcal = workouts.fold<double>(0, (sum, w) => sum + w.caloriesBurned).toInt();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(dateStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Hero Calorie Burned Card (Screenshot 3)
                    Container(
                      padding: const EdgeInsets.all(18),
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
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.directions_run_rounded, color: AppColors.cyan, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$totalBurnedKcal of 361',
                                  style: AppTypography.displayMedium.copyWith(fontSize: 22, fontWeight: FontWeight.w900),
                                ),
                                const Text(
                                  'Cal Burnt',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.bar_chart_rounded, color: AppColors.cyan),
                            onPressed: () {},
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add_rounded, color: AppColors.cyan, size: 22),
                              onPressed: _showActivityLoggerDialog,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 2. Health Connect Auto-Sync Row (Screenshot 3)
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
                              color: const Color(0xFFF97316).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                '0',
                                style: TextStyle(color: Color(0xFFFB923C), fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Others (Health Connect)',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '221 Steps, Other Activities',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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

                    // 3. My Workout Routine Section (Screenshot 3)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('My Workout Routine', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        Text('VIEW ALL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emerald)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Horizontal Cards Carousel
                    SizedBox(
                      height: 130,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // Card 1: Subicharan's Routine
                          InkWell(
                            onTap: () {
                              _tabController.animateTo(0);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 220,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF1E293B),
                                    const Color(0xFF0F172A).withOpacity(0.9),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: const [
                                  Icon(Icons.fitness_center_rounded, color: AppColors.emeraldLight, size: 24),
                                  Spacer(),
                                  Text(
                                    'Subicharan\'s Routine',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Designed for you · 4-Day Recomp',
                                    style: TextStyle(fontSize: 11, color: AppColors.emeraldLight),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Card 2: Quick Workouts @ Home
                          InkWell(
                            onTap: () => _showActivityLoggerDialog(),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 200,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF263040),
                                    const Color(0xFF161C24).withOpacity(0.9),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: const [
                                  Icon(Icons.bolt_rounded, color: AppColors.amber, size: 24),
                                  Spacer(),
                                  Text(
                                    'Quick Workouts @ Home',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Busy? 20-min session',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                  indicatorColor: AppColors.emerald,
                  labelColor: AppColors.emerald,
                  unselectedLabelColor: AppColors.textMuted,
                  tabs: const [
                    Tab(text: 'Recomp Split (Sets & Reps)'),
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
        backgroundColor: AppColors.emerald,
        foregroundColor: Colors.black,
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


class _RecompSplitTab extends ConsumerWidget {
  final List<WorkoutSetLog> setLogs;

  const _RecompSplitTab({required this.setLogs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitDays = [
      _SplitDay(
        day: 'Mon',
        title: 'Push + HIIT + Core',
        focus: 'Chest, Shoulders, Triceps',
        length: '~55–65 min',
        exercises: [
          _SplitExercise('Barbell bench press', '4 × 8–10', 'Long bar, build toward ~26 kg. 3-sec lowering', 90, 24.0),
          _SplitExercise('Overhead press', '3 × 8–12', 'EZ bar or long bar, seated or standing', 90, 16.0),
          _SplitExercise('Incline DB press', '3 × 10–12', 'Bench at 30–45°, ~9.5 kg/hand', 75, 9.5),
          _SplitExercise('EZ bar skullcrushers', '3 × 10–15', 'EZ bar, light load', 60, 8.0),
          _SplitExercise('Push-up burnout', '1 × failure', 'Feet on bench once bodyweight is easy', 60, 0.0),
          _SplitExercise('HIIT — elliptical', '8 rounds', '30s sprint (L5-7) / 30s recovery (L1-2)', 30, 0.0),
          _SplitExercise('Core finisher', 'Plank 5×1m + leg raises 3×15', 'Mat', 45, 0.0),
        ],
      ),
      _SplitDay(
        day: 'Tue',
        title: 'Pull',
        focus: 'Back, Biceps',
        length: '~45–50 min',
        exercises: [
          _SplitExercise('Pull-ups', '4 × max', 'Bodyweight — log every set (8/6/5/4 style)', 120, 0.0),
          _SplitExercise('Barbell rows', '4 × 8–12', 'Long bar, bent-over, up to ~26 kg', 90, 22.0),
          _SplitExercise('DB bicep curls', '3 × 10–12', 'Dumbbells ~9.5 kg/hand', 60, 9.5),
          _SplitExercise('Hammer curls', '3 × 10–12', 'EZ bar or dumbbells', 60, 9.5),
          _SplitExercise('Band pull-aparts', '3 × 15–20', 'Resistance band, arms straight', 45, 0.0),
        ],
      ),
      _SplitDay(
        day: 'Wed',
        title: 'Zone 2 + Core',
        focus: 'Conditioning',
        length: '~35 min',
        exercises: [
          _SplitExercise('Elliptical, steady state', '25–30 min', 'Level 2–3, conversational pace', 0, 0.0),
          _SplitExercise('Plank', '3 × 30–45s', 'Mat', 45, 0.0),
          _SplitExercise('Leg raises', '3 × 12–15', 'Lying or hanging', 45, 0.0),
        ],
      ),
      _SplitDay(
        day: 'Thu',
        title: 'Legs',
        focus: 'Quads, Hamstrings, Calves',
        length: '~50–55 min',
        exercises: [
          _SplitExercise('Barbell back squat', '4 × 8–10', 'Long bar, up to ~26 kg', 120, 26.0),
          _SplitExercise('Romanian deadlift', '3 × 10–12', 'Long bar', 90, 24.0),
          _SplitExercise('DB walking lunges', '3 × 12/leg', 'Dumbbells ~9.5 kg/hand', 75, 9.5),
          _SplitExercise('Standing calf raises', '4 × 15–20', 'Bodyweight, add DB once easy', 45, 0.0),
          _SplitExercise('Goblet squat finisher', '2 × 15–20', 'Single dumbbell ~19 kg at chest', 60, 19.0),
        ],
      ),
      _SplitDay(
        day: 'Fri',
        title: 'Core + HIIT',
        focus: 'Abs, Shoulders, Conditioning',
        length: '~35–40 min',
        exercises: [
          _SplitExercise('Plank', '3 × max hold', 'Mat', 60, 0.0),
          _SplitExercise('Hanging leg raises', '3 × 12–15', 'Pull-up bar', 60, 0.0),
          _SplitExercise('Lateral raises', '4 × 15', 'Light dumbbells, 2–2.5 kg/hand', 45, 2.5),
          _SplitExercise('Wrist curls', '3 × 15–20', 'Light dumbbell or band', 30, 4.0),
          _SplitExercise('HIIT — elliptical', '6 rounds', '30s sprint / 30s recovery', 30, 0.0),
        ],
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: splitDays.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final dayPlan = splitDays[index];

        return ExpansionTile(
          initiallyExpanded: index == 0,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          backgroundColor: AppColors.card,
          collapsedBackgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.emerald.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              dayPlan.day,
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.emerald, fontSize: 14),
            ),
          ),
          title: Text(dayPlan.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          subtitle: Text('${dayPlan.focus} · ${dayPlan.length}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          children: [
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dayPlan.exercises.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (ctx, exIndex) {
                final ex = dayPlan.exercises[exIndex];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ex.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text('${ex.setsReps} · Setup: ${ex.setup}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            if (ex.restSec > 0)
                              Text('Rest: ${ex.restSec}s', style: const TextStyle(fontSize: 11, color: AppColors.amber)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cardElevated,
                          foregroundColor: AppColors.emerald,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _showQuickSetLogger(context, ref, dayPlan.day, ex),
                        child: const Text('Log Sets', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
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
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Weight (kg)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: AppColors.emerald,
                            onPressed: weight >= 2.0 ? () => setModalState(() => weight -= 2.0) : null,
                          ),
                          Text('${weight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            color: AppColors.emerald,
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
                            color: AppColors.emerald,
                            onPressed: reps > 1 ? () => setModalState(() => reps -= 1) : null,
                          ),
                          Text('$reps reps', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            color: AppColors.emerald,
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
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald),
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

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Logged ${ex.name} — ${weight}kg × $reps reps')),
                          );
                        }
                      },
                      child: const Text('Save Set', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald),
              onPressed: onLogActivityTap,
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('Log Workout Session', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
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
                  color: AppColors.emerald.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_run_rounded, color: AppColors.emerald, size: 24),
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
                  Text('${w.caloriesBurned.toInt()} kcal', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.amberLight)),
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

  _SplitExercise(this.name, this.setsReps, this.setup, this.restSec, this.defaultWeight);
}
