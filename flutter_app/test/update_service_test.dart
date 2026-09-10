import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pilebox/services/update_service.dart';

/// download() normally resolves its temp folder through path_provider's
/// platform channel, which has no real backend in a plain unit test.
/// Directory.systemTemp is pure dart:io and needs nothing special, so tests
/// inject it via UpdateService's tempDir parameter instead.
UpdateService _service({required http.Client client}) {
  return UpdateService(client: client, tempDir: () async => Directory.systemTemp);
}

Map<String, dynamic> _releaseJson({
  required String tag,
  required String downloadUrl,
  String? sha,
  String extraNotes = '',
}) {
  final notes = sha == null ? extraNotes : '$extraNotes\n\nSHA256: $sha';
  return {
    'tag_name': tag,
    'body': notes,
    'html_url': 'https://github.com/evanbackup1256-ship-it/pilebox/releases/tag/$tag',
    'assets': [
      {
        'name': 'Pilebox-windows-$tag.zip',
        'browser_download_url': downloadUrl,
        'size': 123,
      },
    ],
  };
}

void main() {
  group('checksum extraction from release notes', () {
    test('a release with a valid checksum becomes available for download', () async {
      final payload = Uint8List.fromList(utf8.encode('fake zip contents'));
      final hash = sha256.convert(payload).toString();

      final client = MockClient((request) async {
        if (request.url.host == 'api.github.com') {
          return http.Response(
            jsonEncode(_releaseJson(
              tag: 'v99.0.0',
              downloadUrl: 'https://github.com/owner/repo/releases/download/v99.0.0/x.zip',
              sha: hash,
            )),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final service = _service(client: client);
      await service.check();

      expect(service.stage, UpdateStage.available);
      expect(service.release?.sha256, hash);
    });

    test('a release with no checksum line has a null sha256', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(_releaseJson(
            tag: 'v99.0.0',
            downloadUrl: 'https://github.com/owner/repo/releases/download/v99.0.0/x.zip',
            sha: null,
            extraNotes: 'Just some notes, no hash here.',
          )),
          200,
        );
      });

      final service = _service(client: client);
      await service.check();

      expect(service.release?.sha256, isNull);
    });

    test('is case-insensitive and normalises to lowercase', () async {
      const upperHash = 'AB'
          'CDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789';
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(_releaseJson(
            tag: 'v99.0.0',
            downloadUrl: 'https://github.com/owner/repo/releases/download/v99.0.0/x.zip',
            sha: upperHash,
          )),
          200,
        );
      });

      final service = _service(client: client);
      await service.check();

      expect(service.release?.sha256, upperHash.toLowerCase());
    });

    test('ignores a malformed (wrong-length) hash', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(_releaseJson(
            tag: 'v99.0.0',
            downloadUrl: 'https://github.com/owner/repo/releases/download/v99.0.0/x.zip',
            sha: null,
            extraNotes: 'SHA256: deadbeef',
          )),
          200,
        );
      });

      final service = _service(client: client);
      await service.check();

      expect(service.release?.sha256, isNull);
    });
  });

  group('download integrity verification', () {
    test('refuses a download URL that is not a trusted GitHub host', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'api.github.com') {
          return http.Response(
            jsonEncode(_releaseJson(
              tag: 'v99.0.0',
              downloadUrl: 'https://evil.example.com/malware.zip',
              sha: 'a' * 64,
            )),
            200,
          );
        }
        fail('should never reach the download host');
      });

      final service = _service(client: client);
      await service.check();
      expect(service.stage, UpdateStage.available);

      await service.download();

      expect(service.stage, UpdateStage.failed);
      expect(service.message, contains('not a GitHub asset URL'));
    });

    test('accepts objects.githubusercontent.com as a trusted redirect target', () async {
      final payload = Uint8List.fromList(utf8.encode('genuine update bytes'));
      final hash = sha256.convert(payload).toString();

      final client = MockClient((request) async {
        if (request.url.host == 'api.github.com') {
          return http.Response(
            jsonEncode(_releaseJson(
              tag: 'v99.0.0',
              downloadUrl: 'https://objects.githubusercontent.com/release-asset/x.zip',
              sha: hash,
            )),
            200,
          );
        }
        return http.Response.bytes(payload, 200);
      });

      final service = _service(client: client);
      await service.check();
      await service.download();

      expect(service.stage, UpdateStage.readyToInstall);
    });

    test('refuses a download whose bytes do not match the published hash', () async {
      final realPayload = Uint8List.fromList(utf8.encode('the actual release'));
      final tamperedPayload = Uint8List.fromList(utf8.encode('substituted bytes'));
      final expectedHash = sha256.convert(realPayload).toString();

      final client = MockClient((request) async {
        if (request.url.host == 'api.github.com') {
          return http.Response(
            jsonEncode(_releaseJson(
              tag: 'v99.0.0',
              downloadUrl: 'https://github.com/owner/repo/releases/download/v99.0.0/x.zip',
              sha: expectedHash,
            )),
            200,
          );
        }
        // Server returns something other than what the checksum promised -
        // simulates a compromised/corrupted asset.
        return http.Response.bytes(tamperedPayload, 200);
      });

      final service = _service(client: client);
      await service.check();
      await service.download();

      expect(service.stage, UpdateStage.failed);
      expect(service.message, contains('failed verification'));
    });

    test('refuses to install a release with no published checksum at all', () async {
      final payload = Uint8List.fromList(utf8.encode('anything'));

      final client = MockClient((request) async {
        if (request.url.host == 'api.github.com') {
          return http.Response(
            jsonEncode(_releaseJson(
              tag: 'v99.0.0',
              downloadUrl: 'https://github.com/owner/repo/releases/download/v99.0.0/x.zip',
              sha: null,
            )),
            200,
          );
        }
        return http.Response.bytes(payload, 200);
      });

      final service = _service(client: client);
      await service.check();
      expect(service.release?.sha256, isNull);

      await service.download();

      expect(service.stage, UpdateStage.failed);
      expect(service.message, contains('no published checksum'));
    });

    test('accepts a download whose bytes exactly match the published hash', () async {
      final payload = Uint8List.fromList(utf8.encode('the real, correct release bytes'));
      final hash = sha256.convert(payload).toString();

      final client = MockClient((request) async {
        if (request.url.host == 'api.github.com') {
          return http.Response(
            jsonEncode(_releaseJson(
              tag: 'v99.0.0',
              downloadUrl: 'https://github.com/owner/repo/releases/download/v99.0.0/x.zip',
              sha: hash,
            )),
            200,
          );
        }
        return http.Response.bytes(payload, 200);
      });

      final service = _service(client: client);
      await service.check();
      await service.download();

      expect(service.stage, UpdateStage.readyToInstall);
      expect(service.message, contains('verified'));
    });
  });

  group('version comparisons that gate whether an update is even offered', () {
    test('does not offer a release that is not newer than the running version', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(_releaseJson(
            tag: 'v0.0.1', // far below AppConfig.version
            downloadUrl: 'https://github.com/owner/repo/releases/download/v0.0.1/x.zip',
            sha: 'a' * 64,
          )),
          200,
        );
      });

      final service = _service(client: client);
      await service.check();

      expect(service.stage, UpdateStage.upToDate);
      expect(service.release, isNull);
    });
  });
}
