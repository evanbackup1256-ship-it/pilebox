@TestOn('windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilebox/services/vault_service.dart';

void main() {
  late Directory tempDir;
  late VaultService vault;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('slipbox_test_');
    vault = VaultService();
    // Bypass load()'s settings-file lookup (which needs a real app-support
    // directory) and point straight at the temp folder for these tests.
    await vault.setPath(tempDir.path, persist: false);
  });

  tearDown(() async {
    vault.dispose();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // Best-effort cleanup.
    }
  });

  group('create', () {
    test('writes a new .md file with a heading', () async {
      final note = await vault.create('First Note');
      expect(note.title, 'First Note');
      expect(await File(note.path).exists(), isTrue);
      expect(await File(note.path).readAsString(), contains('# First Note'));
    });

    test('returns the existing note instead of duplicating on same title', () async {
      final first = await vault.create('Same Title');
      final second = await vault.create('Same Title');
      expect(second.path, first.path);
      expect(vault.notes.length, 1);
    });

    test('title matching for duplicates is case-insensitive', () async {
      await vault.create('MixedCase');
      final second = await vault.create('mixedcase');
      expect(vault.notes.length, 1);
      expect(second.title, 'MixedCase');
    });

    test('sanitises filesystem-illegal characters out of the filename', () async {
      final note = await vault.create('Weird: Name / Test?');
      expect(await File(note.path).exists(), isTrue);
      // The illegal characters must not survive into the path.
      for (final bad in [':', '?', '*', '"', '<', '>', '|']) {
        expect(note.path.split('\\').last.contains(bad), isFalse);
      }
    });

    test('accepts a custom initial body instead of the default heading', () async {
      final note = await vault.create('Custom', initialBody: 'hand-written body');
      expect(await File(note.path).readAsString(), 'hand-written body');
    });
  });

  group('update and rename-on-retitle', () {
    test('changing the body updates the in-memory note immediately', () async {
      final note = await vault.create('Editable');
      vault.update(note.id, '# Editable\n\nNew content.');
      expect(vault.byTitle('Editable')!.body, contains('New content.'));
    });

    test('changing the heading moves the note to its new id', () async {
      final note = await vault.create('Old Title');
      vault.update(note.id, '# New Title\n\nBody.');

      expect(vault.byTitle('Old Title'), isNull);
      expect(vault.byTitle('New Title'), isNotNull);
      expect(vault.notes.length, 1);
    });

    test('the debounced write eventually reaches disk', () async {
      final note = await vault.create('Debounced');
      vault.update(note.id, '# Debounced\n\nSaved content.');

      // The debounce is 400ms; wait past it.
      await Future.delayed(const Duration(milliseconds: 600));

      expect(await File(note.path).readAsString(), contains('Saved content.'));
    });
  });

  group('delete', () {
    test('removes both the file and the in-memory entry', () async {
      final note = await vault.create('ToDelete');
      await vault.delete(note.id);

      expect(vault.byTitle('ToDelete'), isNull);
      expect(await File(note.path).exists(), isFalse);
    });

    test('deleting a nonexistent id is a harmless no-op', () async {
      await vault.delete('does-not-exist');
      expect(vault.notes, isEmpty);
    });
  });

  group('backlinksFor', () {
    test('finds notes that link to a given title', () async {
      await vault.create('Target');
      await vault.create('Linker One', initialBody: '# Linker One\n\n[[Target]]');
      await vault.create('Linker Two', initialBody: '# Linker Two\n\nSee [[Target|here]].');
      await vault.create('Unrelated', initialBody: '# Unrelated\n\nNo links.');

      final backlinks = vault.backlinksFor('Target').map((n) => n.title).toSet();
      expect(backlinks, {'Linker One', 'Linker Two'});
    });

    test('matching is case-insensitive on the target title', () async {
      await vault.create('CaseTarget');
      await vault.create('Linker', initialBody: '# Linker\n\n[[casetarget]]');

      expect(vault.backlinksFor('CaseTarget'), hasLength(1));
    });

    test('returns nothing for a title with no incoming links', () async {
      await vault.create('Lonely');
      expect(vault.backlinksFor('Lonely'), isEmpty);
    });
  });

  group('tagCounts and notesTagged', () {
    test('counts each tag across all notes', () async {
      await vault.create('A', initialBody: '# A\n\n#shared #onlyA');
      await vault.create('B', initialBody: '# B\n\n#shared');

      expect(vault.tagCounts['shared'], 2);
      // Note.parse lowercases every tag, so #onlyA is stored as "onlya".
      expect(vault.tagCounts['onlya'], 1);
    });

    test('notesTagged returns only notes carrying that tag', () async {
      await vault.create('Tagged', initialBody: '# Tagged\n\n#keep');
      await vault.create('Untagged', initialBody: '# Untagged\n\nno tags');

      final tagged = vault.notesTagged('keep');
      expect(tagged.map((n) => n.title), ['Tagged']);
    });
  });

  group('search', () {
    test('ranks title matches before body matches', () async {
      await vault.create('Body Match', initialBody: '# Body Match\n\nnothing special');
      await vault.create('Other', initialBody: '# Other\n\nThis mentions apple.');
      await vault.create('Apple Pie', initialBody: '# Apple Pie\n\nrecipe');

      final results = vault.search('apple');
      expect(results.first.title, 'Apple Pie');
    });

    test('an empty query returns every note', () async {
      await vault.create('One');
      await vault.create('Two');
      expect(vault.search('').length, 2);
    });

    test('is case-insensitive', () async {
      await vault.create('UPPERCASE TITLE');
      expect(vault.search('uppercase'), hasLength(1));
    });
  });

  group('rescan from disk', () {
    test('setPath reloads notes already present in the folder', () async {
      final other = await Directory.systemTemp.createTemp('slipbox_test2_');
      try {
        await File('${other.path}\\Preexisting.md')
            .writeAsString('# Preexisting\n\nFound on disk.');

        await vault.setPath(other.path, persist: false);

        expect(vault.byTitle('Preexisting'), isNotNull);
      } finally {
        await other.delete(recursive: true);
      }
    });

    test('skips non-.md files in the folder', () async {
      final other = await Directory.systemTemp.createTemp('slipbox_test3_');
      try {
        await File('${other.path}\\notes.txt').writeAsString('not markdown');
        await File('${other.path}\\Real.md').writeAsString('# Real\n\nok');

        await vault.setPath(other.path, persist: false);

        expect(vault.notes.length, 1);
        expect(vault.notes.first.title, 'Real');
      } finally {
        await other.delete(recursive: true);
      }
    });
  });
}
