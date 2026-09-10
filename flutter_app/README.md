# Pilebox

A local, Zettelkasten-style markdown knowledge base for Windows.

Every note is a plain `.md` file in a folder you choose. Link notes with
`[[double brackets]]`, tag them with `#hashtags`, and Pilebox builds the
backlinks and graph for you - live, from the files themselves. Nothing
leaves your machine: no account, no server, no telemetry.

## Building

```powershell
..\setup_flutter.ps1   # one-time: installs Flutter + the C++ toolchain
..\build_exe.ps1       # builds build\windows\x64\runner\Release\Pilebox.exe
```

## Releasing an update

```powershell
..\publish_release.ps1 -Version 3.2.0 -Notes "What changed"
```

This bumps the version, rebuilds, zips the release, and publishes it to
GitHub. Running copies of the app pick it up automatically (see
`lib/services/update_service.dart`).

## Testing

```powershell
flutter test
```
