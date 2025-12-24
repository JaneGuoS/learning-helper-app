import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/entities/workflow_node.dart';
import '../../providers/workflow_provider.dart';
import '../../providers/resource_provider.dart'; // <--- 1. IMPORT THIS

class WorkflowNodeTile extends StatelessWidget {
  final WorkflowNode node;
  final int depth;
  final List<WorkflowNode> parentList; 
  // Note: Updated onEdit signature to match your specific implementation if needed, 
  // or keep your existing one. 
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
    // We listen: false here for actions, but we might need values for the buttons
    final wfProvider = Provider.of<WorkflowProvider>(context, listen: false);

    return Padding(
      padding: EdgeInsets.only(left: 10.0 * depth),
      child: Card(
        key: ValueKey(node.id),
        color: node.isSelected ? Colors.deepPurple.shade50 : Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: ExpansionTile(
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: node.isSelected,
                activeColor: Colors.deepPurple,
                onChanged: (val) => wfProvider.toggleNodeSelection(node),
              ),
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.deepPurple.shade100,
                child: Text(
                  depth == 0 ? "${parentList.indexOf(node) + 1}" : "•",
                  style: const TextStyle(fontSize: 12, color: Colors.deepPurple),
                ),
              ),
            ],
          ),
          
          title: Text(node.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: node.description.isNotEmpty ? Text(node.description) : null,
          
          children: [
            // --- ACTION BUTTONS ROW ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: SingleChildScrollView( // Added scroll in case buttons overflow on small screens
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (node.isLoading)
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    
                    // Existing Edit
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                      tooltip: 'Edit',
                      onPressed: () => onEdit(node, null, false),
                    ),
                    
                    // Existing Add Child
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                      tooltip: 'Add Child',
                      onPressed: () => onEdit(null, node, true),
                    ),
                    
                    // Existing Subworkflow
                    IconButton(
                      icon: const Icon(Icons.account_tree_outlined, color: Colors.orange),
                      tooltip: 'Create Subworkflow',
                      onPressed: onCreateSubworkflow != null ? () => onCreateSubworkflow!(node) : null,
                    ),

                    // --- 2. NEW: GENERATE MIND MAP ---
                    IconButton(
                      icon: const Icon(Icons.hub, color: Colors.deepPurple),
                      tooltip: 'Generate Deep Mind Map',
                      onPressed: () async { // <--- Make async
                        final resProvider = context.read<ResourceProvider>();
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Analyzing content (this may take  a while)..."))
                        );
                        
                        // Wait for completion
                        await resProvider.createAndSaveMindMap(
                          node.title, 
                          node.description, 
                          wfProvider.useGemini
                        );

                        // Check for error
                        if (context.mounted) {
                          if (resProvider.error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(resProvider.error!), backgroundColor: Colors.red)
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Mind Map Created! Check Resources Tab."), backgroundColor: Colors.green)
                            );
                          }
                        }
                      },
                    ),

                    // --- 3. NEW: FETCH MATERIALS ---
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.teal),
                      tooltip: 'Fetch Resources',
                      onPressed: () {
                        final resProvider = context.read<ResourceProvider>();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Finding materials for '${node.title}'..."))
                        );
                        
                        resProvider.fetchAndSaveMaterials(node.title, wfProvider.useGemini);
                      },
                    ),

                    // Existing Delete (Keep at end)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      tooltip: 'Delete',
                      onPressed: () => wfProvider.deleteStep(parentList, node),
                    ),
                  ],
                ),
              ),
            ),
            
            // RECURSION
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