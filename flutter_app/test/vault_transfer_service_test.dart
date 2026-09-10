@TestOn('windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilebox/services/vault_transfer_service.dart';

void main() {
  late Directory sourceVault;
  late Directory targetVault;
  late Directory workDir;

  setUp(() async {
    workDir = await Directory.systemTemp.createTemp('pilebox_transfer_test_');
    sourceVault = Directory('${workDir.path}\\source')..createSync();
    targetVault = Directory('${workDir.path}\\target');
  });

  tearDown(() async {
    try {
      await workDir.delete(recursive: true);
    } catch (_) {
      // Best-effort cleanup.
    }
  });

  group('export', () {
    test('throws for a vault path that does not exist', () async {
      final zip = '${workDir.path}\\out.zip';
      expect(
        () => VaultTransferService.export('${workDir.path}\\missing', zip),
        throwsArgumentError,
      );
    });

    test('produces a zip file that exists on disk', () async {
      await File('${sourceVault.path}\\Note One.md').writeAsString('# Note One\n\nbody');
      final zip = '${workDir.path}\\out.zip';

      await VaultTransferService.export(sourceVault.path, zip);

      expect(await File(zip).exists(), isTrue);
    });

    test('returns the count of .md files exported', () async {
      await File('${sourceVault.path}\\A.md').writeAsString('# A');
      await File('${sourceVault.path}\\B.md').writeAsString('# B');
      await File('${sourceVault.path}\\notes.txt').writeAsString('not a note');

      final count = await VaultTransferService.export(sourceVault.path, '${workDir.path}\\out.zip');

      expect(count, 2);
    });
  });

  group('export then import round trip', () {
    test('every note survives with identical content', () async {
      await File('${sourceVault.path}\\First.md').writeAsString('# First\n\nSome content here.');
      await File('${sourceVault.path}\\Second.md').writeAsString('# Second\n\n[[First]] and #atag');

      final zip = '${workDir.path}\\backup.zip';
      await VaultTransferService.export(sourceVault.path, zip);
      await VaultTransferService.import(zip, targetVault.path);

      final restored = targetVault.listSync().whereType<File>().toList();
      expect(restored.length, 2);

      final firstContent = await File('${targetVault.path}\\First.md').readAsString();
      expect(firstContent, '# First\n\nSome content here.');

      final secondContent = await File('${targetVault.path}\\Second.md').readAsString();
      expect(secondContent, contains('[[First]]'));
      expect(secondContent, contains('#atag'));
    });

    test('does not nest an extra folder level - notes land directly in the target', () async {
      await File('${sourceVault.path}\\Flat.md').writeAsString('# Flat');

      final zip = '${workDir.path}\\backup.zip';
      await VaultTransferService.export(sourceVault.path, zip);
      await VaultTransferService.import(zip, targetVault.path);

      // Must exist directly at targetVault/Flat.md, not
      // targetVault/source/Flat.md - the whole point of includeDirName:false.
      expect(await File('${targetVault.path}\\Flat.md').exists(), isTrue);
      expect(await Directory('${targetVault.path}\\source').exists(), isFalse);
    });

    test('an empty vault round-trips to an empty vault without error', () async {
      final zip = '${workDir.path}\\empty.zip';
      await VaultTransferService.export(sourceVault.path, zip);
      await VaultTransferService.import(zip, targetVault.path);

      expect(await targetVault.exists(), isTrue);
      expect(targetVault.listSync(), isEmpty);
    });
  });

  group('import', () {
    test('throws for a zip that does not exist', () async {
      expect(
        () => VaultTransferService.import('${workDir.path}\\missing.zip', targetVault.path),
        throwsArgumentError,
      );
    });

    test('creates the target folder if it does not exist yet', () async {
      await File('${sourceVault.path}\\X.md').writeAsString('# X');
      final zip = '${workDir.path}\\out.zip';
      await VaultTransferService.export(sourceVault.path, zip);

      expect(await targetVault.exists(), isFalse);
      await VaultTransferService.import(zip, targetVault.path);
      expect(await targetVault.exists(), isTrue);
    });

    test('merges into an existing folder rather than wiping it', () async {
      await targetVault.create();
      await File('${targetVault.path}\\AlreadyHere.md').writeAsString('# AlreadyHere');

      await File('${sourceVault.path}\\Imported.md').writeAsString('# Imported');
      final zip = '${workDir.path}\\out.zip';
      await VaultTransferService.export(sourceVault.path, zip);
      await VaultTransferService.import(zip, targetVault.path);

      expect(await File('${targetVault.path}\\AlreadyHere.md').exists(), isTrue);
      expect(await File('${targetVault.path}\\Imported.md').exists(), isTrue);
    });
  });
}
