import 'package:flutter/material.dart';

import '../models/graph_models.dart';
import 'tool_button.dart';

class GraphToolbar extends StatelessWidget {
  const GraphToolbar({
    super.key,
    required this.selectedTool,
    required this.onSelectTool,
    required this.onClear,
    required this.hasNodes,
  });

  final Tool selectedTool;
  final ValueChanged<Tool> onSelectTool;
  final VoidCallback onClear;
  final bool hasNodes;

  static const _tools = [
    _ToolbarItem(
      tool: Tool.add,
      icon: Icons.add,
      label: 'Agregar',
    ),
    _ToolbarItem(
      tool: Tool.select,
      icon: Icons.open_with,
      label: 'Mover',
    ),
    _ToolbarItem(
      tool: Tool.connect,
      icon: Icons.link,
      label: 'Conectar',
    ),
    _ToolbarItem(
      tool: Tool.delete,
      icon: Icons.delete_outline,
      label: 'Eliminar',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const buttonHeight = 72.0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final entry in _tools.asMap().entries)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: entry.key == _tools.length - 1 ? 0 : 12),
                    child: SizedBox(
                      height: buttonHeight,
                      child: ToolButton(
                        icon: entry.value.icon,
                        label: entry.value.label,
                        isSelected: selectedTool == entry.value.tool,
                        onPressed: () => onSelectTool(entry.value.tool),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              SizedBox(
                height: buttonHeight,
                width: 60,
                child: OutlinedButton(
                  onPressed: hasNodes ? () => _confirmClear(context) : null,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.cleaning_services_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _descriptionFor(selectedTool),
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF64748B),
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Limpiar grafo?'),
        content: const Text(
          'Esta acción eliminará todos los nodos y conexiones. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Limpiar todo'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onClear();
    }
  }

  String _descriptionFor(Tool tool) {
    switch (tool) {
      case Tool.add:
        return 'Toca el canvas para agregar un nodo';
      case Tool.select:
        return 'Arrastra nodos para moverlos • Mantén presionado para editar';
      case Tool.connect:
        return 'Toca dos nodos para conectarlos';
      case Tool.delete:
        return 'Toca nodos o conexiones para eliminarlos';
    }
  }
}

class _ToolbarItem {
  const _ToolbarItem({
    required this.tool,
    required this.icon,
    required this.label,
  });

  final Tool tool;
  final IconData icon;
  final String label;
}
