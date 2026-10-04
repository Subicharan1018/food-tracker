import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/scoreboard.dart';
import '../../../checkin/checkin_screen.dart';
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
        title: Text('Edit Weight Goal', style: AppTypography.titleLarge),
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
            style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.textInverse,
            ),
            onPressed: () {
              final newTarget = double.tryParse(targetCtrl.text);
              final newWeeks = int.tryParse(weeksCtrl.text);
              setState(() {
                if (newTarget != null && newTarget > 0) _targetWeightKg = newTarget;
                if (newWeeks != null && newWeeks > 0) _weeksRemaining = newWeeks;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  Text('Log Today\'s Weigh-In', style: AppTypography.titleLarge),
                  const SizedBox(height: 4),
                  const Text('Weigh in the morning before food for consistency.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(weight.toStringAsFixed(1), style: AppTypography.displayLarge.copyWith(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                        const Text(' kg', style: TextStyle(fontSize: 20, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Decrease',
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 32),
                        color: AppColors.textPrimary,
                        onPressed: () => setModalState(() => weight -= 0.1),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        tooltip: 'Increase',
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 32),
                        color: AppColors.textPrimary,
                        onPressed: () => setModalState(() => weight += 0.1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.textInverse,
                      ),
                      onPressed: () async {
                        final db = ref.read(databaseProvider);
                        final dateStr = ref.read(formattedSelectedDateProvider);

                        await db.saveWeighIn(dateStr, weight);

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Saved weigh-in: ${weight.toStringAsFixed(1)} kg')),
                          );
                        }
                      },
                      child: const Text('Save Weigh-In', style: TextStyle(color: AppColors.textInverse, fontWeight: FontWeight.w800)),
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
                  Text('Log Tape Measurement', style: AppTypography.titleLarge),
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
                            selectedColor: AppColors.brandPrimary,
                            backgroundColor: AppColors.card,
                            side: BorderSide(color: sel ? AppColors.brandPrimary : AppColors.border),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: sel ? AppColors.textInverse : AppColors.textSecondary,
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
                        Text(valueCm.toStringAsFixed(1), style: AppTypography.displayLarge.copyWith(fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                        const Text(' cm', style: TextStyle(fontSize: 18, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Decrease',
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 28),
                        color: AppColors.textPrimary,
                        onPressed: () => setModalState(() => valueCm -= 0.5),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        tooltip: 'Increase',
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
                        color: AppColors.textPrimary,
                        onPressed: () => setModalState(() => valueCm += 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.textInverse,
                      ),
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
                      child: const Text('Save Measurement', style: TextStyle(color: AppColors.textInverse, fontWeight: FontWeight.w800)),
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
    final weighIns = ref.watch(weighInsStreamProvider).value ?? const <WeighIn>[];
    final profileWeight = ref.watch(userProfileProvider).value?.weightKg ?? 62.0;
    // Newest first from the db; charts read left-to-right in time.
    final chronological = weighIns.reversed.toList();
    final latest = weighIns.isEmpty ? null : weighIns.first;
    final currentWeight = latest?.weightKg ?? profileWeight;
    final average = latest?.rollingAvgKg ?? currentWeight;
    final change = chronological.length < 2 ? null : currentWeight - chronological.first.weightKg;

    final targetWeight = _targetWeightKg ?? (currentWeight > 1.8 ? currentWeight - 1.8 : currentWeight);
    final toGo = targetWeight - average;
    final suggestion = AdherenceEngine.evaluate(weeklyAverages: weighIns.take(4).map((w) => w.weightKg).toList());

    String kg(double v) => v.toStringAsFixed(1);
    String signed(double v) => '${v > 0 ? '+' : v < 0 ? '−' : '±'}${kg(v.abs())}';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppShapes.gutter,
        title: const Text('PROGRESS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.straighten, size: 20),
            tooltip: 'Log tape measurements',
            onPressed: _showMeasurementDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 32),
        children: [
          Board(
            label: 'Weight',
            trailing: TextButton(
              onPressed: () => _showWeighInDialog(currentWeight),
              child: Text('LOG WEIGH-IN', style: AppTypography.label.copyWith(color: AppColors.brandPrimary)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BigNumber(kg(currentWeight), unit: 'kg', caption: latest == null ? 'No weigh-ins yet' : 'WEIGHED ${_day(latest.date)}'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _Figure(label: '7-day avg', value: '${kg(average)} kg')),
                    Expanded(child: _Figure(label: 'Since start', value: change == null ? '–' : '${signed(change)} kg')),
                    Expanded(
                      child: InkWell(
                        onTap: () => _showEditGoalDialog(currentWeight),
                        child: _Figure(label: 'Goal · edit', value: '${kg(targetWeight)} kg', note: '${signed(toGo)} to go'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Board(
            label: 'Trend',
            trailing: Text('LINE = 7-DAY AVG', style: AppTypography.dataSmall),
            child: SizedBox(
              height: 200,
              child: chronological.length < 2
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Two weigh-ins draw the trend. Weigh in each Sunday, before food and water.', style: AppTypography.bodyMedium),
                    )
                  : LineChart(
                      LineChartData(
                        minY: (chronological.map((w) => w.weightKg).reduce((a, b) => a < b ? a : b) - 0.5).floorToDouble(),
                        maxY: (chronological.map((w) => w.weightKg).reduce((a, b) => a > b ? a : b) + 0.5).ceilToDouble(),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval: 0.5,
                          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.borderSubtle, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: const Border(bottom: BorderSide(color: AppColors.border)),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: 0.5,
                              getTitlesWidget: (v, _) => Text(kg(v), style: AppTypography.dataSmall.copyWith(fontSize: 10)),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              interval: 1,
                              getTitlesWidget: (v, _) {
                                final i = v.toInt();
                                if (i < 0 || i >= chronological.length || v != i.toDouble()) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    DateFormat('d MMM').format(DateTime.parse(chronological[i].date)).toUpperCase(),
                                    style: AppTypography.dataSmall.copyWith(fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          // 7-day average: the line that matters.
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < chronological.length; i++)
                                FlSpot(i.toDouble(), chronological[i].rollingAvgKg ?? chronological[i].weightKg),
                            ],
                            color: AppColors.brandPrimary,
                            barWidth: 3,
                            isCurved: false,
                            dotData: const FlDotData(show: false),
                          ),
                          // Raw weigh-ins as dots only.
                          LineChartBarData(
                            spots: [for (var i = 0; i < chronological.length; i++) FlSpot(i.toDouble(), chronological[i].weightKg)],
                            color: Colors.transparent,
                            barWidth: 0,
                            dotData: FlDotData(
                              getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 3, color: AppColors.textPrimary, strokeWidth: 0),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          if (suggestion.type != AdherenceSuggestionType.none)
            Board(
              label: suggestion.title,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(suggestion.description, style: AppTypography.bodyLarge),
                  const SizedBox(height: 8),
                  Text(
                    suggestion.actionRecommendation,
                    style: AppTypography.bodyLarge.copyWith(
                      color: suggestion.type == AdherenceSuggestionType.trimCalories ? AppColors.attention : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

          Board(
            label: 'Photos & tape',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckInScreen())),
            trailing: Text('OPEN', style: AppTypography.label.copyWith(color: AppColors.brandPrimary)),
            child: Text('Sunday photo in the same spot, tape every 4 weeks, first-vs-latest side by side.', style: AppTypography.bodyMedium),
          ),

          Board(
            label: 'Log',
            child: weighIns.isEmpty
                ? Text('No weigh-ins yet.', style: AppTypography.bodyMedium)
                : Column(
                    children: [
                      for (final w in weighIns) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(child: Text(_day(w.date), style: AppTypography.dataSmall)),
                              SizedBox(width: 90, child: Text('${kg(w.weightKg)} kg', style: AppTypography.data, textAlign: TextAlign.right)),
                              SizedBox(
                                width: 110,
                                child: Text('avg ${kg(w.rollingAvgKg ?? w.weightKg)}', style: AppTypography.dataSmall, textAlign: TextAlign.right),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

String _day(String date) => DateFormat('EEE d MMM').format(DateTime.parse(date)).toUpperCase();

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  const _Figure({required this.label, required this.value, this.note});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTypography.label.copyWith(fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.data.copyWith(fontSize: 16)),
          if (note != null) Text(note!, style: AppTypography.dataSmall),
        ],
      );
}
