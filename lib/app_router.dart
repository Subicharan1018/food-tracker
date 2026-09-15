import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/ai_digest/weekly_digest_card.dart';
import 'features/workouts/hiit/hiit_timer_screen.dart';
import 'features/workouts/progression_card.dart';
import 'shared/screens/main_nav_screen.dart';
import 'core/theme/app_theme.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainNavScreen(),
    ),
    GoRoute(
      path: '/workout/hiit',
      builder: (context, state) => const HiitTimerScreen(),
    ),
    GoRoute(
      path: '/workout/progression',
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Workout Progression')),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: SingleChildScrollView(child: WorkoutProgressionCard()),
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/digest/:week',
      builder: (context, state) {
        final week = state.pathParameters['week'] ?? calculateIsoWeek();
        return Scaffold(
          appBar: AppBar(title: Text('Weekly Digest ($week)')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: WeeklyDigestCard(weekOverride: week),
              ),
            ),
          ),
        );
      },
    ),
  ],
);
