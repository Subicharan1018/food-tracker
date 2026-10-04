import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../core/local_db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ledger.dart';
import '../pantry/pantry_screen.dart';
import 'cart_checkout_sheet.dart';
import 'quick_add_parser.dart';
import 'shopping_cart_service.dart';
import 'shopping_list_card.dart';

/// The list you take to the shop.
///
/// Tap a row to put it in the trolley, swipe to remove, long-press to change
/// the amount.  "Finish shopping" moves everything in the trolley into the
/// pantry; anything not picked up stays here for next time.
class ShoppingCartScreen extends ConsumerStatefulWidget {
  const ShoppingCartScreen({super.key});

  @override
  ConsumerState<ShoppingCartScreen> createState() => _ShoppingCartScreenState();
}

class _ShoppingCartScreenState extends ConsumerState<ShoppingCartScreen> {
  bool _trolleyOpen = true;

  ShoppingCartService get _service => ref.read(shoppingCartServiceProvider);

  Future<void> _quickAdd(String text) async {
    final entry = parseQuickAdd(text);
    if (entry == null) return;
    await _service.addToCart(
      name: entry.name,
      quantity: entry.quantity,
      unit: entry.unit,
      addedFrom: CartSource.manual,
    );
  }

  void _remove(ShoppingCartItem item) {
    _service.removeItem(item.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Removed ${item.name}'),
        action: SnackBarAction(label: 'Undo', onPressed: () => _service.restoreItem(item)),
      ));
  }

  Future<void> _editQuantity(ShoppingCartItem item) async {
    var quantity = item.quantity;
    var unit = item.unit;
    final saved = await showModalBottomSheet<bool>(
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
                const SizedBox(height: 16),
                QuantityStepper(value: quantity, unit: unit, onChanged: (v) => setSheet(() => quantity = v)),
                const SizedBox(height: 12),
                UnitPicker(value: unit, onChanged: (u) => setSheet(() => unit = u)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: quantity > 0 ? () => Navigator.pop(ctx, true) : null,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) await _service.updateQuantity(item.id, quantity, unit);
  }

  void _finish(List<ShoppingCartItem> inTrolley) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (_) => CartCheckoutSheet(
        checkedItems: inTrolley,
        cartService: _service,
        onCheckoutComplete: (count) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$count ${count == 1 ? 'item' : 'items'} added to your pantry'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantryScreen())),
            ),
          ));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(cartItemsProvider);
    final items = itemsAsync.value ?? const <ShoppingCartItem>[];
    final toBuy = items.where((i) => !i.checked).toList();
    final inTrolley = items.where((i) => i.checked).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SHOPPING'),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantryScreen())),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('Pantry'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: itemsAsync.isLoading && items.isEmpty
          ? const SizedBox.shrink()
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Header(toBuy: toBuy.length, inTrolley: inTrolley.length)),
                SliverToBoxAdapter(child: _QuickAddField(onSubmit: _quickAdd)),
                if (items.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Text(
                        'Nothing on the list. Type above, or add what this week\'s gaps call for below.',
                        style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                if (toBuy.isNotEmpty) ...[
                  SliverToBoxAdapter(child: SectionHeader(title: 'To buy', detail: '${toBuy.length}')),
                  SliverList.separated(
                    itemCount: toBuy.length,
                    separatorBuilder: (_, _) => const Hairline(indent: 56),
                    itemBuilder: (_, i) => _CartRow(
                      item: toBuy[i],
                      onToggle: () => _service.toggleChecked(toBuy[i].id, true),
                      onRemove: () => _remove(toBuy[i]),
                      onEdit: () => _editQuantity(toBuy[i]),
                    ),
                  ),
                ],
                if (inTrolley.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: InkWell(
                      onTap: () => setState(() => _trolleyOpen = !_trolleyOpen),
                      child: SectionHeader(
                        title: 'In the trolley',
                        detail: '${inTrolley.length}',
                        trailing: Icon(
                          _trolleyOpen ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  if (_trolleyOpen)
                    SliverList.separated(
                      itemCount: inTrolley.length,
                      separatorBuilder: (_, _) => const Hairline(indent: 56),
                      itemBuilder: (_, i) => _CartRow(
                        item: inTrolley[i],
                        onToggle: () => _service.toggleChecked(inTrolley[i].id, false),
                        onRemove: () => _remove(inTrolley[i]),
                        onEdit: () => _editQuantity(inTrolley[i]),
                      ),
                    ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                const SliverToBoxAdapter(child: Hairline(indent: 0)),
                const SliverToBoxAdapter(child: ShoppingListCard()),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : _FinishBar(
              inTrolley: inTrolley.length,
              total: items.length,
              onFinish: inTrolley.isEmpty ? null : () => _finish(inTrolley),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  final int toBuy;
  final int inTrolley;
  const _Header({required this.toBuy, required this.inTrolley});

  @override
  Widget build(BuildContext context) {
    final total = toBuy + inTrolley;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                total == 0 ? 'Empty' : '$toBuy',
                style: AppTypography.hero.copyWith(fontSize: 64),
              ),
              if (total > 0) ...[
                const SizedBox(width: 8),
                Text(
                  toBuy == 0 ? 'left — all picked up' : 'left to pick up',
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 14),
            Meter(fraction: inTrolley / total, color: AppColors.brandPrimary),
          ],
        ],
      ),
    );
  }
}

class _QuickAddField extends StatefulWidget {
  final Future<void> Function(String) onSubmit;
  const _QuickAddField({required this.onSubmit});

  @override
  State<_QuickAddField> createState() => _QuickAddFieldState();
}

class _QuickAddFieldState extends State<_QuickAddField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text;
    if (text.trim().isEmpty) return;
    _ctrl.clear();
    await widget.onSubmit(text);
    _focus.requestFocus(); // keep typing the next item
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Add an item — e.g. "500 g paneer"',
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

class _CartRow extends StatelessWidget {
  final ShoppingCartItem item;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  const _CartRow({required this.item, required this.onToggle, required this.onRemove, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final done = item.checked;
    final reason = item.reason;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.surfaceElevated,
        child: const Icon(Icons.delete_outline, color: AppColors.destructive, size: 22),
      ),
      child: InkWell(
        onTap: onToggle,
        onLongPress: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 1), child: LedgerCheckbox(checked: done)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 140),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: done ? AppColors.textMuted : AppColors.textPrimary,
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.textMuted,
                      ),
                      child: Text(item.name),
                    ),
                    if (reason != null && reason.isNotEmpty && !done) ...[
                      const SizedBox(height: 3),
                      Text(
                        reason,
                        style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${formatQty(item.quantity)} ${item.unit}',
                style: TextStyle(
                  fontSize: 14,
                  color: done ? AppColors.textMuted : AppColors.textSecondary,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinishBar extends StatelessWidget {
  final int inTrolley;
  final int total;
  final VoidCallback? onFinish;

  const _FinishBar({required this.inTrolley, required this.total, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          Expanded(
            child: Text(
              inTrolley == 0 ? 'Tap items as you pick them up' : '$inTrolley of $total in the trolley',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFeatures: tabularFigures),
            ),
          ),
          ElevatedButton(
            onPressed: onFinish,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              disabledBackgroundColor: AppColors.surfaceElevated,
              disabledForegroundColor: AppColors.textMuted,
            ),
            child: const Text('Finish shopping'),
          ),
        ],
      ),
    );
  }
}
