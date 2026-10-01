import 'package:flutter/material.dart';
import '../../core/local_db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ledger.dart';
import 'shopping_cart_service.dart';

/// Shown on "Finish shopping": confirm what was actually bought.
///
/// Quantities start at what the cart suggested and can be changed — the
/// pantry should reflect the bag, not the plan.  Setting one to 0 leaves it
/// out of the pantry (and off the list).
class CartCheckoutSheet extends StatefulWidget {
  final List<ShoppingCartItem> checkedItems;
  final ShoppingCartService cartService;
  final void Function(int addedCount) onCheckoutComplete;

  const CartCheckoutSheet({
    super.key,
    required this.checkedItems,
    required this.cartService,
    required this.onCheckoutComplete,
  });

  @override
  State<CartCheckoutSheet> createState() => _CartCheckoutSheetState();
}

class _CartCheckoutSheetState extends State<CartCheckoutSheet> {
  late final List<double> _quantities = [for (final i in widget.checkedItems) i.quantity];
  bool _saving = false;
  String? _error;

  int get _addCount => _quantities.where((q) => q > 0).length;

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final bought = [
        for (var i = 0; i < widget.checkedItems.length; i++) widget.checkedItems[i].copyWith(quantity: _quantities[i]),
      ];
      await widget.cartService.checkoutCart(bought);
      if (!mounted) return;
      final count = _addCount;
      Navigator.of(context).pop();
      widget.onCheckoutComplete(count);
    } catch (e) {
      if (mounted) setState(() => _error = 'Couldn\'t update the pantry. Nothing was changed.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.checkedItems;
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text('Into the pantry', style: AppTypography.titleLarge),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Adjust to what you actually bought. Items left unticked stay on the list.',
              style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              controller: scroll,
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, _) => const Hairline(),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        items[i].name,
                        style: TextStyle(
                          fontSize: 15,
                          color: _quantities[i] > 0 ? AppColors.textPrimary : AppColors.textMuted,
                          decoration: _quantities[i] > 0 ? null : TextDecoration.lineThrough,
                          decorationColor: AppColors.textMuted,
                        ),
                      ),
                    ),
                    QuantityStepper(
                      value: _quantities[i],
                      unit: items[i].unit,
                      onChanged: (v) => setState(() => _quantities[i] = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.attention)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: ElevatedButton(
                onPressed: _saving ? null : _confirm,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textInverse),
                      )
                    : Text(_addCount == 0
                        ? 'Clear from list'
                        : 'Add $_addCount ${_addCount == 1 ? 'item' : 'items'} to pantry'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
