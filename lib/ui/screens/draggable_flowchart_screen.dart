
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

class DraggableFlowchartScreen extends StatefulWidget {
  final List<WorkflowNode> nodes;
  final Map<String, WorkflowNode>? subworkflowCache;

  const DraggableFlowchartScreen({Key? key, required this.nodes, this.subworkflowCache}) : super(key: key);

  @override
  State<DraggableFlowchartScreen> createState() => _DraggableFlowchartScreenState();
}

class _DraggableFlowchartScreenState extends State<DraggableFlowchartScreen> {
  static const double nodeWidth = 180;
  static const double nodeHeight = 60;
  static const double verticalSpacing = 40;
  static const double horizontalSpacing = 60;

  late Map<String, Offset> mainNodePositions;
  late Map<String, List<Offset>> subNodePositions;
  late Map<String, List<WorkflowNode>> subNodeLists;

  @override
  void initState() {
    super.initState();
    _initPositions();
  }

  void _initPositions() {
    final mainNodes = widget.nodes;
    final subworkflowCache = widget.subworkflowCache ?? {};
    mainNodePositions = {};
    for (int i = 0; i < mainNodes.length; i++) {
      mainNodePositions[mainNodes[i].id] = Offset(60, i * (nodeHeight + verticalSpacing) + 60);
    }
    subNodePositions = {};
    subNodeLists = {};
    // Assign each subworkflow to the next available slot on its side (no overlap)
    List<String> rightSideParents = [];
    List<String> leftSideParents = [];
    const double mainColumnLeft = 60.0;
    const double subflowGap = 40.0;
    for (final entry in subworkflowCache.entries) {
      final parentId = entry.key;
      final subRoot = entry.value;
      final subNodes = subRoot.children;
      subNodeLists[parentId] = subNodes;
      // Find the index of the parent node in mainNodes
      final parentIdx = mainNodes.indexWhere((n) => n.id == parentId);
      final parentPos = mainNodePositions[parentId]!;
      final isRight = parentIdx % 2 == 0; // Even index: right, Odd: left
      double xBase;
      if (isRight) {
        rightSideParents.add(parentId);
        int slot = rightSideParents.length - 1;
        xBase = mainColumnLeft + nodeWidth + horizontalSpacing + slot * (nodeWidth + horizontalSpacing + subflowGap);
      } else {
        leftSideParents.add(parentId);
        int slot = leftSideParents.length - 1;
        xBase = mainColumnLeft - (slot + 1) * (nodeWidth + horizontalSpacing + subflowGap);
      }
      subNodePositions[parentId] = [
        for (int i = 0; i < subNodes.length; i++)
          Offset(xBase, parentPos.dy + i * (nodeHeight + verticalSpacing))
      ];
    }
  }

  void _onDragMain(String id, Offset delta) {
    setState(() {
      mainNodePositions[id] = mainNodePositions[id]! + delta;
      // Move subworkflow nodes if any
      if (subNodePositions.containsKey(id)) {
        final subOffsets = subNodePositions[id]!;
        subNodePositions[id] = [for (final o in subOffsets) o + Offset(delta.dx, delta.dy)];
      }
    });
  }

  void _onDragSub(String parentId, int idx, Offset delta) {
    setState(() {
      final subOffsets = subNodePositions[parentId]!;
      subNodePositions[parentId] = [
        for (int i = 0; i < subOffsets.length; i++)
          i == idx ? subOffsets[i] + delta : subOffsets[i]
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final mainNodes = widget.nodes;
    final subworkflowCache = widget.subworkflowCache ?? {};
    // Calculate canvas size to fit all nodes
    double maxRight = 0;
    double maxBottom = 0;
    double minLeft = double.infinity;
    for (final pos in mainNodePositions.values) {
      maxRight = maxRight < pos.dx + nodeWidth ? pos.dx + nodeWidth : maxRight;
      maxBottom = maxBottom < pos.dy + nodeHeight ? pos.dy + nodeHeight : maxBottom;
      minLeft = minLeft > pos.dx ? pos.dx : minLeft;
    }
    for (final entry in subNodePositions.values) {
      for (final pos in entry) {
        maxRight = maxRight < pos.dx + nodeWidth ? pos.dx + nodeWidth : maxRight;
        maxBottom = maxBottom < pos.dy + nodeHeight ? pos.dy + nodeHeight : maxBottom;
        minLeft = minLeft > pos.dx ? pos.dx : minLeft;
      }
    }
    // Ensure minLeft is not infinity
    if (minLeft == double.infinity) minLeft = 0;
    // Add padding to the left if needed
    final canvasLeftPadding = minLeft < 40 ? 40 - minLeft : 0;
    maxRight += canvasLeftPadding;
    return Scaffold(
      appBar: AppBar(title: const Text('Draggable Flowchart')),
      body: LayoutBuilder(
        builder: (context, constraints) {
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
                        mainNodePositions: mainNodePositions.map((k, v) => MapEntry(k, v + Offset(canvasLeftPadding.toDouble(), 0))),
                        subNodePositions: subNodePositions.map((k, v) => MapEntry(k, v.map((o) => o + Offset(canvasLeftPadding.toDouble(), 0)).toList())),
                        subNodeLists: subNodeLists,
                        nodeWidth: nodeWidth,
                        nodeHeight: nodeHeight,
                        verticalSpacing: verticalSpacing,
                      ),
                    ),
                    // Draw main nodes (draggable)
                    for (int i = 0; i < mainNodes.length; i++)
                      Positioned(
                        left: mainNodePositions[mainNodes[i].id]!.dx + canvasLeftPadding,
                        top: mainNodePositions[mainNodes[i].id]!.dy,
                        child: GestureDetector(
                          onPanUpdate: (details) => _onDragMain(mainNodes[i].id, details.delta),
                          child: SizedBox(
                            width: nodeWidth,
                            height: nodeHeight,
                            child: _FlowchartNode(
                              label: mainNodes[i].title,
                              isSubworkflow: false,
                            ),
                          ),
                        ),
                      ),
                    // Draw subworkflow nodes (draggable)
                    for (final entry in subNodePositions.entries)
                      for (int i = 0; i < entry.value.length; i++)
                        Positioned(
                          left: entry.value[i].dx + canvasLeftPadding,
                          top: entry.value[i].dy,
                          child: GestureDetector(
                            onPanUpdate: (details) => _onDragSub(entry.key, i, details.delta),
                            child: SizedBox(
                              width: nodeWidth,
                              height: nodeHeight,
                              child: _FlowchartNode(
                                label: subNodeLists[entry.key]![i].title,
                                isSubworkflow: true,
                              ),
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
        // Find the index of the parent node in mainNodes
        final parentIdx = mainNodes.indexWhere((n) => n.id == parentId);
        final isRight = parentIdx % 2 == 0;
        // Edge from main node to first subworkflow node
        final from = mainNodePositions[parentId]! + Offset(
          isRight ? nodeWidth : 0,
          nodeHeight / 2,
        );
        final to = subPositions[0] + Offset(isRight ? 0 : nodeWidth, nodeHeight / 2);
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
