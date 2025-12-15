import 'package:flutter/material.dart';
import '../../models/entities/workflow_node.dart';
import '../widgets/workflow_node_tile.dart';

class SubworkflowScreen extends StatelessWidget {
  final WorkflowNode node;
  final VoidCallback onBack;

  const SubworkflowScreen({
    super.key,
    required this.node,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: Text('Subworkflow: ' + node.title),
      ),
      body: ListView(
        children: [
          ...node.children.map((child) => WorkflowNodeTile(
                node: child,
                depth: 0,
                parentList: node.children,
                onEdit: (a, b, c) {},
                onCreateSubworkflow: (n) {},
              )),
        ],
      ),
    );
  }
}
