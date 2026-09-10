import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/vault_service.dart';
import '../theme/app_theme.dart';
import 'widgets/primitives.dart';

/// The Zettelkasten workflow screen: process the inbox, find orphaned
/// notes that need connecting, and surface a random note for review - the
/// method's own upkeep habits, not just a notes list.
class ReviewPanel extends StatefulWidget {
  const ReviewPanel({
    super.key,
    required this.vault,
    required this.onOpenNote,
    this.initialTab = 0,
  });

  final VaultService vault;
  final ValueChanged<String> onOpenNote;
  final int initialTab;

  @override
  State<ReviewPanel> createState() => _ReviewPanelState();
}

class _ReviewPanelState extends State<ReviewPanel> {
  late int _tab = widget.initialTab;
  Note? _reviewNote;

  @override
  void initState() {
    super.initState();
    _reviewNote = widget.vault.randomForReview();
  }

  void _shuffle() {
    setState(() => _reviewNote = widget.vault.randomForReview());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.vault,
      builder: (context, _) {
        final inbox = widget.vault.inbox;
        final orphans = widget.vault.orphans;
        final pinned = widget.vault.pinned;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SectionLabel('REVIEW')),
                const SizedBox(width: 12),
                _Segmented(
                  index: _tab,
                  labels: [
                    'Inbox (${inbox.length})',
                    'Orphans (${orphans.length})',
                    'Pinned (${pinned.length})',
                    'Random',
                  ],
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ],
            ),
            SizedBox(height: Layout.gap),
            Expanded(
              child: switch (_tab) {
                0 => _NoteGrid(
                    notes: inbox,
                    empty: (
                      Icons.inbox_outlined,
                      'Inbox zero',
                      'Every fleeting capture has been tagged or linked '
                          'somewhere. Nothing left to process.',
                    ),
                    onOpen: widget.onOpenNote,
                  ),
                1 => _NoteGrid(
                    notes: orphans,
                    empty: (
                      Icons.hub_outlined,
                      'Nothing orphaned',
                      'Every note connects to at least one other. That is '
                          'exactly what the method is for.',
                    ),
                    onOpen: widget.onOpenNote,
                  ),
                2 => _NoteGrid(
                    notes: pinned,
                    empty: (
                      Icons.push_pin_outlined,
                      'Nothing pinned',
                      'Pin a note from its editor toolbar to keep it '
                          'close at hand here.',
                    ),
                    onOpen: widget.onOpenNote,
                  ),
                _ => _RandomReview(
                    note: _reviewNote,
                    onOpen: widget.onOpenNote,
                    onShuffle: _shuffle,
                  ),
              },
            ),
          ],
        );
      },
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.index, required this.labels, required this.onChanged});

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        for (var i = 0; i < labels.length; i++)
          MiniChip(label: labels[i], selected: i == index, onTap: () => onChanged(i)),
      ],
    );
  }
}

class _NoteGrid extends StatelessWidget {
  const _NoteGrid({required this.notes, required this.empty, required this.onOpen});

  final List<Note> notes;
  final (IconData, String, String) empty;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return _EmptyState(icon: empty.$1, title: empty.$2, body: empty.$3);
    }

    return QuietScroll(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: staggered([
          for (final note in notes)
            SizedBox(
              width: 260,
              child: _ReviewCard(note: note, onTap: () => onOpen(note.id)),
            ),
        ]),
      ),
    );
  }
}

class _ReviewCard extends StatefulWidget {
  const _ReviewCard({required this.note, required this.onTap});
  final Note note;
  final VoidCallback onTap;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    return HoverLift(
      onTap: widget.onTap,
      builder: (context, t, liftPx) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Color.lerp(Palette.surface, Palette.surfaceRaised, t),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Color.lerp(Palette.hairline, Palette.amber.withValues(alpha: 0.4), t)!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25 * t),
              blurRadius: 16 * t,
              offset: Offset(0, 6 * t),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (note.isPinned) ...[
                  Icon(Icons.push_pin_rounded, size: 12, color: Palette.amber),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: Palette.textPrimary),
                  ),
                ),
              ],
            ),
            if (note.excerpt.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                note.excerpt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.body.copyWith(fontSize: 11.5, color: Palette.textTertiary, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RandomReview extends StatefulWidget {
  const _RandomReview({required this.note, required this.onOpen, required this.onShuffle});

  final Note? note;
  final ValueChanged<String> onOpen;
  final VoidCallback onShuffle;

  @override
  State<_RandomReview> createState() => _RandomReviewState();
}

class _RandomReviewState extends State<_RandomReview> {
  int _spins = 0;

  void _shuffle() {
    setState(() => _spins++);
    widget.onShuffle();
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    if (note == null) {
      return _EmptyState(
        icon: Icons.shuffle_rounded,
        title: 'Nothing to review yet',
        body: 'Process a few fleeting notes into permanent ones first - '
            'random review works on notes that have already been developed.',
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeInUp(child: Text('A NOTE TO REVISIT', style: AppType.label)),
            const SizedBox(height: 14),
            // Keyed on the note's own id, not just "a card" - swapping to a
            // different random note replays the entrance, which is exactly
            // what should draw the eye each time "Another one" is pressed.
            AnimatedSwitcher(
              duration: Motion.base,
              switchInCurve: Motion.glide,
              switchOutCurve: Motion.swift,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(anim),
                  child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(anim), child: child),
                ),
              ),
              child: Container(
                key: ValueKey(note.id),
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Palette.hairline),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(note.title, style: AppType.heading),
                    if (note.excerpt.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        note.excerpt,
                        style: AppType.body.copyWith(height: 1.6),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ActionButton(
                  label: 'Open',
                  primary: true,
                  icon: Icons.open_in_new_rounded,
                  onPressed: () => widget.onOpen(note.id),
                ),
                const SizedBox(width: 10),
                _SpinningShuffleButton(spins: _spins, onPressed: _shuffle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Another one" button, whose icon does a full spin every time it's
/// pressed - a small piece of feedback that the click was registered and a
/// new note is on its way, timed to roughly match the card swap above it.
class _SpinningShuffleButton extends StatefulWidget {
  const _SpinningShuffleButton({required this.spins, required this.onPressed});
  final int spins;
  final VoidCallback onPressed;

  @override
  State<_SpinningShuffleButton> createState() => _SpinningShuffleButtonState();
}

class _SpinningShuffleButtonState extends State<_SpinningShuffleButton> {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.spins),
      tween: Tween(begin: 0, end: 1),
      duration: Motion.base,
      curve: Motion.glide,
      builder: (context, t, child) => Transform.rotate(angle: t * 6.28319, child: child),
      child: ActionButton(label: 'Another one', icon: Icons.shuffle_rounded, onPressed: widget.onPressed),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: Palette.textTertiary),
            const SizedBox(height: 14),
            Text(title, style: AppType.heading, textAlign: TextAlign.center),
            const SizedBox(height: 7),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
