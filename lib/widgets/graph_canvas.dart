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
    required this.onAddNode,
    required this.onMoveNode,
    required this.onDeleteNode,
    required this.onSelectNode,
    required this.onEditNode,
    required this.onStartConnect,
    required this.onCompleteConnect,
    required this.onDeleteEdge,
    required this.onEditEdge,
  });

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Tool selectedTool;
  final String? selectedNodeId;
  final String? connectingFrom;

  final void Function(Offset position) onAddNode;
  final void Function(String id, Offset position) onMoveNode;
  final void Function(String id) onDeleteNode;
  final void Function(String? id) onSelectNode;
  final void Function(GraphNode node) onEditNode;
  final void Function(String? id) onStartConnect;
  final void Function(String from, String to) onCompleteConnect;
  final void Function(String id) onDeleteEdge;
  final void Function(GraphEdge edge) onEditEdge;

  @override
  State<GraphCanvas> createState() => _GraphCanvasState();
}

class _GraphCanvasState extends State<GraphCanvas> {
  static const double _nodeRadius = 28;
  static const double _selectionRadius = 36;

  Offset? _pointerPosition;

  GraphNode? _nodeById(String id) {
    for (final node in widget.nodes) {
      if (node.id == id) return node;
    }
    return null;
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
          widget.onSelectNode(null);
          widget.onEditEdge(edge);
          return;
        }
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

  GraphEdge? _edgeHitTest(Offset point) {
    const double threshold = 24;

    for (final edge in widget.edges) {
      final fromNode = _nodeById(edge.from);
      final toNode = _nodeById(edge.to);

      if (fromNode == null || toNode == null) {
        continue;
      }

      final distance = _distanceToSegment(
        point,
        Offset(fromNode.x, fromNode.y),
        Offset(toNode.x, toNode.y),
      );

      if (distance <= threshold) {
        return edge;
      }
    }

    return null;
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
  });

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Tool selectedTool;
  final String? connectingFrom;
  final Offset? pointerPosition;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawEdges(canvas);
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

      canvas.drawLine(start, end, edgePaint);

      final midPoint = Offset(
        (start.dx + end.dx) / 2,
        (start.dy + end.dy) / 2,
      );

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
        oldDelegate.pointerPosition != pointerPosition;
  }
}
