import 'package:flutter/material.dart';

class DraggableFlowchartScreen extends StatefulWidget {
  @override
  _DraggableFlowchartScreenState createState() => _DraggableFlowchartScreenState();
}

class _DraggableFlowchartScreenState extends State<DraggableFlowchartScreen> {
  // Example node data: each node has a label and position
  List<_NodeData> nodes = [
    _NodeData(label: 'Node 1', position: Offset(50, 100)),
    _NodeData(label: 'Node 2', position: Offset(200, 300)),
    _NodeData(label: 'Node 3', position: Offset(120, 400)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Draggable Flowchart')),
      body: Stack(
        children: [
          // Draw nodes
          for (int i = 0; i < nodes.length; i++)
            Positioned(
              left: nodes[i].position.dx,
              top: nodes[i].position.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    nodes[i].position += details.delta;
                  });
                },
                child: _FlowchartNode(label: nodes[i].label),
              ),
            ),
        ],
      ),
    );
  }
}

class _NodeData {
  String label;
  Offset position;
  _NodeData({required this.label, required this.position});
}

class _FlowchartNode extends StatelessWidget {
  final String label;
  const _FlowchartNode({required this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.blue[100],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
