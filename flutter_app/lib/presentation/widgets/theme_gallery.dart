import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'springable.dart';

/// Theme chooser. Each card previews its own palette rather than showing a
/// swatch row, so the choice is made on the real thing.
class ThemeGallery extends StatelessWidget {
  const ThemeGallery({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Two per row at panel width; keeps each preview legible.
        final width = (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: Skins.all.map((skin) {
            return SizedBox(
              width: width,
              child: _SkinCard(
                skin: skin,
                selected: skin.id == selected,
                onTap: () => onSelect(skin.id),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SkinCard extends StatefulWidget {
  const _SkinCard({
    required this.skin,
    required this.selected,
    required this.onTap,
  });

  final AppSkin skin;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SkinCard> createState() => _SkinCardState();
}

class _SkinCardState extends State<_SkinCard> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: Springable(
          value: _down ? 0.96 : (_hover ? 1.02 : 1.0),
          spring: Motion.snappy,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: AnimatedContainer(
            duration: Motion.quick,
            curve: Motion.swift,
            transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: widget.selected ? Palette.amber : (_hover ? Palette.textTertiary : Palette.hairline),
                width: widget.selected ? 1.5 : 1,
              ),
              boxShadow: [
                if (widget.selected)
                  BoxShadow(color: Palette.amber.withValues(alpha: 0.25), blurRadius: 18, spreadRadius: 1),
                if (_hover)
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Live miniature of the theme, drawn in its own colours.
                      Container(
                        height: 62,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: skin.glowOrigin,
                            radius: 1.4,
                            colors: [skin.surfaceRaised, skin.voidColor],
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 11,
                              top: 13,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: skin.surface,
                                  border: Border.all(color: skin.hairline),
                                ),
                                child: Center(
                                  child: Icon(Icons.graphic_eq_rounded, size: 13, color: skin.accent),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 45,
                              top: 16,
                              right: 12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 5,
                                    width: 62,
                                    decoration: BoxDecoration(
                                      color: skin.textPrimary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    height: 4,
                                    width: 40,
                                    decoration: BoxDecoration(
                                      color: skin.textTertiary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Row(
                                    children: [
                                      Container(
                                        height: 3,
                                        width: 34,
                                        decoration: BoxDecoration(
                                          color: skin.accent,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      Container(
                                        height: 3,
                                        width: 26,
                                        decoration: BoxDecoration(
                                          color: skin.hairline,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        color: Palette.surface,
                        padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              skin.name,
                              style: AppType.body.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.selected ? Palette.amber : Palette.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              skin.blurb,
                              style: AppType.body.copyWith(fontSize: 10.5, color: Palette.textTertiary, height: 1.35),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // A checkmark that springs into the corner on selection,
                  // rather than relying on the border colour alone - a
                  // clearer, more immediate "this one" signal at a glance
                  // across a grid of otherwise similar-shaped cards.
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Springable(
                      value: widget.selected ? 1.0 : 0.0,
                      spring: Motion.snappy,
                      builder: (context, t, child) => Transform.scale(scale: t, child: child),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Palette.amber,
                          boxShadow: [BoxShadow(color: Palette.amber.withValues(alpha: 0.5), blurRadius: 8)],
                        ),
                        child: Icon(Icons.check_rounded, size: 13, color: skin.voidColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
