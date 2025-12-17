
import 'package:flutter/material.dart';
import '../../models/entities/workflow_node.dart';

// --- Graph node and flattening logic ---
class _GraphNode {
  final WorkflowNode node;
  final WorkflowNode? parent;
  final int depth;
  final bool isSubworkflow;
  _GraphNode(this.node, this.parent, this.depth, {this.isSubworkflow = false});
}

// Flattens the workflow tree and inserts subworkflow nodes from cache for visualization
List<_GraphNode> _flattenWithCache(List<WorkflowNode> roots, Map<String, WorkflowNode> cache) {
  final List<_GraphNode> result = [];
  void visit(WorkflowNode node, WorkflowNode? parent, int depth, {bool isSubworkflow = false}) {
    result.add(_GraphNode(node, parent, depth, isSubworkflow: isSubworkflow));
    // If a subworkflow is cached for this node, use it for visualization
    if (cache.containsKey(node.id)) {
      final subNode = cache[node.id]!;
      for (int i = 0; i < subNode.children.length; i++) {
        visit(subNode.children[i], node, depth + 1, isSubworkflow: true);
      }
    } else if (node.children.isNotEmpty) {
      for (int i = 0; i < node.children.length; i++) {
        visit(node.children[i], node, depth + 1, isSubworkflow: true);
      }
    }
  }
  for (final root in roots) {
    visit(root, null, 0);
  }
  return result;
}

class DraggableFlowchartScreen extends StatelessWidget {
  final List<WorkflowNode> nodes;
  final Map<String, WorkflowNode>? subworkflowCache;

  const DraggableFlowchartScreen({Key? key, required this.nodes, this.subworkflowCache}) : super(key: key);

  static const double nodeWidth = 180;
  static const double nodeHeight = 60;
  static const double verticalSpacing = 40;
  static const double horizontalSpacing = 60;

  @override
  Widget build(BuildContext context) {
    final flatNodes = _flattenWithCache(nodes, subworkflowCache ?? {});
    return Scaffold(
      appBar: AppBar(title: const Text('Draggable Flowchart')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Draw edges between parent and child nodes
              CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _TreeEdgePainter(flatNodes, nodeWidth, nodeHeight, verticalSpacing),
              ),
              // Draw nodes vertically, indented by depth
              for (int i = 0; i < flatNodes.length; i++)
                Positioned(
                  left: (constraints.maxWidth - nodeWidth) / 2 + flatNodes[i].depth * horizontalSpacing,
                  top: i * (nodeHeight + verticalSpacing) + verticalSpacing,
                  child: SizedBox(
                    width: nodeWidth,
                    height: nodeHeight,
                    child: _FlowchartNode(
                      label: flatNodes[i].node.title,
                      isSubworkflow: flatNodes[i].isSubworkflow,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FlowchartNode extends StatelessWidget {
  final String label;
  final bool isSubworkflow;
  const _FlowchartNode({required this.label, this.isSubworkflow = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: isSubworkflow ? Colors.orange[100] : Colors.blue[100],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}



class _TreeEdgePainter extends CustomPainter {
  final List<_GraphNode> flatNodes;
  final double nodeWidth;
  final double nodeHeight;
  final double verticalSpacing;
  _TreeEdgePainter(this.flatNodes, this.nodeWidth, this.nodeHeight, this.verticalSpacing);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey
      ..strokeWidth = 2.0;
    // Draw lines from parent to child
    for (int i = 0; i < flatNodes.length; i++) {
      final node = flatNodes[i];
      if (node.parent != null) {
        // Find parent index
        final parentIndex = flatNodes.indexWhere((n) => n.node == node.parent);
        if (parentIndex != -1) {
          final from = Offset(
            size.width / 2 + flatNodes[parentIndex].depth * 60 + nodeWidth / 2,
            parentIndex * (nodeHeight + verticalSpacing) + verticalSpacing + nodeHeight,
          );
          final to = Offset(
            size.width / 2 + node.depth * 60 + nodeWidth / 2,
            i * (nodeHeight + verticalSpacing) + verticalSpacing,
          );
          canvas.drawLine(from, to, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
