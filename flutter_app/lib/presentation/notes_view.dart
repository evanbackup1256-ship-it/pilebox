import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/vault_service.dart';
import '../theme/app_theme.dart';
import 'widgets/markdown_view.dart';
import 'widgets/primitives.dart';

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

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note, required this.selected, required this.onTap});

  final Note note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: Motion.quick,
          curve: Motion.swift,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Palette.amber.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: selected ? Palette.amber.withValues(alpha: 0.4) : Palette.hairline),
          ),
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
              child: Text(
                note.title,
                style: AppType.title.copyWith(fontSize: 20),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
            children: [
              for (final b in backlinks)
                MiniChip(label: b.title, selected: false, onTap: () => onOpenLink(b.title)),
            ],
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
          child: Icon(
            widget.icon,
            size: 15,
            color: widget.active ? Palette.amber : Palette.textSecondary,
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
