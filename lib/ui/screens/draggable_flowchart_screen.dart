import 'package:flutter/material.dart';
import '../../models/entities/workflow_node.dart';

class DraggableFlowchartScreen extends StatelessWidget {
  final List<WorkflowNode> nodes;
  const DraggableFlowchartScreen({Key? key, required this.nodes}) : super(key: key);

  static const double nodeWidth = 180;
  static const double nodeHeight = 60;
  static const double verticalSpacing = 40;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Draggable Flowchart')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Draw lines between consecutive nodes
              CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _VerticalEdgePainter(nodes.length, nodeWidth, nodeHeight, verticalSpacing),
              ),
              // Draw nodes vertically
              for (int i = 0; i < nodes.length; i++)
                Positioned(
                  left: (constraints.maxWidth - nodeWidth) / 2,
                  top: i * (nodeHeight + verticalSpacing) + verticalSpacing,
                  child: SizedBox(
                    width: nodeWidth,
                    height: nodeHeight,
                    child: _FlowchartNode(label: nodes[i].title),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _VerticalEdgePainter extends CustomPainter {
  final int nodeCount;
  final double nodeWidth;
  final double nodeHeight;
  final double verticalSpacing;
  _VerticalEdgePainter(this.nodeCount, this.nodeWidth, this.nodeHeight, this.verticalSpacing);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey
      ..strokeWidth = 2.0;
    for (int i = 0; i < nodeCount - 1; i++) {
      final from = Offset(size.width / 2, i * (nodeHeight + verticalSpacing) + verticalSpacing + nodeHeight);
      final to = Offset(size.width / 2, (i + 1) * (nodeHeight + verticalSpacing) + verticalSpacing);
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FlowchartNode extends StatelessWidget {
  final String label;
  const _FlowchartNode({required this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.blue[100],
      child: Center(
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}