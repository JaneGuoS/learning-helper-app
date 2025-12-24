import 'package:flutter/material.dart';
import '../agents/workflow_generator.dart'; // Replaces AIService
import '../agents/plan_agent.dart';         // New Agent
import '../models/entities/plan_node.dart'; // Ensures PlanNode and PlanPriority are available
import '../models/entities/workflow_node.dart';
import 'plan_provider.dart';

class WorkflowProvider extends ChangeNotifier {
  // --- INJECTION ---
  // 1. Internal instance
  final WorkflowGenerator _workflowGen = WorkflowGenerator();
  final PlanAgent _planAgent = PlanAgent();
  // 2. ADD THIS GETTER (This fixes the error)
  WorkflowGenerator get aiGenerator => _workflowGen; 
  // Expose for UI logic if needed
  WorkflowGenerator get generator => _workflowGen; 

  // --- STATE ---
  List<WorkflowNode> _rootSteps = [];
  bool _isLoading = false;
  String _agentStatus = ""; // UI Feedback

  List<WorkflowNode> get steps => _rootSteps;
  bool get isLoading => _isLoading;
  String get agentStatus => _agentStatus;
  
  bool _useGemini = true;
  bool get useGemini => _useGemini;

  // Fix 1. ADD THIS METHOD to fix the Switch error
  void toggleModel(bool value) {
    _useGemini = value;
    notifyListeners();
  }

  // --- 1. GENERATION LOGIC (Uses WorkflowGenerator) ---
  Future<void> generateRootPlan(String userProblem) async {
    _isLoading = true;
    notifyListeners();
    try {
      // FIX: Pass all 3 arguments: (Topic, Context, ModelFlag)
      _rootSteps = await _workflowGen.generateSteps(
        userProblem,   // Topic
        "Root Plan",   // Context
        _useGemini     // Model Flag (Required by BaseLLMClient)
      );
    } catch (e) {
      print("Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- 2.1. ACTION: Toggle Selection
  void toggleNodeSelection(WorkflowNode node) {
    node.isSelected = !node.isSelected;
    notifyListeners();
  }

  // --- 2.2. GETTER: recursive search for selected nodes
  List<WorkflowNode> get selectedNodes {
    List<WorkflowNode> selected = [];
    void visit(List<WorkflowNode> nodes) {
      for (var n in nodes) {
        if (n.isSelected) selected.add(n);
        visit(n.children); // Check children too!
      }
    }
    visit(_rootSteps);
    return selected;
  }

  // --- 2.3. UPDATE: Accept specific nodes for scheduling
  Future<void> autoScheduleWorkflow(BuildContext context, PlanProvider planProvider, {List<WorkflowNode>? nodesToSchedule}) async {
    final targets = nodesToSchedule ?? _rootSteps;
    if (targets.isEmpty) return;

    _agentStatus = "Agent: Analyzing schedule context...";
    notifyListeners();

    try {
      // 1. Get Context
      String contextData = planProvider.getScheduleContext();

      // 2. Call Agent (Now returns a List of Maps, not PlanNodes)
      final actions = await _planAgent.incorporateWorkflow(
        newWorkflow: targets,
        currentPlanContext: contextData,
        preference: "Analyze tasks: shrink leisure time if needed to fit study.",
        useGemini: _useGemini,
      );

      _agentStatus = "Agent: Executing ${actions.length} optimization actions...";
      notifyListeners();

      // 3. Process the Actions
      int delay = 0;
      for (var action in actions) {
        String tool = action['tool'];
        
        // Artificial delay for UX
        await Future.delayed(Duration(milliseconds: 300 + delay));
        delay += 100;

        if (tool == 'create_plan_node') {
          // --- FIX: Manually construct the PlanNode here ---
          final newNode = PlanNode(
            id: DateTime.now().millisecondsSinceEpoch.toString() + action['title'].hashCode.toString(),
            title: action['title'],
            description: action['description'] ?? "AI Scheduled",
            scheduledDate: DateTime.parse(action['start_time']),
            durationMinutes: action['duration_minutes'] ?? 45,
            // Handle Priority Enum conversion safely
            priority: PlanPriority.values.firstWhere(
              (e) => e.name == (action['priority'] ?? 'medium'), 
              orElse: () => PlanPriority.medium
            ),
          );
          
          planProvider.addPlan(newNode); // <--- Now passing a valid PlanNode object
        } 
        else if (tool == 'update_plan_node') {
          // --- Handle Updates ---
          String targetId = action['target_id'];
          
          // Parse optional fields safely
          DateTime? newTime;
          if (action['new_start_time'] != null) {
            newTime = DateTime.parse(action['new_start_time']);
          }
          
          int? newDuration = action['new_duration_minutes']; // Can be null

          planProvider.agentUpdateNode(targetId, newTime, newDuration);
        }
      }

      _agentStatus = "Schedule Optimized!";
      
      // Clear selection after success
      if (nodesToSchedule != null) {
        for (var n in nodesToSchedule) n.isSelected = false;
      }

    } catch (e) {
      print(e);
      _agentStatus = "Agent Failed: $e";
    } finally {
      notifyListeners();
      Future.delayed(const Duration(seconds: 3), () {
        _agentStatus = "";
        notifyListeners();
      });
    }
  }
  
  // 3. Manual CRUD Operations
  void addRootStep(String title, String desc) {
    _rootSteps.add(WorkflowNode(title: title, description: desc));
    notifyListeners();
  }

  void addChildStep(WorkflowNode parent, String title, String desc) {
    parent.children.add(WorkflowNode(title: title, description: desc));
    parent.isExpanded = true;
    notifyListeners();
  }

  void updateStep(WorkflowNode node, String title, String desc) {
    node.title = title;
    node.description = desc;
    notifyListeners();
  }

  void deleteStep(List<WorkflowNode> list, WorkflowNode node) {
    list.remove(node);
    notifyListeners();
  }

  void reorderSteps(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _rootSteps.removeAt(oldIndex);
    _rootSteps.insert(newIndex, item);
    notifyListeners();
  }

}