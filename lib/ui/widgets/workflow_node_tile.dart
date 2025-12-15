import 'package:flutter/material.dart';
import 'package:learning_helper_app/ui/screens/sub_workflow_screen.dart';
import 'package:provider/provider.dart';
import '../../models/entities/workflow_node.dart';
import '../../providers/workflow_provider.dart';

class WorkflowNodeTile extends StatelessWidget {
  final WorkflowNode node;
  final int depth;
  final List<WorkflowNode> parentList; // Needed for delete/numbering
  final Function(WorkflowNode? step, WorkflowNode? parent, bool isChild) onEdit;

  const WorkflowNodeTile({
    super.key,
    required this.node,
    required this.depth,
    required this.parentList,
    required this.onEdit,
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
          
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (node.isLoading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  icon: const Icon(Icons.auto_awesome, color: Colors.blue),
                  onPressed: () => provider.expandNode(node),
                ),
              // Edit
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                onPressed: () => onEdit(node, null, false), // Call generic dialog in parent
              ),
              // Add Child
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                onPressed: () => onEdit(null, node, true), // Call generic dialog in parent
              ),
              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => provider.deleteStep(parentList, node),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.deepPurple),
                tooltip: "Open Sub-Workflow",
                onPressed: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => SubWorkflowScreen(parentNode: node)
                    )
                  );
                },
              ),
              if (node.isLoading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                IconButton(
                  icon: const Icon(Icons.auto_awesome, color: Colors.blue),
                  onPressed: () => provider.generateSubStepsForNode(node),
                ),
            ],
          ),
          
          // RECURSION HAPPENS HERE
          children: node.children.map((child) => WorkflowNodeTile(
            node: child,
            depth: depth + 1,
            parentList: node.children,
            onEdit: onEdit,
          )).toList(),
        ),
      ),
    );
  }
}