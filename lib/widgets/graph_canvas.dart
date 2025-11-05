import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/graph_models.dart';

class GraphCanvas extends StatefulWidget {
  const GraphCanvas({
    super.key,
    required this.nodes,
    required this.edges,
    required this.selectedTool,
    required this.selectedNodeId,
    required this.connectingFrom,
    required this.highlightedRoute,
    required this.highlightVersion,
    required this.onAddNode,
    required this.onMoveNode,
    required this.onDeleteNode,
    required this.onSelectNode,
    required this.onEditNode,
    required this.onStartConnect,
    required this.onCompleteConnect,
    required this.onDeleteEdge,
    required this.onEditEdge,
    required this.onUpdateEdgeControl,
  });

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Tool selectedTool;
  final String? selectedNodeId;
  final String? connectingFrom;
  final List<String>? highlightedRoute;
  final int highlightVersion;

  final void Function(Offset position) onAddNode;
  final void Function(String id, Offset position) onMoveNode;
  final void Function(String id) onDeleteNode;
  final void Function(String? id) onSelectNode;
  final void Function(GraphNode node) onEditNode;
  final void Function(String? id) onStartConnect;
  final void Function(String from, String to) onCompleteConnect;
  final void Function(String id) onDeleteEdge;
  final void Function(GraphEdge edge) onEditEdge;
  final void Function(String edgeId, Offset controlPoint) onUpdateEdgeControl;

  @override
  State<GraphCanvas> createState() => _GraphCanvasState();
}

class _GraphCanvasState extends State<GraphCanvas>
    with SingleTickerProviderStateMixin {
  static const double _nodeRadius = 28;
  static const double _selectionRadius = 36;

  Offset? _pointerPosition;
  String? _pendingEdgeTapId;
  String? _draggingEdgeId;
  Offset? _edgeDragStart;
  bool _edgeDragMoved = false;
  late final AnimationController _highlightController;

  GraphNode? _nodeById(String id) {
    for (final node in widget.nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    if (widget.highlightedRoute != null &&
        widget.highlightedRoute!.length >= 2) {
      _highlightController.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant GraphCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connectingFrom == null && _pointerPosition != null) {
      _pointerPosition = null;
    }
    if (oldWidget.selectedTool != widget.selectedTool &&
        widget.selectedTool != Tool.connect &&
        _pointerPosition != null) {
      _pointerPosition = null;
    }
    if (widget.selectedTool != Tool.select && _draggingEdgeId != null) {
      _draggingEdgeId = null;
      _pendingEdgeTapId = null;
      _edgeDragStart = null;
      _edgeDragMoved = false;
    }

    final routeChanged = !listEquals(
      widget.highlightedRoute,
      oldWidget.highlightedRoute,
    );
    final versionChanged = widget.highlightVersion != oldWidget.highlightVersion;
    if (routeChanged || versionChanged) {
      if (widget.highlightedRoute == null ||
          widget.highlightedRoute!.length < 2) {
        _highlightController.reverse();
      } else {
        _highlightController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  void _handlePointer(PointerEvent event, Size size) {
    if (widget.connectingFrom == null) {
      return;
    }

    final local = event.localPosition;
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > size.width ||
        local.dy > size.height) {
      return;
    }

    setState(() {
      _pointerPosition = local;
    });
  }

  Offset _clampToCanvas(Offset offset, Size size) {
    final dx = offset.dx.clamp(_nodeRadius, size.width - _nodeRadius);
    final dy = offset.dy.clamp(_nodeRadius, size.height - _nodeRadius);
    return Offset(dx, dy);
  }

  Offset _clampPointer(Offset offset, Size size) {
    final dx = offset.dx.clamp(0.0, size.width);
    final dy = offset.dy.clamp(0.0, size.height);
    return Offset(dx, dy);
  }

  void _handleBackgroundTapDown(TapDownDetails details, Size size) {
    final position = details.localPosition;
    if (widget.selectedTool != Tool.select) {
      _pendingEdgeTapId = null;
    }

    if (widget.selectedTool == Tool.delete) {
      final edge = _edgeHitTest(position);
      if (edge != null) {
        widget.onDeleteEdge(edge.id);
        return;
      }
    }

    switch (widget.selectedTool) {
      case Tool.add:
        widget.onAddNode(_clampToCanvas(position, size));
        break;
      case Tool.select:
        final edge = _edgeHitTest(position);
        if (edge != null) {
          _pendingEdgeTapId = edge.id;
          widget.onSelectNode(null);
          _draggingEdgeId = null;
          return;
        }
        _pendingEdgeTapId = null;
        widget.onSelectNode(null);
        break;
      case Tool.connect:
        if (widget.connectingFrom != null) {
          widget.onStartConnect(null);
          setState(() {
            _pointerPosition = null;
          });
        }
        break;
      case Tool.delete:
        break;
    }
  }

  void _handlePanStart(DragStartDetails details, Size size) {
    if (widget.selectedTool != Tool.select) {
      return;
    }
    final edge = _edgeHitTest(details.localPosition);
    if (edge != null) {
      _draggingEdgeId = edge.id;
      _edgeDragStart = _clampPointer(details.localPosition, size);
      _edgeDragMoved = false;
      _pendingEdgeTapId = edge.id;
      widget.onSelectNode(null);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    if (_draggingEdgeId == null || widget.selectedTool != Tool.select) {
      return;
    }

    final position = _clampPointer(details.localPosition, size);

    if (!_edgeDragMoved && _edgeDragStart != null) {
      final delta = (position - _edgeDragStart!).distance;
      if (delta > 8) {
        _edgeDragMoved = true;
      }
    }

    if (_edgeDragMoved) {
      _pendingEdgeTapId = null;
      widget.onUpdateEdgeControl(_draggingEdgeId!, position);
    }
  }

  void _handleTapUp() {
    if (_draggingEdgeId != null) {
      return;
    }
    if (_pendingEdgeTapId != null && widget.selectedTool == Tool.select) {
      final edge = widget.edges.firstWhere(
        (e) => e.id == _pendingEdgeTapId,
        orElse: () => const GraphEdge(
          id: '',
          from: '',
          to: '',
          weight: 0,
        ),
      );
      if (edge.id.isNotEmpty) {
        widget.onEditEdge(edge);
      }
    }

    _pendingEdgeTapId = null;
  }

  void _handlePanEnd({required bool allowEdit}) {
    if (_draggingEdgeId != null) {
      final edgeId = _draggingEdgeId!;
      final edge = widget.edges.firstWhere(
        (e) => e.id == edgeId,
        orElse: () => const GraphEdge(
          id: '',
          from: '',
          to: '',
          weight: 0,
        ),
      );

      if (allowEdit &&
          !_edgeDragMoved &&
          widget.selectedTool == Tool.select &&
          edge.id.isNotEmpty) {
        widget.onEditEdge(edge);
      }
    } else if (allowEdit &&
        _pendingEdgeTapId != null &&
        widget.selectedTool == Tool.select) {
      final edge = widget.edges.firstWhere(
        (e) => e.id == _pendingEdgeTapId,
        orElse: () => const GraphEdge(
          id: '',
          from: '',
          to: '',
          weight: 0,
        ),
      );
      if (edge.id.isNotEmpty) {
        widget.onEditEdge(edge);
      }
    }

    _draggingEdgeId = null;
    _edgeDragStart = null;
    _edgeDragMoved = false;
    _pendingEdgeTapId = null;
  }

  GraphEdge? _edgeHitTest(Offset point) {
    const double threshold = 24;

    for (final edge in widget.edges) {
      final fromNode = _nodeById(edge.from);
      final toNode = _nodeById(edge.to);

      if (fromNode == null || toNode == null) {
        continue;
      }

      final points = _edgeSamplePoints(
        Offset(fromNode.x, fromNode.y),
        Offset(toNode.x, toNode.y),
        edge,
      );

      for (var i = 0; i < points.length - 1; i++) {
        final distance = _distanceToSegment(
          point,
          points[i],
          points[i + 1],
        );
        if (distance <= threshold) {
          return edge;
        }
      }
    }

    return null;
  }

  List<Offset> _edgeSamplePoints(
    Offset start,
    Offset end,
    GraphEdge edge,
  ) {
    final control = (edge.controlX != null && edge.controlY != null)
        ? Offset(edge.controlX!, edge.controlY!)
        : null;

    if (control == null) {
      return [start, end];
    }

    const segments = 32;
    final points = <Offset>[];
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      points.add(_quadraticPoint(start, control, end, t));
    }
    return points;
  }

  Offset _quadraticPoint(Offset p0, Offset p1, Offset p2, double t) {
    final oneMinusT = 1 - t;
    return Offset(
      oneMinusT * oneMinusT * p0.dx +
          2 * oneMinusT * t * p1.dx +
          t * t * p2.dx,
      oneMinusT * oneMinusT * p0.dy +
          2 * oneMinusT * t * p1.dy +
          t * t * p2.dy,
    );
  }

  double _distanceToSegment(Offset p, Offset v, Offset w) {
    final double dx = w.dx - v.dx;
    final double dy = w.dy - v.dy;
    final double l2 = dx * dx + dy * dy;
    if (l2 == 0.0) {
      return (p - v).distance;
    }

    final double t = ((p.dx - v.dx) * (w.dx - v.dx) +
            (p.dy - v.dy) * (w.dy - v.dy)) /
        l2;
    if (t < 0.0) {
      return (p - v).distance;
    } else if (t > 1.0) {
      return (p - w).distance;
    }

    final projection = Offset(
      v.dx + t * (w.dx - v.dx),
      v.dy + t * (w.dy - v.dy),
    );
    return (p - projection).distance;
  }

  void _handleNodeTap(GraphNode node) {
    switch (widget.selectedTool) {
      case Tool.delete:
        widget.onDeleteNode(node.id);
        return;
      case Tool.connect:
        if (widget.connectingFrom == null) {
          widget.onStartConnect(node.id);
          setState(() {
            _pointerPosition = Offset(node.x, node.y);
          });
        } else {
          final from = widget.connectingFrom!;
          widget.onCompleteConnect(from, node.id);
        }
        return;
      case Tool.select:
        widget.onSelectNode(node.id);
        widget.onEditNode(node);
        return;
      case Tool.add:
        return;
    }
  }

  void _handleNodePanUpdate(
    String nodeId,
    DragUpdateDetails details,
    Size size,
  ) {
    if (widget.selectedTool != Tool.select) return;

    final current = _nodeById(nodeId);
    if (current == null) return;

    final newOffset = _clampToCanvas(
      Offset(current.x + details.delta.dx, current.y + details.delta.dy),
      size,
    );

    widget.onMoveNode(nodeId, newOffset);
  }

  Widget _buildNode(GraphNode node, Size size) {
    final isSelected = widget.selectedNodeId == node.id;
    final isConnecting = widget.connectingFrom == node.id;
    final isDeleteMode = widget.selectedTool == Tool.delete;

    return Positioned(
      left: node.x - _selectionRadius,
      top: node.y - _selectionRadius,
      width: _selectionRadius * 2,
      height: _selectionRadius * 2,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _handleNodeTap(node),
        onPanStart: widget.selectedTool == Tool.select
            ? (_) => widget.onSelectNode(node.id)
            : widget.selectedTool == Tool.connect
                ? (_) {
                    widget.onStartConnect(node.id);
                    setState(() {
                      _pointerPosition = Offset(node.x, node.y);
                    });
                  }
                : null,
        onPanUpdate: (details) {
          if (widget.selectedTool == Tool.select) {
            _handleNodePanUpdate(node.id, details, size);
          } else if (widget.selectedTool == Tool.connect &&
              widget.connectingFrom != null) {
            final pointer = _clampPointer(
              Offset(
                node.x - _selectionRadius + details.localPosition.dx,
                node.y - _selectionRadius + details.localPosition.dy,
              ),
              size,
            );
            setState(() {
              _pointerPosition = pointer;
            });
          }
        },
        onLongPress: widget.selectedTool == Tool.select
            ? () {
                final current = _nodeById(node.id);
                if (current != null) {
                  widget.onEditNode(current);
                }
              }
            : null,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _selectionRadius * 2,
                height: _selectionRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? node.color.withOpacity(0.18)
                      : Colors.transparent,
                  border: isConnecting
                      ? Border.all(
                          color: const Color(0xFF6366F1),
                          width: 3,
                        )
                      : null,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _nodeRadius * 2,
                height: _nodeRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDeleteMode ? const Color(0xFFFEE2E2) : Colors.white,
                  border: Border.all(
                    color: isDeleteMode ? const Color(0xFFEF4444) : node.color,
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  node.label,
                  style: TextStyle(
                    color: isDeleteMode
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerMove: (event) => _handlePointer(event, size),
          onPointerDown: (event) => _handlePointer(event, size),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _handleBackgroundTapDown(details, size),
            onTapUp: (_) => _handleTapUp(),
            onPanStart: (details) => _handlePanStart(details, size),
            onPanUpdate: (details) => _handlePanUpdate(details, size),
            onPanEnd: (_) => _handlePanEnd(allowEdit: true),
            onPanCancel: () => _handlePanEnd(allowEdit: false),
            child: SizedBox.expand(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GraphPainter(
                        nodes: widget.nodes,
                        edges: widget.edges,
                        selectedTool: widget.selectedTool,
                        connectingFrom: widget.connectingFrom,
                        pointerPosition: _pointerPosition,
                        highlightedRoute: widget.highlightedRoute,
                        highlightAnimation: _highlightController,
                      ),
                    ),
                  ),
                  ...widget.nodes.map((node) => _buildNode(node, size)),
                  if (widget.nodes.isEmpty)
                    const IgnorePointer(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Toca para agregar nodos',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Usa las herramientas abajo',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.nodes,
    required this.edges,
    required this.selectedTool,
    required this.connectingFrom,
    required this.pointerPosition,
    required this.highlightedRoute,
    required this.highlightAnimation,
  }) : super(repaint: highlightAnimation);

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Tool selectedTool;
  final String? connectingFrom;
  final Offset? pointerPosition;
  final List<String>? highlightedRoute;
  final Animation<double>? highlightAnimation;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawEdges(canvas);
    _drawHighlightedRoute(canvas);
    _drawTempEdge(canvas);
  }

  void _drawGrid(Canvas canvas, Size size) {
    const double spacing = 20;
    final Paint dotPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x + 1, y + 1), 1.1, dotPaint);
      }
    }
  }

  void _drawEdges(Canvas canvas) {
    final Map<String, GraphNode> nodeMap = {
      for (final node in nodes) node.id: node,
    };

    final bool deleteMode = selectedTool == Tool.delete;
    final Paint edgePaint = Paint()
      ..color = deleteMode ? const Color(0xFFEF4444) : const Color(0xFF94A3B8)
      ..strokeWidth = deleteMode ? 4 : 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final edge in edges) {
      final fromNode = nodeMap[edge.from];
      final toNode = nodeMap[edge.to];

      if (fromNode == null || toNode == null) continue;

      final start = Offset(fromNode.x, fromNode.y);
      final end = Offset(toNode.x, toNode.y);
      final control = (edge.controlX != null && edge.controlY != null)
          ? Offset(edge.controlX!, edge.controlY!)
          : null;

      Offset midPoint;

      if (control == null) {
        canvas.drawLine(start, end, edgePaint);
        midPoint = Offset(
          (start.dx + end.dx) / 2,
          (start.dy + end.dy) / 2,
        );
      } else {
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(
            control.dx,
            control.dy,
            end.dx,
            end.dy,
          );
        canvas.drawPath(path, edgePaint);
        midPoint = _quadraticPoint(start, control, end, 0.5);
      }

      final label = _formatWeight(edge.weight);
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      final width = textPainter.width + 12;
      final height = textPainter.height + 6;
      final rect = Rect.fromCenter(
        center: midPoint,
        width: width,
        height: height,
      );
      final rrect = RRect.fromRectAndRadius(
        rect,
        const Radius.circular(12),
      );

      final backgroundPaint = Paint()
        ..color = Colors.white.withOpacity(deleteMode ? 0.95 : 0.85);
      final borderPaint = Paint()
        ..color = deleteMode
            ? const Color(0xFFEF4444)
            : const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke;

      canvas.drawRRect(rrect, backgroundPaint);
      canvas.drawRRect(rrect, borderPaint);

      final textOffset = Offset(
        rect.center.dx - textPainter.width / 2,
        rect.center.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  void _drawHighlightedRoute(Canvas canvas) {
    if (highlightedRoute == null || highlightedRoute!.length < 2) {
      return;
    }

    final progress = highlightAnimation?.value ?? 0;
    if (progress <= 0) return;

    final eased = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    final nodeMap = {for (final node in nodes) node.id: node};
    final baseColor = const Color(0xFF22C55E);

    final glowPaint = Paint()
      ..color = baseColor.withOpacity(0.22 * eased)
      ..strokeWidth = ui.lerpDouble(6, 12, eased)!
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final strokePaint = Paint()
      ..color = baseColor.withOpacity(0.85 * eased)
      ..strokeWidth = ui.lerpDouble(3.5, 6, eased)!
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < highlightedRoute!.length - 1; i++) {
      final fromId = highlightedRoute![i];
      final toId = highlightedRoute![i + 1];
      final fromNode = nodeMap[fromId];
      final toNode = nodeMap[toId];
      if (fromNode == null || toNode == null) continue;

      final edge = _findEdge(fromId, toId);
      final start = Offset(fromNode.x, fromNode.y);
      final end = Offset(toNode.x, toNode.y);
      final path = Path()..moveTo(start.dx, start.dy);

      if (edge != null && edge.controlX != null && edge.controlY != null) {
        final control = Offset(edge.controlX!, edge.controlY!);
        path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      } else {
        path.lineTo(end.dx, end.dy);
      }

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, strokePaint);
    }

    final highlightNodes = highlightedRoute!.toSet();
    final nodeGlowPaint = Paint()
      ..color = baseColor.withOpacity(0.18 * eased)
      ..style = PaintingStyle.fill;
    final nodeStrokePaint = Paint()
      ..color = baseColor.withOpacity(0.9 * eased)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final nodeId in highlightNodes) {
      final node = nodeMap[nodeId];
      if (node == null) continue;
      final center = Offset(node.x, node.y);
      canvas.drawCircle(center, ui.lerpDouble(12, 16, eased)!, nodeGlowPaint);
      canvas.drawCircle(center, ui.lerpDouble(7, 9, eased)!, nodeStrokePaint);
    }

    if (highlightedRoute!.isNotEmpty) {
      final startNode = nodeMap[highlightedRoute!.first];
      if (startNode != null) {
        final center = Offset(startNode.x, startNode.y);
        final textPainter = TextPainter(
          text: TextSpan(
            text: 'INICIO',
            style: TextStyle(
              color: baseColor.withOpacity(0.95 * eased),
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.6,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final labelSize = Size(textPainter.width + 14, textPainter.height + 6);
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center.translate(0, -24),
            width: labelSize.width,
            height: labelSize.height,
          ),
          const Radius.circular(12),
        );

        final backgroundPaint = Paint()
          ..color = Colors.white.withOpacity(0.92 * eased);
        canvas.drawRRect(rect, backgroundPaint);
        canvas.drawRRect(
          rect,
          Paint()
            ..color = baseColor.withOpacity(0.5 * eased)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );

        textPainter.paint(
          canvas,
          Offset(
            rect.center.dx - textPainter.width / 2,
            rect.center.dy - textPainter.height / 2,
          ),
        );
        canvas.drawCircle(
          center,
          ui.lerpDouble(4, 6, eased)!,
          Paint()..color = baseColor.withOpacity(0.95 * eased),
        );
      }
    }
  }

  GraphEdge? _findEdge(String from, String to) {
    for (final edge in edges) {
      final matchesDirect = edge.from == from && edge.to == to;
      final matchesInverse = edge.from == to && edge.to == from;
      if (matchesDirect || matchesInverse) {
        return edge;
      }
    }
    return null;
  }

  String _formatWeight(double weight) {
    final fixed = weight.toStringAsFixed(2);
    return fixed.contains('.')
        ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
        : fixed;
  }

  void _drawTempEdge(Canvas canvas) {
    if (connectingFrom == null || pointerPosition == null) return;

    final fromNode = nodes.firstWhere(
      (node) => node.id == connectingFrom,
      orElse: () => const GraphNode(
        id: '',
        x: 0,
        y: 0,
        label: '',
        color: Colors.transparent,
      ),
    );

    if (fromNode.id.isEmpty) {
      return;
    }

    final Paint dashPaint = Paint()
      ..color = const Color(0xFF6366F1)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    _drawDashedLine(
      canvas,
      dashPaint,
      Offset(fromNode.x, fromNode.y),
      pointerPosition!,
      10,
      6,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Paint paint,
    Offset start,
    Offset end,
    double dashWidth,
    double dashSpace,
  ) {
    final double totalDistance = (end - start).distance;
    if (totalDistance == 0) return;

    final int dashCount =
        (totalDistance / (dashWidth + dashSpace)).floor().clamp(1, 200);

    final Offset direction = (end - start) / totalDistance;
    Offset currentPoint = start;

    for (int i = 0; i < dashCount; i++) {
      final Offset nextPoint = currentPoint + direction * dashWidth;
      canvas.drawLine(currentPoint, nextPoint, paint);
      currentPoint = nextPoint + direction * dashSpace;
    }

    if ((currentPoint - end).distance > dashWidth) {
      canvas.drawLine(currentPoint, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.edges != edges ||
        oldDelegate.selectedTool != selectedTool ||
        oldDelegate.connectingFrom != connectingFrom ||
        oldDelegate.pointerPosition != pointerPosition ||
        !listEquals(oldDelegate.highlightedRoute, highlightedRoute);
  }

  Offset _quadraticPoint(Offset p0, Offset p1, Offset p2, double t) {
    final oneMinusT = 1 - t;
    return Offset(
      oneMinusT * oneMinusT * p0.dx +
          2 * oneMinusT * t * p1.dx +
          t * t * p2.dx,
      oneMinusT * oneMinusT * p0.dy +
          2 * oneMinusT * t * p1.dy +
          t * t * p2.dy,
    );
  }
}
