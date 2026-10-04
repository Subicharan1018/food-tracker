import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/scoreboard.dart';
import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../../features/food_logging/presentation/screens/log_food_screen.dart';
import '../../features/workouts/presentation/screens/workouts_screen.dart';
import '../../features/weight_progress/presentation/screens/weight_screen.dart';
import '../../features/recipes/presentation/screens/recipes_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/macro_breakdown/presentation/screens/macro_source_screen.dart';
import '../../features/sleep/presentation/screens/sleep_screen.dart';
import '../../features/steps_activity/presentation/screens/steps_screen.dart';
import '../../features/shopping_cart/shopping_cart_screen.dart';
import '../../features/pantry/pantry_screen.dart';
import '../../features/checkin/checkin_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    LogFoodScreen(initialMealSlot: 'breakfast'),
    WorkoutsScreen(),
    WeightProgressScreen(),
    MoreMenuScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          elevation: 0,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'HOME'),
            NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: 'LOG'),
            NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'TRAIN'),
            NavigationDestination(icon: Icon(Icons.show_chart_outlined), selectedIcon: Icon(Icons.show_chart), label: 'PROGRESS'),
            NavigationDestination(icon: Icon(Icons.menu), selectedIcon: Icon(Icons.menu_open), label: 'MORE'),
          ],
        ),
      ),
    );
  }
}

class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void go(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(titleSpacing: AppShapes.gutter, title: const Text('MORE')),
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 32),
        children: [
          Board(
            label: 'Body',
            child: Column(children: [
              _MenuRow(title: 'Check-in & photos', detail: 'Sunday weigh-in · progress photo · tape every 4 weeks', onTap: () => go(const CheckInScreen())),
              _MenuRow(title: 'Sleep', detail: 'Last nights from Health Connect · your schedule', onTap: () => go(const SleepScreen())),
              _MenuRow(title: 'Steps', detail: 'Today and the 7-day trend', onTap: () => go(const StepsScreen()), last: true),
            ]),
          ),
          Board(
            label: 'Kitchen',
            child: Column(children: [
              _MenuRow(title: 'Shopping', detail: "Your list · this week's nutrient gaps", onTap: () => go(const ShoppingCartScreen())),
              _MenuRow(title: 'Pantry', detail: 'What you have — the weekly ceiling is computed from it', onTap: () => go(const PantryScreen())),
              _MenuRow(title: 'Recipes', detail: 'Your recipe box · add one by pasting it', onTap: () => go(const RecipesScreen())),
              _MenuRow(title: 'Macro sources', detail: 'Which foods your protein and carbs came from', onTap: () => go(const MacroSourceScreen()), last: true),
            ]),
          ),
          Board(
            label: 'App',
            child: _MenuRow(title: 'Settings & targets', detail: 'Calories, protein, sync, export', onTap: () => go(const SettingsScreen()), last: true),
          ),
        ],
      ),
    );
  }
}

/// A navigation row: name in condensed caps, one line of what's inside.
class _MenuRow extends StatelessWidget {
  final String title;
  final String detail;
  final VoidCallback onTap;
  final bool last;

  const _MenuRow({required this.title, required this.detail, required this.onTap, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title.toUpperCase(), style: AppTypography.label.copyWith(fontSize: 19, color: AppColors.textPrimary)),
                      const SizedBox(height: 3),
                      Text(detail, style: AppTypography.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
        if (!last) const Divider(height: 1),
      ],
    );
  }
}
