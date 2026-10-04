import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/local_db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ledger.dart';

/// Your manual's progress-tracking routine in one place:
/// Sunday weigh-in (fasted), a progress photo from the same spot, and the
/// tape measure every 4 weeks.  Photos never leave the phone.
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

const tapeEveryDays = 28;
const _tapeSites = ['waist', 'biceps', 'forearm'];

final _photosProvider = StreamProvider<List<ProgressPhoto>>((ref) => ref.watch(databaseProvider).watchProgressPhotos());

final _checkInStateProvider = FutureProvider<({WeighIn? weighIn, String? lastTape})>((ref) async {
  ref.watch(weighInsStreamProvider);
  final db = ref.watch(databaseProvider);
  return (weighIn: await db.latestWeighIn(), lastTape: await db.latestMeasurementDate());
});

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  final _weight = TextEditingController();
  final _tape = {for (final s in _tapeSites) s: TextEditingController()};
  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void dispose() {
    _weight.dispose();
    for (final c in _tape.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _saveWeight() async {
    final kg = double.tryParse(_weight.text.trim());
    if (kg == null || kg <= 20 || kg > 300) return _toast('Enter your weight in kg');
    await ref.read(databaseProvider).saveWeighIn(_today, kg);
    _weight.clear();
    _toast('Weigh-in saved: ${formatQty(kg)} kg');
  }

  Future<void> _takePhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/progress_photos');
    await dir.create(recursive: true);
    final file = await File(picked.path).copy('${dir.path}/$_today.jpg');
    await ref.read(databaseProvider).saveProgressPhoto(_today, file.path);
    // Same filename on retake: drop the old decoded image from the cache.
    imageCache.evict(FileImage(file));
    if (mounted) setState(() {});
  }

  Future<void> _saveTape() async {
    final db = ref.read(databaseProvider);
    var saved = 0;
    for (final site in _tapeSites) {
      final cm = double.tryParse(_tape[site]!.text.trim());
      if (cm == null || cm <= 0) continue;
      await db.addMeasurement(MeasurementsCompanion.insert(
        id: const Uuid().v4(),
        date: _today,
        type: site,
        valueCm: cm,
      ));
      _tape[site]!.clear();
      saved++;
    }
    _toast(saved == 0 ? 'Enter at least one measurement in cm' : 'Saved $saved measurement${saved == 1 ? '' : 's'}');
    ref.invalidate(_checkInStateProvider);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_checkInStateProvider).value;
    final photos = ref.watch(_photosProvider).value ?? const <ProgressPhoto>[];
    final weighedToday = state?.weighIn?.date == _today;
    final photoToday = photos.any((p) => p.date == _today);
    final lastTape = state?.lastTape == null ? null : DateTime.parse(state!.lastTape!);
    final tapeDue = lastTape == null || DateTime.now().difference(lastTape).inDays >= tapeEveryDays;

    return Scaffold(
      appBar: AppBar(title: const Text('CHECK-IN')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              'Every Sunday: weigh in before food and water, then a photo in the same spot and light. Tape measure every 4 weeks.',
              style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSecondary),
            ),
          ),

          // Weigh-in
          SectionHeader(title: 'Weigh-in', detail: weighedToday ? 'done today' : null),
          if (weighedToday)
            _DoneRow('${formatQty(state!.weighIn!.weightKg)} kg'
                '${state.weighIn!.rollingAvgKg != null ? ' · 7-day average ${formatQty(state.weighIn!.rollingAvgKg!)} kg' : ''}')
          else
            _InputRow(
              controller: _weight,
              hint: state?.weighIn == null ? 'Weight in kg' : 'Last: ${formatQty(state!.weighIn!.weightKg)} kg (${state.weighIn!.date})',
              suffix: 'kg',
              action: 'Save',
              onAction: _saveWeight,
            ),

          // Photo
          SectionHeader(title: 'Progress photo', detail: photoToday ? 'done today' : null),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => _takePhoto(ImageSource.camera),
                  style: TextButton.styleFrom(foregroundColor: AppColors.brandPrimary),
                  child: Text(photoToday ? 'Retake' : 'Take photo'),
                ),
                TextButton(
                  onPressed: () => _takePhoto(ImageSource.gallery),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                  child: const Text('From gallery'),
                ),
              ],
            ),
          ),

          // Tape
          SectionHeader(
            title: 'Tape measure',
            detail: tapeDue ? 'due' : 'next ${DateFormat('d MMM').format(lastTape.add(const Duration(days: tapeEveryDays)))}',
          ),
          if (tapeDue) ...[
            for (final site in _tapeSites)
              _InputRow(controller: _tape[site]!, hint: '${site[0].toUpperCase()}${site.substring(1)}', suffix: 'cm'),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _saveTape,
                  style: TextButton.styleFrom(foregroundColor: AppColors.brandPrimary),
                  child: const Text('Save measurements'),
                ),
              ),
            ),
          ] else
            const _DoneRow('Not due yet — every 4 weeks keeps the trend honest.'),

          if (photos.length >= 2) ...[
            const SectionHeader(title: 'Then and now'),
            _PhotoCompare(photos: photos),
          ] else if (photos.length == 1)
            const _DoneRow('Your second photo unlocks the side-by-side comparison.'),
        ],
      ),
    );
  }
}

class _DoneRow extends StatelessWidget {
  final String text;
  const _DoneRow(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFeatures: tabularFigures)),
      );
}

class _InputRow extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String suffix;
  final String? action;
  final VoidCallback? onAction;

  const _InputRow({required this.controller, required this.hint, required this.suffix, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, fontFeatures: tabularFigures),
              decoration: InputDecoration(
                hintText: hint,
                suffixText: suffix,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.brandPrimary)),
              ),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: AppColors.brandPrimary),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// First photo vs a chosen one (latest by default); tap a date to switch.
class _PhotoCompare extends StatefulWidget {
  final List<ProgressPhoto> photos;
  const _PhotoCompare({required this.photos});

  @override
  State<_PhotoCompare> createState() => _PhotoCompareState();
}

class _PhotoCompareState extends State<_PhotoCompare> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final first = photos.first;
    final other = photos.firstWhere((p) => p.date == _selected, orElse: () => photos.last);

    Widget pane(ProgressPhoto p) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: AppShapes.information,
                  child: Image.file(
                    File(p.path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: AppColors.surfaceElevated,
                      child: Center(child: Text('Missing', style: TextStyle(color: AppColors.textMuted))),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(DateFormat('d MMM yyyy').format(DateTime.parse(p.date)),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [pane(first), const SizedBox(width: 10), pane(other)]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final p in photos.skip(1))
                TextButton(
                  onPressed: () => setState(() => _selected = p.date),
                  style: TextButton.styleFrom(
                    foregroundColor: p.date == other.date ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                  child: Text(DateFormat('d MMM').format(DateTime.parse(p.date))),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
