import 'package:flutter/material.dart';
import '../models/entities/plan_node.dart';

class PlanProvider extends ChangeNotifier {
  // The Master List
  final List<PlanNode> _planNodes = [
    // ... keep your existing dummy data ...
    PlanNode(
      id: "1",
      title: "Master Flutter State Management",
      description: "Deep dive into Provider and Riverpod.",
      scheduledDate: DateTime.now().add(const Duration(hours: 1)),
      durationMinutes: 90,
      checkpoints: [
        PlanCheckpoint(title: "Read Provider Docs", isCompleted: true),
      ]
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

  // 1. ADD
  void addPlan(PlanNode newNode) {
    _planNodes.add(newNode);
    _sortNodes();
    notifyListeners();
  }

  // 2. UPDATE
  void updatePlan(PlanNode oldNode, PlanNode updatedNode) {
    final index = _planNodes.indexOf(oldNode);
    if (index != -1) {
      _planNodes[index] = updatedNode;
      _sortNodes();
      notifyListeners();
    }
  }

  // 3. DELETE
  void deletePlan(PlanNode node) {
    _planNodes.remove(node);
    notifyListeners();
  }

  // Helper to keep list ordered by date
  void _sortNodes() {
    _planNodes.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  }

  // Helper for the Agent to "Read" the calendar
  String getScheduleContext() {
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));
    
    // Filter nodes for the next 7 days
    final upcoming = _planNodes.where((n) => 
      n.scheduledDate.isAfter(now.subtract(const Duration(hours: 1))) && 
      n.scheduledDate.isBefore(nextWeek)
    ).toList();

    if (upcoming.isEmpty) return "The schedule is completely empty for the next 7 days.";

    StringBuffer buffer = StringBuffer();
    buffer.writeln("EXISTING SCHEDULE (Do not overlap with these):");
    for (var node in upcoming) {
      buffer.writeln("- ${node.scheduledDate.toString().substring(0, 16)}: '${node.title}' (${node.durationMinutes} min)");
    }
    return buffer.toString();
  }
}