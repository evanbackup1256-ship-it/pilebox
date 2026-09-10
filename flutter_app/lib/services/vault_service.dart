import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/note.dart';

/// Owns the vault folder: a plain directory of `.md` files on disk.
///
/// Everything here is derived from those files - there is no database to
/// get out of sync. Notes are cached in memory and only re-read from disk
/// on load/refresh, so editing is fast; saves are debounced per-note.
class VaultService extends ChangeNotifier {
  String _path = '';
  String get path => _path;

  final Map<String, Note> _notes = {}; // keyed by Note.id (lowercase title)
  final Map<String, Timer> _saveDebounce = {};

  List<Note> get notes => _notes.values.toList()
    ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

  bool get isEmpty => _notes.isEmpty;

  Future<void> load() async {
    final configDir = await getApplicationSupportDirectory();
    final configFile = File('${configDir.path}\\vault.json');

    String? savedPath;
    try {
      if (await configFile.exists()) {
        final json = jsonDecode(await configFile.readAsString());
        if (json is Map<String, dynamic>) savedPath = json['path'] as String?;
      }
    } catch (_) {
      // Fall through to the default below.
    }

    if (savedPath == null || savedPath.isEmpty) {
      final docs = Platform.environment['USERPROFILE'] ?? configDir.path;
      // The app was previously called Slipbox; anyone who already has notes
      // in that default folder keeps using it rather than silently starting
      // a second, empty vault next to their real one. A brand-new install
      // gets the current name.
      final legacy = Directory('$docs\\Documents\\Slipbox');
      savedPath = legacy.existsSync() && legacy.listSync().isNotEmpty
          ? legacy.path
          : '$docs\\Documents\\Pilebox';
    }

    await setPath(savedPath, persist: false);
    await _persistPath();
  }

  /// Points the vault at a different folder, creating it if needed, and
  /// reloads every note from it.
  Future<void> setPath(String newPath, {bool persist = true}) async {
    _path = newPath;
    final dir = Directory(_path);
    await dir.create(recursive: true);
    await _rescan();
    if (persist) await _persistPath();
    notifyListeners();
  }

  Future<void> _persistPath() async {
    try {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      await File('${dir.path}\\vault.json').writeAsString(jsonEncode({'path': _path}));
    } catch (_) {
      // Non-fatal: the vault still works for this session.
    }
  }

  Future<void> _rescan() async {
    _notes.clear();
    try {
      final dir = Directory(_path);
      await for (final entity in dir.list()) {
        if (entity is! File || !entity.path.toLowerCase().endsWith('.md')) continue;
        try {
          final body = await entity.readAsString();
          final stat = await entity.stat();
          final note = Note.parse(entity.path, body, stat.modified);
          _notes[note.id] = note;
        } catch (_) {
          // Skip an unreadable file rather than losing the whole vault.
        }
      }
    } catch (_) {
      // A missing/inaccessible folder just means an empty vault.
    }
  }

  Note? byTitle(String title) => _notes[title.toLowerCase()];

  /// Creates a note, using [title] for both the heading and the filename.
  /// Returns the created note, or the existing one if the title is taken.
  Future<Note> create(String title, {String initialBody = ''}) async {
    final existing = byTitle(title);
    if (existing != null) return existing;

    final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').trim();
    final filePath = '$_path\\$safeName.md';
    final body = initialBody.isEmpty ? '# $title\n\n' : initialBody;

    final file = File(filePath);
    await file.writeAsString(body);
    final note = Note.parse(filePath, body, DateTime.now());
    _notes[note.id] = note;
    notifyListeners();
    return note;
  }

  /// Opens today's daily note, creating it on first use.
  Future<Note> dailyNote() async {
    final now = DateTime.now();
    final title = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return create(title);
  }

  void update(String noteId, String newBody) {
    final note = _notes[noteId];
    if (note == null) return;

    final updated = Note.parse(note.path, newBody, DateTime.now());
    // A title change (editing the `# Heading`) changes the note's id; drop
    // the old key so the note doesn't appear twice.
    if (updated.id != noteId) _notes.remove(noteId);
    _notes[updated.id] = updated;
    notifyListeners();

    _saveDebounce[updated.id]?.cancel();
    _saveDebounce[updated.id] = Timer(const Duration(milliseconds: 400), () {
      _write(updated);
    });
  }

  Future<void> _write(Note note) async {
    try {
      await File(note.path).writeAsString(note.body);
    } catch (_) {
      // Best-effort: the in-memory copy is still correct for this session.
    }
  }

  Future<void> delete(String noteId) async {
    final note = _notes[noteId];
    if (note == null) return;
    _saveDebounce.remove(noteId)?.cancel();
    try {
      await File(note.path).delete();
    } catch (_) {
      // Already gone.
    }
    _notes.remove(noteId);
    notifyListeners();
  }

  /// Notes that contain a `[[title]]` link pointing at [title].
  List<Note> backlinksFor(String title) {
    final needle = title.toLowerCase();
    return notes.where((n) => n.links.any((l) => l.toLowerCase() == needle)).toList();
  }

  /// All tags in the vault, with how many notes carry each.
  Map<String, int> get tagCounts {
    final counts = <String, int>{};
    for (final note in _notes.values) {
      for (final tag in note.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<Note> notesTagged(String tag) =>
      notes.where((n) => n.tags.contains(tag)).toList();

  /// Simple substring search over title and body, title matches ranked first.
  List<Note> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return notes;

    final titleMatches = <Note>[];
    final bodyMatches = <Note>[];
    for (final note in notes) {
      if (note.title.toLowerCase().contains(needle)) {
        titleMatches.add(note);
      } else if (note.body.toLowerCase().contains(needle)) {
        bodyMatches.add(note);
      }
    }
    return [...titleMatches, ...bodyMatches];
  }

  // --- Zettelkasten-specific views ---------------------------------------

  /// Pinned notes, most recently modified first.
  List<Note> get pinned => notes.where((n) => n.isPinned).toList();

  /// Fleeting, unconnected captures waiting to be processed - the inbox.
  List<Note> get inbox => notes.where((n) => n.isInboxItem).toList();

  List<Note> notesOfType(NoteType type) =>
      notes.where((n) => n.type == type).toList();

  /// Notes with neither an outgoing link nor a single incoming one.
  ///
  /// In the Zettelkasten method an orphan is a warning sign: a permanent
  /// note is supposed to earn its place by connecting to the web of
  /// existing ideas, and one with zero connections either belongs somewhere
  /// it hasn't been linked yet, or was never actually developed past a
  /// fleeting thought.
  List<Note> get orphans {
    final linkedTo = <String>{};
    for (final note in _notes.values) {
      for (final link in note.links) {
        final target = byTitle(link);
        if (target != null) linkedTo.add(target.id);
      }
    }
    return notes
        .where((n) => n.links.isEmpty && !linkedTo.contains(n.id))
        .toList();
  }

  final _reviewRand = Random();

  /// One random note, for the method's own "read something at random and
  /// see what new connection it suggests" review habit. Excludes fleeting
  /// inbox items, which have not been processed into a real idea yet.
  Note? randomForReview() {
    final candidates = notes.where((n) => !n.isInboxItem).toList();
    if (candidates.isEmpty) return null;
    return candidates[_reviewRand.nextInt(candidates.length)];
  }

  /// Toggles the note's pin state by editing its body, same as if the user
  /// had typed or deleted "#pinned" themselves.
  void togglePin(String noteId) {
    final note = _notes[noteId];
    if (note == null) return;
    update(noteId, Note.toggleTag(note.body, 'pinned', !note.isPinned));
  }

  void setType(String noteId, NoteType type) {
    final note = _notes[noteId];
    if (note == null) return;
    update(noteId, Note.withType(note.body, type));
  }

  /// Forces any pending debounced write to happen immediately, then returns.
  /// Used before an export so it reflects the very latest edits.
  Future<void> flushPendingWrites() async {
    final pending = _saveDebounce.keys.toList();
    for (final id in pending) {
      _saveDebounce.remove(id)?.cancel();
      final note = _notes[id];
      if (note != null) await _write(note);
    }
  }

  @override
  void dispose() {
    for (final timer in _saveDebounce.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
