import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_theme.dart';

class MacroSourceScreen extends ConsumerStatefulWidget {
  const MacroSourceScreen({super.key});

  @override
  ConsumerState<MacroSourceScreen> createState() => _MacroSourceScreenState();
}

class _MacroSourceScreenState extends ConsumerState<MacroSourceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedSlotFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(diaryEntriesProvider);
    final userAsync = ref.watch(userProfileProvider);
    final dateStr = ref.watch(formattedSelectedDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Macro Source Breakdown'),
            Text(
              dateStr,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'Protein Sources'),
            Tab(text: 'Carb Sources'),
            Tab(text: 'Fat Sources'),
          ],
        ),
      ),
      body: entriesAsync.when(
        data: (allEntries) {
          final entries = _selectedSlotFilter == 'all'
              ? allEntries
              : allEntries.where((e) => e.mealSlot == _selectedSlotFilter).toList();

          if (allEntries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.pie_chart_outline_rounded, size: 54, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('No meals logged for this date yet.', style: TextStyle(color: AppColors.textSecondary)),
                  SizedBox(height: 4),
                  Text('Log breakfast or lunch to view macro origins.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            );
          }

          final totalProtein = entries.fold<double>(0, (sum, e) => sum + e.proteinG);
          final totalCarbs = entries.fold<double>(0, (sum, e) => sum + e.carbsG);
          final totalFat = entries.fold<double>(0, (sum, e) => sum + e.fatG);

          final proteinTarget = userAsync.value?.proteinTargetG ?? 155.0;
          final carbTarget = userAsync.value?.carbTargetG ?? 260.0;
          final fatTarget = userAsync.value?.fatTargetG ?? 70.0;

          return Column(
            children: [
              // Meal Filter Chips
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppColors.surface,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(label: 'All Day', value: 'all', selected: _selectedSlotFilter == 'all', onSelect: (v) => setState(() => _selectedSlotFilter = v)),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Breakfast', value: 'breakfast', selected: _selectedSlotFilter == 'breakfast', onSelect: (v) => setState(() => _selectedSlotFilter = v)),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Lunch', value: 'lunch', selected: _selectedSlotFilter == 'lunch', onSelect: (v) => setState(() => _selectedSlotFilter = v)),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Shake (4:30 PM)', value: 'shake', selected: _selectedSlotFilter == 'shake', onSelect: (v) => setState(() => _selectedSlotFilter = v)),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Dinner', value: 'dinner', selected: _selectedSlotFilter == 'dinner', onSelect: (v) => setState(() => _selectedSlotFilter = v)),
                    ],
                  ),
                ),
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 1. Protein Sources
                    _MacroListTab(
                      macroName: 'Protein',
                      totalConsumed: totalProtein,
                      target: proteinTarget,
                      color: AppColors.primary,
                      items: entries.map((e) => _SourceItem(foodName: e.foodName, grams: e.proteinG, mealSlot: e.mealSlot)).toList()
                        ..sort((a, b) => b.grams.compareTo(a.grams)),
                    ),

                    // 2. Carb Sources
                    _MacroListTab(
                      macroName: 'Carbohydrates',
                      totalConsumed: totalCarbs,
                      target: carbTarget,
                      color: AppColors.primary,
                      items: entries.map((e) => _SourceItem(foodName: e.foodName, grams: e.carbsG, mealSlot: e.mealSlot)).toList()
                        ..sort((a, b) => b.grams.compareTo(a.grams)),
                    ),

                    // 3. Fat Sources
                    _MacroListTab(
                      macroName: 'Fat',
                      totalConsumed: totalFat,
                      target: fatTarget,
                      color: AppColors.primary,
                      items: entries.map((e) => _SourceItem(foodName: e.foodName, grams: e.fatG, mealSlot: e.mealSlot)).toList()
                        ..sort((a, b) => b.grams.compareTo(a.grams)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error loading macro sources: $err')),
      ),
    );
  }
}

class _SourceItem {
  final String foodName;
  final double grams;
  final String mealSlot;

  _SourceItem({required this.foodName, required this.grams, required this.mealSlot});
}

class _MacroListTab extends StatelessWidget {
  final String macroName;
  final double totalConsumed;
  final double target;
  final Color color;
  final List<_SourceItem> items;

  const _MacroListTab({
    required this.macroName,
    required this.totalConsumed,
    required this.target,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final validItems = items.where((i) => i.grams > 0.05).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Header Card
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total $macroName', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  Text(
                    '${totalConsumed.toStringAsFixed(1)}g / ${target.toInt()}g',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: target > 0 ? (totalConsumed / target).clamp(0.0, 1.0) : 0,
                  backgroundColor: AppColors.cardElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                ),
              ),
              if (validItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Top source: ${validItems.first.foodName} (${validItems.first.grams.toStringAsFixed(1)}g, ${totalConsumed > 0 ? ((validItems.first.grams / totalConsumed) * 100).toInt() : 0}%)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 18),
        const Text(
          'FOOD ORIGIN BREAKDOWN',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 10),

        if (validItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('No significant sources recorded for this macro.', style: TextStyle(color: AppColors.textMuted)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: validItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = validItems[index];
              final sharePercent = totalConsumed > 0 ? (item.grams / totalConsumed) : 0.0;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.foodName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${item.grams.toStringAsFixed(1)}g',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${(sharePercent * 100).toInt()}%',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.cardElevated,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.mealSlot.toUpperCase(),
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: sharePercent.clamp(0.0, 1.0),
                              backgroundColor: AppColors.cardElevated,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                              minHeight: 5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Function(String) onSelect;

  const _FilterChip({required this.label, required this.value, required this.selected, required this.onSelect});

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
