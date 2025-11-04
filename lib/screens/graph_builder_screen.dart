import 'dart:math';

import 'package:flutter/material.dart';

import '../models/graph_models.dart';
import '../widgets/graph_canvas.dart';
import '../widgets/graph_toolbar.dart';
import '../widgets/node_edit_dialog.dart';
import '../widgets/edge_weight_dialog.dart';

class GraphBuilderScreen extends StatefulWidget {
  const GraphBuilderScreen({super.key});

  @override
  State<GraphBuilderScreen> createState() => _GraphBuilderScreenState();
}

class _GraphBuilderScreenState extends State<GraphBuilderScreen> {
  static const Color _defaultNodeColor = Color(0xFF6366F1);

  List<GraphNode> _nodes = [];
  List<GraphEdge> _edges = [];

  Tool _selectedTool = Tool.add;
  String? _selectedNodeId;
  String? _connectingFrom;
  void _showSnackBar(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? const Color(0xFFE11D48) : const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _addNode(Offset position) {
    final newNode = GraphNode(
      id: 'node-${DateTime.now().millisecondsSinceEpoch}',
      x: position.dx,
      y: position.dy,
      label: 'N${_nodes.length + 1}',
      color: _defaultNodeColor,
    );

    final updatedNodes = List<GraphNode>.from(_nodes)..add(newNode);

    setState(() {
      _nodes = updatedNodes;
      _selectedNodeId = newNode.id;
    });

    _showSnackBar('Nodo agregado');
  }

  void _moveNode(String id, Offset position) {
    final index = _nodes.indexWhere((node) => node.id == id);
    if (index == -1) return;

    final updatedNodes = List<GraphNode>.from(_nodes);
    updatedNodes[index] = updatedNodes[index].copyWith(
      x: position.dx,
      y: position.dy,
    );

    setState(() {
      _nodes = updatedNodes;
    });
  }

  void _deleteNode(String id) {
    final updatedNodes =
        _nodes.where((node) => node.id != id).toList(growable: false);
    final updatedEdges = _edges
        .where((edge) => edge.from != id && edge.to != id)
        .toList(growable: false);

    setState(() {
      _nodes = updatedNodes;
      _edges = updatedEdges;
      if (_selectedNodeId == id) {
        _selectedNodeId = null;
      }
      if (_connectingFrom == id) {
        _connectingFrom = null;
      }
    });

    _showSnackBar('Nodo eliminado');
  }

  void _deleteEdge(String id) {
    if (_edges.any((edge) => edge.id == id)) {
      final updatedEdges =
          _edges.where((edge) => edge.id != id).toList(growable: false);
      setState(() {
        _edges = updatedEdges;
      });
      _showSnackBar('Conexión eliminada');
    }
  }

  void _selectNode(String? id) {
    setState(() {
      _selectedNodeId = id;
    });
  }

  void _startConnect(String? id) {
    setState(() {
      _connectingFrom = id;
    });
  }

  void _completeConnect(String from, String to) {
    if (from == to) {
      setState(() {
        _connectingFrom = null;
      });
      _showSnackBar('No puedes conectar un nodo consigo mismo', error: true);
      return;
    }

    final exists = _edges.any(
      (edge) =>
          (edge.from == from && edge.to == to) ||
          (edge.from == to && edge.to == from),
    );

    if (exists) {
      setState(() {
        _connectingFrom = null;
      });
      _showSnackBar('Esta conexión ya existe', error: true);
      return;
    }

    final newEdge = GraphEdge(
      id:
          'edge-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999)}',
      from: from,
      to: to,
      weight: 1.0,
    );

    setState(() {
      _edges = List<GraphEdge>.from(_edges)..add(newEdge);
      _connectingFrom = null;
    });

    _showSnackBar('Conexión creada');
  }

  Future<void> _editNode(GraphNode node) async {
    final updatedNode = await showDialog<GraphNode>(
      context: context,
      barrierDismissible: false,
      builder: (context) => NodeEditDialog(node: node),
    );

    if (updatedNode == null) {
      return;
    }

    final index = _nodes.indexWhere((n) => n.id == node.id);
    if (index == -1) return;

    final updatedNodes = List<GraphNode>.from(_nodes);
    updatedNodes[index] = updatedNode;

    setState(() {
      _nodes = updatedNodes;
    });

    _showSnackBar('Nodo actualizado');
  }

  void _clearGraph() {
    setState(() {
      _nodes = const [];
      _edges = const [];
      _selectedNodeId = null;
      _connectingFrom = null;
    });

    _showSnackBar('Grafo limpiado');
  }

  @override
  Widget build(BuildContext context) {
    final nodeCount = _nodes.length;
    final edgeCount = _edges.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x11000000),
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Graph Builder',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: const Color(0xFF0F172A),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$nodeCount nodos • $edgeCount conexiones',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF64748B),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: GraphCanvas(
                      nodes: _nodes,
                      edges: _edges,
                      selectedTool: _selectedTool,
                      selectedNodeId: _selectedNodeId,
                      connectingFrom: _connectingFrom,
                      onAddNode: _addNode,
                      onMoveNode: _moveNode,
                      onDeleteNode: _deleteNode,
                      onSelectNode: _selectNode,
                      onEditNode: _editNode,
                      onStartConnect: _startConnect,
                      onCompleteConnect: _completeConnect,
                      onDeleteEdge: _deleteEdge,
                      onEditEdge: _editEdge,
                    ),
                  ),
                ),
              ),
              GraphToolbar(
                selectedTool: _selectedTool,
                onSelectTool: (tool) {
                  setState(() {
                    _selectedTool = tool;
                    if (tool != Tool.connect) {
                      _connectingFrom = null;
                    }
                  });
                },
                onClear: _clearGraph,
                hasNodes: _nodes.isNotEmpty,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editEdge(GraphEdge edge) async {
    final updatedWeight = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EdgeWeightDialog(initialValue: edge.weight),
    );

    if (updatedWeight == null) {
      return;
    }

    final index = _edges.indexWhere((e) => e.id == edge.id);
    if (index == -1) return;

    final updatedEdges = List<GraphEdge>.from(_edges);
    updatedEdges[index] = updatedEdges[index].copyWith(weight: updatedWeight);

    setState(() {
      _edges = updatedEdges;
    });

    _showSnackBar('Peso actualizado');
  }

}
