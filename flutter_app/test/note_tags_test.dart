import 'package:flutter_test/flutter_test.dart';
import 'package:pilebox/models/note.dart';

void main() {
  group('Note.toggleTag adding', () {
    test('appends a tag to a non-empty body', () {
      final result = Note.toggleTag('# Title\n\nBody text.', 'pinned', true);
      expect(result, '# Title\n\nBody text. #pinned');
    });

    test('does not duplicate a tag that is already present', () {
      final result = Note.toggleTag('# Title\n\nBody. #pinned', 'pinned', true);
      expect(result, '# Title\n\nBody. #pinned');
    });

    test('handles an empty body', () {
      final result = Note.toggleTag('', 'pinned', true);
      expect(result, '#pinned');
    });

    test('collapses trailing blank lines/whitespace before appending', () {
      // trimRight() before appending is deliberate: without it, pinning a
      // note whose body ends in blank lines would put "#pinned" several
      // empty lines below the actual content instead of right after it.
      final result = Note.toggleTag('# Title\n\nBody.   \n\n', 'pinned', true);
      expect(result, '# Title\n\nBody. #pinned');
    });

    test('never appends inline onto a heading-only body', () {
      // Regression: a fresh note's body is just "# Title\n\n". Appending
      // inline would put the tag on the SAME line as the heading, and
      // Note.parse's title regex captures the rest of that line - so the
      // tag would silently become part of the note's title.
      final result = Note.toggleTag('# Fresh Note\n\n', 'pinned', true);
      expect(result, '# Fresh Note\n\n#pinned');

      final parsed = Note.parse('x.md', result, DateTime(2026));
      expect(parsed.title, 'Fresh Note');
      expect(parsed.isPinned, isTrue);
    });

    test('never appends inline onto a bare heading with no trailing newlines', () {
      final result = Note.toggleTag('# Fresh Note', 'pinned', true);
      final parsed = Note.parse('x.md', result, DateTime(2026));
      expect(parsed.title, 'Fresh Note');
      expect(parsed.isPinned, isTrue);
    });
  });

  group('Note.toggleTag removing', () {
    test('removes a trailing tag cleanly', () {
      final result = Note.toggleTag('# Title\n\nBody. #pinned', 'pinned', false);
      expect(result, '# Title\n\nBody.');
    });

    test('removes a tag from the middle of a line without leaving double spaces', () {
      final result = Note.toggleTag('Body #pinned more text', 'pinned', false);
      expect(result, 'Body more text');
    });

    test('is a no-op when the tag is not present', () {
      final result = Note.toggleTag('# Title\n\nBody.', 'pinned', false);
      expect(result, '# Title\n\nBody.');
    });

    test('does not remove a tag that only shares a prefix', () {
      // #pinnedfoo must survive removing #pinned - the two are different tags.
      final result = Note.toggleTag('Body #pinnedfoo', 'pinned', false);
      expect(result, contains('#pinnedfoo'));
    });

    test('does not remove part of a longer tag when asked to remove a short one', () {
      final result = Note.toggleTag('#permanent-ish note', 'permanent', false);
      expect(result, contains('#permanent-ish'));
    });

    test('removing leaves a tag-only body empty rather than a stray space', () {
      final result = Note.toggleTag('#pinned', 'pinned', false);
      expect(result, isEmpty);
    });
  });

  group('Note.toggleTag round trip', () {
    test('add then remove returns to the original text', () {
      const original = '# Title\n\nSome body content here.';
      final added = Note.toggleTag(original, 'pinned', true);
      final removed = Note.toggleTag(added, 'pinned', false);
      expect(removed, original);
    });

    test('is idempotent: adding twice equals adding once', () {
      const original = '# Title\n\nBody.';
      final once = Note.toggleTag(original, 'pinned', true);
      final twice = Note.toggleTag(once, 'pinned', true);
      expect(twice, once);
    });
  });

  group('Note.withType', () {
    test('adds a type tag to an untyped note', () {
      final result = Note.withType('# Title\n\nBody.', NoteType.permanent);
      expect(result, contains('#permanent'));
    });

    test('switching type removes the old tag and adds the new one', () {
      var body = Note.withType('# Title\n\nBody.', NoteType.fleeting);
      body = Note.withType(body, NoteType.permanent);
      expect(body, contains('#permanent'));
      expect(body, isNot(contains('#fleeting')));
    });

    test('setting the same type twice does not duplicate the tag', () {
      var body = Note.withType('# Title\n\nBody.', NoteType.literature);
      body = Note.withType(body, NoteType.literature);
      final count = '#literature'.allMatches(body).length;
      expect(count, 1);
    });

    test('does not disturb an unrelated tag on the note', () {
      final result = Note.withType('# Title\n\nBody. #project', NoteType.permanent);
      expect(result, contains('#project'));
      expect(result, contains('#permanent'));
    });
  });

  group('Note.type derivation', () {
    Note make(String body) => Note.parse('x.md', body, DateTime(2026));

    test('defaults to fleeting when no type tag is present', () {
      expect(make('# T\n\nplain body').type, NoteType.fleeting);
    });

    test('recognises an explicit fleeting tag', () {
      expect(make('# T\n\nbody #fleeting').type, NoteType.fleeting);
    });

    test('recognises a literature tag', () {
      expect(make('# T\n\nbody #literature').type, NoteType.literature);
    });

    test('recognises a permanent tag', () {
      expect(make('# T\n\nbody #permanent').type, NoteType.permanent);
    });

    test('permanent wins if somehow both permanent and literature are present', () {
      expect(make('# T\n\n#literature #permanent').type, NoteType.permanent);
    });
  });

  group('Note.isPinned', () {
    Note make(String body) => Note.parse('x.md', body, DateTime(2026));

    test('is false with no pinned tag', () {
      expect(make('# T\n\nbody').isPinned, isFalse);
    });

    test('is true with a pinned tag', () {
      expect(make('# T\n\nbody #pinned').isPinned, isTrue);
    });
  });

  group('Note.isInboxItem', () {
    Note make(String body) => Note.parse('x.md', body, DateTime(2026));

    test('a bare fleeting note with no links or extra tags is an inbox item', () {
      expect(make('# Quick capture\n\nsome unsorted thought').isInboxItem, isTrue);
    });

    test('a pinned fleeting note with nothing else is still an inbox item', () {
      expect(make('# T\n\nthought #pinned').isInboxItem, isTrue);
    });

    test('gains a real tag and leaves the inbox', () {
      expect(make('# T\n\nthought #project').isInboxItem, isFalse);
    });

    test('gains a link and leaves the inbox', () {
      expect(make('# T\n\nsee [[Other Note]]').isInboxItem, isFalse);
    });

    test('a permanent note is never an inbox item', () {
      expect(make('# T\n\nthought #permanent').isInboxItem, isFalse);
    });

    test('a literature note is never an inbox item', () {
      expect(make('# T\n\nthought #literature').isInboxItem, isFalse);
    });
  });
}
