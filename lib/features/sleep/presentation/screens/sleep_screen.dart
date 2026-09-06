import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';

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
  TimeOfDay _sleepTime = const TimeOfDay(hour: 23, minute: 30); // 11:30 PM
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 30);  // 07:30 AM
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedTimes();
  }

  Future<void> _loadSavedTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final sleepHour = prefs.getInt('sleep_time_hour') ?? 23;
    final sleepMin = prefs.getInt('sleep_time_minute') ?? 30;
    final wakeHour = prefs.getInt('wake_time_hour') ?? 7;
    final wakeMin = prefs.getInt('wake_time_minute') ?? 30;

    if (mounted) {
      setState(() {
        _sleepTime = TimeOfDay(hour: sleepHour, minute: sleepMin);
        _wakeTime = TimeOfDay(hour: wakeHour, minute: wakeMin);
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTimes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sleep_time_hour', _sleepTime.hour);
    await prefs.setInt('sleep_time_minute', _sleepTime.minute);
    await prefs.setInt('wake_time_hour', _wakeTime.hour);
    await prefs.setInt('wake_time_minute', _wakeTime.minute);

    final duration = SleepEngine.computeSleepDurationMinutes(
      sleepHour: _sleepTime.hour,
      sleepMinute: _sleepTime.minute,
      wakeHour: _wakeTime.hour,
      wakeMinute: _wakeTime.minute,
    );
    await prefs.setInt('sleep_target_minutes', duration);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sleep schedule saved: ${SleepEngine.formatDuration(duration)} daily goal!')),
      );
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final min = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    final hourStr = hour.toString().padLeft(2, '0');
    return '$hourStr:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    final totalMinutes = SleepEngine.computeSleepDurationMinutes(
      sleepHour: _sleepTime.hour,
      sleepMinute: _sleepTime.minute,
      wakeHour: _wakeTime.hour,
      wakeMinute: _wakeTime.minute,
    );
    final durationStr = SleepEngine.formatDuration(totalMinutes);

    return Scaffold(
      backgroundColor: const Color(0xFF070D1A), // Dark Midnight Navy
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Setup your Sleep Tracker',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 30),

                  // Hero Duration (Screenshot 4)
                  Text(
                    durationStr,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Sleep Goal - Recommended',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4ADE80), // Emerald Green
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '7–9 hours is the recommended amount of sleep for all adults from age 18–64, according to the sleepfoundation.org',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                        height: 1.45,
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  // Schedule Pickers (Screenshot 4)
                  Row(
                    children: [
                      // Regular Sleep Time Card
                      Expanded(
                        child: Column(
                          children: [
                            const Text('🌙', style: TextStyle(fontSize: 28)),
                            const SizedBox(height: 16),
                            Text(
                              _formatTimeOfDay(_sleepTime),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Regular Sleep Time',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _sleepTime,
                                );
                                if (picked != null) {
                                  setState(() => _sleepTime = picked);
                                }
                              },
                              child: const Text(
                                'EDIT',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF60A5FA),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Divider Line
                      Container(
                        height: 90,
                        width: 1,
                        color: const Color(0xFF1E293B),
                      ),

                      // Regular Wake Time Card
                      Expanded(
                        child: Column(
                          children: [
                            const Text('⛅', style: TextStyle(fontSize: 28)),
                            const SizedBox(height: 16),
                            Text(
                              _formatTimeOfDay(_wakeTime),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Regular Wake Time',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _wakeTime,
                                );
                                if (picked != null) {
                                  setState(() => _wakeTime = picked);
                                }
                              },
                              child: const Text(
                                'EDIT',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF60A5FA),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // DONE Button (Screenshot 4)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6), // Vibrant Blue
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _saveTimes,
                      child: const Text(
                        'DONE',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
