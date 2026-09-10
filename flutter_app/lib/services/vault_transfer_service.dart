import 'dart:io';

import 'package:archive/archive_io.dart';

/// Exports a vault folder to a single .zip, and imports one back.
///
/// This is a distinct feature from the vault simply being plain files on
/// disk (which already makes any general-purpose backup tool work without
/// help): it is a one-click way to hand someone your whole Zettelkasten, or
/// move it to a new machine, as one file instead of a folder.
class VaultTransferService {
  const VaultTransferService._();

  /// Zips every file in [vaultPath] into [destinationZip].
  ///
  /// Returns the number of files written, so the caller can show something
  /// more useful than "done" (e.g. "42 notes exported").
  static Future<int> export(String vaultPath, String destinationZip) async {
    final dir = Directory(vaultPath);
    if (!await dir.exists()) {
      throw ArgumentError('Vault folder does not exist: $vaultPath');
    }

    var count = 0;
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.md')) count++;
    }

    final encoder = ZipFileEncoder();
    encoder.create(destinationZip);
    // includeDirName: false - the zip's top level should be the notes
    // themselves, not a folder wrapping them, so extracting it later drops
    // straight into a vault folder rather than one level of nesting deeper.
    await encoder.addDirectory(dir, includeDirName: false);
    await encoder.close();

    return count;
  }

  /// Extracts [sourceZip] into [vaultPath], creating it if needed.
  ///
  /// Deliberately does not delete anything already in [vaultPath] first -
  /// an import merges into the target folder (files with the same name are
  /// overwritten by extractFileToDisk, everything else is left alone) rather
  /// than silently wiping out notes that happen to already be there.
  static Future<void> import(String sourceZip, String vaultPath) async {
    final zip = File(sourceZip);
    if (!await zip.exists()) {
      throw ArgumentError('Zip file does not exist: $sourceZip');
    }
    await Directory(vaultPath).create(recursive: true);
    // extractFileToDisk itself guards every extracted path against escaping
    // vaultPath (see archive's _isWithinOutputPath), so a zip cannot use
    // "../" entries to write outside the vault folder.
    await extractFileToDisk(sourceZip, vaultPath);
  }
}
