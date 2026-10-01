import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

/// Small building blocks for list-like screens (cart, pantry, checkout):
/// hairline rows, square checkboxes, tabular quantities.  Deliberately plain —
/// the content is the interface.

const tabularFigures = [FontFeature.tabularFigures()];

const kPantryUnits = ['g', 'kg', 'ml', 'l', 'pieces'];

String formatQty(double q) {
  if (q % 1 == 0) return q.toStringAsFixed(0);
  final s = q.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

/// Sensible +/- step per unit: nobody buys paneer 1 g at a time.
double stepFor(String unit) => switch (unit) {
      'g' || 'ml' => 50,
      'kg' || 'l' => 0.5,
      _ => 1,
    };

class SectionHeader extends StatelessWidget {
  final String title;
  final String? detail;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.detail,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 28, 20, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          if (detail != null) ...[
            const SizedBox(width: 8),
            Text(
              detail!,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontFeatures: tabularFigures),
            ),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class Hairline extends StatelessWidget {
  final double indent;
  const Hairline({super.key, this.indent = 20});

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, indent: indent, endIndent: 0, color: AppColors.borderSubtle);
}

class LedgerCheckbox extends StatelessWidget {
  final bool checked;
  const LedgerCheckbox({super.key, required this.checked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: checked ? AppColors.textPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: checked ? AppColors.textPrimary : AppColors.textMuted, width: 1.5),
      ),
      child: checked ? const Icon(Icons.check, size: 15, color: AppColors.textInverse) : null,
    );
  }
}

/// "+ Add" / "In cart" toggle used wherever a suggestion can go to the cart.
class AddToCartLink extends StatelessWidget {
  final bool inCart;
  final VoidCallback onAdd;
  const AddToCartLink({super.key, required this.inCart, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    if (inCart) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Text('In cart', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
      );
    }
    return TextButton(
      onPressed: onAdd,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brandPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: const Text('+ Add'),
    );
  }
}

/// Quantity with − / + and a typeable value.  Unit is shown, not edited here.
class QuantityStepper extends StatefulWidget {
  final double value;
  final String unit;
  final ValueChanged<double> onChanged;

  const QuantityStepper({super.key, required this.value, required this.unit, required this.onChanged});

  @override
  State<QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<QuantityStepper> {
  late final TextEditingController _ctrl = TextEditingController(text: formatQty(widget.value));

  @override
  void didUpdateWidget(QuantityStepper old) {
    super.didUpdateWidget(old);
    final parsed = double.tryParse(_ctrl.text);
    if (parsed != widget.value) _ctrl.text = formatQty(widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _nudge(int direction) {
    final step = stepFor(widget.unit);
    final next = (widget.value + direction * step).clamp(0.0, 100000.0);
    widget.onChanged(double.parse(next.toStringAsFixed(2)));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(icon: Icons.remove, onTap: widget.value > 0 ? () => _nudge(-1) : null),
        SizedBox(
          width: 56,
          child: TextField(
            controller: _ctrl,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFeatures: tabularFigures,
            ),
            decoration: const InputDecoration(
              isDense: true,
              filled: false,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.brandPrimary)),
            ),
            onChanged: (text) {
              final v = double.tryParse(text);
              if (v != null) widget.onChanged(v);
            },
          ),
        ),
        _StepButton(icon: Icons.add, onTap: () => _nudge(1)),
        const SizedBox(width: 6),
        SizedBox(
          width: 44,
          child: Text(widget.unit, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: onTap == null ? AppColors.borderSubtle : AppColors.border),
        ),
        child: Icon(icon, size: 16, color: onTap == null ? AppColors.textMuted : AppColors.textPrimary),
      ),
    );
  }
}

/// Thin horizontal meter.  [fraction] is clamped to 0..1.
class Meter extends StatelessWidget {
  final double fraction;
  final Color color;
  const Meter({super.key, required this.fraction, this.color = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: AppColors.surfaceElevated)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              heightFactor: 1,
              widthFactor: fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0,
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Unit choice as plain words; the selected one is underlined in brand colour.
/// Units the backend can't convert to grams would silently drop out of the
/// weekly ceiling, so the choice is limited to [kPantryUnits].
class UnitPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const UnitPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final units = kPantryUnits.contains(value) ? kPantryUnits : [...kPantryUnits, value];
    return Wrap(
      spacing: 4,
      children: [
        for (final unit in units)
          InkWell(
            onTap: () => onChanged(unit),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: unit == value ? AppColors.brandPrimary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: unit == value ? FontWeight.w600 : FontWeight.w400,
                  color: unit == value ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
