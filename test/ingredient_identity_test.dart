import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/core/ingredients/ingredient_identity.dart';
import 'package:food_tracker/features/shopping_cart/quick_add_parser.dart';

void main() {
  test('Dart canonicalizer matches the backend for the same inputs', () {
    // Expected values captured from app/services/ingredient_identity.py.
    const cases = {
      'Keerai': 'spinach',
      'Onions': 'onion',
      'Garlic, minced': 'garlic',
      'Chicken (boneless)': 'chicken',
      'Rajma': 'kidney beans',
      'Mystery Powder': 'mystery powder',
      '  Palak  ': 'spinach',
      '': '',
    };
    cases.forEach((input, expected) => expect(canonicalizeIngredient(input), expected, reason: input));
  });

  group('quick add', () {
    void check(String input, String name, double qty, String unit) {
      final e = parseQuickAdd(input)!;
      expect([e.name, e.quantity, e.unit], [name, qty, unit], reason: input);
    }

    test('leading and trailing quantities', () {
      check('2 kg onions', 'onions', 2, 'kg');
      check('paneer 200g', 'paneer', 200, 'g');
      check('1.5 litres milk', 'milk', 1.5, 'l');
      check('12 eggs', 'eggs', 12, 'pieces');
      check('2 large eggs', 'large eggs', 2, 'pieces');
    });

    test('no quantity means one piece', () {
      check('Coriander', 'Coriander', 1, 'pieces');
      expect(parseQuickAdd('   '), isNull);
    });
  });
}
