import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'widgets/primitives.dart';
import 'widgets/springable.dart';

/// One entry in the reference guide - a question/heading and its answer.
class _Topic {
  const _Topic(this.title, this.body, {this.shortcut});
  final String title;
  final String body;
  final String? shortcut;
}

class _Section {
  const _Section(this.label, this.icon, this.topics);
  final String label;
  final IconData icon;
  final List<_Topic> topics;
}

const _sections = [
  _Section('Zettelkasten', Icons.auto_awesome_outlined, [
    _Topic(
      'What is a Zettelkasten?',
      'A slip-box method for building a web of atomic notes instead of a '
          'folder tree. Every note holds one idea, in your own words, linked to '
          'the other notes it relates to. Structure emerges from the links '
          'themselves rather than a filing hierarchy you have to plan up front.',
    ),
    _Topic(
      'The three note types',
      '• Fleeting - a quick capture, unprocessed. This is the default for new notes.\n'
          '• Literature - a note tied to something you read or watched, in your own words.\n'
          '• Permanent - a fully-formed, standalone idea, written so it makes sense '
          'without its source. Promote a fleeting note here once it has matured.\n\n'
          'Change a note\'s type any time from its editor toolbar.',
    ),
    _Topic(
      'Inbox and processing',
      'The Inbox (in Review) lists every fleeting note - your unprocessed capture '
          'queue. The goal is not zero inbox today; it is regularly revisiting it, '
          'turning captures into permanent notes or deciding they are done being useful.',
    ),
    _Topic(
      'Orphans',
      'A note with no incoming or outgoing links. Not necessarily a problem, but '
          'worth a look - is it actually connected to something and just needs a '
          'link added, or does it belong somewhere it currently is not?',
    ),
    _Topic(
      'Random review',
      'Surfaces a random existing note so you re-encounter old ideas instead of '
          'only ever seeing the newest ones. Resurfacing is how a slip-box earns '
          'its keep over time - connections you did not plan for tend to show up here.',
    ),
  ]),
  _Section('Linking & tags', Icons.hub_outlined, [
    _Topic(
      'Linking notes',
      'Type [[ inside the editor to link to another note by title. If the note '
          'does not exist yet, opening the link creates it - so you can write '
          '"related to [[Some Idea]]" before Some Idea exists, and fill it in later.',
    ),
    _Topic(
      'Tags',
      'Write #tags directly in a note\'s body - #project, #idea, whatever is '
          'useful. Tags are just text; there is no separate tag database to keep '
          'in sync. The Tags view lists every tag currently in use across the vault.',
    ),
    _Topic(
      'Backlinks',
      'Every note shows which other notes link to it, computed live from the '
          'files themselves. This is what turns a pile of notes into a real graph.',
    ),
    _Topic(
      'Graph view',
      'A visual map of every note and the links between them. Isolated clusters '
          'or lone dots are usually orphans or a topic that has not been connected '
          'to the rest of the vault yet.',
    ),
  ]),
  _Section('Shortcuts', Icons.keyboard_outlined, [
    _Topic('Command palette', 'Jump to any note, or run a command, from anywhere.', shortcut: 'Ctrl+K'),
    _Topic('New note', 'Create a new untitled note and open it immediately.', shortcut: 'Ctrl+N'),
    _Topic('Pin / unpin note', 'Toggle the pin on the currently open note.', shortcut: 'Ctrl+P'),
    _Topic(
      'Focus mode',
      'Hides the rail and widens the margins around whatever you are reading '
          'or writing, so nothing but the note is on screen. Toggle it back off '
          'the same way, or with the button that replaces the search hint while it is on.',
      shortcut: 'Ctrl+.',
    ),
    _Topic(
      'Command palette actions',
      'Ctrl+K also reaches views directly - type "graph", "tags", "settings", '
          '"inbox", "random", or "help" and press Enter, without touching the mouse.',
    ),
  ]),
  _Section('Productivity', Icons.bolt_outlined, [
    _Topic(
      'Focus mode',
      'Hides the rail and widens the margins so nothing but the current note '
          'is on screen. Toggle it with Ctrl+. or the button in the titlebar.',
    ),
    _Topic(
      'Daily note',
      'One note per calendar day, created automatically the first time you '
          'open it. Reach it from the command palette by typing "daily".',
    ),
    _Topic(
      'Version history',
      'Every note keeps its recent past states, saved automatically as you '
          'edit. Open the history icon in a note\'s toolbar to browse and '
          'restore an earlier version - restoring keeps the current version '
          'in the list too, so nothing is lost either way.',
    ),
    _Topic(
      'Templates',
      'Save any note\'s body as a reusable template from its toolbar, then '
          'start new notes from it with "New from template" wherever you '
          'create a note. Good for recurring shapes - meeting logs, reviews, briefs.',
    ),
    _Topic(
      'Find & replace across the vault',
      'Search every note\'s body at once and replace every match in a single '
          'pass, instead of opening notes one at a time. Reach it from the '
          'command palette by typing "replace".',
    ),
    _Topic(
      'Activity and streaks',
      'Settings > Vault shows a two-week activity strip and your current '
          'streak - consecutive days with at least one note touched - so you '
          'can see at a glance whether the practice is active or has gone quiet.',
    ),
  ]),
  _Section('Your data', Icons.folder_outlined, [
    _Topic(
      'Where notes live',
      'Every note is a plain .md file in your vault folder on disk. There is no '
          'database, no cloud sync, and no account - you can read, edit, or back up '
          'that folder with any other tool, at any time.',
    ),
    _Topic(
      'Export and import',
      'Settings > Vault lets you export the whole vault to a single .zip, or '
          'import one back in. Useful for backups or moving to another machine.',
    ),
    _Topic(
      'Updates',
      'Pilebox checks GitHub Releases for new versions. Downloads are only '
          'accepted from a GitHub-owned address over HTTPS and must match a '
          'published checksum before they are ever applied - see About for details.',
    ),
  ]),
];

/// Dedicated in-app reference guide: the Zettelkasten workflow, linking and
/// tags, every keyboard shortcut, and how your data is stored - a page you
/// come back to, not a one-time overlay shown only on first launch.
class HelpPanel extends StatefulWidget {
  const HelpPanel({super.key});

  @override
  State<HelpPanel> createState() => _HelpPanelState();
}

class _HelpPanelState extends State<HelpPanel> {
  int _sectionIndex = 0;
  final _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final section = _sections[_sectionIndex];

    return QuietScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.menu_book_outlined, size: 22, color: Palette.amber),
              const SizedBox(width: 12),
              Text('Help & guide', style: AppType.title.copyWith(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'How Pilebox works, and how to get the most out of it.',
            style: AppType.body.copyWith(color: Palette.textTertiary),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _sections.length; i++)
                MiniChip(
                  label: _sections[i].label,
                  selected: i == _sectionIndex,
                  onTap: () => setState(() => _sectionIndex = i),
                ),
            ],
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: Motion.base,
            switchInCurve: Motion.glide,
            switchOutCurve: Motion.swift,
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.topLeft,
              children: [...previousChildren, if (currentChild != null) currentChild],
            ),
            child: Column(
              key: ValueKey(_sectionIndex),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(section.label.toUpperCase()),
                const SizedBox(height: 12),
                for (final entry in staggered([
                  for (final topic in section.topics)
                    _TopicCard(
                      topic: topic,
                      expanded: _expanded.contains(topic.title),
                      onTap: () => setState(() {
                        if (!_expanded.add(topic.title)) _expanded.remove(topic.title);
                      }),
                    ),
                ])) ...[
                  entry,
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TopicCard extends StatefulWidget {
  const _TopicCard({required this.topic, required this.expanded, required this.onTap});
  final _Topic topic;
  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<_TopicCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: Motion.quick,
          curve: Motion.swift,
          decoration: BoxDecoration(
            color: _hover ? Palette.surfaceRaised : Palette.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: widget.expanded ? Palette.hairline : Palette.hairline.withValues(alpha: 0.6)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.topic.title,
                      style: AppType.body.copyWith(fontWeight: FontWeight.w600, color: Palette.textPrimary),
                    ),
                  ),
                  if (widget.topic.shortcut != null) ...[
                    _ShortcutChip(widget.topic.shortcut!),
                    const SizedBox(width: 10),
                  ],
                  Springable(
                    value: widget.expanded ? 1 : 0,
                    spring: Motion.snappy,
                    builder: (context, t, child) => Transform.rotate(angle: t * 3.14159, child: child),
                    child: Icon(Icons.expand_more_rounded, size: 18, color: Palette.textTertiary),
                  ),
                ],
              ),
              AnimatedSize(
                duration: Motion.base,
                curve: Motion.swift,
                alignment: Alignment.topLeft,
                child: widget.expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          widget.topic.body,
                          style: AppType.body.copyWith(color: Palette.textSecondary, height: 1.6, fontSize: 12.5),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Palette.void_,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Palette.hairline),
      ),
      child: Text(text, style: AppType.timecode.copyWith(fontSize: 10.5, color: Palette.textSecondary)),
    );
  }
}
