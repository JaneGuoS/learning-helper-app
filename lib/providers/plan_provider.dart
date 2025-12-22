import 'package:flutter/material.dart';
import '../models/entities/plan_node.dart';

class PlanProvider extends ChangeNotifier {
  // The Master List of Plan Items
  final List<PlanNode> _planNodes = [
    // --- DUMMY DATA FOR TODAY ---
    PlanNode(
      id: "1",
      title: "Master Flutter State Management",
      description: "Deep dive into Provider and Riverpod.",
      scheduledDate: DateTime.now().add(const Duration(hours: 1)), // Today + 1 hr
      durationMinutes: 90,
      checkpoints: [
        PlanCheckpoint(title: "Read Provider Docs", isCompleted: true),
        PlanCheckpoint(title: "Refactor Main App", isCompleted: false),
      ]
    ),
    PlanNode(
      id: "2",
      title: "Agentic AI Architecture",
      description: "Study how tools interact with LLMs.",
      scheduledDate: DateTime.now().add(const Duration(hours: 4)), // Today + 4 hrs
      durationMinutes: 45,
      checkpoints: [
        PlanCheckpoint(title: "Read Google GenAI Docs", isCompleted: false),
      ]
    ),
    // --- DUMMY DATA FOR TOMORROW ---
    PlanNode(
      id: "3",
      title: "Advanced Math Review",
      description: "Calculus refreshment for ML.",
      scheduledDate: DateTime.now().add(const Duration(days: 1, hours: 2)), 
      durationMinutes: 120,
      checkpoints: []
    ),
  ];

  List<PlanNode> get planNodes => _planNodes;

  // --- ACTIONS ---

  void toggleTaskCompletion(PlanNode node) {
    node.isCompleted = !node.isCompleted;
    notifyListeners();
  }

  void toggleCheckpoint(PlanNode node, int index) {
    node.checkpoints[index].isCompleted = !node.checkpoints[index].isCompleted;
    notifyListeners();
  }
  
  // The Agent will use this later!
  void addNodeFromAgent(PlanNode newNode) {
    _planNodes.add(newNode);
    // Sort by date ensures it appears in the right place
    _planNodes.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    notifyListeners();
  }
}