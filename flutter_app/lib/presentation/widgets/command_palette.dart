import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/note.dart';
import '../../services/vault_service.dart';
import '../../theme/app_theme.dart';

/// One entry in the palette results list.
class PaletteAction {
  const PaletteAction({
    required this.icon,
    required this.title,
    this.subtitle = '',
    required this.onSelect,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onSelect;
}

/// A Ctrl+K command palette: jump to any note by typing its title, or run
/// one of a short list of app-wide actions, without leaving the keyboard.
///
/// Shown as a dialog rather than a route push, so it overlays whatever view
/// is open and closes back to exactly where the user was.
class CommandPalette extends StatefulWidget {
  const CommandPalette({
    super.key,
    required this.vault,
    required this.onOpenNote,
    required this.onNewNote,
    required this.onOpenView,
    required this.onOpenDaily,
  });

  final VaultService vault;
  final ValueChanged<String> onOpenNote;
  final VoidCallback onNewNote;
  final ValueChanged<String> onOpenView;
  final VoidCallback onOpenDaily;

  static Future<void> show(
    BuildContext context, {
    required VaultService vault,
    required ValueChanged<String> onOpenNote,
    required VoidCallback onNewNote,
    required ValueChanged<String> onOpenView,
    required VoidCallback onOpenDaily,
  }) {
    return showGeneralDialog(
      context: context,
      barrierLabel: 'Command palette',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: Motion.quick,
      pageBuilder: (context, _, __) => CommandPalette(
        vault: vault,
        onOpenNote: onOpenNote,
        onNewNote: onNewNote,
        onOpenView: onOpenView,
        onOpenDaily: onOpenDaily,
      ),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Motion.swift);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.97, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  int _selected = 0;
  late List<PaletteAction> _results;

  @override
  void initState() {
    super.initState();
    _results = _buildResults('');
    _controller.addListener(_onQueryChanged);
    // Autofocus at dialog-open time rather than via the TextField's own
    // autofocus: a dialog transition can eat the very first focus request.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() {
      _results = _buildResults(_controller.text);
      _selected = 0;
    });
  }

  List<PaletteAction> _buildResults(String query) {
    final needle = query.trim().toLowerCase();

    final actions = <PaletteAction>[
      PaletteAction(
        icon: Icons.add_rounded,
        title: 'New note',
        subtitle: 'Create a blank note',
        onSelect: widget.onNewNote,
      ),
      PaletteAction(
        icon: Icons.today_outlined,
        title: "Open today's daily note",
        subtitle: 'Creates it on first use, reopens it after that',
        onSelect: widget.onOpenDaily,
      ),
      PaletteAction(
        icon: Icons.hub_outlined,
        title: 'Open Graph',
        onSelect: () => widget.onOpenView('graph'),
      ),
      PaletteAction(
        icon: Icons.inbox_outlined,
        title: 'Open Inbox',
        subtitle: 'Unprocessed fleeting notes',
        onSelect: () => widget.onOpenView('inbox'),
      ),
      PaletteAction(
        icon: Icons.shuffle_rounded,
        title: 'Random note for review',
        onSelect: () => widget.onOpenView('random'),
      ),
      PaletteAction(
        icon: Icons.sell_outlined,
        title: 'Open Tags',
        onSelect: () => widget.onOpenView('tags'),
      ),
      PaletteAction(
        icon: Icons.tune_rounded,
        title: 'Open Settings',
        onSelect: () => widget.onOpenView('settings'),
      ),
      PaletteAction(
        icon: Icons.menu_book_outlined,
        title: 'Open Help',
        subtitle: 'Guide, shortcuts, and how your data is stored',
        onSelect: () => widget.onOpenView('help'),
      ),
      PaletteAction(
        icon: Icons.find_replace_rounded,
        title: 'Find & replace across vault',
        subtitle: 'Search and replace text in every note at once',
        onSelect: () => widget.onOpenView('find-replace'),
      ),
      PaletteAction(
        icon: Icons.dashboard_customize_outlined,
        title: 'New from template',
        subtitle: 'Start a note from a saved template',
        onSelect: () => widget.onOpenView('template'),
      ),
    ];

    final noteResults = <PaletteAction>[
      for (final note in widget.vault.notes)
        if (needle.isEmpty || note.title.toLowerCase().contains(needle))
          PaletteAction(
            icon: _iconFor(note),
            title: note.title,
            subtitle: note.excerpt,
            onSelect: () => widget.onOpenNote(note.id),
          ),
    ];

    if (needle.isEmpty) {
      return [...actions, ...noteResults.take(8)];
    }

    final matchedActions = actions
        .where((a) => a.title.toLowerCase().contains(needle))
        .toList();

    return [...matchedActions, ...noteResults];
  }

  IconData _iconFor(Note note) {
    if (note.isPinned) return Icons.push_pin_rounded;
    return switch (note.type) {
      NoteType.permanent => Icons.check_circle_outline_rounded,
      NoteType.literature => Icons.menu_book_outlined,
      NoteType.fleeting => Icons.description_outlined,
    };
  }

  void _moveSelection(int delta) {
    if (_results.isEmpty) return;
    setState(() {
      _selected = (_selected + delta).clamp(0, _results.length - 1);
    });
  }

  void _activate() {
    if (_results.isEmpty) return;
    final action = _results[_selected.clamp(0, _results.length - 1)];
    Navigator.of(context).pop();
    action.onSelect();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.35),
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Palette.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.hairline),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is! KeyDownEvent) return;
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _moveSelection(1);
                } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _moveSelection(-1);
                } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                  _activate();
                } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.of(context).pop();
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 18, color: Palette.textTertiary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            style: AppType.body.copyWith(
                              fontSize: 15,
                              color: Palette.textPrimary,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Jump to a note or run a command...',
                              hintStyle: AppType.body.copyWith(
                                fontSize: 15,
                                color: Palette.textTertiary,
                              ),
                            ),
                          ),
                        ),
                        _KeyHint(label: 'Esc'),
                      ],
                    ),
                  ),
                  Container(height: 1, color: Palette.hairline),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: _results.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              'No matches.',
                              style: AppType.body.copyWith(color: Palette.textTertiary),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(6),
                            itemCount: _results.length,
                            itemBuilder: (context, i) {
                              final action = _results[i];
                              return _PaletteRow(
                                action: action,
                                selected: i == _selected,
                                onTap: () {
                                  Navigator.of(context).pop();
                                  action.onSelect();
                                },
                                onHover: () => setState(() => _selected = i),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({
    required this.action,
    required this.selected,
    required this.onTap,
    required this.onHover,
  });

  final PaletteAction action;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHover(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: Motion.quick,
          curve: Motion.swift,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          transform: Matrix4.translationValues(selected ? 2 : 0, 0, 0),
          decoration: BoxDecoration(
            color: selected ? Palette.amber.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: selected ? Palette.amber.withValues(alpha: 0.25) : Colors.transparent),
          ),
          child: Row(
            children: [
              AnimatedScale(
                duration: Motion.quick,
                curve: Motion.spring,
                scale: selected ? 1.12 : 1.0,
                child: Icon(
                  action.icon,
                  size: 16,
                  color: selected ? Palette.amber : Palette.textTertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Palette.textPrimary : Palette.textPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                    if (action.subtitle.isNotEmpty)
                      Text(
                        action.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body.copyWith(fontSize: 11, color: Palette.textTertiary),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedOpacity(
                duration: Motion.quick,
                opacity: selected ? 1.0 : 0.0,
                child: _KeyHint(label: 'Enter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyHint extends StatelessWidget {
  const _KeyHint({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Palette.hairline),
      ),
      child: Text(
        label,
        style: AppType.timecode.copyWith(fontSize: 10),
      ),
    );
  }
}
