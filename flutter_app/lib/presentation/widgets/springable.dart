import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import '../../theme/app_theme.dart';

/// Drives a single double value with a real [SpringSimulation] rather than
/// a fixed-duration [Tween].
///
/// The point of this over `AnimatedContainer`/`TweenAnimationBuilder`: those
/// restart from scratch every time the target changes mid-flight, so
/// wiggling a hover in and out during its own animation makes it visibly
/// stutter or jump. A spring is retargeted from its current position AND
/// velocity, so it continues the motion it was already making - which is
/// what makes rapid, repeated interaction (hovering, scrolling past several
/// items, dragging) look continuous instead of glitchy.
class Springable extends StatefulWidget {
  const Springable({
    super.key,
    required this.value,
    required this.builder,
    this.child,
    SpringDescription? spring,
  }) : _spring = spring;

  /// The value being sprung toward. Changing it retargets the simulation
  /// in place; it does not restart the animation.
  final double value;

  final Widget? child;
  final Widget Function(BuildContext context, double value, Widget? child) builder;
  final SpringDescription? _spring;

  @override
  State<Springable> createState() => _SpringableState();
}

class _SpringableState extends State<Springable> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  late double _position;
  double _velocity = 0;
  SpringSimulation? _simulation;

  @override
  void initState() {
    super.initState();
    _position = widget.value;
    _ticker = createTicker(_tick);
  }

  @override
  void didUpdateWidget(covariant Springable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _retarget();
  }

  void _retarget() {
    final spring = widget._spring ?? Motion.smooth;
    _simulation = SpringSimulation(spring, _position, widget.value, _velocity);
    // Ticker.start() resets its own elapsed-time clock to zero, which is
    // exactly what _tick needs: "time since this simulation began" always
    // equals "time since the ticker was (re)started". Restarting an
    // already-running ticker is what makes retargeting mid-flight correct -
    // without this, a second retarget would evaluate the new simulation at
    // the OLD simulation's elapsed time and jump.
    _ticker.stop();
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final sim = _simulation;
    if (sim == null) {
      _ticker.stop();
      return;
    }
    final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;

    setState(() {
      _position = sim.x(t);
      _velocity = sim.dx(t);
    });

    if (sim.isDone(t)) {
      _position = widget.value;
      _velocity = 0;
      _simulation = null;
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion: jump straight to the target, no simulation running.
    final value = Motion.enabled ? _position : widget.value;
    return widget.builder(context, value, widget.child);
  }
}
