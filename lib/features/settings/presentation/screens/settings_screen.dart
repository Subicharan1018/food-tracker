import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart';
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
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Edit Daily Targets', style: AppTypography.titleLarge),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: kcalCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Calories (kcal)')),
              const SizedBox(height: 8),
              TextField(controller: proteinCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Protein (g)')),
              const SizedBox(height: 8),
              TextField(controller: carbsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Carbohydrates (g)')),
              const SizedBox(height: 8),
              TextField(controller: fatCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fat (g)')),
              const SizedBox(height: 8),
              TextField(controller: waterCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Water Target (ml)')),
              const SizedBox(height: 8),
              TextField(controller: stepsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Daily Steps Target')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.textInverse,
            ),
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
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Targets saved!')));
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
    final userAsync = ref.watch(userProfileProvider);
    final user = userAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Profile', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Profile / User Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.surfaceElevated,
                  child: const Icon(Icons.person_rounded, color: AppColors.textPrimary, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Subicharan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        '${user?.heightCm.toInt() ?? 160} cm · ${user?.weightKg ?? 62.0} kg · 21 yo Male',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.positive.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('RECOMPOSITION PROTOCOL ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.positive)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                  onPressed: user != null ? () => _showEditTargetsDialog(user) : null,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text('DAILY NUTRITION & ACTIVITY TARGETS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 10),

          // 2. Targets Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _TargetRow(label: 'Calories', value: '${user?.calorieTarget ?? 2350} kcal', subtitle: 'Calculated Recomp TDEE + 200 surplus on training'),
                const Divider(height: 20, color: AppColors.border),
                _TargetRow(label: 'Protein Target', value: '${user?.proteinTargetG.toInt() ?? 155} g', subtitle: '~2.5g per kg bodyweight (high MPS trigger)'),
                const Divider(height: 20, color: AppColors.border),
                _TargetRow(label: 'Carbs Target', value: '${user?.carbTargetG.toInt() ?? 260} g', subtitle: '~4.2g/kg (glycogen replenishment)'),
                const Divider(height: 20, color: AppColors.border),
                _TargetRow(label: 'Fat Target', value: '${user?.fatTargetG.toInt() ?? 70} g', subtitle: '~1.1g/kg (hormonal optimization)'),
                const Divider(height: 20, color: AppColors.border),
                _TargetRow(label: 'Daily Water Target', value: '${user?.waterTargetMl ?? 3000} ml', subtitle: 'Hydration milestone (3.0 Liters)'),
                const Divider(height: 20, color: AppColors.border),
                _TargetRow(label: 'Daily Steps Goal', value: '${user?.stepsTarget ?? 10000} steps', subtitle: 'Health Connect integrated tracking'),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text('EQUIPMENT & ENVIRONMENT PROFILE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 10),

          // 3. Equipment Profile Card
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
                Text('Home Gym Setup (Saved Profile)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                SizedBox(height: 8),
                Text('• 10kg, 15kg, 20kg Dumbbell pairs', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                SizedBox(height: 4),
                Text('• 5ft straight barbell + 20kg weight plates', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                SizedBox(height: 4),
                Text('• Incline/decline bench, pull-up bar, resistance band, elliptical trainer', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text('GOOGLE CLOUD FIRESTORE BACKEND', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 10),

          Consumer(
            builder: (context, ref, child) {
              final syncStatus = ref.watch(syncStatusProvider);
              final isSyncing = syncStatus.isSyncing;
              final hasError = syncStatus.error != null || syncStatus.authReason != null;
              final lastTime = syncStatus.lastSyncTime;
              final lastTimeStr = lastTime != null
                  ? DateFormat('MMM d, h:mm a').format(lastTime)
                  : 'Pending first sync';

              Color statusColor = AppColors.positive;
              String statusTitle = 'Auto-Sync Active (Cloud Connected)';
              String statusDesc = 'All updates save locally & sync to Firestore automatically in background.\nLast sync: $lastTimeStr';

              if (isSyncing) {
                statusColor = AppColors.attention;
                statusTitle = 'Syncing with Firestore...';
                statusDesc = 'Uploading local changes & pulling latest cloud records...';
              } else if (hasError) {
                statusColor = AppColors.destructive;
                if (syncStatus.authReason == 'anonymous_auth_disabled') {
                  statusTitle = 'Not Connected: Anonymous Auth Disabled';
                  statusDesc = 'Enable Anonymous Sign-in in Firebase Console (Authentication > Sign-in method) to activate cloud sync.';
                } else if (syncStatus.authReason == 'network_error') {
                  statusTitle = 'Offline Mode Active';
                  statusDesc = 'Working offline in local SQLite. Changes will auto-sync once internet reconnects.';
                } else {
                  statusTitle = 'Not Connected';
                  statusDesc = syncStatus.error ?? 'Sync encountered an error. Local SQLite is active.';
                }
              }

              return Container(
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
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Icon(
                            isSyncing ? Icons.sync_rounded : Icons.cloud_done_rounded,
                            color: statusColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statusTitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Instant background auto-sync',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<String?>(
                      future: ref.read(firebaseAuthRestServiceProvider).getUserId(),
                      builder: (context, snapshot) {
                        final activeUid = snapshot.data ?? 'xglm2AMV46WgLwOr7CvEQm5I8x02';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_circle_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Active Cloud UID: $activeUid',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusDesc,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                      ),
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
                                    backgroundColor: ok ? AppColors.positive.withValues(alpha: 0.15) : AppColors.cardElevated,
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
                              backgroundColor: AppColors.brandPrimary,
                              foregroundColor: AppColors.textInverse,
                            ),
                            onPressed: isSyncing
                                ? null
                                : () async {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Triggering sync with Firebase Firestore...')),
                                    );
                                    final res = await ref.read(syncSchedulerProvider).syncNow();
                                    if (context.mounted && res != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res.success
                                              ? 'Sync complete: Pushed ${res.pushedCount} records, Pulled ${res.pulledCount} updates!'
                                              : 'Sync completed in offline-first mode: ${res.errorMessage ?? ""}'),
                                          backgroundColor: res.success ? AppColors.positive.withValues(alpha: 0.15) : AppColors.cardElevated,
                                        ),
                                      );
                                    }
                                  },
                            icon: isSyncing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textInverse),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(
                              isSyncing ? 'Syncing...' : 'Retry Sync',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        minimumSize: const Size(double.infinity, 38),
                      ),
                      onPressed: () {
                        final controller = TextEditingController(text: 'xglm2AMV46WgLwOr7CvEQm5I8x02');
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.card,
                            title: const Text('Manage & Merge Cloud Accounts', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Adopt or merge data from any previous Firestore User document into your local app & cloud storage:',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: controller,
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                                    decoration: const InputDecoration(
                                      labelText: 'Firestore User ID',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text('Quick Select from Firestore:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      ActionChip(
                                        backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.15),
                                        label: const Text('Main Verified (xglm2...)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandPrimary)),
                                        onPressed: () => controller.text = 'xglm2AMV46WgLwOr7CvEQm5I8x02',
                                      ),
                                      ActionChip(
                                        label: const Text('Sep 15 (qJBJ...)', style: TextStyle(fontSize: 11)),
                                        onPressed: () => controller.text = 'qJBJWa4OHut6ipBUWz71lr4r4uR2',
                                      ),
                                      ActionChip(
                                        label: const Text('Sep 07 (xGcC...)', style: TextStyle(fontSize: 11)),
                                        onPressed: () => controller.text = 'xGcChyCdwd08zm8QVCe0VW0bV7B3',
                                      ),
                                      ActionChip(
                                        label: const Text('Legacy (FkCX...)', style: TextStyle(fontSize: 11)),
                                        onPressed: () => controller.text = 'FkCXgOvC3pdw7njAez5RV09JgFH2',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '💡 Tip for Firestore Console:\nIn Firebase Console > Firestore, document "xglm2AMV46WgLwOr7CvEQm5I8x02" is your primary account. You can safely delete the other 3 orphan documents (FkCX..., qJBJ..., xGcC...).',
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
                                onPressed: () async {
                                  final id = controller.text.trim();
                                  if (id.isEmpty) return;
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Setting $id as primary and syncing...')),
                                  );
                                  final auth = ref.read(firebaseAuthRestServiceProvider);
                                  await auth.setCanonicalUserId(id);

                                  final db = ref.read(databaseProvider);
                                  final syncService = ref.read(firestoreSyncServiceProvider);
                                  final count = await syncService.importFromUser(db, id);

                                  // Trigger immediate two-way sync
                                  await ref.read(syncSchedulerProvider).syncNow();

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Linked account $id! Merged $count cloud records.'),
                                        backgroundColor: AppColors.positive.withValues(alpha: 0.15),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Set & Sync Account', style: TextStyle(color: AppColors.textInverse, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.manage_accounts_rounded, size: 16, color: AppColors.textPrimary),
                      label: const Text('Manage & Merge Cloud Accounts', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;

  const _TargetRow({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
