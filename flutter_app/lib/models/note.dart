import 'package:flutter/foundation.dart';

/// Matches `[[Note Title]]` or `[[Note Title|display text]]` wikilinks.
final RegExp wikilinkPattern = RegExp(r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]');

/// Matches `#tag` (letters, digits, hyphen, underscore, slash for nesting).
final RegExp tagPattern = RegExp(r'(?<![\w#])#([A-Za-z0-9_\-/]+)');

/// Zettelkasten note types.
///
/// This is the traditional method's own distinction, not something Pilebox
/// invented: fleeting notes are disposable capture, literature notes record
/// a source, and permanent notes are the atomic, fully-formed ideas that
/// actually go in the slip-box proper.
enum NoteType {
  fleeting,
  literature,
  permanent;

  String get label => switch (this) {
        NoteType.fleeting => 'Fleeting',
        NoteType.literature => 'Literature',
        NoteType.permanent => 'Permanent',
      };

  /// The tag that marks a note as this type, written into the body.
  String get tag => switch (this) {
        NoteType.fleeting => 'fleeting',
        NoteType.literature => 'literature',
        NoteType.permanent => 'permanent',
      };
}

/// One markdown file in the vault.
///
/// The file on disk is the only source of truth - this is a read model
/// derived from it (title/tags/links extracted from the body), not a
/// separate database that could drift out of sync. Note type and pin state
/// are likewise stored as ordinary tags in the body (#fleeting, #pinned),
/// not in a side file - so a note edited in any other text editor keeps its
/// state, and nothing is lost if the vault folder is copied elsewhere.
@immutable
class Note {
  const Note({
    required this.path,
    required this.title,
    required this.body,
    required this.tags,
    required this.links,
    required this.modifiedAt,
  });

  final String path;
  final String title;
  final String body;
  final Set<String> tags;

  /// Titles of notes this one links to, verbatim as written (case-preserved,
  /// resolution against actual note titles happens elsewhere).
  final Set<String> links;
  final DateTime modifiedAt;

  String get id => title.toLowerCase();

  bool get isPinned => tags.contains('pinned');

  /// Defaults to fleeting: an un-typed note is exactly what the method calls
  /// a fleeting note - quick capture that has not been processed yet.
  NoteType get type {
    if (tags.contains(NoteType.permanent.tag)) return NoteType.permanent;
    if (tags.contains(NoteType.literature.tag)) return NoteType.literature;
    return NoteType.fleeting;
  }

  /// Fleeting notes with no outgoing links and no tags beyond their type
  /// marker are exactly the "inbox": captured but not yet connected to
  /// anything. This is a derived view, not a stored flag, so a note leaves
  /// the inbox automatically the moment it gets a link or a real tag.
  bool get isInboxItem {
    if (type != NoteType.fleeting) return false;
    if (links.isNotEmpty) return false;
    return tags.difference({'pinned', NoteType.fleeting.tag}).isEmpty;
  }

  /// Everything after the title line, for previews.
  String get excerpt {
    final withoutHeading = body.replaceFirst(RegExp(r'^\s*#.*\n?'), '');
    final plain = withoutHeading
        // `replaceAll(pattern, '$1')` does NOT do backreference substitution
        // in Dart - it would insert the two literal characters "$1". Only
        // replaceAllMapped resolves capture groups, so a [[Link]] rendered
        // here without it as literal "$1" instead of the link text.
        .replaceAllMapped(wikilinkPattern, (m) => m.group(1)!)
        .replaceAll(RegExp(r'[#*`_]'), '')
        .trim();
    return plain.length > 160 ? '${plain.substring(0, 160)}...' : plain;
  }

  /// Derives a [Note] from raw file content.
  ///
  /// Title comes from the first `# Heading` line, falling back to the
  /// filename, so a note is never titleless even before it has content.
  factory Note.parse(String path, String body, DateTime modifiedAt) {
    // `\s` matches newlines too, so `#\s+(.+)` on a heading with no text
    // (just "#" and trailing spaces) would consume the line break and treat
    // the next line as the title. `[ \t]+` restricts the gap after "#" to
    // same-line whitespace, so an empty heading correctly falls through to
    // the filename fallback below instead of stealing the following line.
    final headingMatch =
        RegExp(r'^[ \t]*#[ \t]+(\S.*)$', multiLine: true).firstMatch(body);
    final filename = path.split(RegExp(r'[\\/]')).last.replaceAll('.md', '');
    final title = headingMatch?.group(1)?.trim() ?? filename;

    final tags = tagPattern.allMatches(body).map((m) => m.group(1)!.toLowerCase()).toSet();
    final links = wikilinkPattern.allMatches(body).map((m) => m.group(1)!.trim()).toSet();

    return Note(
      path: path,
      title: title.isEmpty ? filename : title,
      body: body,
      tags: tags,
      links: links,
      modifiedAt: modifiedAt,
    );
  }

  /// Returns [body] with [tag] added or removed as a trailing `#tag`.
  ///
  /// Used for the pin toggle and the note-type switcher: both just add or
  /// remove a tag from the text, same as if the user had typed it.
  static String toggleTag(String body, String tag, bool present) {
    final has = RegExp('(?<![\\w#])#$tag(?![\\w-])').hasMatch(body);
    if (present == has) return body;

    if (present) {
      final trimmed = body.trimRight();
      if (trimmed.isEmpty) return '#$tag';

      // A brand-new note is just its heading line ("# Title") with nothing
      // below. Appending "#pinned" inline there would land it ON the
      // heading line, and Note.parse's title regex captures the whole rest
      // of that line - the tag would silently become part of the title.
      // Detected by checking whether the trimmed body is a single line.
      final isHeadingOnly = !trimmed.contains('\n');
      return isHeadingOnly ? '$trimmed\n\n#$tag' : '$trimmed #$tag';
    }
    return body
        .replaceAll(RegExp('[ \\t]*(?<![\\w#])#$tag(?![\\w-])'), '')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .trimRight();
  }

  /// Replaces whichever note-type tag is present (if any) with [type]'s tag.
  static String withType(String body, NoteType type) {
    var next = body;
    for (final t in NoteType.values) {
      if (t != type) next = toggleTag(next, t.tag, false);
    }
    return toggleTag(next, type.tag, true);
  }
}
