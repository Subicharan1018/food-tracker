import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../streaks/services/streak_service.dart';

class LogFoodScreen extends ConsumerStatefulWidget {
  final String initialMealSlot;

  const LogFoodScreen({
    super.key,
    this.initialMealSlot = 'breakfast',
  });

  @override
  ConsumerState<LogFoodScreen> createState() => _LogFoodScreenState();
}

class _LogFoodScreenState extends ConsumerState<LogFoodScreen> {
  final _searchController = TextEditingController();
  late String _selectedSlot;
  List<FoodItem> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedSlot = widget.initialMealSlot;
    _performSearch('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    final db = ref.read(databaseProvider);
    final results = await db.searchFoodItems(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  void _showPortionDialog(FoodItem food) {
    double portionQty = 1.0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final calories = food.calories * portionQty;
            final protein = food.proteinG * portionQty;
            final carbs = food.carbsG * portionQty;
            final fat = food.fatG * portionQty;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.cardElevated,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    food.name,
                    style: AppTypography.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Standard: ${food.servingSize} ${food.servingUnit} · ${food.calories.toInt()} kcal',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Real-time macro preview
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MacroMini(label: 'Calories', value: '${calories.toInt()}', unit: 'kcal', color: AppColors.primary),
                        _MacroMini(label: 'Protein', value: protein.toStringAsFixed(1), unit: 'g', color: AppColors.textPrimary),
                        _MacroMini(label: 'Carbs', value: carbs.toStringAsFixed(1), unit: 'g', color: AppColors.textPrimary),
                        _MacroMini(label: 'Fat', value: fat.toStringAsFixed(1), unit: 'g', color: AppColors.textPrimary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Portion Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Number of Servings',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded),
                            color: AppColors.primary,
                            onPressed: portionQty > 0.25
                                ? () => setModalState(() => portionQty -= 0.25)
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              portionQty.toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            color: AppColors.primary,
                            onPressed: () => setModalState(() => portionQty += 0.25),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Quick presets
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [0.5, 1.0, 1.5, 2.0, 3.0, 4.0].map((preset) {
                      final selected = portionQty == preset;
                      return InkWell(
                        onTap: () => setModalState(() => portionQty = preset),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : AppColors.card,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          child: Text(
                            '${preset}x',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        final db = ref.read(databaseProvider);
                        final dateStr = ref.read(formattedSelectedDateProvider);

                        await db.addDiaryEntry(
                          DiaryEntriesCompanion.insert(
                            id: const Uuid().v4(),
                            date: dateStr,
                            mealSlot: _selectedSlot,
                            foodItemId: Value(food.id),
                            foodName: food.name,
                            portionQty: portionQty,
                            portionUnit: food.servingUnit,
                            calories: calories,
                            proteinG: protein,
                            carbsG: carbs,
                            fatG: fat,
                            fiberG: Value(food.fiberG * portionQty),
                            loggedAt: Value(DateTime.now()),
                          ),
                        );

                        // Update streak
                        final currentStreak = await db.getStreak('logging');
                        final streakRes = StreakEngine.processActivity(
                          currentCount: currentStreak?.currentCount ?? 0,
                          longestCount: currentStreak?.longestCount ?? 0,
                          lastActiveDate: currentStreak?.lastActiveDate,
                          today: DateTime.now(),
                        );
                        await db.updateStreak(
                          StreaksCompanion.insert(
                            type: 'logging',
                            currentCount: Value(streakRes.currentCount),
                            longestCount: Value(streakRes.longestCount),
                            lastActiveDate: Value(streakRes.lastActiveDate),
                            updatedAt: Value(DateTime.now()),
                          ),
                        );

                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added ${food.name} to ${_selectedSlot.toUpperCase()}'),
                              backgroundColor: AppColors.cardElevated,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: Text(
                        'Log Food (${calories.toInt()} kcal)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showManualEntryDialog() {
    final nameCtrl = TextEditingController();
    final kcalCtrl = TextEditingController();
    final proteinCtrl = TextEditingController();
    final carbsCtrl = TextEditingController();
    final fatCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Manual Food Entry', style: AppTypography.titleLarge),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Food Name (e.g. Homemade Sambar)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: kcalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Calories (kcal)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: proteinCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Protein (g)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: carbsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Carbs (g)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: fatCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fat (g)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final kcal = double.tryParse(kcalCtrl.text) ?? 0.0;
                final protein = double.tryParse(proteinCtrl.text) ?? 0.0;
                final carbs = double.tryParse(carbsCtrl.text) ?? 0.0;
                final fat = double.tryParse(fatCtrl.text) ?? 0.0;

                if (name.isEmpty || kcal <= 0) return;

                final db = ref.read(databaseProvider);
                final dateStr = ref.read(formattedSelectedDateProvider);

                await db.addDiaryEntry(
                  DiaryEntriesCompanion.insert(
                    id: const Uuid().v4(),
                    date: dateStr,
                    mealSlot: _selectedSlot,
                    foodName: name,
                    portionQty: 1.0,
                    portionUnit: 'serving',
                    calories: kcal,
                    proteinG: protein,
                    carbsG: carbs,
                    fatG: fat,
                    fiberG: const Value(0.0),
                    loggedAt: Value(DateTime.now()),
                  ),
                );

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logged $name!')),
                  );
                }
              },
              child: const Text('Add Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final recentFoodsAsync = ref.watch(recentFoodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Food'),
        actions: [
          TextButton.icon(
            onPressed: _showManualEntryDialog,
            icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
            label: const Text('Manual Entry', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Meal slot selector chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SlotChip(label: 'Breakfast', value: 'breakfast', selected: _selectedSlot == 'breakfast', onSelect: (v) => setState(() => _selectedSlot = v)),
                  const SizedBox(width: 8),
                  _SlotChip(label: 'Lunch', value: 'lunch', selected: _selectedSlot == 'lunch', onSelect: (v) => setState(() => _selectedSlot = v)),
                  const SizedBox(width: 8),
                  _SlotChip(label: 'Shake (4:30 PM)', value: 'shake', selected: _selectedSlot == 'shake', onSelect: (v) => setState(() => _selectedSlot = v)),
                  const SizedBox(width: 8),
                  _SlotChip(label: 'Pre-workout (6 PM)', value: 'pre_workout', selected: _selectedSlot == 'pre_workout', onSelect: (v) => setState(() => _selectedSlot = v)),
                  const SizedBox(width: 8),
                  _SlotChip(label: 'Dinner', value: 'dinner', selected: _selectedSlot == 'dinner', onSelect: (v) => setState(() => _selectedSlot = v)),
                  const SizedBox(width: 8),
                  _SlotChip(label: 'Snack', value: 'snack', selected: _selectedSlot == 'snack', onSelect: (v) => setState(() => _selectedSlot = v)),
                ],
              ),
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: _performSearch,
              decoration: InputDecoration(
                hintText: 'Search food (e.g. egg, chicken, rice, chapati, dal)',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Recent / Frequent items horizontal list
          recentFoodsAsync.when(
            data: (recents) {
              if (recents.isEmpty) return const SizedBox.shrink();
              return Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recents.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final foodName = recents[index];
                    return ActionChip(
                      label: Text(foodName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      backgroundColor: AppColors.card,
                      side: const BorderSide(color: AppColors.border),
                      onPressed: () {
                        _searchController.text = foodName;
                        _performSearch(foodName);
                      },
                    );
                  },
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Food items list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 10),
                            const Text('No foods found matching query', style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _showManualEntryDialog,
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text('Add Custom Food', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            title: Text(item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            subtitle: Text(
                              '${item.servingSize} ${item.servingUnit} · ${item.calories.toInt()} kcal · ${item.proteinG}g P · ${item.carbsG}g C · ${item.fatG}g F',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
                            ),
                            onTap: () => _showPortionDialog(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Function(String) onSelect;

  const _SlotChip({required this.label, required this.value, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelect(value),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.card,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppColors.textSecondary,
      ),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      showCheckmark: false,
    );
  }
}

class _MacroMini extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MacroMini({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            Text(' $unit', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}
