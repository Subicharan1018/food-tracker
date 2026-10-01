import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/ledger.dart';

class SleepEngine {
  /// Computes duration in minutes between bedtime and wake-up time,
  /// accurately handling midnight boundary crossings.
  static int computeSleepDurationMinutes({
    required int sleepHour,
    required int sleepMinute,
    required int wakeHour,
    required int wakeMinute,
  }) {
    final sleepTotalMinutes = sleepHour * 60 + sleepMinute;
    final wakeTotalMinutes = wakeHour * 60 + wakeMinute;

    if (wakeTotalMinutes >= sleepTotalMinutes) {
      return wakeTotalMinutes - sleepTotalMinutes;
    } else {
      // Crosses midnight (e.g. 23:30 to 07:30)
      return (24 * 60 - sleepTotalMinutes) + wakeTotalMinutes;
    }
  }

  static String formatDuration(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return '${hours}h ${mins}m';
  }
}

class SleepScreen extends ConsumerStatefulWidget {
  const SleepScreen({super.key});

  @override
  ConsumerState<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends ConsumerState<SleepScreen> {
  TimeOfDay _sleepTime = const TimeOfDay(hour: 23, minute: 30);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 30);
  bool _connected = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _loadSavedTimes();
    _refresh();
  }

  Future<void> _loadSavedTimes() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sleepTime = TimeOfDay(hour: prefs.getInt('sleep_time_hour') ?? 23, minute: prefs.getInt('sleep_time_minute') ?? 30);
      _wakeTime = TimeOfDay(hour: prefs.getInt('wake_time_hour') ?? 7, minute: prefs.getInt('wake_time_minute') ?? 30);
    });
  }

  Future<void> _refresh({bool askPermission = false}) async {
    setState(() => _importing = true);
    final health = ref.read(healthSyncServiceProvider);
    var connected = await health.checkConnectionStatus();
    if (!connected && askPermission) connected = await health.requestPermissions();
    if (connected) {
      final changed = await health.importSleep(ref.read(databaseProvider));
      if (changed > 0) ref.read(syncSchedulerProvider).scheduleSync();
    }
    if (mounted) {
      setState(() {
        _connected = connected;
        _importing = false;
      });
    }
  }

  Future<void> _saveTimes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sleep_time_hour', _sleepTime.hour);
    await prefs.setInt('sleep_time_minute', _sleepTime.minute);
    await prefs.setInt('wake_time_hour', _wakeTime.hour);
    await prefs.setInt('wake_time_minute', _wakeTime.minute);
    await prefs.setInt('sleep_target_minutes', _goalMinutes);
  }

  int get _goalMinutes => SleepEngine.computeSleepDurationMinutes(
        sleepHour: _sleepTime.hour,
        sleepMinute: _sleepTime.minute,
        wakeHour: _wakeTime.hour,
        wakeMinute: _wakeTime.minute,
      );

  Future<void> _pick(bool bedtime) async {
    final picked = await showTimePicker(context: context, initialTime: bedtime ? _sleepTime : _wakeTime);
    if (picked == null) return;
    setState(() => bedtime ? _sleepTime = picked : _wakeTime = picked);
    await _saveTimes();
  }

  @override
  Widget build(BuildContext context) {
    final nights = ref.watch(recentSleepProvider).value ?? const <SleepLog>[];
    final week = nights.take(7).toList();
    final average = week.isEmpty ? null : week.fold<int>(0, (sum, n) => sum + n.minutes) ~/ week.length;
    final goal = _goalMinutes;

    return Scaffold(
      appBar: AppBar(title: const Text('Sleep')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nights.isEmpty ? '–' : SleepEngine.formatDuration(nights.first.minutes),
                    style: const TextStyle(
                      fontSize: 40,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                      color: AppColors.textPrimary,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    nights.isEmpty
                        ? (_connected ? 'No sleep recorded in Health Connect yet.' : 'Health Connect sleep access is off.')
                        : 'Last night · 7-night average ${SleepEngine.formatDuration(average!)} · goal ${SleepEngine.formatDuration(goal)}',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFeatures: tabularFigures),
                  ),
                  if (!_connected) ...[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _importing ? null : () => _refresh(askPermission: true),
                      child: const Text('Allow sleep access'),
                    ),
                  ],
                ],
              ),
            ),
            if (nights.isNotEmpty) ...[
              SectionHeader(title: 'Recent nights', detail: _importing ? 'updating…' : null),
              for (final night in nights) ...[
                _NightRow(night: night, goalMinutes: goal),
                const Hairline(),
              ],
            ],
            const SectionHeader(title: 'Your schedule'),
            _TimeRow(label: 'Bedtime', time: _sleepTime, onTap: () => _pick(true)),
            const Hairline(),
            _TimeRow(label: 'Wake up', time: _wakeTime, onTap: () => _pick(false)),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                'Adults 18–64 are recommended 7–9 hours (sleepfoundation.org). Nights come from Health Connect, '
                'so a watch or sleep app needs to be writing there. Pull down to refresh.',
                style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NightRow extends StatelessWidget {
  final SleepLog night;
  final int goalMinutes;
  const _NightRow({required this.night, required this.goalMinutes});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(night.date);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final short = night.minutes < goalMinutes - 30;
    String hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text('${days[date.weekday - 1]} ${date.day}',
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              ),
              Expanded(
                child: Text('${hm(night.bedtime)} – ${hm(night.wakeTime)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontFeatures: tabularFigures)),
              ),
              Text(
                SleepEngine.formatDuration(night.minutes),
                style: TextStyle(
                  fontSize: 14,
                  color: short ? AppColors.attention : AppColors.textPrimary,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Meter(fraction: goalMinutes == 0 ? 0 : night.minutes / goalMinutes, color: short ? AppColors.attention : AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeRow({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary))),
            Text(time.format(context), style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontFeatures: tabularFigures)),
          ],
        ),
      ),
    );
  }
}
