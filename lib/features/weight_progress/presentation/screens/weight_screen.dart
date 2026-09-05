import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:fl_chart/fl_chart.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../adherence_engine/services/adherence_service.dart';

class WeightProgressScreen extends ConsumerStatefulWidget {
  const WeightProgressScreen({super.key});

  @override
  ConsumerState<WeightProgressScreen> createState() => _WeightProgressScreenState();
}

class _WeightProgressScreenState extends ConsumerState<WeightProgressScreen> {
  void _showWeighInDialog(double currentWeight) {
    double weight = currentWeight;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Log Today\'s Weigh-In', style: AppTypography.titleLarge),
                  const SizedBox(height: 4),
                  const Text('Weigh in the morning before food for consistency.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(weight.toStringAsFixed(1), style: AppTypography.displayLarge.copyWith(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.emerald)),
                        const Text(' kg', style: TextStyle(fontSize: 20, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 32),
                        color: AppColors.emerald,
                        onPressed: () => setModalState(() => weight -= 0.1),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 32),
                        color: AppColors.emerald,
                        onPressed: () => setModalState(() => weight += 0.1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald),
                      onPressed: () async {
                        final db = ref.read(databaseProvider);
                        final dateStr = ref.read(formattedSelectedDateProvider);

                        await db.addWeighIn(
                          WeighInsCompanion.insert(
                            id: const Uuid().v4(),
                            date: dateStr,
                            weightKg: weight,
                            rollingAvgKg: Value(weight), // computed by engine
                            loggedAt: Value(DateTime.now()),
                          ),
                        );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Saved weigh-in: ${weight.toStringAsFixed(1)} kg')),
                          );
                        }
                      },
                      child: const Text('Save Weigh-In', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
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

  void _showMeasurementDialog() {
    String selectedType = 'waist';
    double valueCm = 70.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Log Tape Measurement', style: AppTypography.titleLarge),
                  const SizedBox(height: 4),
                  const Text('Measure every 2–4 weeks (waist, arms, chest).', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  Row(
                    children: ['waist', 'biceps', 'forearm', 'chest'].map((type) {
                      final sel = selectedType == type;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ChoiceChip(
                            label: Text(type.toUpperCase()),
                            selected: sel,
                            onSelected: (_) => setModalState(() {
                              selectedType = type;
                              if (type == 'biceps') valueCm = 35.0;
                              if (type == 'forearm') valueCm = 30.0;
                              if (type == 'waist') valueCm = 70.0;
                              if (type == 'chest') valueCm = 95.0;
                            }),
                            selectedColor: AppColors.emerald,
                            backgroundColor: AppColors.card,
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.black : AppColors.textSecondary,
                            ),
                            showCheckmark: false,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(valueCm.toStringAsFixed(1), style: AppTypography.displayLarge.copyWith(fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.emerald)),
                        const Text(' cm', style: TextStyle(fontSize: 18, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 28),
                        color: AppColors.emerald,
                        onPressed: () => setModalState(() => valueCm -= 0.5),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
                        color: AppColors.emerald,
                        onPressed: () => setModalState(() => valueCm += 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald),
                      onPressed: () async {
                        final db = ref.read(databaseProvider);
                        final dateStr = ref.read(formattedSelectedDateProvider);

                        await db.addMeasurement(
                          MeasurementsCompanion.insert(
                            id: const Uuid().v4(),
                            date: dateStr,
                            type: selectedType,
                            valueCm: valueCm,
                            loggedAt: Value(DateTime.now()),
                          ),
                        );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Logged ${selectedType.toUpperCase()}: $valueCm cm')),
                          );
                        }
                      },
                      child: const Text('Save Measurement', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
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

  @override
  Widget build(BuildContext context) {
    final weighInsAsync = ref.watch(weighInsStreamProvider);
    final userAsync = ref.watch(userProfileProvider);
    final currentWeight = userAsync.value?.weightKg ?? 62.0;

    final weighIns = weighInsAsync.value ?? [];

    // Adherence suggestion check
    final weeklyAverages = weighIns.take(4).map((w) => w.weightKg).toList();
    final suggestion = AdherenceEngine.evaluate(weeklyAverages: weeklyAverages);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight & Trend'),
        actions: [
          IconButton(
            icon: const Icon(Icons.straighten_rounded, color: AppColors.emerald),
            tooltip: 'Tape Measurements',
            onPressed: _showMeasurementDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current Weight & Rolling Average Summary
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Weight', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(currentWeight.toStringAsFixed(1), style: AppTypography.displayLarge.copyWith(fontSize: 32, fontWeight: FontWeight.w900)),
                        const Text(' kg', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('Goal: Recomp (Hold ~62kg, build muscle)', style: TextStyle(fontSize: 11, color: AppColors.emeraldLight)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showWeighInDialog(currentWeight),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Weigh In', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),

          // Adherence Rule Card (if triggered)
          if (suggestion.type != AdherenceSuggestionType.none) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: suggestion.type == AdherenceSuggestionType.trimCalories
                    ? AppColors.amber.withOpacity(0.12)
                    : AppColors.emerald.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: suggestion.type == AdherenceSuggestionType.trimCalories
                      ? AppColors.amber.withOpacity(0.4)
                      : AppColors.emerald.withOpacity(0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: suggestion.type == AdherenceSuggestionType.trimCalories ? AppColors.amber : AppColors.emerald,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          suggestion.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: suggestion.type == AdherenceSuggestionType.trimCalories ? AppColors.amber : AppColors.emerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(suggestion.description, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Action: ${suggestion.actionRecommendation}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 7-Day Rolling Trend Chart
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('7-Day Rolling Trend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                const Text('Filters daily water fluctuation to show actual tissue recomp.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => const FlLine(color: AppColors.borderSubtle, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (val, _) => Text('${val.toInt()}', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (val, _) => Text('Wk${val.toInt()}', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minY: 60,
                      maxY: 64,
                      lineBarsData: [
                        LineChartBarData(
                          spots: weighIns.isNotEmpty
                              ? weighIns.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.weightKg)).toList()
                              : const [
                                  FlSpot(0, 62.2),
                                  FlSpot(1, 62.0),
                                  FlSpot(2, 61.9),
                                  FlSpot(3, 62.0),
                                  FlSpot(4, 62.1),
                                ],
                          isCurved: true,
                          color: AppColors.emerald,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.emerald.withOpacity(0.08),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Baseline Body Measurements from refeerece.html
          const SizedBox(height: 20),
          const Text('PHASE 1 BASELINE MEASUREMENTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(child: _MetricBadge(label: 'Height', value: '160 cm', sub: 'Baseline')),
              SizedBox(width: 8),
              Expanded(child: _MetricBadge(label: 'Biceps', value: '35 cm', sub: 'Upper Arm')),
              SizedBox(width: 8),
              Expanded(child: _MetricBadge(label: 'Forearm', value: '30 cm', sub: 'Grip')),
              SizedBox(width: 8),
              Expanded(child: _MetricBadge(label: 'Waist', value: '~70 cm', sub: 'Core')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final String sub;

  const _MetricBadge({required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.emeraldLight)),
          Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
