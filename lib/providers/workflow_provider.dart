
  // ...existing code...
import 'package:flutter/material.dart';
import '../../models/entities/workflow_node.dart';
import '../../services/ai_services.dart';

class WorkflowProvider extends ChangeNotifier {
  // Expose AIService for temporary subworkflow generation (read-only)
  AIService get aiService => _service;
  // Generate a subworkflow for a given node using AI
  Future<void> generateSubworkflow(WorkflowNode node) async {
    node.isLoading = true;
    notifyListeners();

    try {
      final prompt = "You are a learning coach. For the topic: '${node.title}'. Details: '${node.description}'. Generate a 3-5 step subworkflow. Strictly follow this JSON schema: { \"steps\": [ { \"title\": \"Step Title\", \"description\": \"Step details\" } ] }";
      final newChildren = await _service.generateSteps(prompt, _useGemini);
      node.children.clear();
      node.children.addAll(newChildren);
      node.isExpanded = true;
    } catch (e) {
      print("Subworkflow Error: $e");
    } finally {
      node.isLoading = false;
      notifyListeners();
    }
  }
  final AIService _service = AIService();
  
  // State
  List<WorkflowNode> _rootSteps = [];
  bool _isLoadingRoot = false;
  bool _useGemini = true;

  // Getters
  List<WorkflowNode> get steps => _rootSteps;
  bool get isLoading => _isLoadingRoot;
  bool get useGemini => _useGemini;

  // --- ACTIONS ---

  void toggleModel(bool value) {
    _useGemini = value;
    notifyListeners();
  }

  // 1. Generate Root Plan
  Future<void> generateRootPlan(String userProblem) async {
    if (userProblem.isEmpty) return;
    
    _isLoadingRoot = true;
    notifyListeners();

    try {
      final prompt = "You are a learning coach. Problem: '$userProblem'. "
        "Generate a 3-5 step workflow. "
        "Strictly follow this JSON schema: { \"steps\": [ { \"title\": \"Step Title\", \"description\": \"Step details\" } ] }";
      
      _rootSteps = await _service.generateSteps(prompt, _useGemini);
    } catch (e) {
      print("Error: $e"); // In real app, handle error UI via a status stream
    } finally {
      _isLoadingRoot = false;
      notifyListeners();
    }
  }

  // 2. Expand a Specific Node (Recursion)
  Future<void> expandNode(WorkflowNode node) async {
    node.isLoading = true;
    notifyListeners();

    try {
      final prompt = "Topic: '${node.title}'. Details: '${node.description}'. "
          "Generate 3-5 sub-steps. Output JSON only. Schema: { \"steps\": [...] }";
      
      final newChildren = await _service.generateSteps(prompt, _useGemini);
      node.children.addAll(newChildren);
      node.isExpanded = true;
    } catch (e) {
      print("Expand Error: $e");
    } finally {
      node.isLoading = false;
      notifyListeners();
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