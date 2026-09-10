import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_config.dart';
import '../services/appearance_service.dart';
import '../services/update_service.dart';
import '../services/vault_service.dart';
import '../theme/app_theme.dart';
import 'credits_panel.dart';
import 'graph_panel.dart';
import 'notes_view.dart';
import 'review_panel.dart';
import 'settings_panel.dart';
import 'tags_panel.dart';
import 'widgets/command_palette.dart';
import 'widgets/window_chrome.dart';

enum _View { notes, graph, tags, review, settings, about }

/// Application shell: a fixed left rail plus a swapping content pane.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.vault,
    required this.updater,
    required this.onQuit,
  });

  final VaultService vault;
  final UpdateService updater;
  final Future<void> Function() onQuit;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _View _view = _View.notes;
  String? _openNoteId;
  String? _tagFilter;
  int _reviewTab = 0;
  final _notesKey = GlobalKey<NotesViewState>();
  final _shortcuts = FocusNode();
  AppPreferences _preferences = const AppPreferences();

  @override
  void initState() {
    super.initState();
    widget.vault.addListener(_onChange);
    _boot();
  }

  Future<void> _boot() async {
    _preferences = await AppearanceStore.loadPreferences();
    await widget.vault.load();
    if (widget.vault.isEmpty) {
      await widget.vault.create(
        'Welcome to Pilebox',
        initialBody: '# Welcome to Pilebox\n\n'
            'This is your first note. A few things worth knowing:\n\n'
            '- Every note is a plain `.md` file in your vault folder.\n'
            '- Link notes with [[double brackets]] - typing [[Another Note]] and '
            'opening it creates it if it does not exist yet.\n'
            '- Tag anything with #tags, like #project or #idea.\n'
            '- The Graph view shows every note and how they connect.\n'
            '- Notes start as Fleeting captures. Mark one Permanent once it '
            'is a fully-formed idea, from its editor toolbar.\n'
            '- Press Ctrl+K any time to jump straight to a note or command.\n\n'
            'Try creating [[My Second Note]] to see a link in action.',
      );
    }
    if (mounted) setState(() {});
    unawaited(widget.updater.check(silent: true));
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _openNote(String id) {
    setState(() {
      _view = _View.notes;
      _openNoteId = id;
      _tagFilter = null;
    });
    _notesKey.currentState?.openNote(id);
  }

  void _openTag(String tag) {
    setState(() {
      _view = _View.notes;
      _tagFilter = tag;
      _openNoteId = null;
    });
  }

  Future<void> _newNoteFromPalette() async {
    var name = 'Untitled';
    var n = 1;
    while (widget.vault.byTitle(name) != null) {
      n++;
      name = 'Untitled $n';
    }
    final note = await widget.vault.create(name);
    _openNote(note.id);
  }

  void _openPaletteView(String key) {
    setState(() {
      switch (key) {
        case 'graph':
          _view = _View.graph;
        case 'tags':
          _view = _View.tags;
        case 'settings':
          _view = _View.settings;
        case 'inbox':
          _view = _View.review;
          _reviewTab = 0;
        case 'random':
          _view = _View.review;
          _reviewTab = 3;
      }
    });
  }

  void _showPalette() {
    CommandPalette.show(
      context,
      vault: widget.vault,
      onOpenNote: _openNote,
      onNewNote: _newNoteFromPalette,
      onOpenView: _openPaletteView,
    );
  }

  KeyEventResult _handleShortcut(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    if (!isCtrl) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyK:
        _showPalette();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyN:
        _newNoteFromPalette();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyP:
        if (_openNoteId != null) widget.vault.togglePin(_openNoteId!);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  void dispose() {
    widget.vault.removeListener(_onChange);
    _shortcuts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inboxCount = widget.vault.inbox.length;

    return Focus(
      focusNode: _shortcuts,
      autofocus: true,
      onKeyEvent: _handleShortcut,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Palette.skin.glowOrigin,
              radius: 1.5,
              colors: [
                Color.alphaBlend(Palette.amber.withValues(alpha: 0.05), Palette.surfaceRaised),
                Palette.void_,
              ],
            ),
          ),
          child: Column(
            children: [
              WindowChrome(
                title: AppConfig.displayName.toUpperCase(),
                trailing: _SearchHint(onTap: _showPalette),
              ),
              Expanded(
                child: Row(
                  children: [
                    _Rail(
                      view: _view,
                      inboxCount: _preferences.showInboxBadge ? inboxCount : 0,
                      onSelect: (v) => setState(() => _view = v),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(Layout.gutter, Layout.gap, Layout.gutter, Layout.gap),
                        child: _buildView(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildView() {
    return AnimatedSwitcher(
      duration: Motion.base,
      switchInCurve: Motion.swift,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: switch (_view) {
        _View.notes => NotesView(
            key: _notesKey,
            vault: widget.vault,
            initialNoteId: _openNoteId,
            tagFilter: _tagFilter,
          ),
        _View.graph => GraphPanel(key: const ValueKey('graph'), vault: widget.vault, onOpenNote: _openNote),
        _View.tags => TagsPanel(key: const ValueKey('tags'), vault: widget.vault, onSelectTag: _openTag),
        _View.review => ReviewPanel(
            key: ValueKey('review-$_reviewTab'),
            vault: widget.vault,
            onOpenNote: _openNote,
            initialTab: _reviewTab,
          ),
        _View.settings => SettingsPanel(
            key: const ValueKey('settings'),
            vault: widget.vault,
            preferences: _preferences,
          ),
        _View.about => CreditsPanel(key: const ValueKey('about'), updater: widget.updater, onQuit: widget.onQuit),
      },
    );
  }
}

class _SearchHint extends StatefulWidget {
  const _SearchHint({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_SearchHint> createState() => _SearchHintState();
}

class _SearchHintState extends State<_SearchHint> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Motion.quick,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hover ? Palette.surfaceRaised : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Palette.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, size: 13, color: Palette.textTertiary),
              const SizedBox(width: 7),
              Text('Ctrl+K', style: AppType.timecode.copyWith(fontSize: 10.5)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon navigation rail.
class _Rail extends StatelessWidget {
  const _Rail({required this.view, required this.inboxCount, required this.onSelect});

  final _View view;
  final int inboxCount;
  final ValueChanged<_View> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      decoration: BoxDecoration(color: Palette.chrome, border: Border(right: BorderSide(color: Palette.hairline))),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _RailButton(icon: Icons.description_outlined, tooltip: 'Notes', selected: view == _View.notes, onTap: () => onSelect(_View.notes)),
          _RailButton(icon: Icons.hub_outlined, tooltip: 'Graph', selected: view == _View.graph, onTap: () => onSelect(_View.graph)),
          _RailButton(icon: Icons.sell_outlined, tooltip: 'Tags', selected: view == _View.tags, onTap: () => onSelect(_View.tags)),
          _RailButton(
            icon: Icons.inbox_outlined,
            tooltip: 'Review',
            selected: view == _View.review,
            badgeCount: inboxCount,
            onTap: () => onSelect(_View.review),
          ),
          const Spacer(),
          _RailButton(icon: Icons.tune_rounded, tooltip: 'Settings', selected: view == _View.settings, onTap: () => onSelect(_View.settings)),
          _RailButton(icon: Icons.info_outline_rounded, tooltip: 'About', selected: view == _View.about, onTap: () => onSelect(_View.about)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _RailButton extends StatefulWidget {
  const _RailButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 450),
      decoration: BoxDecoration(
        color: Palette.surfaceRaised,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Palette.hairline),
      ),
      textStyle: AppType.body.copyWith(fontSize: 11.5),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedPositioned(
                  duration: Motion.base,
                  curve: Motion.spring,
                  left: 0,
                  top: active ? 12 : 23,
                  bottom: active ? 12 : 23,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: active ? Palette.amber : Colors.transparent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                AnimatedScale(
                  duration: Motion.quick,
                  scale: _hover ? 1.09 : 1,
                  child: Icon(
                    widget.icon,
                    size: 19,
                    color: active ? Palette.amber : (_hover ? Palette.textSecondary : Palette.textTertiary),
                  ),
                ),
                if (widget.badgeCount > 0)
                  Positioned(
                    top: 8,
                    right: 11,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 15),
                      height: 15,
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Palette.amber,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Palette.chrome, width: 1.5),
                      ),
                      child: Text(
                        widget.badgeCount > 9 ? '9+' : '${widget.badgeCount}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Segoe UI',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          color: Palette.skin.isLight ? Colors.white : Palette.void_,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
