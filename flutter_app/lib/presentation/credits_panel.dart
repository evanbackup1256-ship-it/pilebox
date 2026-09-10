import 'package:flutter/material.dart';

import '../app_config.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'widgets/primitives.dart';

/// About and the update control.
class CreditsPanel extends StatelessWidget {
  const CreditsPanel({super.key, required this.updater, required this.onQuit});

  final UpdateService updater;
  final Future<void> Function() onQuit;

  @override
  Widget build(BuildContext context) {
    return QuietScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('assets/brand/logo.png', width: 48, height: 48, filterQuality: FilterQuality.high),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppConfig.displayName, style: AppType.title.copyWith(fontSize: 22)),
                  const SizedBox(height: 3),
                  Text(AppConfig.tagline, style: AppType.body),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Palette.surfaceRaised,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Palette.hairline),
                    ),
                    child: Text('v${AppConfig.version}', style: AppType.timecode.copyWith(color: Palette.textSecondary)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 26),
          const SectionLabel('UPDATES'),
          const SizedBox(height: 12),
          _UpdateBlock(updater: updater, onQuit: onQuit),
          const SizedBox(height: 22),
          const SectionLabel('SECURITY'),
          const SizedBox(height: 12),
          _SecurityNote(),
          const SizedBox(height: 22),
          const SectionLabel('HOW IT WORKS'),
          const SizedBox(height: 12),
          Text(
            'Every note is a plain .md file in a folder you choose. Link notes with '
            '[[double brackets]], tag them with #hashtags, and Pilebox builds the '
            'backlinks and graph for you - live, from the files themselves.\n\n'
            'Nothing leaves your machine. No account, no server, no telemetry.',
            style: AppType.body.copyWith(height: 1.7),
          ),
        ],
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Palette.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, size: 16, color: Palette.live),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Updates are only ever downloaded from a GitHub-owned address '
              'over HTTPS, and every download is checked against a '
              'published SHA-256 checksum before it is applied. A download '
              'that fails either check is deleted and refused, never run.',
              style: AppType.body.copyWith(fontSize: 11.5, color: Palette.textTertiary, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateBlock extends StatefulWidget {
  const _UpdateBlock({required this.updater, required this.onQuit});
  final UpdateService updater;
  final Future<void> Function() onQuit;

  @override
  State<_UpdateBlock> createState() => _UpdateBlockState();
}

class _UpdateBlockState extends State<_UpdateBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.updater,
      builder: (context, _) {
        final stage = widget.updater.stage;
        final release = widget.updater.release;
        final isBusy = stage == UpdateStage.checking ||
            stage == UpdateStage.downloading ||
            stage == UpdateStage.verifying;
        final isGood = stage == UpdateStage.available || stage == UpdateStage.readyToInstall;

        return AnimatedContainer(
          duration: Motion.base,
          curve: Motion.swift,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isGood ? Palette.amber.withValues(alpha: 0.45) : Palette.hairline,
            ),
            boxShadow: isGood
                ? [BoxShadow(color: Palette.amber.withValues(alpha: 0.08), blurRadius: 18, spreadRadius: 1)]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      final t = isBusy ? _pulse.value : 0.0;
                      return Transform.scale(scale: 1 + t * 0.15, child: child);
                    },
                    child: _StageIcon(stage: stage),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: Motion.quick,
                          child: Text(
                            key: ValueKey(stage),
                            switch (stage) {
                              UpdateStage.available => 'Version ${release?.version} available',
                              UpdateStage.readyToInstall => 'Update ready',
                              UpdateStage.downloading => 'Downloading update',
                              UpdateStage.verifying => 'Verifying download',
                              UpdateStage.checking => 'Checking for updates',
                              UpdateStage.failed => 'Update failed',
                              UpdateStage.idle || UpdateStage.upToDate => 'Up to date',
                            },
                            style: AppType.body.copyWith(
                              color: isGood ? Palette.amber : Palette.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.updater.message.isEmpty
                              ? 'You are running v${AppConfig.version}.'
                              : widget.updater.message,
                          style: AppType.body.copyWith(fontSize: 11.5, color: Palette.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _UpdateAction(updater: widget.updater, onQuit: widget.onQuit),
                ],
              ),
              AnimatedSize(
                duration: Motion.base,
                curve: Motion.swift,
                alignment: Alignment.topCenter,
                child: stage == UpdateStage.downloading
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: widget.updater.progress > 0 ? widget.updater.progress : null,
                            minHeight: 3,
                            backgroundColor: Palette.hairline,
                            valueColor: AlwaysStoppedAnimation<Color>(Palette.amber),
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StageIcon extends StatelessWidget {
  const _StageIcon({required this.stage});
  final UpdateStage stage;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (stage) {
      UpdateStage.available || UpdateStage.readyToInstall => (Icons.arrow_circle_up_rounded, Palette.amber),
      UpdateStage.checking || UpdateStage.downloading || UpdateStage.verifying => (Icons.sync_rounded, Palette.textSecondary),
      UpdateStage.failed => (Icons.error_outline_rounded, Palette.dropped),
      UpdateStage.idle || UpdateStage.upToDate => (Icons.check_circle_outline_rounded, Palette.live),
    };
    return Icon(icon, size: 22, color: color);
  }
}

class _UpdateAction extends StatelessWidget {
  const _UpdateAction({required this.updater, required this.onQuit});
  final UpdateService updater;
  final Future<void> Function() onQuit;

  @override
  Widget build(BuildContext context) {
    return switch (updater.stage) {
      UpdateStage.available => ActionButton(
          label: 'Download',
          primary: true,
          compact: true,
          icon: Icons.download_rounded,
          onPressed: updater.download,
        ),
      UpdateStage.readyToInstall => ActionButton(
          label: 'Restart now',
          primary: true,
          compact: true,
          icon: Icons.restart_alt_rounded,
          onPressed: () async {
            final ok = await updater.installAndRestart();
            if (ok) await onQuit();
          },
        ),
      UpdateStage.downloading || UpdateStage.checking || UpdateStage.verifying => const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      _ => ActionButton(
          label: 'Check now',
          compact: true,
          onPressed: () => updater.check(),
        ),
    };
  }
}
