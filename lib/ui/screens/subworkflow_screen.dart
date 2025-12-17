import 'package:flutter/material.dart';
import '../../models/entities/workflow_node.dart';
import '../widgets/workflow_node_tile.dart';

class SubworkflowScreen extends StatefulWidget {
  final WorkflowNode node;
  final VoidCallback onBack;

  const SubworkflowScreen({
    super.key,
    required this.node,
    required this.onBack,
  });

  @override
  State<SubworkflowScreen> createState() => _SubworkflowScreenState();
}

class _SubworkflowScreenState extends State<SubworkflowScreen> {
  @override
  void initState() {
    super.initState();
    // If the node has no children, add a placeholder sub-step
    if (widget.node.children.isEmpty) {
      widget.node.children.add(WorkflowNode(title: 'Sub-step 1', description: ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Text('Subworkflow: ' + widget.node.title),
      ),
      body: ListView(
        children: [
          ...widget.node.children.map((child) => WorkflowNodeTile(
                node: child,
                depth: 0,
                parentList: widget.node.children,
                onEdit: (a, b, c) {},
                onCreateSubworkflow: (n) {},
              )),
        ],
      ),
    );
  }
}
