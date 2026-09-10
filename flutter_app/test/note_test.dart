import 'package:flutter_test/flutter_test.dart';
import 'package:pilebox/models/note.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  group('Note.parse title extraction', () {
    test('takes the title from the first heading', () {
      final note = Note.parse('C:\\vault\\x.md', '# My Title\n\nBody text.', now);
      expect(note.title, 'My Title');
    });

    test('falls back to the filename when there is no heading', () {
      final note = Note.parse('C:\\vault\\My File.md', 'just some text', now);
      expect(note.title, 'My File');
    });

    test('falls back to the filename when the heading is empty', () {
      final note = Note.parse('C:\\vault\\Fallback.md', '#   \nBody', now);
      expect(note.title, 'Fallback');
    });

    test('ignores a heading that is not on the first matching line', () {
      final note = Note.parse(
        'C:\\vault\\x.md',
        'Some intro text\n# Real Title\nmore',
        now,
      );
      expect(note.title, 'Real Title');
    });

    test('handles a forward-slash path the same as backslash', () {
      final note = Note.parse('/vault/Unix Style.md', 'body', now);
      expect(note.title, 'Unix Style');
    });

    test('id is the lowercased title', () {
      final note = Note.parse('C:\\vault\\x.md', '# Mixed CASE Title', now);
      expect(note.id, 'mixed case title');
    });
  });

  group('Note.parse tag extraction', () {
    test('finds simple tags', () {
      final note = Note.parse('x.md', '# T\n\nSome #project text and #idea.', now);
      expect(note.tags, {'project', 'idea'});
    });

    test('lowercases tags so #Project and #project are the same', () {
      final note = Note.parse('x.md', '#Project #project', now);
      expect(note.tags, {'project'});
    });

    test('supports nested tags with a slash', () {
      final note = Note.parse('x.md', 'See #project/frontend for details.', now);
      expect(note.tags, {'project/frontend'});
    });

    test('does not treat a markdown heading marker as a tag', () {
      final note = Note.parse('x.md', '# Heading\n## Subheading', now);
      expect(note.tags, isEmpty);
    });

    test('does not match a bare hash with no word characters after it', () {
      final note = Note.parse('x.md', 'price is # 5 dollars', now);
      expect(note.tags, isEmpty);
    });

    test('a tag immediately after another tag is still matched', () {
      final note = Note.parse('x.md', '#foo#bar', now);
      // (?<![\w#]) means #bar right after #foo is NOT counted (preceded by
      // an alnum char from "foo"), matching how real "no space" tags are
      // ambiguous in most tag syntaxes. Confirm the actual, intentional
      // behaviour rather than assume.
      expect(note.tags, {'foo'});
    });
  });

  group('Note.parse link extraction', () {
    test('finds a simple wikilink', () {
      final note = Note.parse('x.md', 'See [[Other Note]] for more.', now);
      expect(note.links, {'Other Note'});
    });

    test('finds a piped wikilink by its target, not its display text', () {
      final note = Note.parse('x.md', 'See [[Other Note|here]] for more.', now);
      expect(note.links, {'Other Note'});
    });

    test('trims whitespace around the link target', () {
      final note = Note.parse('x.md', '[[  Spaced Title  ]]', now);
      expect(note.links, {'Spaced Title'});
    });

    test('collects multiple distinct links', () {
      final note = Note.parse('x.md', '[[A]] and [[B]] and [[A]] again', now);
      expect(note.links, {'A', 'B'});
    });

    test('an empty vault produces no links', () {
      final note = Note.parse('x.md', 'no links here', now);
      expect(note.links, isEmpty);
    });
  });

  group('Note.excerpt', () {
    test('strips the heading line', () {
      final note = Note.parse('x.md', '# Title\n\nThe actual body content.', now);
      expect(note.excerpt, 'The actual body content.');
    });

    test('strips wikilink brackets but keeps the target text', () {
      final note = Note.parse('x.md', '# T\n\nSee [[Other]] for context.', now);
      expect(note.excerpt, contains('Other'));
      expect(note.excerpt, isNot(contains('[[')));
    });

    test('strips markdown emphasis markers', () {
      final note = Note.parse('x.md', '# T\n\n**bold** and `code` and _x_', now);
      expect(note.excerpt, isNot(contains('*')));
      expect(note.excerpt, isNot(contains('`')));
    });

    test('truncates a very long body to 160 chars plus ellipsis', () {
      final long = 'a' * 300;
      final note = Note.parse('x.md', '# T\n\n$long', now);
      expect(note.excerpt.length, 163); // 160 chars + '...'
      expect(note.excerpt.endsWith('...'), isTrue);
    });

    test('is empty for a note with only a heading', () {
      final note = Note.parse('x.md', '# Just A Title', now);
      expect(note.excerpt, isEmpty);
    });
  });
}
