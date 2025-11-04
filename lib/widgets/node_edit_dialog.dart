import 'package:flutter/material.dart';

import '../models/graph_models.dart';

class NodeEditDialog extends StatefulWidget {
  const NodeEditDialog({super.key, required this.node});

  final GraphNode node;

  @override
  State<NodeEditDialog> createState() => _NodeEditDialogState();
}

class _NodeEditDialogState extends State<NodeEditDialog> {
  late final TextEditingController _labelController;
  late Color _selectedColor;

  static const _colorOptions = [
    _NodeColorOption('Indigo', Color(0xFF6366F1)),
    _NodeColorOption('Azul', Color(0xFF3B82F6)),
    _NodeColorOption('Verde', Color(0xFF10B981)),
    _NodeColorOption('Amarillo', Color(0xFFF59E0B)),
    _NodeColorOption('Rojo', Color(0xFFEF4444)),
    _NodeColorOption('Rosa', Color(0xFFEC4899)),
    _NodeColorOption('Morado', Color(0xFFA855F7)),
    _NodeColorOption('Turquesa', Color(0xFF06B6D4)),
  ];

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.node.label);
    _selectedColor = widget.node.color;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _closeWithResult() {
    final label = _labelController.text.trim();
    final updatedNode = widget.node.copyWith(
      label: label.isEmpty ? widget.node.label : label,
      color: _selectedColor,
    );
    Navigator.of(context).pop(updatedNode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Editar nodo'),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              maxLength: 10,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Etiqueta',
                hintText: 'Ej: A, B, Inicio…',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Color',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colorOptions.map((option) {
                final isSelected = option.color.value == _selectedColor.value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = option.color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: option.color,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                            isSelected ? Colors.white : option.color.withOpacity(0.4),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: option.color.withOpacity(
                            isSelected ? 0.35 : 0.2,
                          ),
                          blurRadius: isSelected ? 16 : 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 28, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Vista previa',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: CustomPaint(
                      painter: _NodePreviewPainter(
                        color: _selectedColor,
                        label: _labelController.text.trim().isEmpty
                            ? 'N'
                            : _labelController.text.trim(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _closeWithResult,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _NodeColorOption {
  const _NodeColorOption(this.name, this.color);

  final String name;
  final Color color;
}

class _NodePreviewPainter extends CustomPainter {
  const _NodePreviewPainter({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 32.0;

    final nodePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0);

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final shadowPaint = Paint()
      ..color = const Color(0x22000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(center.translate(0, 4), radius, shadowPaint);
    canvas.drawCircle(center, radius, nodePaint);
    canvas.drawCircle(center, radius, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label.isEmpty ? 'N' : label,
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = center -
        Offset(textPainter.width / 2, textPainter.height / 2);
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _NodePreviewPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.label != label;
  }
}
