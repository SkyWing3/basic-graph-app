import 'package:flutter/material.dart';

enum Tool { add, select, connect, delete }

class GraphNode {
  const GraphNode({
    required this.id,
    required this.x,
    required this.y,
    required this.label,
    required this.color,
  });

  final String id;
  final double x;
  final double y;
  final String label;
  final Color color;

  GraphNode copyWith({
    double? x,
    double? y,
    String? label,
    Color? color,
  }) {
    return GraphNode(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      label: label ?? this.label,
      color: color ?? this.color,
    );
  }
}

class GraphEdge {
  const GraphEdge({
    required this.id,
    required this.from,
    required this.to,
    required this.weight,
  });

  final String id;
  final String from;
  final String to;
  final double weight;

  GraphEdge copyWith({
    String? from,
    String? to,
    double? weight,
  }) {
    return GraphEdge(
      id: id,
      from: from ?? this.from,
      to: to ?? this.to,
      weight: weight ?? this.weight,
    );
  }
}
