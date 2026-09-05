import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../../features/food_logging/presentation/screens/log_food_screen.dart';
import '../../features/workouts/presentation/screens/workouts_screen.dart';
import '../../features/weight_progress/presentation/screens/weight_screen.dart';
import '../../features/recipes/presentation/screens/recipes_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.emerald.withOpacity(0.2),
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: AppColors.textMuted),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.emerald),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_outlined, color: AppColors.textMuted),
              selectedIcon: Icon(Icons.restaurant_rounded, color: AppColors.emerald),
              label: 'Log',
            ),
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined, color: AppColors.textMuted),
              selectedIcon: Icon(Icons.fitness_center_rounded, color: AppColors.emerald),
              label: 'Train',
            ),
            NavigationDestination(
              icon: Icon(Icons.trending_up_rounded, color: AppColors.textMuted),
              selectedIcon: Icon(Icons.trending_up_rounded, color: AppColors.emerald),
              label: 'Progress',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded, color: AppColors.textMuted),
              selectedIcon: Icon(Icons.grid_view_rounded, color: AppColors.emerald),
              label: 'More',
            ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('More & Tools'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MenuTile(
            title: 'Personal Recipe Box',
            subtitle: 'Tamil Nadu dry-packs & chicken curries pre-seeded',
            icon: Icons.menu_book_rounded,
            color: AppColors.amber,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecipesScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _MenuTile(
            title: 'Macro Source Breakdown',
            subtitle: 'Attribution analysis for protein & carb sources',
            icon: Icons.pie_chart_rounded,
            color: AppColors.coral,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _MenuTile(
            title: 'Settings & Daily Targets',
            subtitle: 'Calorie budget, protein targets, and equipment setup',
            icon: Icons.settings_rounded,
            color: AppColors.emerald,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
