import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/entities/workflow_node.dart';
import '../../providers/workflow_provider.dart';
import '../widgets/workflow_node_tile.dart';
import 'draggable_flowchart_screen.dart';

class SubWorkflowScreen extends StatelessWidget {
  final WorkflowNode parentNode;

  const SubWorkflowScreen({super.key, required this.parentNode});

  @override
  Widget build(BuildContext context) {
    // Watch provider to see updates (like when children are generated)
    final provider = context.watch<WorkflowProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(parentNode.title),
        actions: [
          // Button to view the ENTIRE tree (Global Context)
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: "View Entire Flowchart",
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  // KEY FIX: Always pass the ROOT steps to the flowchart
                  builder: (_) => DraggableFlowchartScreen(nodes: provider.rootSteps)
                )
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Header showing description
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.shade50,
            width: double.infinity,
            child: Text(
              parentNode.description,
              style: TextStyle(color: Colors.deepPurple.shade900),
            ),
          ),

          // Main Content
          Expanded(
            child: parentNode.children.isEmpty
                ? Center(
                    child: parentNode.isLoading 
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("No sub-steps yet."),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text("Generate Sub-Workflow"),
                              onPressed: () {
                                provider.generateSubStepsForNode(parentNode);
                              },
                            )
                          ],
                        ),
                  )
                : ListView.builder(
                    itemCount: parentNode.children.length,
                    itemBuilder: (context, index) {
                      final child = parentNode.children[index];
                      // Reuse the tile, but depth is reset relative to this view
                      return WorkflowNodeTile(
                        node: child, 
                        depth: 0, 
                        parentList: parentNode.children,
                        // We pass a dummy callback or your existing dialog logic
                        onEdit: (step, parent, isChild) {
                           // You can reuse your dialog logic here by extracting it 
                           // or passing it down. For now, we assume simple display.
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}