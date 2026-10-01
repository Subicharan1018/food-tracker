/// Parses one-line entries like "2 kg onions", "paneer 200g", "1.5 l milk".
///
/// Anything without a recognisable quantity is one piece of [name].
class QuickAddEntry {
  final String name;
  final double quantity;
  final String unit;
  const QuickAddEntry(this.name, this.quantity, this.unit);
}

const _unitAliases = {
  'g': 'g', 'gm': 'g', 'gms': 'g', 'gram': 'g', 'grams': 'g',
  'kg': 'kg', 'kgs': 'kg', 'kilo': 'kg', 'kilos': 'kg',
  'ml': 'ml',
  'l': 'l', 'ltr': 'l', 'litre': 'l', 'litres': 'l', 'liter': 'l', 'liters': 'l',
  'pc': 'pieces', 'pcs': 'pieces', 'piece': 'pieces', 'pieces': 'pieces', 'x': 'pieces',
};

final _qty = r'(\d+(?:\.\d+)?)\s*([a-zA-Z]+)?';
final _leading = RegExp('^$_qty\\s+(.+)\$');
final _trailing = RegExp('^(.+?)\\s+$_qty\$');

QuickAddEntry? parseQuickAdd(String input) {
  final text = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return null;

  for (final (pattern, leading) in [(_leading, true), (_trailing, false)]) {
    final m = pattern.firstMatch(text);
    if (m == null) continue;
    final name = (leading ? m.group(3) : m.group(1))!.trim();
    final amount = double.parse(leading ? m.group(1)! : m.group(2)!);
    final rawUnit = (leading ? m.group(2) : m.group(3))?.toLowerCase();
    if (rawUnit == null) {
      if (amount > 0) return QuickAddEntry(name, amount, 'pieces');
      continue;
    }
    final unit = _unitAliases[rawUnit];
    // "2 eggs": the trailing word is the food, not a unit.
    if (unit == null) {
      if (leading && amount > 0) return QuickAddEntry('$rawUnit $name'.trim(), amount, 'pieces');
      continue;
    }
    if (amount > 0 && name.isNotEmpty) return QuickAddEntry(name, amount, unit);
  }
  return QuickAddEntry(text, 1, 'pieces');
}
