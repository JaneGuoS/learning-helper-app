import 'package:flutter/material.dart';
import '../../models/entities/workflow_node.dart';

class MindmapScreen extends StatefulWidget {
  final List<WorkflowNode> nodes; // The Roots
  final Map<String, WorkflowNode>? subworkflowCache; // Optional: For Problem Solver

  const MindmapScreen({
    super.key, 
    required this.nodes, 
    this.subworkflowCache
  });

  @override
  State<MindmapScreen> createState() => _MindmapScreenState();
}

class _MindmapScreenState extends State<MindmapScreen> {
  // Render Data
  final List<_RenderNode> _renderNodes = [];
  final List<_RenderEdge> _edges = [];

  // Config
  final double nodeWidth = 160.0;
  final double nodeHeight = 70.0;
  final double siblingGap = 40.0;
  final double levelGap = 100.0;

  @override
  void initState() {
    super.initState();
    _calculateLayout();
  }

  @override
  void didUpdateWidget(covariant MindmapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.nodes != oldWidget.nodes || widget.subworkflowCache != oldWidget.subworkflowCache) {
      _calculateLayout();
    }
  }

  // --- 1. DATA PREPARATION ---
  // Helper to get children from EITHER node.children OR subworkflowCache
  List<WorkflowNode> _getEffectiveChildren(WorkflowNode node) {
    // Priority 1: Direct Children (Mind Maps & Subworkflows)
    if (node.children.isNotEmpty) return node.children;
    
    // Priority 2: Cache (Legacy Problem Solver)
    if (widget.subworkflowCache != null && widget.subworkflowCache!.containsKey(node.id)) {
      return widget.subworkflowCache![node.id]!.children;
    }
    
    return [];
  }

  // --- 2. LAYOUT ENGINE ---
  void _calculateLayout() {
    _renderNodes.clear();
    _edges.clear();

    double currentX = 50.0;

    for (var root in widget.nodes) {
      // Calculate how wide this entire family tree is
      double treeWidth = _measureTreeWidth(root);
      
      // Position the tree centered on that width
      _placeNodeRecursive(root, null, currentX, 50.0, treeWidth);
      
      // Move X pointer for the next root
      currentX += treeWidth + siblingGap;
    }
  }

  // Recursive Measurement
  double _measureTreeWidth(WorkflowNode node) {
    final children = _getEffectiveChildren(node);
    if (children.isEmpty) return nodeWidth;

    double childrenTotalWidth = 0;
    for (var child in children) {
      childrenTotalWidth += _measureTreeWidth(child);
    }
    // Add gaps between children
    childrenTotalWidth += (children.length - 1) * siblingGap;

    // The node is at least as wide as itself, or as wide as its children
    return childrenTotalWidth > nodeWidth ? childrenTotalWidth : nodeWidth;
  }

  // Recursive Placement
  void _placeNodeRecursive(
    WorkflowNode node, 
    String? parentId, 
    double startX, 
    double y, 
    double availableWidth
  ) {
    // Center the node horizontally in its available slot
    final nodeX = startX + (availableWidth - nodeWidth) / 2;
    final nodePos = Offset(nodeX, y);

    _renderNodes.add(_RenderNode(node, nodePos));

    if (parentId != null) {
      _edges.add(_RenderEdge(parentId, node.id));
    }

    // Place Children
    final children = _getEffectiveChildren(node);
    if (children.isNotEmpty) {
      double childX = startX;
      double childY = y + nodeHeight + levelGap;

      for (var child in children) {
        double childWidth = _measureTreeWidth(child);
        _placeNodeRecursive(child, node.id, childX, childY, childWidth);
        childX += childWidth + siblingGap;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic canvas size based on content
    double maxX = 0;
    double maxY = 0;
    for (var n in _renderNodes) {
      if (n.pos.dx > maxX) maxX = n.pos.dx;
      if (n.pos.dy > maxY) maxY = n.pos.dy;
    }
    final canvasSize = Size(maxX + 400, maxY + 400);

    return Scaffold(
      appBar: AppBar(title: const Text("Knowledge Graph")),
      backgroundColor: Colors.grey[50],
      body: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(500), // Allow scrolling far
        minScale: 0.1,
        maxScale: 3.0,
        constrained: false, // Infinite Canvas
        child: SizedBox(
          width: canvasSize.width,
          height: canvasSize.height,
          child: Stack(
            children: [
              // 1. EDGES (Lines)
              CustomPaint(
                size: canvasSize,
                painter: _FlowchartPainter(
                  edges: _edges, 
                  nodes: _renderNodes, 
                  nodeWidth: nodeWidth, 
                  nodeHeight: nodeHeight
                ),
              ),
              
              // 2. NODES (Widgets)
              ..._renderNodes.map((rn) => Positioned(
                left: rn.pos.dx,
                top: rn.pos.dy,
                child: _NodeWidget(
                  node: rn.node, 
                  width: nodeWidth, 
                  height: nodeHeight
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// --- HELPERS ---

class _RenderNode {
  final WorkflowNode node;
  final Offset pos;
  _RenderNode(this.node, this.pos);
}

class _RenderEdge {
  final String fromId;
  final String toId;
  _RenderEdge(this.fromId, this.toId);
}

class _NodeWidget extends StatelessWidget {
  final WorkflowNode node;
  final double width;
  final double height;

  const _NodeWidget({required this.node, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
        ]
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              node.title, 
              textAlign: TextAlign.center,
              maxLines: 2, 
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            if (node.description.isNotEmpty)
              Text(
                node.description, 
                textAlign: TextAlign.center,
                maxLines: 1, 
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600], fontSize: 10),
              )
          ],
        ),
      ),
    );
  }
}

class _FlowchartPainter extends CustomPainter {
  final List<_RenderEdge> edges;
  final List<_RenderNode> nodes;
  final double nodeWidth;
  final double nodeHeight;
  final Map<String, Offset> _posMap;

  _FlowchartPainter({required this.edges, required this.nodes, required this.nodeWidth, required this.nodeHeight}) 
      : _posMap = { for (var n in nodes) n.node.id : n.pos };

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var edge in edges) {
      final startPos = _posMap[edge.fromId];
      final endPos = _posMap[edge.toId];

      if (startPos != null && endPos != null) {
        final p1 = Offset(startPos.dx + nodeWidth / 2, startPos.dy + nodeHeight);
        final p2 = Offset(endPos.dx + nodeWidth / 2, endPos.dy);

        final path = Path();
        path.moveTo(p1.dx, p1.dy);
        
        // Curved Line
        path.cubicTo(
          p1.dx, p1.dy + 50, // Control point 1 (down)
          p2.dx, p2.dy - 50, // Control point 2 (up)
          p2.dx, p2.dy
        );

        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}