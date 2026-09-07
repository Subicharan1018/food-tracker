import 'package:flutter/material.dart';

class WorkoutRoutine {
  final String id;
  final String name;
  final String subtitle;
  final String category;
  final int daysPerWeek;
  final IconData icon;
  final bool isCustom;

  const WorkoutRoutine({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.category,
    required this.daysPerWeek,
    this.icon = Icons.fitness_center_rounded,
    this.isCustom = false,
  });
}
