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
  
  // 1. Logic to reorder items
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = widget.node.children.removeAt(oldIndex);
      widget.node.children.insert(newIndex, item);
    });
  }

  // 2. Logic to Show Edit/Add Dialog (Copied & adapted for local sub-list)
  void _showStepDialog(WorkflowNode? step, WorkflowNode? parentNode, bool isAddingChild) {
    // Note: In this screen, 'parentNode' usually refers to the node we are viewing (widget.node)
    // But WorkflowNodeTile might pass the immediate parent if we supported nested recursion here.
    // For a flat sub-list, we simplify.

    final titleController = TextEditingController(text: isAddingChild ? "" : (step?.title ?? ""));
    final descController = TextEditingController(text: isAddingChild ? "" : (step?.description ?? ""));
    final isEditing = step != null && !isAddingChild;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAddingChild ? "Add Sub-Step" : (isEditing ? "Edit Step" : "Add Step")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: "Title"), autofocus: true),
            const SizedBox(height: 8),
            TextField(controller: descController, decoration: const InputDecoration(labelText: "Description")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                setState(() {
                  if (isAddingChild) {
                    // If adding a child to a specific node in this list (nested)
                    if (parentNode != null) {
                      parentNode.children.add(WorkflowNode(
                        title: titleController.text,
                        description: descController.text,
                      ));
                    } else {
                      // Fallback: Add to the main list of this subworkflow
                      widget.node.children.add(WorkflowNode(
                        title: titleController.text,
                        description: descController.text,
                      ));
                    }
                  } else if (isEditing) {
                    // Update existing
                    step!.title = titleController.text;
                    step!.description = descController.text;
                  } else {
                    // Add new item to this list
                     widget.node.children.add(WorkflowNode(
                        title: titleController.text,
                        description: descController.text,
                      ));
                  }
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Text('Subworkflow: ${widget.node.title}'),
      ),
      // 3. Use ReorderableListView instead of ListView
      body: widget.node.children.isEmpty 
        ? const Center(child: Text("No steps. Click + to add.")) 
        : ReorderableListView.builder(
            onReorder: _onReorder,
            itemCount: widget.node.children.length,
            padding: const EdgeInsets.only(bottom: 80),
            itemBuilder: (context, index) {
              final child = widget.node.children[index];
              // 4. Wrap in a Container with a Key for Reordering
              return Container(
                key: ValueKey(child.id), // IMPORTANT: Unique Key
                child: WorkflowNodeTile(
                  node: child,
                  depth: 0,
                  parentList: widget.node.children,
                  // 5. Connect the Dialog logic
                  onEdit: _showStepDialog, 
                  // Sub-sub workflows can be disabled or implemented recursively
                  onCreateSubworkflow: (n) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Nested subworkflows not supported in this view yet."))
                    );
                  },
                ),
              );
            },
          ),
      // 6. Add Floating Button to add new items easily
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showStepDialog(null, null, false),
      ),
    );
  }
}