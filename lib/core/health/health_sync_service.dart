import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

class HealthActivitySummary {
  final int steps;
  final int activeCalories;
  final List<String> workouts;
  final bool isConnected;

  const HealthActivitySummary({
    this.steps = 0,
    this.activeCalories = 0,
    this.workouts = const [],
    this.isConnected = true,
  });
}

class HealthSyncService {
  final Health _health = Health();
  bool _isConfigured = false;
  bool _hasPermissions = false;

  static final List<HealthDataType> _dataTypes = [
    HealthDataType.STEPS,
    HealthDataType.WORKOUT,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.TOTAL_CALORIES_BURNED,
  ];

  Future<void> initialize() async {
    try {
      await _health.configure();
      _isConfigured = true;
    } catch (e) {
      debugPrint('Health Connect configure notice: $e');
      _isConfigured = false;
    }
  }

  Future<HealthConnectSdkStatus?> getSdkStatus() async {
    try {
      return await _health.getHealthConnectSdkStatus();
    } catch (e) {
      debugPrint('Error getting Health Connect SDK status: $e');
      return null;
    }
  }

  Future<void> installHealthConnect() async {
    try {
      await _health.installHealthConnect();
    } catch (e) {
      debugPrint('Error launching Health Connect installation: $e');
    }
  }

  Future<bool> requestPermissions() async {
    if (!_isConfigured) {
      await initialize();
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await _health.getHealthConnectSdkStatus();
        if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
          await _health.installHealthConnect();
          return false;
        }
      }

      final permissions = _dataTypes.map((_) => HealthDataAccess.READ).toList();
      final granted = await _health.requestAuthorization(
        _dataTypes,
        permissions: permissions,
      );
      _hasPermissions = granted;
      return granted;
    } catch (e) {
      debugPrint('Health request permissions exception: $e');
      _hasPermissions = false;
      return false;
    }
  }

  Future<bool> checkConnectionStatus() async {
    if (!_isConfigured) {
      await initialize();
    }
    try {
      final hasPerm = await _health.hasPermissions(_dataTypes);
      return hasPerm ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<int> fetchTodaySteps() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      final steps = await _health.getTotalStepsInInterval(midnight, now);
      if (steps != null && steps > 0) {
        return steps;
      }
    } catch (e) {
      debugPrint('Error fetching steps from Health Connect: $e');
    }
    return 0;
  }

  /// Returns 7-day daily step history for the Steps Trend BarChart
  Future<List<DailyStepRecord>> fetch7DayStepsTrend() async {
    final now = DateTime.now();
    final List<DailyStepRecord> trend = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      int steps = 0;
      try {
        final count = await _health.getTotalStepsInInterval(dayStart, dayEnd);
        if (count != null && count > 0) {
          steps = count;
        }
      } catch (_) {}

      trend.add(DailyStepRecord(date: dayStart, steps: steps));
    }

    return trend;
  }

  /// Fetch active workouts recorded by wearable/phone
  Future<List<String>> fetchTodayWorkouts() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: midnight,
        endTime: now,
      );
      if (data.isNotEmpty) {
        return data.map((d) => d.value.toString()).toList();
      }
    } catch (e) {
      debugPrint('Error reading workouts from Health Connect: $e');
    }
    return [];
  }
}

class DailyStepRecord {
  final DateTime date;
  final int steps;

  const DailyStepRecord({required this.date, required this.steps});
}
