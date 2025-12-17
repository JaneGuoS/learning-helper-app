import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/entities/workflow_node.dart';
import '../../providers/workflow_provider.dart';

class WorkflowNodeTile extends StatelessWidget {
  final WorkflowNode node;
  final int depth;
  final List<WorkflowNode> parentList; // Needed for delete/numbering
  final Function(WorkflowNode? step, WorkflowNode? parent, bool isChild) onEdit;
  final void Function(WorkflowNode node)? onCreateSubworkflow;

  const WorkflowNodeTile({
    super.key,
    required this.node,
    required this.depth,
    required this.parentList,
    required this.onEdit,
    this.onCreateSubworkflow,
  });

  @override
  Widget build(BuildContext context) {
  final provider = Provider.of<WorkflowProvider>(context, listen: false);

    return Padding(
      padding: EdgeInsets.only(left: 10.0 * depth),
      child: Card(
        key: ValueKey(node.id),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: ExpansionTile(
          key: PageStorageKey(node.id),
          initiallyExpanded: node.isExpanded,
          onExpansionChanged: (val) => node.isExpanded = val,
          shape: const Border(),
          leading: CircleAvatar(
            radius: 12,
            backgroundColor: Colors.deepPurple.shade100,
            child: Text(depth == 0 ? "${parentList.indexOf(node) + 1}" : "•",
                   style: const TextStyle(fontSize: 12, color: Colors.deepPurple)),
          ),
          title: Text(node.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: node.description.isNotEmpty ? Text(node.description) : null,
          // Move all action buttons below the details
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (node.isLoading)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                    tooltip: 'Edit',
                    onPressed: () => onEdit(node, null, false),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                    tooltip: 'Add Child',
                    onPressed: () => onEdit(null, node, true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.account_tree_outlined, color: Colors.orange),
                    tooltip: 'Create Subworkflow',
                    onPressed: onCreateSubworkflow != null ? () => onCreateSubworkflow!(node) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Delete',
                    onPressed: () => provider.deleteStep(parentList, node),
                  ),
                ],
              ),
            ),
            // RECURSION HAPPENS HERE
            ...node.children.map((child) => WorkflowNodeTile(
              node: child,
              depth: depth + 1,
              parentList: node.children,
              onEdit: onEdit,
              onCreateSubworkflow: onCreateSubworkflow,
            )).toList(),
          ],
        ),
      ),
    );
  }
}