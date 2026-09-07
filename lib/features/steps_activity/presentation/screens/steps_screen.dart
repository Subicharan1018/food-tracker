import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:health/health.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/health/health_sync_service.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/theme/app_theme.dart';

class StepsScreen extends ConsumerStatefulWidget {
  const StepsScreen({super.key});

  @override
  ConsumerState<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends ConsumerState<StepsScreen> {
  int _todaySteps = 0;
  bool _isRefreshing = false;
  List<DailyStepRecord> _trendData = [];

  @override
  void initState() {
    super.initState();
    _loadStepsData();
  }

  Future<void> _loadStepsData() async {
    setState(() => _isRefreshing = true);
    final healthService = ref.read(healthSyncServiceProvider);
    final steps = await healthService.fetchTodaySteps();
    final trend = await healthService.fetch7DayStepsTrend();

    if (mounted) {
      setState(() {
        _todaySteps = steps;
        _trendData = trend;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _requestHealthConnectPermissions() async {
    setState(() => _isRefreshing = true);
    final healthService = ref.read(healthSyncServiceProvider);

    final status = await healthService.getSdkStatus();
    if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Google Health Connect is not installed. Opening Play Store...'),
            action: SnackBarAction(
              label: 'Install',
              onPressed: () => healthService.installHealthConnect(),
            ),
          ),
        );
      }
      await healthService.installHealthConnect();
      if (mounted) setState(() => _isRefreshing = false);
      return;
    }

    final granted = await healthService.requestPermissions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(granted
              ? 'Connected to Health Connect! Steps synced.'
              : 'Health Connect permission not granted. Please enable in Health Connect.'),
          backgroundColor: granted ? AppColors.positive.withOpacity(0.15) : AppColors.cardElevated,
        ),
      );
    }
    await _loadStepsData();
  }

  void _showEditGoalDialog(int currentGoal) {
    final ctrl = TextEditingController(text: '$currentGoal');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Edit Daily Step Goal', style: AppTypography.titleLarge),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Target Steps',
            suffixText: 'steps',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final newGoal = int.tryParse(ctrl.text);
              if (newGoal != null && newGoal > 0) {
                final db = ref.read(databaseProvider);
                final user = await db.getUserProfile();
                if (user != null) {
                  await db.saveUserProfile(
                    UsersCompanion(
                      id: const Value('default_user'),
                      stepsTarget: Value(newGoal),
                      updatedAt: Value(DateTime.now()),
                    ),
                  );
                }
              }
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Step goal updated!')),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final stepGoal = userAsync.value?.stepsTarget ?? defaultDailyStepsTarget;
    final selectedDate = ref.watch(selectedDateProvider);
    final dateDisplay = DateFormat('MMM d, yyyy').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(dateDisplay, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Primary Steps Hero
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$_todaySteps',
                            style: AppTypography.displayLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 34,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'of ${NumberFormat("#,###").format(stepGoal)} steps',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.positive,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${((_todaySteps / stepGoal) * 100).toStringAsFixed(1)}% of daily goal reached',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.positive),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                  onPressed: () => _showEditGoalDialog(stepGoal),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Connection Status Row
          InkWell(
            onTap: _isRefreshing ? null : _requestHealthConnectPermissions,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'You are connected to',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'TAP TO SYNC / CONNECT',
                        style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.favorite_rounded, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Health Connect',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: _isRefreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : const Icon(Icons.sync_rounded, color: AppColors.primary, size: 22),
                        onPressed: _isRefreshing ? null : _requestHealthConnectPermissions,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 3. Reminder Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Reminder',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Evening step goal reminder set for 8:00 PM')),
                    );
                  },
                  child: const Text('SET', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. Today's Tip Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.attention.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_walk_rounded, color: AppColors.attention, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Today’s Tip',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Take it Outdoors. Bring some change in the scenery, head outdoors! This will also bring some changes in the ground surface, thus giving your body a bit more of a challenge than on a treadmill.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 5. Daily Steps Trend Bar Chart
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Daily Steps Trend',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Last 7 days',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 220,
                  child: _trendData.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: 14000,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  return BarTooltipItem(
                                    '${rod.toY.toInt()} steps',
                                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (val, meta) {
                                    final index = val.toInt();
                                    if (index < 0 || index >= _trendData.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final d = _trendData[index].date;
                                    final dayName = DateFormat('E').format(d);
                                    final dayNum = DateFormat('d').format(d);
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(dayName, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                          Text(dayNum, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              checkToShowHorizontalLine: (value) => value == stepGoal.toDouble(),
                              getDrawingHorizontalLine: (val) {
                                return FlLine(
                                  color: AppColors.textMuted.withOpacity(0.5),
                                  strokeWidth: 1.5,
                                  dashArray: [5, 5],
                                );
                              },
                            ),
                            borderData: FlBorderData(show: false),
                            extraLinesData: ExtraLinesData(
                              horizontalLines: [
                                HorizontalLine(
                                  y: stepGoal.toDouble(),
                                  color: AppColors.textMuted,
                                  strokeWidth: 1.2,
                                  dashArray: [4, 4],
                                  label: HorizontalLineLabel(
                                    show: true,
                                    alignment: Alignment.topLeft,
                                    padding: const EdgeInsets.only(bottom: 4),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                                    labelResolver: (_) => 'GOAL',
                                  ),
                                ),
                              ],
                            ),
                            barGroups: List.generate(_trendData.length, (idx) {
                              final item = _trendData[idx];
                              final isMet = item.steps >= stepGoal;
                              return BarChartGroupData(
                                x: idx,
                                barRods: [
                                  BarChartRodData(
                                    toY: item.steps.toDouble(),
                                    color: isMet ? AppColors.positive : AppColors.primary,
                                    width: 22,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                  ),
                                ],
                                showingTooltipIndicators: [],
                              );
                            }),
                          ),
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 6. Rate / Feedback Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Rate Steps Tracker',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Share your feedback & help us improve',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star_rounded, color: AppColors.primary, size: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
