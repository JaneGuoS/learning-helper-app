import 'workflow_node.dart'; // Reuse your node structure for Mindmaps

enum ResourceType { pdf, ppt, doc, video, website, book }

class LearningMaterial {
  final String id;
  final String title;
  final String url;
  final String description;
  final ResourceType type;
  final String category; // e.g. "Math", "Coding"

  LearningMaterial({
    required this.id,
    required this.title,
    required this.url,
    required this.description,
    required this.type,
    required this.category,
  });
}

class SavedMindMap {
  final String id;
  final String title;
  final String category;
  final DateTime createdAt;
  final List<WorkflowNode> nodes; // The graph data

  SavedMindMap({
    required this.id,
    required this.title,
    required this.category,
    required this.createdAt,
    required this.nodes,
  });
}