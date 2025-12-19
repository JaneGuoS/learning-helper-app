
import 'package:flutter/material.dart';
import '../../models/entities/workflow_node.dart';



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
    // Assign each subworkflow to a slot: top node's subworkflow is farthest, bottom's is nearest
  // Removed unused rightSideParents and leftSideParents
    const double mainColumnLeft = 60.0;
    const double subflowGap = 40.0;
    // Collect all parentIds and their indices for ordering
    final parentIdToIdx = <String, int>{};
    for (final entry in subworkflowCache.entries) {
      final parentId = entry.key;
      final parentIdx = mainNodes.indexWhere((n) => n.id == parentId);
      parentIdToIdx[parentId] = parentIdx;
    }
    // Sort parentIds for each side by their index (top to bottom)
    final rightSideOrdered = parentIdToIdx.entries.where((e) => e.value % 2 == 0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final leftSideOrdered = parentIdToIdx.entries.where((e) => e.value % 2 == 1).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    // Reverse for slot assignment: top node gets farthest slot
    final rightSideSlots = rightSideOrdered.reversed.toList();
    final leftSideSlots = leftSideOrdered.reversed.toList();
    for (final entry in subworkflowCache.entries) {
      final parentId = entry.key;
      final subRoot = entry.value;
      final subNodes = subRoot.children;
      subNodeLists[parentId] = subNodes;
      final parentIdx = mainNodes.indexWhere((n) => n.id == parentId);
      final parentPos = mainNodePositions[parentId]!;
      final isRight = parentIdx % 2 == 0;
      double xBase;
      if (isRight) {
        int slot = rightSideSlots.indexWhere((e) => e.key == parentId);
        xBase = mainColumnLeft + nodeWidth + horizontalSpacing + slot * (nodeWidth + horizontalSpacing + subflowGap);
      } else {
        int slot = leftSideSlots.indexWhere((e) => e.key == parentId);
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

  void _showEditDialog(WorkflowNode node) {
    final titleController = TextEditingController(text: node.title);
    final descController = TextEditingController(text: node.description);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Node"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: "Title")),
            TextField(controller: descController, decoration: const InputDecoration(labelText: "Description")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                node.title = titleController.text;
                node.description = descController.text;
              });
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainNodes = widget.nodes;
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
    if (minLeft == double.infinity) minLeft = 0;
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
                              node: mainNodes[i],
                              isSubworkflow: false,
                              onEdit: () => _showEditDialog(mainNodes[i]),
                            ),
                          ),
                        ),
                      ),
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
                                node: subNodeLists[entry.key]![i],
                                isSubworkflow: true,
                                onEdit: () => _showEditDialog(subNodeLists[entry.key]![i]),
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
  final WorkflowNode node;
  final bool isSubworkflow;
  final VoidCallback? onEdit;
  const _FlowchartNode({required this.node, this.isSubworkflow = false, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: isSubworkflow ? Colors.orange[100] : Colors.blue[100],
      child: InkWell(
        onTap: onEdit,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              node.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}



