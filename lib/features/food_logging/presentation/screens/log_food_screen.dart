import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/ingredients/ingredient_identity.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/domain/meal_slots.dart';
import '../../nlp_input_widget.dart';

class _PortionSpec {
  final double servingSize;
  final String unit;
  final double step;
  final bool isMass;

  const _PortionSpec({required this.servingSize, required this.unit, required this.step, required this.isMass});

  String format(double amount) => isMass
      ? (amount == amount.roundToDouble() ? amount.toInt().toString() : amount.toStringAsFixed(1))
      : (amount == amount.roundToDouble() ? amount.toInt().toString() : amount.toStringAsFixed(2));
}

_PortionSpec _portionSpec(FoodItem food) {
  // Strip any parenthesized weight suffix, e.g. "cup (200g)" -> "cup"
  final rawFull = food.servingUnit.trim();
  final raw = rawFull.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim().toLowerCase();
  final isKg = raw == 'kg' || raw.startsWith('kg ') || raw.startsWith('kilogram');
  final isGram = raw == 'g' || raw.startsWith('g ') || raw.startsWith('gram');
  final isMl = raw == 'ml' || raw.startsWith('ml ') || raw.startsWith('milliliter');
  final isLiter = raw == 'l' || raw.startsWith('l ') || raw.startsWith('liter');
  final isMass = isKg || isGram || isMl || isLiter;
  final unit = isKg ? 'kg' : (isGram ? 'g' : (isMl ? 'ml' : (isLiter ? 'L' : raw)));
  final step = (isKg || isLiter) ? 0.1 : (isMass ? 10.0 : 0.25);
  return _PortionSpec(
    servingSize: food.servingSize > 0 ? food.servingSize : 1.0,
    unit: unit,
    step: step,
    isMass: isMass,
  );
}

double _portionFactor(_PortionSpec spec, double amount) => amount / spec.servingSize;

/// Returns the unit string with correct pluralisation for count-based units.
String _pluraliseUnit(String unit, double amount) {
  if (amount == 1.0) return unit;
  switch (unit) {
    case 'cup':
      return 'cups';
    case 'tbsp':
    case 'tablespoon':
      return 'tbsp';
    case 'tsp':
    case 'teaspoon':
      return 'tsp';
    default:
      return unit;
  }
}

double _convertMass(double amount, String? from, String to) {
  if (from == null) return amount;
  final source = from.trim().toLowerCase();
  final target = to.trim().toLowerCase();
  if (source == target) return amount;
  if (source == 'kg' && target == 'g') return amount * 1000;
  if (source == 'g' && target == 'kg') return amount / 1000;
  if (source == 'l' && target == 'ml') return amount * 1000;
  if (source == 'ml' && target == 'l') return amount / 1000;
  return amount;
}

/// The food [query] unambiguously refers to, or `null`.
///
/// Search is a substring match, so its first row can be the wrong food
/// ("egg" → an eggplant dish, or egg noodles).  Accept a result only when its
/// canonical name equals the query's, or when exactly one result is an IFCT
/// style variant of it ("Spinach, boiled" for "spinach").
FoodItem? confidentFoodMatch(List<FoodItem> results, String query) {
  final wanted = canonicalizeIngredient(query);
  if (wanted.isEmpty) return null;
  final exact = results.where((f) => canonicalizeIngredient(f.name) == wanted).toList();
  if (exact.length == 1) return exact.single;
  final heads = results.where((f) {
    final name = canonicalizeIngredient(f.name);
    return name.startsWith('$wanted,');
  }).toList();
  return heads.length == 1 ? heads.single : null;
}

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
  bool _nlpMode = false;

  Future<void> _handleNlpParsedItems(List<Map<String, dynamic>> items) async {
    final db = ref.read(databaseProvider);
    final dateStr = ref.read(formattedSelectedDateProvider);
    final unmatched = <String>[];
    var logged = 0;

    for (final item in items) {
      final name = item['food_name']?.toString() ?? 'Item';
      final requested = (item['portion_qty'] as num?)?.toDouble() ?? 1.0;
      final slot = item['meal_slot']?.toString().toLowerCase() ?? _selectedSlot;

      // Only log against a food we're sure of; numbers are never invented.
      final food = confidentFoodMatch(await db.searchFoodItems(name), name);
      if (food == null) {
        unmatched.add(name);
        continue;
      }

      final spec = _portionSpec(food);
      // A bare NLP quantity means servings for count-based foods, but the
      // standard serving size for gram/ml foods. Explicit 200g/250ml values
      // remain literal amounts from the parser.
      final parsedUnit = item['portion_unit']?.toString();
      final portion = spec.isMass && parsedUnit == null && requested == 1.0
          ? spec.servingSize
          : (spec.isMass ? _convertMass(requested, parsedUnit, spec.unit) : requested);
      final factor = _portionFactor(spec, portion);

      await db.logDiaryEntry(
        DiaryEntriesCompanion.insert(
          id: const Uuid().v4(),
          date: dateStr,
          mealSlot: slot,
          foodItemId: Value(food.id),
          foodName: food.name,
          portionQty: portion,
          portionUnit: food.servingUnit,
          calories: food.calories * factor,
          proteinG: food.proteinG * factor,
          carbsG: food.carbsG * factor,
          fatG: food.fatG * factor,
          fiberG: Value(food.fiberG * factor),
          loggedAt: Value(DateTime.now()),
        ),
      );
      logged++;
    }

    if (!mounted) return;
    setState(() => _nlpMode = false);
    final parts = [
      if (logged > 0) 'Logged $logged ${logged == 1 ? 'item' : 'items'}.',
      if (unmatched.isNotEmpty) "Couldn't match ${unmatched.join(', ')} — pick it from search.",
    ];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parts.join(' '))));
    if (unmatched.isNotEmpty) {
      _searchController.text = unmatched.first;
      _performSearch(unmatched.first);
    }
  }

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
    final spec = _portionSpec(food);
    double portionQty = spec.servingSize;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final factor = _portionFactor(spec, portionQty);
            final calories = food.calories * factor;
            final protein = food.proteinG * factor;
            final carbs = food.carbsG * factor;
            final fat = food.fatG * factor;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
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
                    'Standard: ${spec.format(spec.servingSize)} ${spec.unit} · ${food.calories.toInt()} kcal',
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
                    child: Wrap(
                      alignment: WrapAlignment.spaceAround,
                      runAlignment: WrapAlignment.center,
                      spacing: 18,
                      runSpacing: 10,
                      children: [
                        _MacroMini(label: 'Calories', value: '${calories.toInt()}', unit: 'kcal', color: AppColors.textPrimary),
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
                      Text(
                        'Amount (${spec.unit})',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Decrease',
                            icon: const Icon(Icons.remove_circle_outline_rounded),
                            color: AppColors.textPrimary,
                            onPressed: portionQty > spec.step
                                ? () => setModalState(() => portionQty = (portionQty - spec.step).clamp(spec.step, double.infinity).toDouble())
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
                              spec.format(portionQty),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Increase',
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            color: AppColors.textPrimary,
                            onPressed: () => setModalState(() => portionQty += spec.step),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Quick presets
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [0.5, 1.0, 1.5, 2.0, 3.0, 4.0].map((multiplier) {
                      final preset = spec.servingSize * multiplier;
                      final selected = portionQty == preset;
                      return InkWell(
                        onTap: () => setModalState(() => portionQty = preset),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.brandPrimary : AppColors.card,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected ? AppColors.brandPrimary : AppColors.border,
                            ),
                          ),
                          child: Text(
                            '${spec.format(preset)} ${_pluraliseUnit(spec.unit, preset)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: selected ? AppColors.textInverse : AppColors.textSecondary,
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
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.textInverse,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        final db = ref.read(databaseProvider);
                        final dateStr = ref.read(formattedSelectedDateProvider);

                        await db.logDiaryEntry(
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
                            fiberG: Value(food.fiberG * factor),
                            loggedAt: Value(DateTime.now()),
                          ),
                        );

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted) {
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
    final amountCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController(text: 'serving');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Manual Food Entry', style: AppTypography.titleLarge),
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Amount'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(labelText: 'Unit (g, ml, piece)'),
                      ),
                    ),
                  ],
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.textInverse,
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final kcal = double.tryParse(kcalCtrl.text) ?? 0.0;
                final protein = double.tryParse(proteinCtrl.text) ?? 0.0;
                final carbs = double.tryParse(carbsCtrl.text) ?? 0.0;
                final fat = double.tryParse(fatCtrl.text) ?? 0.0;
                final amount = double.tryParse(amountCtrl.text) ?? 1.0;
                final unit = unitCtrl.text.trim().isEmpty ? 'serving' : unitCtrl.text.trim();

                if (name.isEmpty || kcal <= 0) return;

                final db = ref.read(databaseProvider);
                final dateStr = ref.read(formattedSelectedDateProvider);

                await db.logDiaryEntry(
                  DiaryEntriesCompanion.insert(
                    id: const Uuid().v4(),
                    date: dateStr,
                    mealSlot: _selectedSlot,
                    foodName: name,
                    portionQty: amount,
                    portionUnit: unit,
                    calories: kcal,
                    proteinG: protein,
                    carbsG: carbs,
                    fatG: fat,
                    fiberG: const Value(0.0),
                    loggedAt: Value(DateTime.now()),
                  ),
                );

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logged $name!')),
                  );
                }
              },
              child: const Text('Add Entry', style: TextStyle(color: AppColors.textInverse, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final recentFoodsAsync = ref.watch(recentFoodsProvider);
    final query = _searchController.text.trim();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppShapes.gutter,
        title: const Text('LOG'),
        actions: [
          TextButton(onPressed: _showManualEntryDialog, child: const Text('Enter manually')),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Which meal this goes into — straight from the day's slot catalogue.
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final slot in mealSlots)
                  _SlotTab(
                    slot: slot,
                    selected: _selectedSlot == slot.key,
                    onSelect: () => setState(() => _selectedSlot = slot.key),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.fromLTRB(AppShapes.gutter, 8, 8, 4),
            child: _nlpMode
                ? NlpInputWidget(
                    userId: ref.watch(firestoreUserIdProvider).value,
                    initialText: _searchController.text,
                    onParsed: _handleNlpParsedItems,
                    onFallbackSearch: (fallback) {
                      setState(() {
                        _nlpMode = false;
                        _searchController.text = fallback;
                      });
                      _performSearch(fallback);
                    },
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (q) {
                            setState(() {});
                            _performSearch(q);
                          },
                          textInputAction: TextInputAction.search,
                          style: AppTypography.bodyLarge,
                          decoration: InputDecoration(
                            hintText: 'Search IFCT foods — egg, rice, chapati…',
                            prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                            suffixIcon: query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                      _performSearch('');
                                    },
                                  ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _nlpMode = true),
                        child: const Text('Describe'),
                      ),
                    ],
                  ),
          ),

          // Recent foods — one tap to search them again.
          recentFoodsAsync.when(
            data: (recents) {
              if (recents.isEmpty || _nlpMode) return const SizedBox.shrink();
              return SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppShapes.gutter, vertical: 6),
                  itemCount: recents.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => ActionChip(
                    label: Text(recents[index]),
                    onPressed: () {
                      _searchController.text = recents[index];
                      setState(() {});
                      _performSearch(recents[index]);
                    },
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          Expanded(
            child: _isLoading
                ? const SizedBox.shrink()
                : _searchResults.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppShapes.gutter),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              query.isEmpty ? 'NO FOODS YET' : 'NO MATCH FOR “${query.toUpperCase()}”',
                              style: AppTypography.label.copyWith(color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Try the Tamil or Hindi name, describe the meal, or enter its numbers from the label.',
                              style: AppTypography.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(onPressed: _showManualEntryDialog, child: const Text('ENTER MANUALLY')),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, indent: AppShapes.gutter),
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          final serving = '${item.servingSize % 1 == 0 ? item.servingSize.toInt() : item.servingSize} ${item.servingUnit}';
                          return InkWell(
                            onTap: () => _showPortionDialog(item),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(AppShapes.gutter, 12, 8, 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name, style: AppTypography.bodyLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 3),
                                        Text(
                                          '$serving · P ${item.proteinG.toStringAsFixed(1)}  C ${item.carbsG.toStringAsFixed(1)}  F ${item.fatG.toStringAsFixed(1)}',
                                          style: AppTypography.dataSmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Semantics(
                                    label: '${item.calories.round()} kilocalories',
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('${item.calories.round()}', style: AppTypography.displayMedium.copyWith(fontSize: 26)),
                                        Text('KCAL', style: AppTypography.label.copyWith(fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// Meal slot as a scoreboard tab: caps name over its planned time.
class _SlotTab extends StatelessWidget {
  final MealSlot slot;
  final bool selected;
  final VoidCallback onSelect;

  const _SlotTab({required this.slot, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: selected ? AppColors.brandPrimary : Colors.transparent, width: 3),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slot.label.toUpperCase(),
                style: AppTypography.label.copyWith(
                  fontSize: 16,
                  color: selected ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
              Text(slot.timeLabel, style: AppTypography.dataSmall.copyWith(fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
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
