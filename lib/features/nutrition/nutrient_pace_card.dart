import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/ingredients/ingredient_identity.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ledger.dart';
import '../shopping_cart/shopping_cart_screen.dart';
import '../shopping_cart/shopping_cart_service.dart';
import 'nutrient_labels.dart';

/// Today's micronutrient pace from the server's 11/14/17/21 checks.
///
/// Shows only what the server computed: how far behind each nutrient is, and
/// the one pre-computed recipe that would help ("fix with what you have", or
/// what to buy to make it).  The coach message is AI prose over those facts.
class NutrientPaceCard extends ConsumerWidget {
  final Map<String, dynamic>? status;

  const NutrientPaceCard({super.key, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = status ?? const <String, dynamic>{};
    final issues = data['issues'] is Map ? Map<String, dynamic>.from(data['issues'] as Map) : const <String, dynamic>{};
    final gaps = issues['nutrient_gaps'] is Map
        ? Map<String, dynamic>.from(issues['nutrient_gaps'] as Map)
        : const <String, dynamic>{};
    final protein = issues['protein_behind'] is Map ? Map<String, dynamic>.from(issues['protein_behind']) : null;
    final updatedAt = data['updated_at']?.toString();
    final message = data['message']?.toString();
    final candidate = data['candidate_recipe'] is Map ? Map<String, dynamic>.from(data['candidate_recipe']) : null;

    final cart = ref.watch(cartItemsProvider).value ?? const [];
    final inCart = {for (final c in cart) c.canonicalName};

    final rows = <Widget>[
      if (protein != null) _PaceRow(label: 'Protein', consumed: protein['consumed'], expected: protein['expected'], unit: 'g'),
      for (final n in trackedNutrients)
        if (gaps[n.key] is Map)
          _PaceRow(label: n.name, consumed: gaps[n.key]['consumed'], expected: gaps[n.key]['expected'], unit: n.unit),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppShapes.information,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text('Micronutrient pace', style: AppTypography.titleMedium),
                const Spacer(),
                Text(
                  updatedAt == null ? 'checks at 11, 2, 5, 9' : 'as of ${formatStamp(updatedAt)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (issues.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              updatedAt == null
                  ? 'No check has run yet today. Log meals made from your recipes so their nutrients count.'
                  : 'On pace at the last check.',
              style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSecondary),
            ),
          ],
          if (issues['missed_logging'] == true) ...[
            const SizedBox(height: 8),
            const Text(
              'Nothing logged yet today.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
          if (message != null && message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(message, style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textPrimary)),
            ),
          ],
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Behind where you\'d expect by now',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            ...rows,
          ],
          if (candidate != null) ...[
            const SizedBox(height: 14),
            const Padding(padding: EdgeInsets.only(right: 8), child: Hairline(indent: 0)),
            const SizedBox(height: 12),
            _CandidateBlock(
              candidate: candidate,
              inCart: inCart,
              onAdd: (ing) => ref.read(shoppingCartServiceProvider).addToCart(
                    name: '${ing['name']}',
                    canonicalName: '${ing['canonical_name'] ?? ing['name']}',
                    quantity: (ing['quantity'] as num?)?.toDouble() ?? 1,
                    unit: '${ing['unit'] ?? 'pieces'}',
                    addedFrom: CartSource.recipeSuggestion,
                    reason: 'Unlocks ${candidate['name']}',
                  ),
              onOpenCart: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShoppingCartScreen()),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text(
              'Counted from IFCT 2017 / USDA FDC values only. Unmatched ingredients are left out, not guessed.',
              style: TextStyle(fontSize: 11, height: 1.4, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaceRow extends StatelessWidget {
  final String label;
  final dynamic consumed;
  final dynamic expected;
  final String unit;

  const _PaceRow({required this.label, required this.consumed, required this.expected, required this.unit});

  @override
  Widget build(BuildContext context) {
    final fraction = consumed is num && expected is num && expected > 0 ? consumed / expected : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              const Spacer(),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: formatNumber(consumed), style: const TextStyle(color: AppColors.textPrimary)),
                  TextSpan(text: ' / ${formatNumber(expected)} $unit'),
                ]),
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontFeatures: tabularFigures),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Meter(fraction: fraction.toDouble(), color: AppColors.attention),
        ],
      ),
    );
  }
}

class _CandidateBlock extends StatelessWidget {
  final Map<String, dynamic> candidate;
  final Set<String> inCart;
  final void Function(Map<String, dynamic>) onAdd;
  final VoidCallback onOpenCart;

  const _CandidateBlock({
    required this.candidate,
    required this.inCart,
    required this.onAdd,
    required this.onOpenCart,
  });

  @override
  Widget build(BuildContext context) {
    final makeable = candidate['makeable'] == true;
    final label = nutrientLabel('${candidate['nutrient']}');
    final missing = (candidate['missing_ingredients'] is List ? candidate['missing_ingredients'] as List : const [])
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : {'name': '$e', 'canonical_name': '$e'})
        .toList();
    final allInCart = missing.isNotEmpty &&
        missing.every((m) => inCart.contains(canonicalizeIngredient('${m['canonical_name'] ?? m['name']}')));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          makeable ? 'Fix with what you have' : 'Closest fix',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '${candidate['name']}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              if (candidate['per_serving_amount'] is num)
                TextSpan(
                  text: '  ${formatNumber(candidate['per_serving_amount'])} ${label.unit} ${label.name.toLowerCase()} per serving',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
            ]),
            style: const TextStyle(fontFeatures: tabularFigures),
          ),
        ),
        if (makeable)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Everything it needs is in your pantry.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          )
        else ...[
          const SizedBox(height: 2),
          for (final ing in missing)
            Row(
              children: [
                Expanded(
                  child: Text('Needs ${ing['name']}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ),
                if (ing['quantity'] is num)
                  Text(
                    '${formatQty((ing['quantity'] as num).toDouble())} ${ing['unit'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontFeatures: tabularFigures),
                  ),
                AddToCartLink(
                  inCart: inCart.contains(canonicalizeIngredient('${ing['canonical_name'] ?? ing['name']}')),
                  onAdd: () => onAdd(ing),
                ),
              ],
            ),
          if (allInCart)
            TextButton(
              onPressed: onOpenCart,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
              ),
              child: const Text('Open shopping list →'),
            ),
        ],
      ],
    );
  }
}
