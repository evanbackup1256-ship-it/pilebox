import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'springable.dart';

/// A button that lifts and brightens on hover, and dips on press.
///
/// Built from scratch rather than restyling ElevatedButton: Material's ink
/// ripple and elevation curves are the single most recognisable "default
/// framework" tell, and they read wrong in a dark audio tool.
class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.compact = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool compact;
  final bool enabled;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onPressed != null;
    final primary = widget.primary;

    final background = !enabled
        ? Palette.surfaceRaised
        : primary
            ? (_hover ? const Color(0xFFF0B458) : Palette.amber)
            : (_hover ? Palette.surfaceRaised : Palette.surface);

    final foreground = !enabled
        ? Palette.textTertiary
        : primary
            ? Palette.void_
            : (_hover ? Palette.textPrimary : Palette.textSecondary);

    // A real spring here (vs. the AnimatedScale it replaces) means a fast
    // double-click - press, release, press again before the first release's
    // animation settles - continues from the actual in-flight scale and
    // velocity instead of snapping back to 1.0 and re-easing, which is
    // exactly the kind of rapid repeated interaction a button gets.
    final targetScale = _down ? 0.965 : (_hover ? 1.02 : 1.0);

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: Springable(
          value: targetScale,
          spring: Motion.snappy,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: AnimatedContainer(
            duration: Motion.quick,
            curve: Motion.swift,
            transform: Matrix4.translationValues(0, _down ? 1 : 0, 0),
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 12 : 18,
              vertical: widget.compact ? 8 : 11,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: primary
                    ? Colors.transparent
                    : (_hover ? Palette.hairline : const Color(0xFF202028)),
              ),
              boxShadow: primary && enabled && !_down
                  ? [
                      BoxShadow(
                        color: Palette.amber.withValues(alpha: _hover ? 0.3 : 0.18),
                        blurRadius: _hover ? 18 : 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: widget.compact ? 13 : 15, color: foreground),
                  // An icon-only button (empty label) must not carry the
                  // gap meant to separate it from label text - with no text
                  // to fill the row, that gap became dead space that pushed
                  // the icon visibly left-of-centre in the button.
                  if (widget.label.isNotEmpty) const SizedBox(width: 7),
                ],
                if (widget.label.isNotEmpty)
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: widget.compact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                      color: foreground,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled on/off control.
///
/// The track is a thin rail rather than Material's pill, and the thumb
/// travels on a spring so it settles instead of snapping.
class SettingSwitch extends StatelessWidget {
  const SettingSwitch({
    super.key,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
    this.locked = false,
    this.onLockedTap,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// When true the switch cannot be toggled and taps go to [onLockedTap]
  /// (typically opening the Plans panel) instead of [onChanged].
  final bool locked;
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: locked ? onLockedTap : () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: AppType.body.copyWith(
                            color: Palette.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (locked) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.lock_rounded,
                              size: 12, color: Palette.amber),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppType.body.copyWith(
                        fontSize: 11.5,
                        color: Palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.spring,
                  width: 38,
                  height: 20,
                  decoration: BoxDecoration(
                    color: value
                        ? Palette.amber.withValues(alpha: 0.22)
                        : Palette.surfaceRaised,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: value ? Palette.amber : Palette.hairline,
                    ),
                  ),
                  child: AnimatedAlign(
                    duration: Motion.base,
                    curve: Motion.spring,
                    alignment:
                        value ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: value ? Palette.amber : Palette.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section heading with a trailing hairline.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text, style: AppType.label),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: Palette.hairline)),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

/// Scroll view without Material's glow/stretch overscroll, which looks
/// out of place in a compact desktop panel.
class QuietScroll extends StatelessWidget {
  const QuietScroll({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _NoGlow(),
      child: SingleChildScrollView(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );
  }
}

class _NoGlow extends ScrollBehavior {
  const _NoGlow();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

/// Small selectable chip used for filters and segmented choices.
class MiniChip extends StatefulWidget {
  const MiniChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dot;

  @override
  State<MiniChip> createState() => _MiniChipState();
}

class _MiniChipState extends State<MiniChip> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: Springable(
          value: _down ? 0.93 : 1.0,
          spring: Motion.snappy,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: AnimatedContainer(
            duration: Motion.quick,
            curve: Motion.swift,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? Palette.amber.withValues(alpha: 0.13)
                  : (_hover ? Palette.surfaceRaised : Palette.surface),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? Palette.amber.withValues(alpha: 0.55)
                    : Palette.hairline,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.dot) ...[
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Palette.live,
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                Text(
                  widget.label,
                  style: AppType.body.copyWith(
                    fontSize: 11.5,
                    color: selected ? Palette.amber : Palette.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled text field matching the app's input styling.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint = '',
    this.onChanged,
    this.mono = false,
    this.maxLength,
    this.helper = '',
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool mono;
  final int? maxLength;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final style = mono
        ? AppType.mono.copyWith(color: Palette.textPrimary, fontSize: 12.5)
        : AppType.body.copyWith(color: Palette.textPrimary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: AppType.label),
          const SizedBox(height: 7),
        ],
        Container(
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Palette.hairline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: style,
            maxLength: maxLength,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
              hintText: hint,
              hintStyle: style.copyWith(color: Palette.textTertiary),
            ),
          ),
        ),
        if (helper.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(helper, style: AppType.small),
        ],
      ],
    );
  }
}