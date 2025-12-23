import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/plan_provider.dart';
import '../../providers/workflow_provider.dart';
import '../../models/entities/workflow_node.dart';
import '../widgets/workflow_node_tile.dart';
import 'draggable_flowchart_screen.dart';
import 'subworkflow_screen.dart';


class ProblemSolverScreen extends StatefulWidget {
  const ProblemSolverScreen({super.key});

  @override
  State<ProblemSolverScreen> createState() => _ProblemSolverScreenState();
}

class _ProblemSolverScreenState extends State<ProblemSolverScreen> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  WorkflowNode? _currentSubworkflowNode;
  // Cache for generated subworkflows (by node id)
  final Map<String, WorkflowNode> _subworkflowCache = {};

  // --- DIALOG LOGIC (Kept in UI because it involves TextControllers) ---
  void _showStepDialog(WorkflowNode? step, WorkflowNode? parentNode, bool isAddingChild) {
    final titleController = TextEditingController(text: isAddingChild ? "" : (step?.title ?? ""));
    final descController = TextEditingController(text: isAddingChild ? "" : (step?.description ?? ""));
    final isEditing = step != null && !isAddingChild;
    final provider = context.read<WorkflowProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAddingChild ? "Add Step" : (isEditing ? "Edit Step" : "Add Root Step")),
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
              if (titleController.text.isNotEmpty) {
                if (isAddingChild && parentNode != null) {
                  // Insert as sibling under parentNode
                  List<WorkflowNode> targetList = provider.steps;
                  final idx = targetList.indexOf(parentNode);
                  if (idx != -1) {
                    targetList.insert(idx + 1, WorkflowNode(
                      title: titleController.text,
                      description: descController.text,
                    ));
                    // Force update by updating a node (triggers notifyListeners)
                    if (targetList.isNotEmpty) {
                      provider.updateStep(targetList[0], targetList[0].title, targetList[0].description);
                    }
                  } else {
                    provider.addChildStep(parentNode, titleController.text, descController.text);
                  }
                } else if (isEditing) {
                  provider.updateStep(step, titleController.text, descController.text);
                } else {
                  provider.addRootStep(titleController.text, descController.text);
                }
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
    // Consumer watches for changes in Provider
    return Consumer<WorkflowProvider>(
      builder: (context, provider, child) {
        // If a subworkflow node is selected, show the subworkflow screen
        if (_currentSubworkflowNode != null) {
          return SubworkflowScreen(
            node: _currentSubworkflowNode!,
            onBack: () {
              setState(() {
                _currentSubworkflowNode = null;
              });
            },
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text("Learning Helper - Problem Solver")),
          body: Column(
            children: [
              // 1. Navigation to Flowchart
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.device_hub),
                    label: const Text("Open Draggable Flowchart"),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DraggableFlowchartScreen(
                          nodes: provider.steps,
                          subworkflowCache: _subworkflowCache,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Input Area
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _promptController,
                        decoration: const InputDecoration(labelText: "Describe goal", border: OutlineInputBorder()),
                        onSubmitted: (_) => provider.generateRootPlan(_promptController.text),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      onPressed: provider.isLoading ? null : () => provider.generateRootPlan(_promptController.text),
                      icon: provider.isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),

              // 3. Model Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Gemini"),
                  Switch(value: provider.useGemini, onChanged: provider.toggleModel),
                  const Text("DeepSeek"),
                ],
              ),

              if (provider.selectedNodes.isNotEmpty || provider.agentStatus.isNotEmpty) 
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.deepPurple.shade200)
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.smart_toy, color: Colors.deepPurple),
                              const SizedBox(width: 8),
                              Text(
                                "${provider.selectedNodes.length} Items Selected", 
                                style: const TextStyle(fontWeight: FontWeight.bold)
                              ),
                            ],
                          ),
                          
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple, 
                              foregroundColor: Colors.white
                            ),
                            icon: const Icon(Icons.calendar_month, size: 16),
                            label: const Text("Add to Plan"),
                            onPressed: provider.agentStatus.isNotEmpty 
                              ? null 
                              : () {
                                  final planProvider = context.read<PlanProvider>();
                                  // Pass the selected nodes
                                  provider.autoScheduleWorkflow(
                                    context, 
                                    planProvider, 
                                    nodesToSchedule: provider.selectedNodes
                                  );
                                },
                          ),
                        ],
                      ),
                      
                      // Status Text
                      if (provider.agentStatus.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                              const SizedBox(width: 8),
                              Text(provider.agentStatus, style: TextStyle(color: Colors.deepPurple.shade700, fontSize: 12)),
                            ],
                          ),
                        )
                    ],
                  ),
              ),

              // 4. The List
              Expanded(
                child: ScrollConfiguration(
                   behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
                    ),
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: ReorderableListView.builder(
                      scrollController: _scrollController,
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: provider.steps.length,
                      onReorder: provider.reorderSteps,
                      itemBuilder: (context, index) {
                        final step = provider.steps[index];
                        return Container(
                          key: ValueKey(step.id),
                          child: WorkflowNodeTile(
                            node: step, 
                            depth: 0, 
                            parentList: provider.steps,
                            onEdit: _showStepDialog, // Pass dialog callback
                            onCreateSubworkflow: (node) async {
                              // If already generated, just show cached subworkflow
                              if (_subworkflowCache.containsKey(node.id)) {
                                setState(() {
                                  _currentSubworkflowNode = _subworkflowCache[node.id]!;
                                });
                                return;
                              }
                              // Otherwise, generate by AI and cache it
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) => const Center(child: CircularProgressIndicator()),
                              );
                              final provider = context.read<WorkflowProvider>();
      
      
                              final generatedChildren = await provider.aiGenerator.generateSteps(
                                node.title,         // 1. Topic
                                node.description,   // 2. Context
                                provider.useGemini  // 3. Model Flag
                              );
                              
                              final tempNode = WorkflowNode(
                                title: node.title,
                                description: node.description,
                                children: generatedChildren,
                              );

                              setState(() {
                                _subworkflowCache[node.id] = tempNode;
                                _currentSubworkflowNode = tempNode;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: () => _showStepDialog(null, null, false),
          ),
        );
      },
    );
  }
}