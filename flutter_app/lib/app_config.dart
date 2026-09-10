/// Build-time constants.
///
/// [version] must match the tag you publish on GitHub (the updater compares
/// them), and the `version:` field in pubspec.yaml.
class AppConfig {
  const AppConfig._();

  static const appName = 'Pilebox';
  static const displayName = 'Pilebox';
  static const version = '3.2.0';

  static const tagline = 'A local, Zettelkasten-style knowledge base';

  /// "owner/repo" on GitHub, used for update checks.
  /// Leave empty to disable updating entirely.
  static const updateRepo = 'evanbackup1256-ship-it/pilebox';

  /// How often to check for updates while running.
  static const updateCheckInterval = Duration(hours: 6);

  /// SHA-256 of each published release asset, keyed by tag ("v3.1.0").
  /// Populated by publish_release.ps1 in the GitHub release notes; the
  /// updater fetches and checks this before ever running the downloaded
  /// installer script. See UpdateService for why this exists.
  static const releaseNotesChecksumMarker = 'SHA256:';
}
