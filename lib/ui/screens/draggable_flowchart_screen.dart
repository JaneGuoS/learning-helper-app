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

// ... (Previous code remains the same)

class _FlowchartNodeWidget extends StatelessWidget {
  final String title;
  final String desc;

  const _FlowchartNodeWidget({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      // REMOVED fixed height logic from parent, handled here
      constraints: const BoxConstraints(minHeight: 60), // Minimum height
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.deepPurple.shade200, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Center( // Centers text vertically
        child: Column(
          mainAxisSize: MainAxisSize.min, // shrink to fit text
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title, 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (desc.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  desc, 
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                  maxLines: 2, // Allow 2 lines for description
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}