import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../theme/app_theme.dart';

/// Custom titlebar.
///
/// Windows' own titlebar cannot be themed, and a light strip above a dark app
/// is the clearest sign of a framework default. This draws the whole chrome
/// so the window reads as one designed surface.
class WindowChrome extends StatelessWidget {
  const WindowChrome({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // Only the label area drags. Wrapping the whole row in DragToMoveArea
    // swallows clicks on the window buttons, because the drag recogniser wins
    // the gesture arena before a tap is recognised.
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Image.asset(
                    'assets/brand/logo.png',
                    width: 17,
                    height: 17,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: AppType.label.copyWith(
                      color: Palette.textSecondary,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (trailing != null) trailing!,
          const _WindowButtons(),
        ],
      ),
    );
  }
}

class _WindowButtons extends StatelessWidget {
  const _WindowButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ChromeButton(
          icon: Icons.remove_rounded,
          tooltip: 'Minimise',
          onTap: windowManager.minimize,
        ),
        _ChromeButton(
          icon: Icons.crop_square_rounded,
          tooltip: 'Maximise',
          iconSize: 14,
          onTap: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        _ChromeButton(
          icon: Icons.close_rounded,
          tooltip: 'Close',
          danger: true,
          onTap: windowManager.close,
        ),
      ],
    );
  }
}

class _ChromeButton extends StatefulWidget {
  const _ChromeButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
    this.iconSize = 17,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;
  final double iconSize;

  @override
  State<_ChromeButton> createState() => _ChromeButtonState();
}

class _ChromeButtonState extends State<_ChromeButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: Motion.quick,
          width: 44,
          height: 38,
          color: _hover
              ? (widget.danger
                  ? Palette.dropped
                  : Palette.textPrimary.withValues(alpha: 0.09))
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: _hover
                ? (widget.danger ? Colors.white : Palette.textPrimary)
                : Palette.textTertiary,
          ),
        ),
      ),
    );
  }
}
