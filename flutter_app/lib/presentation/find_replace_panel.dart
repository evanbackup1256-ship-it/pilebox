import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/vault_service.dart';
import '../theme/app_theme.dart';
import 'widgets/primitives.dart';

/// One note's matches for the current search term.
class _Match {
  const _Match(this.note, this.count);
  final Note note;
  final int count;
}

/// Vault-wide find & replace: search every note's body at once instead of
/// opening each one, and optionally replace every match in a single pass.
///
/// This is a distinct workflow from the per-note editor - renaming a term
/// used across dozens of notes (a person, a project, a tag typo) is exactly
/// the kind of bulk edit a Zettelkasten accumulates a need for as it grows,
/// and doing it note-by-note does not scale.
class FindReplacePanel extends StatefulWidget {
  const FindReplacePanel({super.key, required this.vault});
  final VaultService vault;

  static Future<void> show(BuildContext context, {required VaultService vault}) {
    return showGeneralDialog(
      context: context,
      barrierLabel: 'Find and replace',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: Motion.quick,
      pageBuilder: (context, _, __) => FindReplacePanel(vault: vault),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Motion.swift);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }

  @override
  State<FindReplacePanel> createState() => _FindReplacePanelState();
}

class _FindReplacePanelState extends State<FindReplacePanel> {
  final _find = TextEditingController();
  final _replace = TextEditingController();
  bool _caseSensitive = false;
  String? _justReplacedSummary;

  @override
  void initState() {
    super.initState();
    _find.addListener(() => setState(() => _justReplacedSummary = null));
  }

  @override
  void dispose() {
    _find.dispose();
    _replace.dispose();
    super.dispose();
  }

  List<_Match> get _matches {
    final needle = _find.text;
    if (needle.isEmpty) return const [];
    final pattern = RegExp(RegExp.escape(needle), caseSensitive: _caseSensitive);
    final matches = <_Match>[];
    for (final note in widget.vault.notes) {
      final count = pattern.allMatches(note.body).length;
      if (count > 0) matches.add(_Match(note, count));
    }
    return matches;
  }

  void _replaceAll() {
    final needle = _find.text;
    if (needle.isEmpty) return;
    final pattern = RegExp(RegExp.escape(needle), caseSensitive: _caseSensitive);
    final matches = _matches;
    var totalReplacements = 0;

    for (final match in matches) {
      final newBody = match.note.body.replaceAll(pattern, _replace.text);
      widget.vault.update(match.note.id, newBody);
      totalReplacements += match.count;
    }

    setState(() {
      _justReplacedSummary = totalReplacements == 0
          ? null
          : 'Replaced $totalReplacements ${totalReplacements == 1 ? 'match' : 'matches'} '
              'across ${matches.length} ${matches.length == 1 ? 'note' : 'notes'}.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    final totalCount = matches.fold<int>(0, (sum, m) => sum + m.count);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 520,
          constraints: const BoxConstraints(maxHeight: 560),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.hairline),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40, offset: const Offset(0, 16))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.find_replace_rounded, size: 17, color: Palette.amber),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Find & replace across vault', style: AppType.heading)),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close_rounded, size: 18, color: Palette.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LabeledField(label: 'Find', controller: _find, hint: 'Text to search for', mono: true),
              const SizedBox(height: 12),
              LabeledField(label: 'Replace with', controller: _replace, hint: 'Leave blank to delete matches', mono: true),
              const SizedBox(height: 10),
              Row(
                children: [
                  MiniChip(
                    label: 'Case sensitive',
                    selected: _caseSensitive,
                    onTap: () => setState(() => _caseSensitive = !_caseSensitive),
                  ),
                  const Spacer(),
                  Text(
                    _find.text.isEmpty
                        ? ''
                        : '$totalCount ${totalCount == 1 ? 'match' : 'matches'} in ${matches.length} ${matches.length == 1 ? 'note' : 'notes'}',
                    style: AppType.body.copyWith(fontSize: 11.5, color: Palette.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(
                child: AnimatedSwitcher(
                  duration: Motion.quick,
                  child: matches.isEmpty
                      ? Padding(
                          key: const ValueKey('empty'),
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            _find.text.isEmpty
                                ? 'Type something to search every note in your vault at once.'
                                : 'No matches.',
                            style: AppType.body.copyWith(color: Palette.textTertiary),
                          ),
                        )
                      : QuietScroll(
                          key: const ValueKey('results'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: staggered(
                              [
                                for (final m in matches)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            m.note.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppType.body.copyWith(fontSize: 12.5, color: Palette.textPrimary),
                                          ),
                                        ),
                                        TweenAnimationBuilder<double>(
                                          key: ValueKey('${m.note.id}-${m.count}'),
                                          tween: Tween(begin: 0, end: 1),
                                          duration: Motion.quick,
                                          curve: Motion.spring,
                                          builder: (context, pop, child) => Transform.scale(scale: 0.7 + 0.3 * pop, child: child),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Palette.surfaceRaised,
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text('${m.count}', style: AppType.timecode.copyWith(fontSize: 10)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                              step: const Duration(milliseconds: 18),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AnimatedSize(
                      duration: Motion.base,
                      curve: Motion.swift,
                      alignment: Alignment.centerLeft,
                      child: _justReplacedSummary == null
                          ? const SizedBox(width: double.infinity)
                          : Row(
                              key: ValueKey(_justReplacedSummary),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: Motion.base,
                                  curve: Motion.spring,
                                  builder: (context, t, child) => Transform.scale(scale: t, child: child),
                                  child: Icon(Icons.check_circle_outline_rounded, size: 14, color: Palette.live),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: FadeInUp(
                                    child: Text(_justReplacedSummary!, style: AppType.body.copyWith(fontSize: 11.5, color: Palette.live)),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ActionButton(
                    label: 'Replace all',
                    primary: true,
                    icon: Icons.find_replace_rounded,
                    enabled: matches.isNotEmpty,
                    onPressed: matches.isEmpty ? null : _replaceAll,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
