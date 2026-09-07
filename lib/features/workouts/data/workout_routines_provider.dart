import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/workout_routine.dart';

final workoutRoutinesProvider = Provider<List<WorkoutRoutine>>((ref) {
  return const [
    WorkoutRoutine(
      id: 'routine_recomp_4day',
      name: 'Custom Recomp Routine',
      subtitle: 'Designed for you · 4-Day Recomp',
      category: 'Strength & Hypertrophy',
      daysPerWeek: 4,
      icon: Icons.fitness_center_rounded,
      isCustom: true,
    ),
    WorkoutRoutine(
      id: 'routine_quick_home',
      name: 'Quick Workouts @ Home',
      subtitle: 'Busy? 20-min dumbbell/bodyweight session',
      category: 'Conditioning & HIIT',
      daysPerWeek: 3,
      icon: Icons.bolt_rounded,
      isCustom: false,
    ),
  ];
});

/// Configurable daily workout calorie burn target (kcal)
const int defaultDailyBurnTargetKcal = 400;

final dailyBurnTargetProvider = Provider<int>((ref) {
  return defaultDailyBurnTargetKcal;
});
