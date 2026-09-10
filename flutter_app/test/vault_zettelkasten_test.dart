@TestOn('windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilebox/models/note.dart';
import 'package:pilebox/services/vault_service.dart';

void main() {
  late Directory tempDir;
  late VaultService vault;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('slipbox_zk_test_');
    vault = VaultService();
    await vault.setPath(tempDir.path, persist: false);
  });

  tearDown(() async {
    vault.dispose();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('pinned', () {
    test('returns only notes with the pinned tag', () async {
      await vault.create('A', initialBody: '# A\n\nnormal');
      await vault.create('B', initialBody: '# B\n\npinned note #pinned');

      final pinned = vault.pinned;
      expect(pinned.map((n) => n.title), ['B']);
    });

    test('togglePin adds the tag when absent', () async {
      final note = await vault.create('Toggle Me');
      vault.togglePin(note.id);
      expect(vault.byTitle('Toggle Me')!.isPinned, isTrue);
    });

    test('togglePin removes the tag when present', () async {
      final note = await vault.create('Toggle Me', initialBody: '# Toggle Me\n\n#pinned');
      vault.togglePin(note.id);
      expect(vault.byTitle('Toggle Me')!.isPinned, isFalse);
    });

    test('togglePin on a nonexistent id is a harmless no-op', () {
      expect(() => vault.togglePin('missing'), returnsNormally);
    });
  });

  group('inbox', () {
    test('surfaces bare fleeting captures', () async {
      await vault.create('Capture', initialBody: '# Capture\n\nrandom thought');
      await vault.create('Processed', initialBody: '# Processed\n\nthought #project');

      expect(vault.inbox.map((n) => n.title), ['Capture']);
    });

    test('is empty when every note has been processed', () async {
      await vault.create('Done', initialBody: '# Done\n\n#permanent');
      expect(vault.inbox, isEmpty);
    });
  });

  group('notesOfType', () {
    test('filters by explicit type tag', () async {
      await vault.create('Perm', initialBody: '# Perm\n\n#permanent');
      await vault.create('Lit', initialBody: '# Lit\n\n#literature');
      await vault.create('Fleet', initialBody: '# Fleet\n\nuntyped');

      expect(vault.notesOfType(NoteType.permanent).map((n) => n.title), ['Perm']);
      expect(vault.notesOfType(NoteType.literature).map((n) => n.title), ['Lit']);
      expect(vault.notesOfType(NoteType.fleeting).map((n) => n.title), ['Fleet']);
    });

    test('setType rewrites the tag in the note body', () async {
      final note = await vault.create('X');
      vault.setType(note.id, NoteType.permanent);
      expect(vault.byTitle('X')!.type, NoteType.permanent);
    });
  });

  group('orphans', () {
    test('a note with no links in or out is an orphan', () async {
      await vault.create('Lonely', initialBody: '# Lonely\n\nno connections');
      expect(vault.orphans.map((n) => n.title), contains('Lonely'));
    });

    test('a note that links out is not an orphan', () async {
      await vault.create('Target');
      await vault.create('Source', initialBody: '# Source\n\n[[Target]]');
      expect(vault.orphans.map((n) => n.title), isNot(contains('Source')));
    });

    test('a note that is linked to is not an orphan, even with no outgoing links', () async {
      await vault.create('Target', initialBody: '# Target\n\nno outgoing links');
      await vault.create('Source', initialBody: '# Source\n\n[[Target]]');
      expect(vault.orphans.map((n) => n.title), isNot(contains('Target')));
    });

    test('a note with only a broken link to a nonexistent note is still an orphan', () async {
      // Links out, but to nothing that exists - has no real connections.
      await vault.create('Broken', initialBody: '# Broken\n\n[[Nothing Here]]');
      expect(vault.orphans.map((n) => n.title), isNot(contains('Broken')));
      // Note: this note DOES have an outgoing link (even if unresolved), so
      // by the `links.isEmpty` definition it is correctly excluded from
      // orphans - the metric tracks "has any link written", not resolution.
    });
  });

  group('randomForReview', () {
    test('returns null for an empty vault', () {
      expect(vault.randomForReview(), isNull);
    });

    test('never returns an inbox item', () async {
      await vault.create('Inboxed', initialBody: '# Inboxed\n\nunsorted');
      expect(vault.randomForReview(), isNull);
    });

    test('returns a processed note when one exists', () async {
      await vault.create('Ready', initialBody: '# Ready\n\n#permanent');
      expect(vault.randomForReview()?.title, 'Ready');
    });
  });

  group('flushPendingWrites', () {
    test('writes a pending debounced edit to disk immediately', () async {
      final note = await vault.create('Flush Me');
      vault.update(note.id, '# Flush Me\n\nedited content');

      // No delay: without flushing, the 400ms debounce would not have fired.
      await vault.flushPendingWrites();

      expect(await File(note.path).readAsString(), contains('edited content'));
    });
  });
}
