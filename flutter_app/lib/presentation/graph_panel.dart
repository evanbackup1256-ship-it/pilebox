import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/vault_service.dart';
import '../theme/app_theme.dart';

/// A force-directed graph of every note and the [[links]] between them.
///
/// A simple spring simulation (Fruchterman-Reingold flavoured) rather than a
/// package: the whole vault is small enough that a naive O(n^2) step per
/// frame is imperceptible, and it keeps this dependency-free.
class GraphPanel extends StatefulWidget {
  const GraphPanel({super.key, required this.vault, required this.onOpenNote});

  final VaultService vault;
  final ValueChanged<String> onOpenNote;

  @override
  State<GraphPanel> createState() => _GraphPanelState();
}

class _GraphNode {
  _GraphNode(this.id, this.label);
  final String id;
  final String label;
  Offset position = Offset.zero;
  Offset velocity = Offset.zero;
}

class _GraphPanelState extends State<GraphPanel> with SingleTickerProviderStateMixin {
  final _nodes = <String, _GraphNode>{};
  final _edges = <(String, String)>[];
  Ticker? _ticker;
  String? _hovered;
  Size _canvasSize = Size.zero;
  final _rand = Random(7);

  @override
  void initState() {
    super.initState();
    _rebuild();
    widget.vault.addListener(_rebuild);
    _ticker = createTicker(_step)..start();
  }

  @override
  void dispose() {
    widget.vault.removeListener(_rebuild);
    _ticker?.dispose();
    super.dispose();
  }

  void _rebuild() {
    final notes = widget.vault.notes;
    final ids = notes.map((n) => n.id).toSet();

    _nodes.removeWhere((id, _) => !ids.contains(id));
    for (final note in notes) {
      _nodes.putIfAbsent(note.id, () {
        final node = _GraphNode(note.id, note.title);
        final center = _canvasSize.isEmpty ? const Offset(300, 250) : _canvasSize.center(Offset.zero);
        node.position = center + Offset(_rand.nextDouble() * 60 - 30, _rand.nextDouble() * 60 - 30);
        return node;
      });
    }

    _edges.clear();
    for (final note in notes) {
      for (final link in note.links) {
        final target = widget.vault.byTitle(link);
        if (target != null) _edges.add((note.id, target.id));
      }
    }
    if (mounted) setState(() {});
  }

  void _step(Duration elapsed) {
    if (_nodes.length < 2 || _canvasSize.isEmpty) return;
    const repulsion = 2600.0;
    const springLength = 130.0;
    const springStrength = 0.02;
    const damping = 0.85;
    const centerPull = 0.002;

    final center = _canvasSize.center(Offset.zero);
    final list = _nodes.values.toList();

    for (final a in list) {
      var force = (center - a.position) * centerPull;

      for (final b in list) {
        if (identical(a, b)) continue;
        final delta = a.position - b.position;
        final dist = delta.distance.clamp(1.0, 800.0);
        force += delta / dist * (repulsion / (dist * dist));
      }

      for (final (from, to) in _edges) {
        _GraphNode? other;
        if (from == a.id) other = _nodes[to];
        if (to == a.id) other = _nodes[from];
        if (other == null) continue;
        final delta = other.position - a.position;
        final dist = delta.distance.clamp(1.0, 1000.0);
        force += delta / dist * ((dist - springLength) * springStrength);
      }

      a.velocity = (a.velocity + force) * damping;
      a.position += a.velocity;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasSize = constraints.biggest;
        return MouseRegion(
          onHover: (event) => _hoverAt(event.localPosition),
          onExit: (_) => setState(() => _hovered = null),
          child: GestureDetector(
            onTapUp: (details) => _tapAt(details.localPosition),
            child: CustomPaint(
              size: Size.infinite,
              painter: _GraphPainter(
                nodes: _nodes.values.toList(),
                edges: _edges,
                hovered: _hovered,
              ),
            ),
          ),
        );
      },
    );
  }

  _GraphNode? _nodeAt(Offset position) {
    for (final node in _nodes.values) {
      if ((node.position - position).distance < 22) return node;
    }
    return null;
  }

  void _hoverAt(Offset position) {
    final node = _nodeAt(position);
    if (node?.id != _hovered) setState(() => _hovered = node?.id);
  }

  void _tapAt(Offset position) {
    final node = _nodeAt(position);
    if (node != null) widget.onOpenNote(node.id);
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({required this.nodes, required this.edges, required this.hovered});

  final List<_GraphNode> nodes;
  final List<(String, String)> edges;
  final String? hovered;

  @override
  void paint(Canvas canvas, Size size) {
    final byId = {for (final n in nodes) n.id: n};

    final edgePaint = Paint()
      ..color = Palette.hairline
      ..strokeWidth = 1;
    for (final (from, to) in edges) {
      final a = byId[from];
      final b = byId[to];
      if (a == null || b == null) continue;
      canvas.drawLine(a.position, b.position, edgePaint);
    }

    for (final node in nodes) {
      final isHovered = node.id == hovered;
      final radius = isHovered ? 9.0 : 6.0;

      canvas.drawCircle(
        node.position,
        radius,
        Paint()..color = isHovered ? Palette.amber : Palette.amber.withValues(alpha: 0.65),
      );
      canvas.drawCircle(
        node.position,
        radius,
        Paint()
          ..color = Palette.void_
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      final painter = TextPainter(
        text: TextSpan(
          text: node.label,
          style: AppType.body.copyWith(
            fontSize: 10.5,
            color: isHovered ? Palette.textPrimary : Palette.textTertiary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 120);
      painter.paint(canvas, node.position + Offset(-painter.width / 2, radius + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) => true;
}
