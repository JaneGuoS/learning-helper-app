import '../entities/workflow_node.dart';

class WorkflowSession {
  final String sessionId;
  final DateTime createdAt;
  List<WorkflowNode> nodes; // The list of steps

  WorkflowSession({
    required this.sessionId,
    required this.nodes, 
    DateTime? createdAt
  }) : createdAt = createdAt ?? DateTime.now();
  
  // Helper to parse the AI response entirely
  factory WorkflowSession.fromMap(Map<String, dynamic> map) {
    var list = map['steps'] as List;
    List<WorkflowNode> parsedNodes = list.map((i) => WorkflowNode.fromJson(i)).toList();
    
    return WorkflowSession(
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      nodes: parsedNodes,
    );
  }
}