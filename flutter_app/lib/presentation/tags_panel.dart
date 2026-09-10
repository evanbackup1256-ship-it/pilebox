import 'package:flutter/material.dart';

import '../services/vault_service.dart';
import '../theme/app_theme.dart';
import 'widgets/primitives.dart';

/// Every #tag in the vault, sized by how often it's used.
class TagsPanel extends StatelessWidget {
  const TagsPanel({super.key, required this.vault, required this.onSelectTag});

  final VaultService vault;
  final ValueChanged<String> onSelectTag;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vault,
      builder: (context, _) {
        final counts = vault.tagCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return QuietScroll(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('TAGS'),
              const SizedBox(height: 4),
              Text(
                'Every #tag used across the vault.',
                style: AppType.body.copyWith(fontSize: 11.5, color: Palette.textTertiary),
              ),
              SizedBox(height: Layout.gap),
              if (counts.isEmpty)
                Text('No tags yet.', style: AppType.body.copyWith(color: Palette.textTertiary))
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: staggered([
                    for (final entry in counts)
                      _TagCard(tag: entry.key, count: entry.value, onTap: () => onSelectTag(entry.key)),
                  ]),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TagCard extends StatefulWidget {
  const _TagCard({required this.tag, required this.count, required this.onTap});
  final String tag;
  final int count;
  final VoidCallback onTap;

  @override
  State<_TagCard> createState() => _TagCardState();
}

class _TagCardState extends State<_TagCard> {
  @override
  Widget build(BuildContext context) {
    return HoverLift(
      onTap: widget.onTap,
      builder: (context, t, liftPx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Color.lerp(Palette.surface, Palette.amber.withValues(alpha: 0.08), t),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Color.lerp(Palette.hairline, Palette.amber.withValues(alpha: 0.4), t)!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('#${widget.tag}', style: AppType.body.copyWith(color: Palette.live, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            TweenAnimationBuilder<double>(
              key: ValueKey(widget.count),
              tween: Tween(begin: 0, end: 1),
              duration: Motion.base,
              curve: Motion.spring,
              builder: (context, pop, child) => Transform.scale(scale: 0.7 + 0.3 * pop, child: child),
              child: Text('${widget.count}', style: AppType.body.copyWith(color: Palette.textTertiary, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}
