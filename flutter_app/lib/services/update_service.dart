import 'dart:convert';
import 'dart:io' show Directory, File, Platform, Process, ProcessStartMode, pid;
import 'dart:typed_data' show BytesBuilder;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../app_config.dart';

/// Where an update currently stands.
enum UpdateStage {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  verifying,
  readyToInstall,
  failed,
}

/// Hosts a release asset is allowed to actually be downloaded from.
///
/// `browser_download_url` in the GitHub API response is server-supplied
/// data - trusting it blindly means a compromised API response (or a
/// malicious/misconfigured proxy in front of it) could redirect the "update"
/// download anywhere. Restricting to GitHub's own asset hosts, over https
/// only, means the worst a corrupted API response can do is fail closed.
const _allowedDownloadHosts = {
  'github.com',
  'objects.githubusercontent.com',
  'release-assets.githubusercontent.com',
};

bool _isTrustedDownloadUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.scheme != 'https') return false;
  return _allowedDownloadHosts.contains(uri.host);
}

/// A release published on GitHub.
@immutable
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.notes,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.pageUrl,
    required this.sha256,
  });

  final Version version;
  final String notes;
  final String downloadUrl;
  final int sizeBytes;
  final String pageUrl;

  /// Expected SHA-256 of the download, lowercase hex. Null when the release
  /// notes did not carry one - see [UpdateService.download] for what
  /// happens then.
  final String? sha256;
}

/// A semantic version, tolerant of a leading "v".
@immutable
class Version implements Comparable<Version> {
  const Version(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static Version? tryParse(String raw) {
    var text = raw.trim();
    if (text.toLowerCase().startsWith('v')) text = text.substring(1);

    // Drop any pre-release / build suffix.
    final cut = text.indexOf(RegExp(r'[-+]'));
    if (cut > 0) text = text.substring(0, cut);

    final parts = text.split('.');
    if (parts.isEmpty) return null;

    int? at(int i) => i < parts.length ? int.tryParse(parts[i]) : 0;
    final major = at(0);
    if (major == null) return null;
    return Version(major, at(1) ?? 0, at(2) ?? 0);
  }

  @override
  int compareTo(Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >(Version other) => compareTo(other) > 0;

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) =>
      other is Version &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}

/// Checks GitHub Releases, downloads a new build, verifies it, and swaps
/// it in.
///
/// The swap works around Windows locking a running executable: the new build
/// is unpacked beside the current install, then a small batch script waits
/// for this process to exit, replaces the files, and relaunches. That is why
/// users never have to re-run an installer.
///
/// Security model: the download URL must resolve to a GitHub-owned host over
/// https ([_isTrustedDownloadUrl]), and the downloaded bytes must match a
/// SHA-256 published in the release notes ([ReleaseInfo.sha256]) before the
/// installer script is ever written or run. Both checks fail closed - if
/// either cannot be satisfied, the update is refused rather than applied
/// with a warning.
class UpdateService extends ChangeNotifier {
  UpdateService({http.Client? client, Future<Directory> Function()? tempDir})
      : _client = client ?? http.Client(),
        _tempDir = tempDir ?? getTemporaryDirectory;

  final http.Client _client;

  /// Injectable so tests can avoid path_provider's platform channel, which
  /// has no real backend in a plain unit test and throws instead of
  /// resolving - same reasoning as the injectable [http.Client].
  final Future<Directory> Function() _tempDir;

  UpdateStage _stage = UpdateStage.idle;
  UpdateStage get stage => _stage;

  ReleaseInfo? _release;
  ReleaseInfo? get release => _release;

  double _progress = 0;
  double get progress => _progress;

  String _message = '';
  String get message => _message;

  File? _downloaded;

  Version get currentVersion =>
      Version.tryParse(AppConfig.version) ?? const Version(0, 0, 0);

  /// Queries the releases API. Safe to call on a timer.
  Future<void> check({bool silent = false}) async {
    if (_stage == UpdateStage.checking || _stage == UpdateStage.downloading) {
      return;
    }
    if (AppConfig.updateRepo.isEmpty) {
      _set(UpdateStage.idle, message: 'Updates are not configured.');
      return;
    }

    _set(UpdateStage.checking, message: 'Checking for updates...');

    try {
      final uri = Uri.parse(
        'https://api.github.com/repos/${AppConfig.updateRepo}/releases/latest',
      );
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': '${AppConfig.appName}/${AppConfig.version}',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 404) {
        _set(UpdateStage.upToDate, message: 'No releases published yet.');
        return;
      }

      // GitHub allows 60 unauthenticated calls per hour per IP address and
      // answers 403 (sometimes 429) once that runs out. That is a temporary
      // throttle, not a broken install, so say so and stay quiet when the
      // check was a background one.
      if (response.statusCode == 403 || response.statusCode == 429) {
        final reset = int.tryParse(
          response.headers['x-ratelimit-reset'] ?? '',
        );
        final when = reset == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(reset * 1000);
        final wait = when == null
            ? 'shortly'
            : 'at ${when.hour.toString().padLeft(2, '0')}:'
                '${when.minute.toString().padLeft(2, '0')}';
        // GitHub also returns 403 for its secondary "abuse detection" limit,
        // which never sets x-ratelimit-remaining: 0. Treat every 403/429 as
        // a temporary throttle rather than a broken install.
        _set(
          UpdateStage.idle,
          message: silent
              ? ''
              : 'GitHub is rate limiting update checks. Try again $wait.',
        );
        return;
      }

      if (response.statusCode != 200) {
        _set(UpdateStage.failed,
            message: 'Update check failed (${response.statusCode}).');
        return;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?) ?? '';
      final version = Version.tryParse(tag);
      if (version == null) {
        _set(UpdateStage.failed, message: 'Unreadable release tag "$tag".');
        return;
      }

      // Pick the Windows zip asset.
      final assets = (json['assets'] as List?) ?? const [];
      Map<String, dynamic>? asset;
      for (final entry in assets.cast<Map<String, dynamic>>()) {
        final name = (entry['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.zip') && name.contains('windows')) {
          asset = entry;
          break;
        }
      }
      asset ??= assets.cast<Map<String, dynamic>>().where((e) {
        return (e['name'] as String? ?? '').toLowerCase().endsWith('.zip');
      }).firstOrNull;

      if (version > currentVersion && asset != null) {
        final downloadUrl = asset['browser_download_url'] as String? ?? '';
        _release = ReleaseInfo(
          version: version,
          notes: (json['body'] as String? ?? '').trim(),
          downloadUrl: downloadUrl,
          sizeBytes: (asset['size'] as num?)?.toInt() ?? 0,
          pageUrl: (json['html_url'] as String?) ?? '',
          sha256: _extractChecksum(json['body'] as String? ?? ''),
        );
        _set(UpdateStage.available, message: 'Version $version is available.');
      } else {
        _set(UpdateStage.upToDate,
            message: silent ? '' : 'You are on the latest version.');
      }
    } catch (e) {
      _set(UpdateStage.failed, message: 'Could not reach the update server.');
    }
  }

  /// Pulls a `SHA256: <hex>` line out of the release notes. publish_release.ps1
  /// writes this for every release it creates.
  static String? _extractChecksum(String notes) {
    final match = RegExp(
      '${RegExp.escape(AppConfig.releaseNotesChecksumMarker)}\\s*([0-9a-fA-F]{64})',
    ).firstMatch(notes);
    return match?.group(1)?.toLowerCase();
  }

  /// Downloads the release zip, reporting progress, then verifies it.
  Future<void> download() async {
    final release = _release;
    if (release == null) return;

    if (!_isTrustedDownloadUrl(release.downloadUrl)) {
      _set(UpdateStage.failed,
          message: 'Refused: the download link is not a GitHub asset URL.');
      return;
    }

    _progress = 0;
    _set(UpdateStage.downloading, message: 'Downloading update...');

    File? file;
    try {
      final request = http.Request('GET', Uri.parse(release.downloadUrl));
      request.headers['User-Agent'] =
          '${AppConfig.appName}/${AppConfig.version}';
      final response = await _client.send(request);

      if (response.statusCode != 200) {
        _set(UpdateStage.failed,
            message: 'Download failed (${response.statusCode}).');
        return;
      }

      final dir = await _tempDir();
      file = File('${dir.path}\\${AppConfig.appName}_update.zip');
      final sink = file.openWrite();

      final total = response.contentLength ?? release.sizeBytes;
      var received = 0;
      // Update packages are a handful of MB, so buffering the whole thing to
      // hash in one call is simpler and just as fast as a chunked digest,
      // with none of the streaming-Sink API surface to get wrong.
      final buffer = BytesBuilder(copy: false);

      await for (final chunk in response.stream) {
        sink.add(chunk);
        buffer.add(chunk);
        received += chunk.length;
        if (total > 0) {
          _progress = received / total;
          notifyListeners();
        }
      }
      await sink.close();
      final actualHash = sha256.convert(buffer.takeBytes()).toString();

      // --- Integrity check --------------------------------------------
      // Without this, whatever bytes arrived over the wire get expanded and
      // robocopied straight over the running install (see
      // installAndRestart). A tampered GitHub asset, a compromised CDN edge,
      // or a corrupted download would all execute silently. The expected
      // hash comes from the release notes GitHub itself served, so this
      // only fails to catch an attacker who can also forge that response -
      // at which point the trusted-host check above is the remaining line
      // of defence, not this one alone.
      _set(UpdateStage.verifying, message: 'Verifying download...');

      final expected = release.sha256;
      if (expected == null) {
        await file.delete();
        _set(UpdateStage.failed,
            message: 'Refused: this release has no published checksum.');
        return;
      }
      if (actualHash != expected) {
        await file.delete();
        _set(UpdateStage.failed,
            message: 'Refused: downloaded file failed verification.');
        return;
      }

      _downloaded = file;
      _set(UpdateStage.readyToInstall,
          message: 'Update verified. Restart to apply.');
    } catch (e) {
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (_) {
        // Best-effort cleanup.
      }
      _set(UpdateStage.failed, message: 'Download failed.');
    }
  }

  /// Writes the swap script, launches it, and asks the app to quit.
  ///
  /// Returns false if anything went wrong, in which case the caller should
  /// keep running rather than exiting. Only ever called with a file that has
  /// already passed the SHA-256 check in [download].
  Future<bool> installAndRestart() async {
    final zip = _downloaded;
    if (zip == null || !await zip.exists()) return false;

    try {
      final exePath = Platform.resolvedExecutable;
      final installDir = File(exePath).parent.path;
      final temp = await _tempDir();
      final script = File('${temp.path}\\${AppConfig.appName}_apply.bat');
      final processId = pid;

      // The running exe is locked, so the swap has to happen after exit.
      // The loop waits for the PID to disappear, then mirrors the new files
      // over the install directory and relaunches.
      await script.writeAsString('''
@echo off
setlocal
set "PIDFILE=$processId"
:waitloop
tasklist /FI "PID eq $processId" 2>nul | find "$processId" >nul
if not errorlevel 1 (
  timeout /t 1 /nobreak >nul
  goto waitloop
)
set "STAGE=%TEMP%\\${AppConfig.appName}_stage"
if exist "%STAGE%" rmdir /s /q "%STAGE%"
mkdir "%STAGE%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '${zip.path}' -DestinationPath '%STAGE%' -Force"
if errorlevel 1 goto fail
robocopy "%STAGE%" "$installDir" /E /IS /R:3 /W:2 /NFL /NDL /NJH /NJS /NC /NS >nul
if errorlevel 8 goto fail
rmdir /s /q "%STAGE%"
del /q "${zip.path}" >nul 2>&1
set "NEWEXE="
for %%F in ("$installDir\\*.exe") do set "NEWEXE=%%F"
if defined NEWEXE (
  start "" "%NEWEXE%"
) else (
  start "" "$exePath"
)
del "%~f0"
exit /b 0
:fail
if exist "%STAGE%" rmdir /s /q "%STAGE%"
del /q "${zip.path}" >nul 2>&1
start "" "$exePath"
del "%~f0"
exit /b 1
''');

      await Process.start(
        'cmd.exe',
        ['/c', script.path],
        mode: ProcessStartMode.detached,
        runInShell: false,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void _set(UpdateStage stage, {String message = ''}) {
    _stage = stage;
    _message = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
