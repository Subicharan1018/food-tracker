import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../core/ingredients/ingredient_identity.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ledger.dart';
import '../nutrition/nutrient_labels.dart';
import 'shopping_cart_service.dart';

/// The server-computed weekly ceiling and the purchases that close its gaps.
///
/// Every number shown here comes from the backend payload (IFCT / USDA,
/// with a `computed_at` stamp).  Nothing is computed or estimated on-device.
class ShoppingListCard extends ConsumerStatefulWidget {
  const ShoppingListCard({super.key});

  @override
  ConsumerState<ShoppingListCard> createState() => _ShoppingListCardState();
}

class _ShoppingListCardState extends ConsumerState<ShoppingListCard> {
  bool _recomputing = false;

  Future<void> _recompute() async {
    setState(() => _recomputing = true);
    try {
      // The backend reads the synced pantry, so push local changes first.
      await ref.read(syncSchedulerProvider).syncNow();
      final userId = await ref.read(firestoreUserIdProvider.future);
      await ref.read(aiApiClientProvider).generateShoppingList(userId: userId);
      ref.invalidate(weeklyShoppingListProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't reach the server. Your cart still works offline.")),
        );
      }
    } finally {
      if (mounted) setState(() => _recomputing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(weeklyShoppingListProvider);
    final cart = ref.watch(cartItemsProvider).value ?? const [];
    final inCart = {for (final c in cart) c.canonicalName};
    final service = ref.read(shoppingCartServiceProvider);

    final recomputeButton = TextButton(
      onPressed: _recomputing ? null : _recompute,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Text(_recomputing ? 'Computing…' : 'Recompute'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: "This week's gaps", trailing: recomputeButton),
        listAsync.when(
          loading: () => const _Note('Loading the latest computation…'),
          error: (_, _) => const _Note("The server isn't reachable, so this week's gaps can't be shown."),
          data: (data) {
            if (data == null) {
              return const _Note(
                'Nothing computed yet. The list runs every Saturday at 8:00, '
                'or tap Recompute to run it against your current pantry.',
              );
            }
            return _GapsBody(data: data, inCart: inCart, service: service);
          },
        ),
      ],
    );
  }
}

class _GapsBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final Set<String> inCart;
  final ShoppingCartService service;

  const _GapsBody({required this.data, required this.inCart, required this.service});

  List<Map<String, dynamic>> _maps(dynamic value) =>
      value is List ? value.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : const [];

  List<String> _strings(dynamic value) => value is List ? value.map((e) => e.toString()).toList() : const [];

  @override
  Widget build(BuildContext context) {
    final gaps = _maps(data['structural_gaps_detail']);
    final buyList = _maps(data['shopping_list']);
    final coverage = data['coverage'] is Map ? Map<String, dynamic>.from(data['coverage']) : const <String, dynamic>{};
    final structural = _strings(data['structural_gaps']);
    final unmeasured = _strings(data['unmeasured_nutrients']);
    final missingData = _strings(data['missing_data']);
    final sources = _strings(data['sources']);
    final summary = data['summary']?.toString();
    final stamp = formatStamp((data['computed_at'] ?? data['generatedAt'])?.toString());

    final notInCart = buyList.where((i) => !inCart.contains(canonicalizeIngredient('${i['canonical_name'] ?? i['name']}'))).toList();
    final gapsWithoutRecipe = structural.where((n) => !gaps.any((g) => g['nutrient'] == n)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Computed $stamp from your synced pantry. Amounts are ceilings: '
            'up to this much, if every item is cooked optimally.',
            style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.textMuted),
          ),
        ),
        if (summary != null && summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(summary, style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textPrimary)),
          ),
        if (gaps.isEmpty && structural.isEmpty)
          const _Note('No structural gaps: your pantry can reach at least half the weekly target for every nutrient it has data for.'),
        for (final gap in gaps)
          _GapBlock(
            gap: gap,
            coverage: coverage[gap['nutrient']] is Map ? Map<String, dynamic>.from(coverage[gap['nutrient']]) : null,
            inCart: inCart,
            onAdd: (ing) => service.addToCart(
              name: '${ing['name']}',
              canonicalName: '${ing['canonical_name'] ?? ing['name']}',
              quantity: (ing['quantity'] as num?)?.toDouble() ?? 1,
              unit: '${ing['unit'] ?? 'pieces'}',
              addedFrom: CartSource.nutrientGap,
              reason: 'Unlocks ${gap['unlocks_recipe']}',
            ),
          ),
        if (notInCart.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 20, 0),
            child: TextButton(
              onPressed: () async {
                for (final item in notInCart) {
                  final unlocks = _strings(item['unlocks']);
                  await service.addToCart(
                    name: '${item['name']}',
                    canonicalName: '${item['canonical_name'] ?? item['name']}',
                    quantity: (item['quantity'] as num?)?.toDouble() ?? 1,
                    unit: '${item['unit'] ?? 'pieces'}',
                    addedFrom: CartSource.shoppingList,
                    reason: unlocks.isEmpty ? null : 'Unlocks ${unlocks.join(', ')}',
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.brandPrimary),
              child: Text('Add all ${notInCart.length} to cart', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        if (gapsWithoutRecipe.isNotEmpty)
          _Note(
            'Also low: ${gapsWithoutRecipe.map((n) => nutrientLabel(n).name).join(', ')} — '
            'none of your recipes is a meaningful source yet.',
          ),
        if (unmeasured.isNotEmpty)
          _Note('No cited data in your pantry for ${unmeasured.map((n) => nutrientLabel(n).name).join(', ')}, so it isn\'t shown as a number.'),
        if (missingData.isNotEmpty) _Note('Not counted: ${missingData.join(', ')}.'),
        if (sources.isNotEmpty) _Note('Sources: ${sources.join(' · ')}'),
      ],
    );
  }
}

class _GapBlock extends StatelessWidget {
  final Map<String, dynamic> gap;
  final Map<String, dynamic>? coverage;
  final Set<String> inCart;
  final void Function(Map<String, dynamic> ingredient) onAdd;

  const _GapBlock({required this.gap, required this.coverage, required this.inCart, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final label = nutrientLabel('${gap['nutrient']}');
    final pct = (coverage?['pct'] as num?)?.toDouble();
    final missing = (gap['missing_ingredients'] is List ? gap['missing_ingredients'] as List : const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(label.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const Spacer(),
                if (pct != null)
                  Text(
                    '${formatNumber(pct)}% of weekly target',
                    style: const TextStyle(fontSize: 13, color: AppColors.attention, fontFeatures: tabularFigures),
                  ),
              ],
            ),
          ),
          if (pct != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Meter(fraction: pct / 100, color: AppColors.attention),
            ),
          ],
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Unlocks '),
              TextSpan(text: '${gap['unlocks_recipe']}', style: const TextStyle(color: AppColors.textPrimary)),
              if (gap['per_serving_amount'] is num)
                TextSpan(text: ' · ${formatNumber(gap['per_serving_amount'])} ${label.unit} per serving'),
            ]),
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFeatures: tabularFigures),
          ),
          if (missing.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Makeable from your pantry already.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ),
          for (final ing in missing)
            Row(
              children: [
                Expanded(
                  child: Text('${ing['name']}', style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                ),
                if (ing['quantity'] is num)
                  Text(
                    '${formatQty((ing['quantity'] as num).toDouble())} ${ing['unit'] ?? ''}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontFeatures: tabularFigures),
                  ),
                const SizedBox(width: 4),
                AddToCartLink(
                  inCart: inCart.contains(canonicalizeIngredient('${ing['canonical_name'] ?? ing['name']}')),
                  onAdd: () => onAdd(ing),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Text(text, style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.textMuted)),
      );
}
