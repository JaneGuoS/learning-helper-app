
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
    // Layout: main nodes vertically, subworkflows as vertical columns to the right of their parent
    final mainNodes = nodes;
    final subworkflowCache = this.subworkflowCache ?? {};
    // Calculate positions for main nodes
    final Map<String, Offset> mainNodePositions = {};
    for (int i = 0; i < mainNodes.length; i++) {
      mainNodePositions[mainNodes[i].id] = Offset(60, i * (nodeHeight + verticalSpacing) + 60);
    }

    // Calculate positions for subworkflow nodes
    final Map<String, List<Offset>> subNodePositions = {};
    final Map<String, List<WorkflowNode>> subNodeLists = {};
    for (final entry in subworkflowCache.entries) {
      final parentId = entry.key;
      final subRoot = entry.value;
      final subNodes = subRoot.children;
      subNodeLists[parentId] = subNodes;
      final parentPos = mainNodePositions[parentId]!;
      subNodePositions[parentId] = [
        for (int i = 0; i < subNodes.length; i++)
          Offset(60 + nodeWidth + horizontalSpacing, parentPos.dy + i * (nodeHeight + verticalSpacing))
      ];
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Draggable Flowchart')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate canvas size to fit all nodes
          double maxRight = 0;
          double maxBottom = 0;
          for (final pos in mainNodePositions.values) {
            maxRight = maxRight < pos.dx + nodeWidth ? pos.dx + nodeWidth : maxRight;
            maxBottom = maxBottom < pos.dy + nodeHeight ? pos.dy + nodeHeight : maxBottom;
          }
          for (final entry in subNodePositions.values) {
            for (final pos in entry) {
              maxRight = maxRight < pos.dx + nodeWidth ? pos.dx + nodeWidth : maxRight;
              maxBottom = maxBottom < pos.dy + nodeHeight ? pos.dy + nodeHeight : maxBottom;
            }
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SizedBox(
                width: maxRight + 100,
                height: maxBottom + 100,
                child: Stack(
                  children: [
                    // Draw edges between main nodes (vertical)
                    CustomPaint(
                      size: Size(maxRight + 100, maxBottom + 100),
                      painter: _AlignedEdgePainter(
                        mainNodes: mainNodes,
                        mainNodePositions: mainNodePositions,
                        subNodePositions: subNodePositions,
                        subNodeLists: subNodeLists,
                        nodeWidth: nodeWidth,
                        nodeHeight: nodeHeight,
                        verticalSpacing: verticalSpacing,
                      ),
                    ),
                    // Draw main nodes
                    for (int i = 0; i < mainNodes.length; i++)
                      Positioned(
                        left: mainNodePositions[mainNodes[i].id]!.dx,
                        top: mainNodePositions[mainNodes[i].id]!.dy,
                        child: SizedBox(
                          width: nodeWidth,
                          height: nodeHeight,
                          child: _FlowchartNode(
                            label: mainNodes[i].title,
                            isSubworkflow: false,
                          ),
                        ),
                      ),
                    // Draw subworkflow nodes
                    for (final entry in subNodePositions.entries)
                      for (int i = 0; i < entry.value.length; i++)
                        Positioned(
                          left: entry.value[i].dx,
                          top: entry.value[i].dy,
                          child: SizedBox(
                            width: nodeWidth,
                            height: nodeHeight,
                            child: _FlowchartNode(
                              label: subNodeLists[entry.key]![i].title,
                              isSubworkflow: true,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AlignedEdgePainter extends CustomPainter {
  final List<WorkflowNode> mainNodes;
  final Map<String, Offset> mainNodePositions;
  final Map<String, List<Offset>> subNodePositions;
  final Map<String, List<WorkflowNode>> subNodeLists;
  final double nodeWidth;
  final double nodeHeight;
  final double verticalSpacing;

  _AlignedEdgePainter({
    required this.mainNodes,
    required this.mainNodePositions,
    required this.subNodePositions,
    required this.subNodeLists,
    required this.nodeWidth,
    required this.nodeHeight,
    required this.verticalSpacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey
      ..strokeWidth = 2.0;
    // Connect main nodes vertically
    for (int i = 0; i < mainNodes.length - 1; i++) {
      final from = mainNodePositions[mainNodes[i].id]! + Offset(nodeWidth / 2, nodeHeight);
      final to = mainNodePositions[mainNodes[i + 1].id]! + Offset(nodeWidth / 2, 0);
      canvas.drawLine(from, to, paint);
    }
    // Connect each main node to its subworkflow's first node, and subworkflow nodes vertically
    for (final entry in subNodePositions.entries) {
      final parentId = entry.key;
      final subPositions = entry.value;
      if (subPositions.isNotEmpty) {
        // Edge from main node to first subworkflow node
        final from = mainNodePositions[parentId]! + Offset(nodeWidth, nodeHeight / 2);
        final to = subPositions[0] + Offset(0, nodeHeight / 2);
        canvas.drawLine(from, to, paint);
        // Edges between subworkflow nodes
        for (int i = 0; i < subPositions.length - 1; i++) {
          final fromSub = subPositions[i] + Offset(nodeWidth / 2, nodeHeight);
          final toSub = subPositions[i + 1] + Offset(nodeWidth / 2, 0);
          canvas.drawLine(fromSub, toSub, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
