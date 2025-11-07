import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/graph_models.dart';
import '../models/genetic_tsp_solver.dart';
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
  List<GeneticTspGeneration> _geneticTimeline = const [];
  List<String>? _highlightedRoute;
  int _highlightVersion = 0;
  int _currentGenerationIndex = 0;
  bool _isSolving = false;
  bool _isPlaying = false;
  bool _isViewingSolution = false;
  Timer? _playbackTimer;

  static const Duration _animationStep = Duration(milliseconds: 1200);
  void _showSnackBar(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error
              ? const Color(0xFFE11D48)
              : const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _clearSolutionInternal() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _geneticTimeline = const [];
    _highlightedRoute = null;
    _currentGenerationIndex = 0;
    _isPlaying = false;
    _isViewingSolution = false;
    _highlightVersion++;
  }

  void _returnToEditingMode() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    setState(() {
      _clearSolutionInternal();
      _isSolving = false;
    });
  }

  String _formatDistance(double value) {
    final formatted = value.toStringAsFixed(2);
    return formatted.replaceFirst(RegExp(r'\.?0+$'), '');
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
      _clearSolutionInternal();
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
    final updatedNodes = _nodes
        .where((node) => node.id != id)
        .toList(growable: false);
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
      _clearSolutionInternal();
    });

    _showSnackBar('Nodo eliminado');
  }

  void _deleteEdge(String id) {
    if (_edges.any((edge) => edge.id == id)) {
      final updatedEdges = _edges
          .where((edge) => edge.id != id)
          .toList(growable: false);
      setState(() {
        _edges = updatedEdges;
        _clearSolutionInternal();
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
      id: 'edge-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999)}',
      from: from,
      to: to,
      weight: 1.0,
    );

    setState(() {
      _edges = List<GraphEdge>.from(_edges)..add(newEdge);
      _connectingFrom = null;
      _clearSolutionInternal();
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
      _clearSolutionInternal();
    });

    _showSnackBar('Grafo limpiado');
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nodeCount = _nodes.length;
    final edgeCount = _edges.length;
    final bool hasSolution = _geneticTimeline.isNotEmpty;
    final GeneticTspGeneration? currentGeneration = hasSolution
        ? _geneticTimeline[_currentGenerationIndex]
        : null;

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
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
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
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grafos',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$nodeCount nodos • $edgeCount conexiones',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFF64748B)),
                          ),
                          if (currentGeneration != null)
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Text(
                                'Mejor actual: ${_formatDistance(currentGeneration.bestDistance)}',
                                key: ValueKey<int>(_highlightVersion),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: const Color(0xFF22C55E),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 44,
                      child: FilledButton.icon(
                        onPressed: _isSolving ? null : _runGeneticSolver,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _isSolving
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                ),
                              )
                            : const Icon(Icons.alt_route_rounded),
                        label: Text(
                          _isSolving
                              ? 'Resolviendo...'
                              : hasSolution
                              ? 'Recalcular ruta'
                              : 'Resolver TSP',
                        ),
                      ),
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
                      highlightedRoute: _highlightedRoute,
                      highlightVersion: _highlightVersion,
                      onAddNode: _addNode,
                      onMoveNode: _moveNode,
                      onDeleteNode: _deleteNode,
                      onSelectNode: _selectNode,
                      onEditNode: _editNode,
                      onStartConnect: _startConnect,
                      onCompleteConnect: _completeConnect,
                      onDeleteEdge: _deleteEdge,
                      onEditEdge: _editEdge,
                      onUpdateEdgeControl: _updateEdgeControl,
                    ),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _isViewingSolution
                    ? _buildSolutionPanel()
                    : GraphToolbar(
                        key: const ValueKey('graph_toolbar'),
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
      _clearSolutionInternal();
    });

    _showSnackBar('Peso actualizado');
  }

  void _updateEdgeControl(String edgeId, Offset control) {
    final index = _edges.indexWhere((edge) => edge.id == edgeId);
    if (index == -1) return;

    final updatedEdges = List<GraphEdge>.from(_edges);
    updatedEdges[index] = updatedEdges[index].copyWith(
      controlX: control.dx,
      controlY: control.dy,
    );

    setState(() {
      _edges = updatedEdges;
    });
  }

  Future<void> _runGeneticSolver() async {
    final validationError = _validateForTsp();
    if (validationError != null) {
      _showSnackBar(validationError, error: true);
      return;
    }

    final adjacency = _buildAdjacencyMap();

    setState(() {
      _clearSolutionInternal();
      _isSolving = true;
      _isViewingSolution = true;
    });

    try {
      final solver = GeneticTspSolver(
        adjacency: adjacency,
        populationSize: 75,
        generations: 120,
        mutationRate: 0.18,
        elitismCount: 2,
        tournamentSize: 5,
      );

      final generations = await solver.solve();
      if (!mounted) {
        return;
      }

      if (generations.isEmpty) {
        setState(() {
          _isSolving = false;
          _isViewingSolution = false;
        });
        _showSnackBar(
          'No se pudo generar una solución. Ajusta el grafo e inténtalo de nuevo.',
          error: true,
        );
        return;
      }

      setState(() {
        _geneticTimeline = generations;
        _currentGenerationIndex = 0;
        _highlightedRoute = List<String>.from(generations.first.route);
        _highlightVersion++;
        _isSolving = false;
        _isViewingSolution = true;
      });

      if (_geneticTimeline.length > 1) {
        _startAutoPlay();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSolving = false;
        _isViewingSolution = false;
      });
      final String errorMessage;
      if (error is StateError) {
        final message = error.message;
        errorMessage = message.isNotEmpty
            ? message
            : 'No se pudo generar una solución válida con las conexiones actuales.';
      } else {
        errorMessage = 'Ocurrió un problema al ejecutar la solución: $error';
      }
      _showSnackBar(errorMessage, error: true);
    }
  }

  void _startAutoPlay() {
    if (_geneticTimeline.length <= 1) {
      setState(() {
        _isPlaying = false;
      });
      return;
    }
    if (_currentGenerationIndex >= _geneticTimeline.length - 1) {
      setState(() {
        _isPlaying = false;
      });
      _showSnackBar(
        'Ya estás en la última generación. Distancia: ${_formatDistance(_geneticTimeline.last.bestDistance)}',
      );
      return;
    }

    _playbackTimer?.cancel();
    setState(() {
      _isPlaying = true;
    });

    _playbackTimer = Timer.periodic(_animationStep, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_currentGenerationIndex >= _geneticTimeline.length - 1) {
        timer.cancel();
        setState(() {
          _isPlaying = false;
        });
        _showSnackBar(
          'Ruta final encontrada: ${_formatDistance(_geneticTimeline.last.bestDistance)}',
        );
        return;
      }

      _goToStep(_currentGenerationIndex + 1, keepPlaying: true);

      if (_currentGenerationIndex >= _geneticTimeline.length - 1) {
        timer.cancel();
        setState(() {
          _isPlaying = false;
        });
        _showSnackBar(
          'Ruta final encontrada: ${_formatDistance(_geneticTimeline.last.bestDistance)}',
        );
      }
    });
  }

  void _pauseAutoPlay() {
    if (_playbackTimer == null) {
      setState(() {
        _isPlaying = false;
      });
      return;
    }
    _playbackTimer?.cancel();
    _playbackTimer = null;
    setState(() {
      _isPlaying = false;
    });
  }

  void _goToStep(int index, {bool keepPlaying = false}) {
    if (index < 0 || index >= _geneticTimeline.length) {
      return;
    }
    if (!keepPlaying) {
      _playbackTimer?.cancel();
      _playbackTimer = null;
    }
    setState(() {
      if (!keepPlaying) {
        _isPlaying = false;
      }
      _currentGenerationIndex = index;
      _highlightedRoute = List<String>.from(
        _geneticTimeline[_currentGenerationIndex].route,
      );
      _highlightVersion++;
    });
  }

  String? _validateForTsp() {
    if (_nodes.length < 3) {
      return 'Agrega al menos 3 nodos para resolver el viajero.';
    }
    if (_edges.isEmpty) {
      return 'Conecta los nodos para construir un ciclo.';
    }

    final adjacency = <String, Set<String>>{
      for (final node in _nodes) node.id: <String>{},
    };

    for (final edge in _edges) {
      adjacency[edge.from]!.add(edge.to);
      adjacency[edge.to]!.add(edge.from);
    }

    GraphNode? insufficientNode;
    for (final node in _nodes) {
      final degree = adjacency[node.id]?.length ?? 0;
      if (degree < 2) {
        insufficientNode = node;
        break;
      }
    }

    if (insufficientNode != null) {
      return 'El nodo ${insufficientNode.label} necesita al menos dos conexiones para formar un ciclo.';
    }

    final visited = <String>{};
    final stack = <String>[_nodes.first.id];

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (!visited.add(current)) {
        continue;
      }
      for (final neighbor in adjacency[current] ?? const <String>{}) {
        if (!visited.contains(neighbor)) {
          stack.add(neighbor);
        }
      }
    }

    if (visited.length != _nodes.length) {
      final unreachable = _nodes.firstWhere(
        (node) => !visited.contains(node.id),
      );
      return 'El grafo debe ser conexo. No se puede llegar al nodo ${unreachable.label} desde los demás.';
    }

    return null;
  }

  Map<String, Map<String, double>> _buildAdjacencyMap() {
    final adjacency = <String, Map<String, double>>{
      for (final node in _nodes) node.id: <String, double>{},
    };

    for (final edge in _edges) {
      adjacency[edge.from]![edge.to] = edge.weight;
      adjacency[edge.to]![edge.from] = edge.weight;
    }

    return adjacency;
  }

  Widget _buildSolutionPanel() {
    final theme = Theme.of(context);
    final hasSolution = _geneticTimeline.isNotEmpty;
    final GeneticTspGeneration? current = hasSolution
        ? _geneticTimeline[_currentGenerationIndex]
        : null;
    final int totalGenerations = hasSolution
        ? _geneticTimeline.last.generation
        : 0;
    final double? progressValue = hasSolution
        ? (totalGenerations == 0
              ? 1.0
              : (current!.generation / totalGenerations).clamp(0.0, 1.0))
        : null;

    final hasPrevious = hasSolution && _currentGenerationIndex > 0;
    final hasNext =
        hasSolution && _currentGenerationIndex < _geneticTimeline.length - 1;

    final String subtitle = hasSolution
        ? 'Generación ${current!.generation} de $totalGenerations'
        : 'Buscando la mejor ruta...';

    return Container(
      key: const ValueKey('solution_panel'),
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solución genética',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _returnToEditingMode,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Modo edición'),
                  ),
                  if (hasSolution) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Generación anterior',
                          onPressed: hasPrevious
                              ? () => _goToStep(_currentGenerationIndex - 1)
                              : null,
                          icon: const Icon(Icons.skip_previous_rounded),
                          color: const Color(0xFF0F172A),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: _isPlaying
                              ? 'Pausar animación'
                              : 'Reproducir animación',
                          onPressed: _isPlaying
                              ? _pauseAutoPlay
                              : _startAutoPlay,
                          icon: Icon(
                            _isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                          ),
                          iconSize: 34,
                          color: const Color(0xFF22C55E),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Siguiente generación',
                          onPressed: hasNext
                              ? () => _goToStep(_currentGenerationIndex + 1)
                              : null,
                          icon: const Icon(Icons.skip_next_rounded),
                          color: const Color(0xFF0F172A),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF22C55E),
              ),
            ),
          ),
          if (!hasSolution) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF22C55E),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isSolving
                        ? 'Evolucionando posibles rutas...'
                        : 'Listo para mostrar la solución más reciente.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetricChip(
                    label: 'Mejor distancia',
                    value: _formatDistance(current!.bestDistance),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricChip(
                    label: 'Promedio',
                    value: _formatDistance(current.averageDistance),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: const Color(0xFF64748B),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
