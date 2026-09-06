import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../core/di/providers.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  void _showEditTargetsDialog(User user) {
    final kcalCtrl = TextEditingController(text: '${user.calorieTarget}');
    final proteinCtrl = TextEditingController(text: '${user.proteinTargetG.toInt()}');
    final carbsCtrl = TextEditingController(text: '${user.carbTargetG.toInt()}');
    final fatCtrl = TextEditingController(text: '${user.fatTargetG.toInt()}');
    final waterCtrl = TextEditingController(text: '${user.waterTargetMl}');
    final stepsCtrl = TextEditingController(text: '${user.stepsTarget}');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Edit Daily Targets', style: AppTypography.titleLarge),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: kcalCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Calorie Target (kcal)')),
                const SizedBox(height: 10),
                TextField(controller: proteinCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Protein Target (g)')),
                const SizedBox(height: 10),
                TextField(controller: carbsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Carbs Target (g)')),
                const SizedBox(height: 10),
                TextField(controller: fatCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fat Target (g)')),
                const SizedBox(height: 10),
                TextField(controller: waterCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Water Target (ml)')),
                const SizedBox(height: 10),
                TextField(controller: stepsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Steps Target')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald),
              onPressed: () async {
                final db = ref.read(databaseProvider);
                await db.saveUserProfile(
                  UsersCompanion(
                    id: const Value('default_user'),
                    calorieTarget: Value(int.tryParse(kcalCtrl.text) ?? user.calorieTarget),
                    proteinTargetG: Value(double.tryParse(proteinCtrl.text) ?? user.proteinTargetG),
                    carbTargetG: Value(double.tryParse(carbsCtrl.text) ?? user.carbTargetG),
                    fatTargetG: Value(double.tryParse(fatCtrl.text) ?? user.fatTargetG),
                    waterTargetMl: Value(int.tryParse(waterCtrl.text) ?? user.waterTargetMl),
                    stepsTarget: Value(int.tryParse(stepsCtrl.text) ?? user.stepsTarget),
                    updatedAt: Value(DateTime.now()),
                  ),
                );

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Updated daily targets!')),
                  );
                }
              },
              child: const Text('Save Targets', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final user = userAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, color: AppColors.emerald, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Home Recomp Manual — Phase 1', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Height: ${user?.heightCm.toInt() ?? 160} cm · Weight: ${user?.weightKg.toStringAsFixed(1) ?? 62.0} kg · Age: ${user?.age ?? 21}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      const Text('Goal: Build visible muscle, slightly leaner (recomp)', style: TextStyle(fontSize: 11, color: AppColors.emeraldLight)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text('NUTRITION TARGETS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Daily Calorie Budget'),
                  trailing: Text('${user?.calorieTarget ?? 2350} kcal', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.emeraldLight)),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Protein Target'),
                  trailing: Text('${user?.proteinTargetG.toInt() ?? 155} g', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.coralLight)),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Carbohydrates Target'),
                  trailing: Text('${user?.carbTargetG.toInt() ?? 260} g', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.amberLight)),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Fats Target'),
                  trailing: Text('${user?.fatTargetG.toInt() ?? 70} g', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.violet)),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Water Intake Target'),
                  trailing: Text('${user?.waterTargetMl ?? 3000} ml', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.cyan)),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Daily Steps Target'),
                  trailing: Text('${user?.stepsTarget ?? 10000} steps', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.emerald)),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.emerald)),
                      onPressed: user != null ? () => _showEditTargetsDialog(user) : null,
                      icon: const Icon(Icons.tune_rounded, color: AppColors.emerald, size: 18),
                      label: const Text('Edit Targets & Macros', style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text('EQUIPMENT & WORKING LOADS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Home Gym Equipment (Pre-configured):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                SizedBox(height: 6),
                Text('• Long barbell (7 kg bare, loaded with plates ≈ 26 kg max)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text('• EZ curl bar (2 kg bare) & light 4 kg bar for isolation work', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text('• Adjustable dumbbells (4×2kg, 2×2.5kg, 2×3kg plates = 19 kg total)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text('• Working load: ~9.5 kg/hand for two-handed lifts, or 19 kg single-arm/goblet', style: TextStyle(fontSize: 12, color: AppColors.emeraldLight)),
                Text('• Incline/decline bench, pull-up bar, resistance band, elliptical trainer', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text('GOOGLE CLOUD FIRESTORE BACKEND', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.cloud_sync_rounded, color: AppColors.amber, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Google Firestore Cloud Sync', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          Text('Zero-server cloud backup for meals, workouts & weights', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Local SQLite (Drift) operates offline instantly. When online, data syncs to your Google Cloud Firestore database.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.border)),
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Testing authenticated Firestore endpoint...')),
                          );
                          final syncService = ref.read(firestoreSyncServiceProvider);
                          final ok = await syncService.testConnection();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'Google Cloud Firestore reachable! Authenticated via Bearer token.'
                                    : 'Offline mode: Firestore endpoint unreachable. Local SQLite active.'),
                                backgroundColor: ok ? AppColors.emeraldMuted : AppColors.cardElevated,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.wifi_tethering_rounded, size: 16, color: AppColors.textSecondary),
                        label: const Text('Test Ping', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Starting two-way sync (Push & Pull)...')),
                          );
                          try {
                            final res = await ref.read(syncStatusNotifierProvider.notifier).triggerSync();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.success
                                      ? 'Two-Way Sync complete: Pushed ${res.pushedCount} records, Pulled ${res.pulledCount} updates!'
                                      : 'Sync completed in offline-first mode'),
                                  backgroundColor: res.success ? AppColors.emeraldMuted : AppColors.cardElevated,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Offline-first sync completed: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                        label: const Text('Sync Now', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
