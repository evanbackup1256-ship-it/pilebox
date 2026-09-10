import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/vault_service.dart';
import '../theme/app_theme.dart';
import 'widgets/animated_text.dart';
import 'widgets/markdown_view.dart';
import 'widgets/primitives.dart';
import 'widgets/springable.dart';

/// The main workspace: a searchable note list on the left, the open note
/// (edit/preview) with its backlinks on the right.
class NotesView extends StatefulWidget {
  const NotesView({super.key, required this.vault, this.initialNoteId, this.tagFilter});

  final VaultService vault;
  final String? initialNoteId;
  final String? tagFilter;

  @override
  State<NotesView> createState() => NotesViewState();
}

class NotesViewState extends State<NotesView> {
  String? _openId;
  bool _preview = true;
  final _search = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _openId = widget.initialNoteId;
    _syncBodyController();
  }

  @override
  void didUpdateWidget(covariant NotesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialNoteId != null && widget.initialNoteId != oldWidget.initialNoteId) {
      openNote(widget.initialNoteId!);
    }
  }

  void _syncBodyController() {
    final note = _openId == null ? null : widget.vault.byTitle(_openId!);
    _bodyController.text = note?.body ?? '';
  }

  void openNote(String noteId) {
    setState(() {
      _openId = noteId;
      _preview = true;
      _syncBodyController();
    });
  }

  /// Opens the "new from template" picker, reachable from outside this view
  /// via the command palette as well as from the empty-state button here.
  void openTemplatePicker() {
    _TemplatePicker.show(context, vault: widget.vault, onCreated: openNote);
  }

  Future<void> _openOrCreate(String title) async {
    final existing = widget.vault.byTitle(title);
    final note = existing ?? await widget.vault.create(title);
    openNote(note.id);
  }

  Future<void> _newNote() async {
    var name = 'Untitled';
    var n = 1;
    while (widget.vault.byTitle(name) != null) {
      n++;
      name = 'Untitled $n';
    }
    final note = await widget.vault.create(name);
    setState(() {
      _openId = note.id;
      _preview = false;
      _syncBodyController();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.vault,
      builder: (context, _) {
        final query = _search.text.trim();
        var list = query.isEmpty ? widget.vault.notes : widget.vault.search(query);
        if (widget.tagFilter != null) {
          list = list.where((n) => n.tags.contains(widget.tagFilter)).toList();
        }
        // Pinned notes lead the list regardless of sort/search order,
        // keeping the notes you deliberately kept close actually close.
        if (query.isEmpty && widget.tagFilter == null) {
          final pinned = list.where((n) => n.isPinned).toList();
          final rest = list.where((n) => !n.isPinned).toList();
          list = [...pinned, ...rest];
        }
        final open = _openId == null ? null : widget.vault.byTitle(_openId!);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 260,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          decoration: BoxDecoration(
                            color: Palette.surfaceRaised,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: Palette.hairline),
                          ),
                          child: TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            style: AppType.body.copyWith(fontSize: 12.5, color: Palette.textPrimary),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 9),
                              hintText: 'Search notes',
                              hintStyle: AppType.body.copyWith(fontSize: 12.5, color: Palette.textTertiary),
                              // The default prefixIcon reserves a 48x48 box
                              // regardless of the icon's own size, which threw
                              // the whole field visibly off-centre against a
                              // 16px icon. Constrained to match the field.
                              prefixIcon: Icon(Icons.search_rounded, size: 15, color: Palette.textTertiary),
                              prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ActionButton(
                        label: '',
                        icon: Icons.add_rounded,
                        compact: true,
                        primary: true,
                        onPressed: _newNote,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.tagFilter != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: MiniChip(label: '#${widget.tagFilter}', selected: true, onTap: () {}),
                    ),
                  Expanded(
                    child: list.isEmpty
                        ? Center(
                            child: Text(
                              query.isEmpty ? 'No notes yet.\nCreate one to begin.' : 'No matches.',
                              textAlign: TextAlign.center,
                              style: AppType.body.copyWith(color: Palette.textTertiary, fontSize: 12, height: 1.5),
                            ),
                          )
                        : QuietScroll(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final note in list)
                                  _NoteRow(
                                    note: note,
                                    selected: note.id == _openId,
                                    onTap: () => openNote(note.id),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: open == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description_outlined, size: 26, color: Palette.textTertiary),
                          const SizedBox(height: 10),
                          Text(
                            'Select or create a note.',
                            style: AppType.body.copyWith(color: Palette.textTertiary),
                          ),
                          const SizedBox(height: 14),
                          ActionButton(
                            label: 'New from template',
                            icon: Icons.dashboard_customize_outlined,
                            compact: true,
                            onPressed: () => _TemplatePicker.show(
                              context,
                              vault: widget.vault,
                              onCreated: openNote,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _Editor(
                      key: ValueKey(open.id),
                      note: open,
                      vault: widget.vault,
                      preview: _preview,
                      bodyController: _bodyController,
                      onTogglePreview: () => setState(() => _preview = !_preview),
                      onChanged: (text) => widget.vault.update(open.id, text),
                      onOpenLink: _openOrCreate,
                      onOpenTag: (tag) => setState(() {}),
                      onDelete: () async {
                        await widget.vault.delete(open.id);
                        setState(() => _openId = null);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _NoteRow extends StatefulWidget {
  const _NoteRow({required this.note, required this.selected, required this.onTap});

  final Note note;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NoteRow> createState() => _NoteRowState();
}

class _NoteRowState extends State<_NoteRow> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final selected = widget.selected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        behavior: HitTestBehavior.opaque,
        child: Springable(
          value: _down ? 0.985 : 1.0,
          spring: Motion.snappy,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: AnimatedContainer(
            duration: Motion.quick,
            curve: Motion.swift,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? Palette.amber.withValues(alpha: 0.1)
                  : (_hover ? Palette.surfaceRaised : Colors.transparent),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: selected
                    ? Palette.amber.withValues(alpha: 0.4)
                    : (_hover ? Palette.amber.withValues(alpha: 0.15) : Palette.hairline),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A thin accent bar that springs in on selection, instead of
                // relying on the border/background tint alone to signal
                // "this is the open note" - a distinct enough cue that it
                // reads at a glance while scanning down the list.
                Springable(
                  value: selected ? 1.0 : 0.0,
                  spring: Motion.snappy,
                  builder: (context, t, child) => SizedBox(
                    width: 3,
                    height: 28 * t,
                    child: child,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Palette.amber, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                SizedBox(width: selected ? 8 : 0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (note.isPinned) ...[
                            Icon(Icons.push_pin_rounded, size: 11, color: Palette.amber),
                            const SizedBox(width: 5),
                          ],
                          Expanded(
                            child: Text(
                              note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.body.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: selected ? Palette.amber : Palette.textPrimary,
                              ),
                            ),
                          ),
                          _TypeDot(type: note.type),
                        ],
                      ),
                      if (note.excerpt.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          note.excerpt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body.copyWith(fontSize: 10.5, color: Palette.textTertiary),
                        ),
                      ],
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

/// A small coloured dot marking a note's Zettelkasten type at a glance,
/// without adding a text label to every row in the list.
class _TypeDot extends StatelessWidget {
  const _TypeDot({required this.type});
  final NoteType type;

  @override
  Widget build(BuildContext context) {
    // A fresh, unprocessed fleeting note gets no dot at all - only a
    // deliberately-set type is worth calling out here.
    if (type == NoteType.fleeting) return const SizedBox.shrink();

    final color = switch (type) {
      NoteType.permanent => Palette.live,
      NoteType.literature => Palette.amber,
      NoteType.fleeting => Palette.textTertiary,
    };

    return Tooltip(
      message: type.label,
      waitDuration: const Duration(milliseconds: 500),
      child: Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({
    super.key,
    required this.note,
    required this.vault,
    required this.preview,
    required this.bodyController,
    required this.onTogglePreview,
    required this.onChanged,
    required this.onOpenLink,
    required this.onOpenTag,
    required this.onDelete,
  });

  final Note note;
  final VaultService vault;
  final bool preview;
  final TextEditingController bodyController;
  final VoidCallback onTogglePreview;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onOpenLink;
  final ValueChanged<String> onOpenTag;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final backlinks = vault.backlinksFor(note.title);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: RevealText(
                note.title,
                style: AppType.title.copyWith(fontSize: 20),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Version history',
              waitDuration: const Duration(milliseconds: 500),
              child: _IconToggle(
                icon: Icons.history_rounded,
                active: false,
                onTap: () => _HistoryDialog.show(context, vault: vault, note: note),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: note.isPinned ? 'Unpin' : 'Pin',
              waitDuration: const Duration(milliseconds: 500),
              child: _IconToggle(
                icon: note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                active: note.isPinned,
                onTap: () => vault.togglePin(note.id),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Save as template',
              waitDuration: const Duration(milliseconds: 500),
              child: _IconToggle(
                icon: Icons.dashboard_customize_outlined,
                active: false,
                onTap: () => _SaveTemplateDialog.show(context, vault: vault, body: note.body),
              ),
            ),
            const SizedBox(width: 8),
            MiniChip(label: preview ? 'Preview' : 'Edit', selected: true, onTap: onTogglePreview),
            const SizedBox(width: 8),
            ActionButton(label: 'Delete', compact: true, onPressed: onDelete),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'Edited ${_relative(note.modifiedAt)}',
              style: AppType.body.copyWith(fontSize: 11, color: Palette.textTertiary),
            ),
            const SizedBox(width: 10),
            _TypeSwitcher(
              current: note.type,
              onChanged: (t) => vault.setType(note.id, t),
            ),
            const Spacer(),
            _WordStats(body: note.body),
          ],
        ),
        SizedBox(height: Layout.gap),
        Expanded(
          child: AnimatedSwitcher(
            duration: Motion.base,
            switchInCurve: Motion.swift,
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: preview
                ? QuietScroll(
                    key: const ValueKey('preview'),
                    child: MarkdownView(
                      body: note.body,
                      onOpenLink: onOpenLink,
                      onOpenTag: onOpenTag,
                    ),
                  )
                : Container(
                    key: const ValueKey('edit'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Palette.surface,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Palette.hairline),
                    ),
                    child: TextField(
                      controller: bodyController,
                      onChanged: onChanged,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: AppType.mono.copyWith(color: Palette.textPrimary, height: 1.7, fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '# Heading\n\nWrite in markdown. Use [[links]] and #tags.',
                      ),
                    ),
                  ),
          ),
        ),
        if (backlinks.isNotEmpty) ...[
          SizedBox(height: Layout.gap),
          SectionLabel('LINKED FROM (${backlinks.length})'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: staggered([
              for (final b in backlinks)
                MiniChip(label: b.title, selected: false, onTap: () => onOpenLink(b.title)),
            ], step: const Duration(milliseconds: 22)),
          ),
        ],
      ],
    );
  }

  String _relative(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Word count and estimated reading time for the open note, animating on
/// change (typing, switching notes) rather than jumping - a small piece of
/// feedback that the note itself, not just its timestamp, just changed.
class _WordStats extends StatelessWidget {
  const _WordStats({required this.body});
  final String body;

  @override
  Widget build(BuildContext context) {
    final words = body.trim().isEmpty ? 0 : body.trim().split(RegExp(r'\s+')).length;
    final minutes = (words / 200).ceil().clamp(0, 999);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CountUpNumber(value: words, style: AppType.timecode.copyWith(color: Palette.textTertiary)),
        Text(' words', style: AppType.timecode.copyWith(color: Palette.textTertiary)),
        if (words > 0) ...[
          const SizedBox(width: 8),
          Text('·', style: AppType.timecode.copyWith(color: Palette.textTertiary)),
          const SizedBox(width: 8),
          Text(
            minutes <= 1 ? '< 1 min read' : '$minutes min read',
            style: AppType.timecode.copyWith(color: Palette.textTertiary),
          ),
        ],
      ],
    );
  }
}

class _IconToggle extends StatefulWidget {
  const _IconToggle({required this.icon, required this.active, required this.onTap});
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_IconToggle> createState() => _IconToggleState();
}

class _IconToggleState extends State<_IconToggle> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: Springable(
          value: _down ? 0.88 : 1.0,
          spring: Motion.snappy,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: AnimatedContainer(
            duration: Motion.quick,
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.active
                  ? Palette.amber.withValues(alpha: 0.14)
                  : (_hover ? Palette.surfaceRaised : Colors.transparent),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: widget.active ? Palette.amber.withValues(alpha: 0.5) : Palette.hairline,
              ),
            ),
            child: Springable(
              value: widget.active ? 1.0 : 0.0,
              spring: Motion.snappy,
              builder: (context, t, child) => Transform.scale(scale: 1.0 + 0.2 * t, child: child),
              child: Icon(
                widget.icon,
                size: 15,
                color: widget.active ? Palette.amber : Palette.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeSwitcher extends StatelessWidget {
  const _TypeSwitcher({required this.current, required this.onChanged});
  final NoteType current;
  final ValueChanged<NoteType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      children: [
        for (final type in NoteType.values)
          MiniChip(label: type.label, selected: type == current, onTap: () => onChanged(type)),
      ],
    );
  }
}

/// Pick a saved template and a title to start a new note from it - the
/// counterpart to "Save as template" in the editor toolbar. Distinct from
/// the daily note and from a blank "New note": this is for the recurring
/// shapes a vault accumulates (meeting logs, book reviews, project briefs)
/// where retyping the same headings every time is pure friction.
class _TemplatePicker extends StatefulWidget {
  const _TemplatePicker({required this.vault, required this.onCreated});
  final VaultService vault;
  final ValueChanged<String> onCreated;

  static Future<void> show(BuildContext context, {required VaultService vault, required ValueChanged<String> onCreated}) {
    return showGeneralDialog(
      context: context,
      barrierLabel: 'New from template',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: Motion.quick,
      pageBuilder: (context, _, __) => _TemplatePicker(vault: vault, onCreated: onCreated),
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
  State<_TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<_TemplatePicker> {
  final _title = TextEditingController();
  NoteTemplate? _selected;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final template = _selected;
    final title = _title.text.trim();
    if (template == null || title.isEmpty) return;
    final note = await widget.vault.createFromTemplate(title, template);
    if (mounted) Navigator.of(context).pop();
    widget.onCreated(note.id);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 440,
          constraints: const BoxConstraints(maxHeight: 480),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.hairline),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40, offset: const Offset(0, 16))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.dashboard_customize_outlined, size: 16, color: Palette.amber),
                  const SizedBox(width: 10),
                  Expanded(child: Text('New from template', style: AppType.heading.copyWith(fontSize: 15))),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close_rounded, size: 18, color: Palette.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(
                child: FutureBuilder<List<NoteTemplate>>(
                  future: widget.vault.loadTemplates(),
                  builder: (context, snapshot) {
                    final templates = snapshot.data ?? const [];
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                      );
                    }
                    if (templates.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'No templates yet. Open any note and use "Save as template" '
                          'in its toolbar to create one.',
                          style: AppType.body.copyWith(color: Palette.textTertiary),
                        ),
                      );
                    }
                    return QuietScroll(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: staggered([
                          for (final t in templates)
                            MiniChip(
                              label: t.name,
                              selected: t == _selected,
                              onTap: () => setState(() => _selected = t),
                            ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              LabeledField(label: 'Title for the new note', controller: _title, hint: 'e.g. Weekly sync 9/10'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ActionButton(
                    label: 'Create',
                    primary: true,
                    compact: true,
                    enabled: _selected != null,
                    onPressed: _selected == null ? null : _create,
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

/// A tiny prompt for naming a new template from the current note's body.
/// Deliberately just a name field - the body is captured as-is, so the
/// template is exactly what you see, no separate authoring step.
class _SaveTemplateDialog extends StatefulWidget {
  const _SaveTemplateDialog({required this.vault, required this.body});
  final VaultService vault;
  final String body;

  static Future<void> show(BuildContext context, {required VaultService vault, required String body}) {
    return showGeneralDialog(
      context: context,
      barrierLabel: 'Save as template',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: Motion.quick,
      pageBuilder: (context, _, __) => _SaveTemplateDialog(vault: vault, body: body),
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
  State<_SaveTemplateDialog> createState() => _SaveTemplateDialogState();
}

class _SaveTemplateDialogState extends State<_SaveTemplateDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.hairline),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40, offset: const Offset(0, 16))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.dashboard_customize_outlined, size: 16, color: Palette.amber),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Save as template', style: AppType.heading.copyWith(fontSize: 15))),
                ],
              ),
              const SizedBox(height: 14),
              LabeledField(label: 'Template name', controller: _name, hint: 'e.g. Meeting notes'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ActionButton(label: 'Cancel', compact: true, onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(width: 8),
                  ActionButton(
                    label: 'Save',
                    primary: true,
                    compact: true,
                    onPressed: () async {
                      final name = _name.text.trim();
                      if (name.isEmpty) return;
                      await widget.vault.saveTemplate(name, widget.body);
                      if (context.mounted) Navigator.of(context).pop();
                    },
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

/// A lightweight local safety net: browse and restore past snapshots of the
/// current note's body. Not a full version-control diff view - just enough
/// to recover from "I deleted a paragraph I wanted back" without needing an
/// external tool, since notes have no undo history once the app is closed.
class _HistoryDialog extends StatelessWidget {
  const _HistoryDialog({required this.vault, required this.note});
  final VaultService vault;
  final Note note;

  static Future<void> show(BuildContext context, {required VaultService vault, required Note note}) {
    return showGeneralDialog(
      context: context,
      barrierLabel: 'Version history',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: Motion.quick,
      pageBuilder: (context, _, __) => _HistoryDialog(vault: vault, note: note),
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
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 460,
          constraints: const BoxConstraints(maxHeight: 520),
          padding: const EdgeInsets.all(18),
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
                  Icon(Icons.history_rounded, size: 17, color: Palette.amber),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Version history', style: AppType.heading)),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close_rounded, size: 18, color: Palette.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Snapshots are saved automatically as you edit. Restoring one keeps '
                'your current version in this list too.',
                style: AppType.body.copyWith(fontSize: 11.5, color: Palette.textTertiary),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: FutureBuilder<List<HistoryEntry>>(
                  future: vault.historyFor(note.id),
                  builder: (context, snapshot) {
                    final entries = snapshot.data?.reversed.toList() ?? const [];
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                      );
                    }
                    if (entries.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Text(
                          'No earlier versions yet. Keep editing - checkpoints appear here '
                          'as your changes accumulate.',
                          style: AppType.body.copyWith(color: Palette.textTertiary),
                        ),
                      );
                    }
                    return QuietScroll(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: staggered(
                          [
                            for (final entry in entries)
                              _HistoryRow(
                                entry: entry,
                                onRestore: () {
                                  vault.restoreVersion(note.id, entry);
                                  Navigator.of(context).pop();
                                },
                              ),
                          ],
                          step: const Duration(milliseconds: 22),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatefulWidget {
  const _HistoryRow({required this.entry, required this.onRestore});
  final HistoryEntry entry;
  final VoidCallback onRestore;

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final excerpt = widget.entry.body.trim().replaceAll(RegExp(r'\s+'), ' ');
    final preview = excerpt.length > 90 ? '${excerpt.substring(0, 90)}...' : excerpt;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: Motion.quick,
        curve: Motion.swift,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: _hover ? Palette.surfaceRaised : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Palette.hairline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatWhen(widget.entry.savedAt), style: AppType.body.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    preview.isEmpty ? '(empty)' : preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(fontSize: 11, color: Palette.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ActionButton(label: 'Restore', compact: true, onPressed: widget.onRestore),
          ],
        ),
      ),
    );
  }

  String _formatWhen(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${t.month}/${t.day}/${t.year}';
  }
}
