import 'package:flutter/material.dart';
import '../language.dart';

/// 备选列表条：展示最近几次 roll 的结果，点击回选
class CandidatesBar<T> extends StatelessWidget {
  const CandidatesBar({
    super.key,
    required this.items,
    required this.selected,
    required this.emojiOf,
    required this.nameOf,
    required this.onSelect,
  });

  final List<T> items;
  final T? selected;
  final String Function(T) emojiOf;
  final String Function(T) nameOf;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(t('备选', 'Candidates'),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text(t('点选回看 · 最近 ${items.length} 次',
                'Tap to re-pick · last ${items.length}'),
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final item = items[i];
              final isSelected = identical(item, selected);
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onSelect(item),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primary.withAlpha(35)
                        : Colors.black.withAlpha(8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? primary.withAlpha(90)
                          : Colors.black.withAlpha(15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emojiOf(item),
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                      Text(nameOf(item),
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
