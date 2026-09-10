import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../services/appearance_service.dart';
import '../services/update_service.dart';
import '../services/vault_service.dart';
import '../theme/app_theme.dart';
import 'widgets/animated_text.dart';
import 'widgets/springable.dart';

/// One step of real startup work, shown while it runs.
///
/// Every step here corresponds to an actual await in [SplashScreen] - this
/// is deliberately not a fake progress bar on a timer. If a step is slow
/// (a large vault to scan, a cold network for the update check), the label
/// stays on it for as long as it actually takes.
class _BootStep {
  const _BootStep(this.label, this.run);
  final String label;
  final Future<void> Function() run;
}

/// Shown once at launch while [PileboxApp] does its real startup sequence,
/// then hands off to [HomeScreen].
///
/// This is the app's first impression, so it carries the brand mark and the
/// theme's own glow rather than a bare spinner - but it never blocks on
/// anything that is not genuinely part of starting up.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.vault,
    required this.updater,
    required this.onReady,
  });

  final VaultService vault;
  final UpdateService updater;

  /// Called once every step has finished, with the loaded preferences so
  /// the home screen does not have to load them again.
  final ValueChanged<AppPreferences> onReady;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  int _stepIndex = 0;
  String _label = 'Starting Pilebox...';
  late final List<_BootStep> _steps;

  @override
  void initState() {
    super.initState();
    _steps = _buildSteps();
    _run();
  }

  List<_BootStep> _buildSteps() {
    AppPreferences prefs = const AppPreferences();

    return [
      _BootStep('Loading preferences', () async {
        prefs = await AppearanceStore.loadPreferences();
      }),
      _BootStep('Opening your vault', () => widget.vault.load()),
      _BootStep('Preparing your first note', () async {
        if (!widget.vault.isEmpty) return;
        await widget.vault.create(
          'Welcome to Pilebox',
          initialBody: '# Welcome to Pilebox\n\n'
              'This is your first note. A few things worth knowing:\n\n'
              '- Every note is a plain `.md` file in your vault folder.\n'
              '- Link notes with [[double brackets]] - typing [[Another Note]] and '
              'opening it creates it if it does not exist yet.\n'
              '- Tag anything with #tags, like #project or #idea.\n'
              '- The Graph view shows every note and how they connect.\n'
              '- Notes start as Fleeting captures. Mark one Permanent once it '
              'is a fully-formed idea, from its editor toolbar.\n'
              '- Press Ctrl+K any time to jump straight to a note or command.\n\n'
              'Open the Help section any time from the rail for the full guide.\n\n'
              'Try creating [[My Second Note]] to see a link in action.',
        );
      }),
      _BootStep('Checking for updates', () async {
        // A slow or unreachable network must never hold the splash screen
        // hostage - this genuinely is a "best effort, do not block" step,
        // enforced with a hard ceiling independent of whatever timeout
        // UpdateService itself uses internally.
        await widget.updater.check(silent: true).timeout(
              const Duration(seconds: 4),
              onTimeout: () {},
            );
      }),
      _BootStep('Ready', () async {
        widget.onReady(prefs);
      }),
    ];
  }

  Future<void> _run() async {
    for (var i = 0; i < _steps.length; i++) {
      if (!mounted) return;
      setState(() {
        _stepIndex = i;
        _label = _steps[i].label;
      });
      try {
        await _steps[i].run();
      } catch (_) {
        // A single failed step (e.g. a genuinely broken vault path) must not
        // strand the user on the splash screen forever - move on and let
        // the affected feature surface its own error where it is visible
        // and actionable, rather than here where nothing can be done.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_stepIndex + 1) / _steps.length;

    return Scaffold(
      backgroundColor: Palette.void_,
      body: Stack(
        children: [
          Positioned.fill(child: _Backdrop()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Mark(),
                const SizedBox(height: 24),
                _StaggeredIn(
                  delay: const Duration(milliseconds: 120),
                  child: Text(
                    AppConfig.displayName,
                    style: AppType.title.copyWith(fontSize: 30, letterSpacing: -0.8),
                  ),
                ),
                const SizedBox(height: 6),
                _StaggeredIn(
                  delay: const Duration(milliseconds: 220),
                  child: Text(AppConfig.tagline, style: AppType.small.copyWith(letterSpacing: 0.2)),
                ),
                const SizedBox(height: 40),
                _StaggeredIn(
                  delay: const Duration(milliseconds: 320),
                  child: SizedBox(
                    width: 260,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Springable(
                            value: progress,
                            spring: Motion.smooth,
                            builder: (context, value, _) => Stack(
                              children: [
                                Container(height: 4, color: Palette.hairline),
                                FractionallySizedBox(
                                  widthFactor: value.clamp(0.0, 1.0),
                                  child: Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Palette.amber, Palette.amberSoft],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Palette.amber.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RevealText(
                              _label,
                              style: AppType.small,
                            ),
                            Text(
                              '${_stepIndex + 1} / ${_steps.length}',
                              style: AppType.timecode,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades and rises into place after [delay] - used to stagger the splash
/// screen's elements in one after another instead of everything appearing
/// at once, which reads as far more deliberate for very little extra code.
class _StaggeredIn extends StatefulWidget {
  const _StaggeredIn({required this.delay, required this.child});
  final Duration delay;
  final Widget child;

  @override
  State<_StaggeredIn> createState() => _StaggeredInState();
}

class _StaggeredInState extends State<_StaggeredIn> {
  bool _in = false;

  @override
  void initState() {
    super.initState();
    if (!Motion.enabled) {
      _in = true;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _in = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: Motion.slow,
      curve: Motion.glide,
      opacity: _in ? 1 : 0,
      child: AnimatedSlide(
        duration: Motion.slow,
        curve: Motion.glide,
        offset: _in ? Offset.zero : const Offset(0, 0.12),
        child: widget.child,
      ),
    );
  }
}

/// A slow, ambient drift of soft light points behind the mark - purely
/// atmospheric, tuned to sit well below the text in contrast so it never
/// competes for attention while the app is genuinely busy starting up.
class _Backdrop extends StatefulWidget {
  @override
  State<_Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<_Backdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void initState() {
    super.initState();
    if (Motion.enabled) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Palette.skin.glowOrigin,
          radius: 1.6,
          colors: [
            Color.alphaBlend(Palette.amber.withValues(alpha: 0.09), Palette.surfaceRaised),
            Palette.void_,
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _DriftPainter(t: _controller.value, color: Palette.amber),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _DriftPainter extends CustomPainter {
  _DriftPainter({required this.t, required this.color});
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(7);
    for (var i = 0; i < 5; i++) {
      final baseX = rand.nextDouble() * size.width;
      final baseY = rand.nextDouble() * size.height;
      final phase = rand.nextDouble() * math.pi * 2;
      final radius = 60.0 + rand.nextDouble() * 70;

      final dx = math.sin(t * math.pi * 2 + phase) * 24;
      final dy = math.cos(t * math.pi * 2 + phase * 1.3) * 18;

      final paint = Paint()
        ..color = color.withValues(alpha: 0.035)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
      canvas.drawCircle(Offset(baseX + dx, baseY + dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DriftPainter oldDelegate) => oldDelegate.t != t;
}

/// The brand mark, with a slow breathing pulse so the splash does not read
/// as frozen during a slower step.
class _Mark extends StatefulWidget {
  const _Mark();

  @override
  State<_Mark> createState() => _MarkState();
}

class _MarkState extends State<_Mark> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Palette.amber.withValues(alpha: 0.25),
            blurRadius: 36,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Image.asset('assets/brand/logo.png', width: 76, height: 76, filterQuality: FilterQuality.high),
    );

    if (!Motion.enabled) return mark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(
          scale: 1.0 + t * 0.045,
          child: Opacity(opacity: 0.88 + t * 0.12, child: child),
        );
      },
      child: mark,
    );
  }
}
