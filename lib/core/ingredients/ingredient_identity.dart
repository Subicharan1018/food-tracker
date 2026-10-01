import 'ingredient_synonyms.g.dart';

/// Dart mirror of `app/services/ingredient_identity.py::canonicalize`.
///
/// Every cart / pantry name comparison goes through this so that "Keerai"
/// added from a recipe and "Spinach" typed into the pantry are the same item.
/// Unknown names pass through (lower-cased, prep notes stripped), never dropped.
String canonicalizeIngredient(String rawName) {
  if (rawName.trim().isEmpty) return '';
  final preprocessed = _preprocess(rawName);

  final direct = ingredientSynonyms[preprocessed];
  if (direct != null) return direct;

  final singular = _depluralize(preprocessed);
  final viaSingular = ingredientSynonyms[singular];
  if (viaSingular != null) return viaSingular;

  return preprocessed;
}

final _parenStrip = RegExp(r'\s*\([^)]*\)');
final _commaStrip = RegExp(
  r'\s*,\s*(minced|chopped|sliced|diced|grated|crushed|'
  r'raw|cooked|dry|dried|washed|peeled|frozen|canned|'
  r'boiled|roasted|ground|powdered|fresh|whole|halved|'
  r'deseeded|deveined|skinless|boneless|cubed|julienned).*$',
  caseSensitive: false,
);

String _preprocess(String raw) {
  var name = raw.trim().toLowerCase();
  name = name.replaceAll(_parenStrip, '');
  name = name.replaceFirst(_commaStrip, '');
  return name.trim();
}

String _depluralize(String name) {
  if (name.endsWith('ies') && name.length > 4) {
    return '${name.substring(0, name.length - 3)}y';
  }
  return name;
}
