import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Renders a note's markdown source as read-only rich text.
///
/// Deliberately custom rather than a generic markdown package: the whole
/// point is [[wikilinks]] and #tags behaving as first-class, tappable
/// citizens, which a stock renderer knows nothing about.
class MarkdownView extends StatelessWidget {
  const MarkdownView({
    super.key,
    required this.body,
    required this.onOpenLink,
    required this.onOpenTag,
  });

  final String body;
  final ValueChanged<String> onOpenLink;
  final ValueChanged<String> onOpenTag;

  @override
  Widget build(BuildContext context) {
    final lines = body.split('\n');
    final blocks = <Widget>[];
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];
      final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);

      if (heading != null) {
        final level = heading.group(1)!.length;
        blocks.add(Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 18, bottom: 6),
          child: _richLine(
            heading.group(2)!,
            style: switch (level) {
              1 => AppType.title.copyWith(fontSize: 24),
              2 => AppType.heading.copyWith(fontSize: 18),
              _ => AppType.heading,
            },
          ),
        ));
      } else if (line.trimLeft().startsWith('- ') || line.trimLeft().startsWith('* ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 9),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(color: Palette.amber, shape: BoxShape.circle),
                ),
              ),
              Expanded(child: _richLine(line.trimLeft().substring(2))),
            ],
          ),
        ));
      } else if (line.trim().isEmpty) {
        blocks.add(const SizedBox(height: 10));
      } else {
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _richLine(line),
        ));
      }
      i++;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }

  Widget _richLine(String text, {TextStyle? style}) {
    final base = style ?? AppType.body.copyWith(color: Palette.textPrimary, height: 1.7);
    final spans = <InlineSpan>[];

    // One combined pass so wikilinks, tags, and emphasis never overlap.
    final pattern = RegExp(
      r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]'
      r'|(?<![\w#])#([A-Za-z0-9_\-/]+)'
      r'|\*\*([^*]+)\*\*'
      r'|`([^`]+)`',
    );

    var last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));

      if (m.group(1) != null) {
        final target = m.group(1)!.trim();
        spans.add(TextSpan(
          text: m.group(2)?.trim() ?? target,
          style: base.copyWith(
            color: Palette.amber,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: Palette.amber.withValues(alpha: 0.4),
          ),
          recognizer: TapGestureRecognizer()..onTap = () => onOpenLink(target),
        ));
      } else if (m.group(3) != null) {
        final tag = m.group(3)!;
        spans.add(TextSpan(
          text: '#$tag',
          style: base.copyWith(color: Palette.live, fontWeight: FontWeight.w600),
          recognizer: TapGestureRecognizer()..onTap = () => onOpenTag(tag.toLowerCase()),
        ));
      } else if (m.group(4) != null) {
        spans.add(TextSpan(text: m.group(4), style: base.copyWith(fontWeight: FontWeight.w700)));
      } else if (m.group(5) != null) {
        spans.add(TextSpan(
          text: m.group(5),
          style: base.copyWith(fontFamily: 'Consolas', color: Palette.amber, fontSize: (base.fontSize ?? 13) - 1),
        ));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));

    return RichText(text: TextSpan(style: base, children: spans));
  }
}
