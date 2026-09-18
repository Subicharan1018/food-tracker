import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../core/theme/app_theme.dart';

class NlpInputWidget extends ConsumerStatefulWidget {
  final Function(List<Map<String, dynamic>> parsedItems) onParsed;
  final Function(String fallbackQuery) onFallbackSearch;
  final String? initialText;
  final String? userId;

  const NlpInputWidget({
    super.key,
    required this.onParsed,
    required this.onFallbackSearch,
    this.initialText,
    this.userId,
  });

  @override
  ConsumerState<NlpInputWidget> createState() => _NlpInputWidgetState();
}

class _NlpInputWidgetState extends ConsumerState<NlpInputWidget> {
  late final TextEditingController _ctrl;
  bool _isParsing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleParse() async {
    final query = _ctrl.text.trim();
    if (query.isEmpty) return;

    setState(() => _isParsing = true);

    try {
      final userId = widget.userId ?? 'default_user';
      if (widget.userId == null) {
        debugPrint('[NlpInputWidget] Warning: No userId provided to widget, falling back to default_user');
      }
      final client = ref.read(aiApiClientProvider);

      final res = await client.parseFood(userId: userId, input: query);
      final rawItems = res['items'];

      if (rawItems is List && rawItems.isNotEmpty) {
        final items = rawItems
            .map((e) => e is Map<String, dynamic> ? e : (e as dynamic).toJson() as Map<String, dynamic>)
            .toList();
        widget.onParsed(items);
      } else {
        // Fallback to standard search on empty response
        widget.onFallbackSearch(query);
      }
    } catch (_) {
      // Auto-fallback to standard search on network / API failure
      widget.onFallbackSearch(query);
    } finally {
      if (mounted) {
        setState(() => _isParsing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.positive.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.positive, size: 18),
              const Text(
                'Natural Language Food Parser',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.positive,
                ),
              ),
              if (_isParsing)
                const Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.attention),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Parsing...',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.attention),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. 2 rotis and egg bhurji for breakfast',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _isParsing ? null : _handleParse(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.positive,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isParsing ? null : _handleParse,
                child: const Text('Parse', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
