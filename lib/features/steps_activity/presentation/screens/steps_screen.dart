import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:health/health.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/health/health_sync_service.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/scoreboard.dart';

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
            content: const Text('Google Health Connect is not installed. Opening Play Store…'),
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
          backgroundColor: granted ? AppColors.positive.withValues(alpha: 0.15) : AppColors.cardElevated,
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
        title: Text('Edit Daily Step Goal', style: AppTypography.titleLarge),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.textInverse,
            ),
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
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Step goal updated!')),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: AppColors.textInverse, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(userProfileProvider).value?.stepsTarget ?? defaultDailyStepsTarget;
    final fmt = NumberFormat.decimalPattern();
    final best = _trendData.isEmpty ? 0 : _trendData.map((d) => d.steps).reduce((a, b) => a > b ? a : b);
    final daysMet = _trendData.where((d) => d.steps >= goal).length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppShapes.gutter,
        title: const Text('STEPS'),
        actions: [
          IconButton(
            tooltip: 'Refresh from Health Connect',
            onPressed: _isRefreshing ? null : _loadStepsData,
            icon: const Icon(Icons.refresh, size: 20),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.brandPrimary,
        onRefresh: _loadStepsData,
        child: ListView(
          padding: const EdgeInsets.only(top: 4, bottom: 32),
          children: [
            Board(
              label: 'Today',
              trailing: TextButton(
                onPressed: () => _showEditGoalDialog(goal),
                child: Text('GOAL ${fmt.format(goal)} · EDIT', style: AppTypography.label.copyWith(color: AppColors.brandPrimary)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BigNumber(fmt.format(_todaySteps), unit: 'steps'),
                  const SizedBox(height: 14),
                  SegmentMeter(
                    fraction: goal == 0 ? 0 : _todaySteps / goal,
                    color: AppColors.brandPrimary,
                    overColor: AppColors.positive,
                    segments: 30,
                    height: 12,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _todaySteps >= goal ? 'GOAL MET' : '${fmt.format(goal - _todaySteps)} TO GO',
                    style: AppTypography.dataSmall.copyWith(color: _todaySteps >= goal ? AppColors.positive : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Board(
              label: 'Last 7 days',
              trailing: Text('GOAL MET $daysMet/7', style: AppTypography.dataSmall),
              child: _trendData.isEmpty
                  ? Text(_isRefreshing ? 'Reading Health Connect…' : 'No step history yet.', style: AppTypography.bodyMedium)
                  : Column(
                      children: [
                        for (final day in _trendData.reversed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 72,
                                  child: Text(
                                    DateFormat('EEE d').format(day.date).toUpperCase(),
                                    style: AppTypography.label.copyWith(fontSize: 13, color: AppColors.textPrimary),
                                  ),
                                ),
                                SizedBox(
                                  width: 64,
                                  child: Text(fmt.format(day.steps), style: AppTypography.data, textAlign: TextAlign.right),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SegmentMeter(
                                    fraction: best == 0 ? 0 : day.steps / (goal > best ? goal : best),
                                    color: day.steps >= goal ? AppColors.positive : AppColors.textSecondary,
                                    segments: 20,
                                    height: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            Board(
              label: 'Source',
              trailing: TextButton(
                onPressed: _isRefreshing ? null : _requestHealthConnectPermissions,
                child: Text('CONNECT / RE-SYNC', style: AppTypography.label.copyWith(color: AppColors.brandPrimary)),
              ),
              child: Text(
                'Steps come from Health Connect — your phone or watch writes them there; Kinetik only reads.',
                style: AppTypography.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
