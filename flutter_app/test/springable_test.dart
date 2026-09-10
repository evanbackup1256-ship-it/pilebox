import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilebox/presentation/widgets/springable.dart';
import 'package:pilebox/theme/app_theme.dart';

void main() {
  // These widgets read Motion.enabled/Motion.smooth, which depend on the
  // global Motion.level - pin it so a test run order elsewhere cannot leak
  // reduced-motion into these.
  setUp(() => Motion.level = 1);

  double? lastValue;

  Widget harness(double value, {SpringDescription? spring}) {
    return MaterialApp(
      home: Springable(
        value: value,
        spring: spring,
        builder: (context, v, child) {
          lastValue = v;
          return const SizedBox();
        },
      ),
    );
  }

  testWidgets('starts exactly at the initial value with no animation', (tester) async {
    await tester.pumpWidget(harness(5.0));
    expect(lastValue, 5.0);
  });

  testWidgets('animates toward a new target over several frames', (tester) async {
    await tester.pumpWidget(harness(0.0));
    expect(lastValue, 0.0);

    await tester.pumpWidget(harness(100.0));
    await tester.pump(const Duration(milliseconds: 16));
    final afterOneFrame = lastValue!;

    // A spring takes real time; one frame in it must have moved toward the
    // target without having arrived yet.
    expect(afterOneFrame, greaterThan(0.0));
    expect(afterOneFrame, lessThan(100.0));

    await tester.pumpAndSettle();
    expect(lastValue, closeTo(100.0, 0.5));
  });

  testWidgets('retargeting mid-flight continues without a discontinuous jump', (tester) async {
    await tester.pumpWidget(harness(0.0, spring: Motion.smooth));
    await tester.pumpWidget(harness(100.0, spring: Motion.smooth));

    // Let it get partway there.
    await tester.pump(const Duration(milliseconds: 80));
    final midFlight = lastValue!;
    expect(midFlight, greaterThan(0.0));
    expect(midFlight, lessThan(100.0));

    // Interrupt: retarget back toward 0 before the first simulation settles.
    await tester.pumpWidget(harness(0.0, spring: Motion.smooth));
    await tester.pump(const Duration(milliseconds: 16));
    final justAfterRetarget = lastValue!;

    // The core behaviour under test: immediately after an interruption, the
    // value must still be close to where it was (continuous), not snapped
    // back to the new target's starting conditions or to 0. A regression
    // where _tick evaluates the new simulation at the OLD simulation's
    // elapsed time would show up here as a large, wrong jump.
    expect((justAfterRetarget - midFlight).abs(), lessThan(15.0));

    await tester.pumpAndSettle();
    expect(lastValue, closeTo(0.0, 0.5));
  });

  testWidgets('reduced motion snaps to target with no intermediate frames', (tester) async {
    Motion.level = 0;
    addTearDown(() => Motion.level = 1);

    await tester.pumpWidget(harness(0.0));
    await tester.pumpWidget(harness(50.0));
    await tester.pump(const Duration(milliseconds: 16));

    // Motion.springReduced is a hard critical-damped snap and Motion.enabled
    // gates build() to read widget.value directly - either way this should
    // already read the target, not something partway there.
    expect(lastValue, 50.0);
  });

  testWidgets('settles exactly on the target value, not just near it', (tester) async {
    await tester.pumpWidget(harness(0.0));
    await tester.pumpWidget(harness(42.0));
    await tester.pumpAndSettle();
    expect(lastValue, 42.0);
  });
}
