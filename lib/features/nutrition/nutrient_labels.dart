/// Display names for the 9 tracked micronutrient keys used by the backend.
class NutrientLabel {
  final String key;
  final String name;
  final String unit;
  const NutrientLabel(this.key, this.name, this.unit);
}

const trackedNutrients = <NutrientLabel>[
  NutrientLabel('vitaminD_mcg', 'Vitamin D', 'mcg'),
  NutrientLabel('b12_mcg', 'B12', 'mcg'),
  NutrientLabel('iron_mg', 'Iron', 'mg'),
  NutrientLabel('calcium_mg', 'Calcium', 'mg'),
  NutrientLabel('magnesium_mg', 'Magnesium', 'mg'),
  NutrientLabel('zinc_mg', 'Zinc', 'mg'),
  NutrientLabel('potassium_mg', 'Potassium', 'mg'),
  NutrientLabel('omega3_g', 'Omega-3', 'g'),
  NutrientLabel('folate_mcg', 'Folate', 'mcg'),
];

NutrientLabel nutrientLabel(String key) => trackedNutrients.firstWhere(
      (n) => n.key == key,
      orElse: () => NutrientLabel(key, key, ''),
    );

String formatNumber(dynamic value) {
  if (value is! num) return '–';
  if (value >= 100) return value.toStringAsFixed(0);
  return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}

/// "Sat 4 Oct, 8:05" — local time, for freshness stamps.
String formatStamp(String? iso) {
  final date = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (date == null) return 'unknown time';
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final minute = date.minute.toString().padLeft(2, '0');
  return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}, ${date.hour}:$minute';
}
