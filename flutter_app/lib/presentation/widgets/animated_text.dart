import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Reveals [text] character by character, like a typewriter.
///
/// Used sparingly - on the splash screen's status line and a note's title
/// when it first opens - because a typewriter effect on every piece of text
/// in an app is exhausting, not delightful. It exists to draw the eye to a
/// specific moment (something just became true), not as decoration.
class TypewriterText extends StatefulWidget {
  const TypewriterText(
    this.text, {
    super.key,
    required this.style,
    this.speed = const Duration(milliseconds: 18),
    this.onDone,
  });

  final String text;
  final TextStyle style;

  /// Time per character. Reduced motion skips straight to the full text.
  final Duration speed;
  final VoidCallback? onDone;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    if (!Motion.enabled) {
      _shown = widget.text.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone?.call());
    } else {
      _scheduleNext();
    }
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _shown = 0;
      if (Motion.enabled) {
        _scheduleNext();
      } else {
        _shown = widget.text.length;
      }
    }
  }

  void _scheduleNext() {
    if (_shown >= widget.text.length) {
      widget.onDone?.call();
      return;
    }
    Future.delayed(widget.speed, () {
      if (!mounted) return;
      setState(() => _shown++);
      _scheduleNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(widget.text.substring(0, _shown.clamp(0, widget.text.length)), style: widget.style);
  }
}

/// Animates a number counting up (or down) to [value] with a spring, instead
/// of jumping straight to it - used for stat tiles where a number changing
/// is itself the interesting event (e.g. Settings > Vault statistics).
class CountUpNumber extends StatefulWidget {
  const CountUpNumber({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 500),
  });

  final int value;
  final TextStyle style;
  final Duration duration;

  @override
  State<CountUpNumber> createState() => _CountUpNumberState();
}

class _CountUpNumberState extends State<CountUpNumber> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;
  int _from = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = IntTween(begin: widget.value, end: widget.value).animate(_controller);
    if (Motion.enabled) {
      _from = 0;
      _startFrom(0, widget.value);
    } else {
      _from = widget.value;
    }
  }

  void _startFrom(int from, int to) {
    _animation = IntTween(begin: from, end: to).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant CountUpNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (!Motion.enabled) {
        setState(() => _from = widget.value);
        return;
      }
      _startFrom(_animation.value, widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Motion.enabled) {
      return Text('$_from', style: widget.style);
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Text('${_animation.value}', style: widget.style),
    );
  }
}

/// Fades and slides text in, keyed on its own content so a text CHANGE
/// (not just first appearance) replays the entrance - used for note titles,
/// status lines, and anywhere text represents "what is true right now"
/// rather than static labelling.
class RevealText extends StatelessWidget {
  const RevealText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.base,
      switchInCurve: Motion.swift,
      switchOutCurve: Motion.swift,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.18), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: Text(
        text,
        key: ValueKey(text),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}
