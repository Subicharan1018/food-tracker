import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/di/providers.dart';
import 'core/theme/app_theme.dart';
import 'shared/screens/main_nav_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: KinetikFitnessApp(),
    ),
  );
}

class KinetikFitnessApp extends ConsumerStatefulWidget {
  const KinetikFitnessApp({super.key});

  @override
  ConsumerState<KinetikFitnessApp> createState() => _KinetikFitnessAppState();
}

class _KinetikFitnessAppState extends ConsumerState<KinetikFitnessApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cold start auto-sync: pull remote updates & push any pending offline records
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncSchedulerProvider).syncNow();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Foreground resume auto-sync
      ref.read(syncSchedulerProvider).syncNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kinetik — Recomp Manual & Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavScreen(),
    );
  }
}

