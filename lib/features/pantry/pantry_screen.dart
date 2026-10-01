import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../core/ingredients/ingredient_identity.dart';
import '../../core/local_db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ledger.dart';
import '../shopping_cart/quick_add_parser.dart';
import '../shopping_cart/shopping_cart_service.dart' show convertQuantity;

/// What's in the kitchen.  The server computes the weekly nutrient ceiling
/// and the shopping list from exactly these rows (synced to Firestore).
class PantryScreen extends ConsumerWidget {
  const PantryScreen({super.key});

  Future<void> _add(WidgetRef ref, String text) async {
    final entry = parseQuickAdd(text);
    if (entry == null) return;
    final db = ref.read(databaseProvider);
    final canonical = canonicalizeIngredient(entry.name);
    for (final row in await db.getInventoryItemsByCanonicalName(canonical)) {
      final converted = convertQuantity(entry.quantity, entry.unit, row.unit);
      if (converted != null) {
        await db.incrementInventoryQuantity(row.id, converted);
        return;
      }
    }
    {
      await db.createInventoryItem(InventoryItemsCompanion.insert(
        name: entry.name,
        canonicalName: canonical,
        quantity: Value(entry.quantity),
        unit: Value(entry.unit),
      ));
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, InventoryItem item) async {
    final db = ref.read(databaseProvider);
    var quantity = item.quantity;
    var unit = item.unit;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTypography.titleLarge),
                if (item.canonicalName != item.name.toLowerCase())
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Matched as ${item.canonicalName}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  ),
                const SizedBox(height: 16),
                QuantityStepper(value: quantity, unit: unit, onChanged: (v) => setSheet(() => quantity = v)),
                const SizedBox(height: 12),
                UnitPicker(value: unit, onChanged: (u) => setSheet(() => unit = u)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(ctx, 'delete'),
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.destructive),
                      label: const Text('Used up', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, quantity > 0 ? 'save' : 'delete'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(120, 48)),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (action == 'save') {
      await db.updateInventoryItem(
        item.id,
        InventoryItemsCompanion(quantity: Value(quantity), unit: Value(unit)),
      );
    } else if (action == 'delete') {
      await db.deleteInventoryItem(item.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inventoryItemsProvider).value ?? const <InventoryItem>[];
    final uncounted = items.where((i) => i.unit == 'pieces').length;

    return Scaffold(
      appBar: AppBar(title: const Text('Pantry')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              items.isEmpty
                  ? 'Your weekly nutrient ceiling is computed from what\'s here. Add what you have, or finish a shopping trip to fill it.'
                  : '${items.length} ${items.length == 1 ? 'item' : 'items'}. The weekly nutrient ceiling is computed from this list.',
              style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSecondary),
            ),
          ),
          _PantryAddField(onSubmit: (text) => _add(ref, text)),
          if (uncounted > 0)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                'Items in "pieces" only count when their piece weight is on record (eggs, onions, bananas…). '
                'Use g, kg, ml or l to be sure they count.',
                style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.textMuted),
              ),
            ),
          const SizedBox(height: 8),
          for (var i = 0; i < items.length; i++) ...[
            InkWell(
              onTap: () => _edit(context, ref, items[i]),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(items[i].name,
                          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                    ),
                    Text(
                      '${formatQty(items[i].quantity)} ${items[i].unit}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < items.length - 1) const Hairline(),
          ],
        ],
      ),
    );
  }
}

class _PantryAddField extends StatefulWidget {
  final Future<void> Function(String) onSubmit;
  const _PantryAddField({required this.onSubmit});

  @override
  State<_PantryAddField> createState() => _PantryAddFieldState();
}

class _PantryAddFieldState extends State<_PantryAddField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text;
    if (text.trim().isEmpty) return;
    _ctrl.clear();
    await widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: TextField(
        controller: _ctrl,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Add stock — e.g. "1 kg rajma"',
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.brandPrimary)),
          suffixIcon: IconButton(
            tooltip: 'Add',
            icon: const Icon(Icons.keyboard_return, size: 20, color: AppColors.textMuted),
            onPressed: _submit,
          ),
        ),
      ),
    );
  }
}
