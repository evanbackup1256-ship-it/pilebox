import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_config.dart';
import '../services/appearance_service.dart';
import '../services/update_service.dart';
import '../services/vault_service.dart';
import '../theme/app_theme.dart';
import 'credits_panel.dart';
import 'find_replace_panel.dart';
import 'graph_panel.dart';
import 'help_panel.dart';
import 'notes_view.dart';
import 'review_panel.dart';
import 'settings_panel.dart';
import 'tags_panel.dart';
import 'widgets/command_palette.dart';
import 'widgets/springable.dart';
import 'widgets/window_chrome.dart';

enum _View { notes, graph, tags, review, help, settings, about }

/// Application shell: a fixed left rail plus a swapping content pane.
///
/// By the time this is shown, [SplashScreen] has already loaded the vault,
/// created the first-run welcome note if needed, and kicked off the update
/// check - this widget owns no startup sequence of its own.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.vault,
    required this.updater,
    required this.preferences,
    required this.onQuit,
  });

  final VaultService vault;
  final UpdateService updater;
  final AppPreferences preferences;
  final Future<void> Function() onQuit;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _View _view = _View.notes;
  String? _openNoteId;
  String? _tagFilter;
  int _reviewTab = 0;
  bool _focusMode = false;
  final _notesKey = GlobalKey<NotesViewState>();
  final _shortcuts = FocusNode();
  late final AppPreferences _preferences = widget.preferences;

  @override
  void initState() {
    super.initState();
    widget.vault.addListener(_onChange);
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

  Future<void> _openDailyNote() async {
    final note = await widget.vault.dailyNote();
    _openNote(note.id);
  }

  void _openPaletteView(String key) {
    if (key == 'find-replace') {
      FindReplacePanel.show(context, vault: widget.vault);
      return;
    }
    if (key == 'template') {
      setState(() {
        _view = _View.notes;
        _openNoteId = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notesKey.currentState?.openTemplatePicker();
      });
      return;
    }
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
        case 'help':
          _view = _View.help;
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
      onOpenDaily: _openDailyNote,
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
      case LogicalKeyboardKey.period:
        setState(() => _focusMode = !_focusMode);
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
                trailing: _focusMode
                    ? _FocusHint(onTap: () => setState(() => _focusMode = false))
                    : _SearchHint(onTap: _showPalette),
              ),
              Expanded(
                child: Row(
                  children: [
                    ClipRect(
                      child: AnimatedAlign(
                        duration: Motion.base,
                        curve: Motion.glide,
                        alignment: Alignment.centerLeft,
                        widthFactor: _focusMode ? 0.0 : 1.0,
                        child: _Rail(
                          view: _view,
                          inboxCount: _preferences.showInboxBadge ? inboxCount : 0,
                          onSelect: (v) => setState(() => _view = v),
                        ),
                      ),
                    ),
                    Expanded(
                      child: AnimatedPadding(
                        duration: Motion.base,
                        curve: Motion.glide,
                        padding: _focusMode
                            ? const EdgeInsets.symmetric(horizontal: 96, vertical: 26)
                            : EdgeInsets.fromLTRB(Layout.gutter, Layout.gap, Layout.gutter, Layout.gap),
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
      switchInCurve: Motion.glide,
      switchOutCurve: Motion.swift,
      // A subtle scale-up-from-98% alongside the fade gives the swap a sense
      // of depth - the incoming view feels like it settles into place from
      // just behind the glass, rather than only fading over the old one.
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim),
          child: ScaleTransition(
            scale: Tween(begin: 0.985, end: 1.0).animate(anim),
            child: child,
          ),
        ),
      ),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topLeft,
        children: [...previousChildren, if (currentChild != null) currentChild],
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
        _View.help => const HelpPanel(key: ValueKey('help')),
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

/// Shown in the titlebar instead of the search hint while Focus Mode is on,
/// so there is always a visible, one-click way back rather than relying on
/// the user to remember the shortcut that got them in.
class _FocusHint extends StatefulWidget {
  const _FocusHint({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_FocusHint> createState() => _FocusHintState();
}

class _FocusHintState extends State<_FocusHint> {
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
            border: Border.all(color: Palette.amber.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.center_focus_strong_rounded, size: 13, color: Palette.amber),
              const SizedBox(width: 7),
              Text('Focus mode · Ctrl+.', style: AppType.timecode.copyWith(fontSize: 10.5, color: Palette.amber)),
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
          _RailButton(icon: Icons.menu_book_outlined, tooltip: 'Help', selected: view == _View.help, onTap: () => onSelect(_View.help)),
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
                // The icon and its badge are sized and positioned together in
                // one fixed 24x24 box, anchored to the icon's own corner
                // rather than to the whole 58px-wide rail. Positioning the
                // badge against the rail's edge put it only ~8px from the
                // icon at this width, close enough to visually collide with
                // it instead of reading as a separate badge.
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: Springable(
                          value: _hover ? 1.12 : (active ? 1.05 : 1.0),
                          spring: Motion.snappy,
                          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                          child: AnimatedContainer(
                            duration: Motion.base,
                            curve: Motion.swift,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: active
                                  ? [BoxShadow(color: Palette.amber.withValues(alpha: 0.35), blurRadius: 14, spreadRadius: 1)]
                                  : null,
                            ),
                            child: Icon(
                              widget.icon,
                              size: 19,
                              color: active ? Palette.amber : (_hover ? Palette.textSecondary : Palette.textTertiary),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -6,
                        // A spring-scaled entrance for the badge itself: it
                        // should feel like it pops into existence, not just
                        // appear, since "your inbox now has an item" is a
                        // state change worth a beat of its own rather than a
                        // silent size-zero-to-full.
                        child: Springable(
                          value: widget.badgeCount > 0 ? 1.0 : 0.0,
                          spring: Motion.snappy,
                          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
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
                      ),
                    ],
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
