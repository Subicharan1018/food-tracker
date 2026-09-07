import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
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
  double? _targetWeightKg;
  int _weeksRemaining = 2;

  void _showEditGoalDialog(double currentWeight) {
    final defaultTarget = _targetWeightKg ?? (currentWeight > 1.8 ? currentWeight - 1.8 : currentWeight);
    final targetCtrl = TextEditingController(text: defaultTarget.toStringAsFixed(1));
    final weeksCtrl = TextEditingController(text: '$_weeksRemaining');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Edit Weight Goal', style: AppTypography.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: targetCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Target Weight (kg)',
                suffixText: 'kg',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weeksCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weeks Remaining'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final newTarget = double.tryParse(targetCtrl.text);
              final newWeeks = int.tryParse(weeksCtrl.text);
              setState(() {
                if (newTarget != null && newTarget > 0) _targetWeightKg = newTarget;
                if (newWeeks != null && newWeeks > 0) _weeksRemaining = newWeeks;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

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
                        Text(weight.toStringAsFixed(1), style: AppTypography.displayLarge.copyWith(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.primary)),
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
                        color: AppColors.primary,
                        onPressed: () => setModalState(() => weight -= 0.1),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 32),
                        color: AppColors.primary,
                        onPressed: () => setModalState(() => weight += 0.1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: () async {
                        final db = ref.read(databaseProvider);
                        final dateStr = ref.read(formattedSelectedDateProvider);

                        await db.addWeighIn(
                          WeighInsCompanion.insert(
                            id: const Uuid().v4(),
                            date: dateStr,
                            weightKg: weight,
                            rollingAvgKg: Value(weight),
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
                      child: const Text('Save Weigh-In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.card,
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : AppColors.textSecondary,
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
                        Text(valueCm.toStringAsFixed(1), style: AppTypography.displayLarge.copyWith(fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.primary)),
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
                        color: AppColors.primary,
                        onPressed: () => setModalState(() => valueCm -= 0.5),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
                        color: AppColors.primary,
                        onPressed: () => setModalState(() => valueCm += 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
                      child: const Text('Save Measurement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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

    final targetWeight = _targetWeightKg ?? (currentWeight > 1.8 ? currentWeight - 1.8 : currentWeight);
    final diff = targetWeight - currentWeight;
    final String goalTitle;
    if (diff < -0.2) {
      goalTitle = 'Lose ${(-diff).toStringAsFixed(1)} kg';
    } else if (diff > 0.2) {
      goalTitle = 'Gain ${diff.toStringAsFixed(1)} kg';
    } else {
      goalTitle = 'Maintain Weight (${currentWeight.toStringAsFixed(1)} kg)';
    }

    final weighIns = weighInsAsync.value ?? [];

    // Adherence suggestion check
    final weeklyAverages = weighIns.take(4).map((w) => w.weightKg).toList();
    final suggestion = AdherenceEngine.evaluate(weeklyAverages: weeklyAverages);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.straighten_rounded, color: AppColors.primary),
            tooltip: 'Tape Measurements',
            onPressed: _showMeasurementDialog,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () => _showWeighInDialog(currentWeight),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Goal Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.scale_rounded, color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goalTitle,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_weeksRemaining weeks remaining',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 18),
                  onPressed: () => _showEditGoalDialog(currentWeight),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. 7-Day Rolling Trend Chart
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Weight Trend (7-Day Avg)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('Current: ${currentWeight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  child: weighIns.isEmpty
                      ? const Center(
                          child: Text(
                            'No weigh-in data logged yet.\nLog daily morning weigh-ins to track your 7-day trend.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
                          ),
                        )
                      : LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => const FlLine(color: AppColors.border, strokeWidth: 1),
                            ),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 36,
                                  getTitlesWidget: (val, _) => Text(val.toStringAsFixed(1), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 22,
                                  getTitlesWidget: (val, _) {
                                    final index = val.toInt();
                                    if (index < 0 || index >= weighIns.length) return const SizedBox.shrink();
                                    final date = DateFormat('M/d').format(DateTime.tryParse(weighIns[index].date) ?? DateTime.now());
                                    return Text(date, style: const TextStyle(color: AppColors.textMuted, fontSize: 10));
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: weighIns.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.weightKg)).toList(),
                                isCurved: true,
                                color: AppColors.primary,
                                barWidth: 3,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: AppColors.primary.withOpacity(0.08),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                    ? AppColors.attention.withOpacity(0.12)
                    : AppColors.positive.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: suggestion.type == AdherenceSuggestionType.trimCalories
                      ? AppColors.attention.withOpacity(0.4)
                      : AppColors.positive.withOpacity(0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: suggestion.type == AdherenceSuggestionType.trimCalories ? AppColors.attention : AppColors.positive,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          suggestion.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: suggestion.type == AdherenceSuggestionType.trimCalories ? AppColors.attention : AppColors.positive,
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

          const SizedBox(height: 16),

          // 3. Build Your Progress Gallery Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Build Your Progress Gallery',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Every photo helps you see changes the scale can\'t.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Photo progress attached to today\'s weigh-in!')),
                          );
                        },
                        child: const Text('Add Photo  >', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primary, size: 30),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 4. Timeline Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Timeline', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text('View Progress Gallery >', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),

          // Timeline weigh-in records
          if (weighIns.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text('No weigh-ins recorded yet. Tap + to log today.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            )
          else
            ...weighIns.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.weightKg.toStringAsFixed(1)} kg',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                          Text(
                            item.date,
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt_outlined, color: AppColors.textSecondary, size: 20),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Attached progress snapshot')),
                        );
                      },
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 80), // Padding for FAB
        ],
      ),
    );
  }
}
