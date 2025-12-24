import '../services/base_llm_client.dart';
import '../models/entities/resource.dart';
import '../models/entities/workflow_node.dart';

class ResourceAgent {
  final BaseLLMClient _client = BaseLLMClient();

  // 1. Generate Learning Materials
  Future<List<LearningMaterial>> findMaterials(String topic, bool useGemini) async {
    final system = """
      You are a Research Librarian.
      GOAL: Find the 3-5 best learning resources for the topic.
      TYPES: PDF, Video, Website, Book.
      OUTPUT JSON: { "resources": [ { "title": "...", "url": "...", "type": "pdf/video/website", "description": "..." } ] }
    """;
    
    final prompt = "Find resources for: '$topic'.";

    final result = await _client.request(
      prompt: "$system\n\nUSER REQUEST: $prompt", 
      useGemini: useGemini
    );

    if (result.containsKey('resources')) {
      return (result['resources'] as List).map((r) {
        // Map string type to Enum
        ResourceType type = ResourceType.website;
        if (r['type'].toString().toLowerCase().contains('pdf')) type = ResourceType.pdf;
        if (r['type'].toString().toLowerCase().contains('video')) type = ResourceType.video;
        if (r['type'].toString().toLowerCase().contains('book')) type = ResourceType.book;

        return LearningMaterial(
          id: DateTime.now().millisecondsSinceEpoch.toString() + r['title'].hashCode.toString(),
          title: r['title'],
          url: r['url'],
          description: r['description'] ?? "",
          category: topic, // Use topic as category
          type: type,
        );
      }).toList();
    }
    return [];
  }

  // 2. Generate Mind Map (Tree Structure)
  Future<List<WorkflowNode>> generateMindMap(String topic, bool useGemini) async {
    final system = """
      You are a Knowledge Mapper.
      GOAL: Create a deep, branching mindmap for the topic.
      STRUCTURE: Root -> Main Concepts -> Sub-details.
      OUTPUT JSON: { "steps": [ { "title": "Main Concept", "description": "Key Idea", "steps": [ ...children... ] } ] }
    """;

    final prompt = "Create a mindmap for: '$topic'.";

    final result = await _client.request(
      prompt: "$system\n\nUSER REQUEST: $prompt", 
      useGemini: useGemini
    );

    if (result.containsKey('steps')) {
      return (result['steps'] as List)
          .map((e) => WorkflowNode.fromJson(e))
          .toList();
    }
    return [];
  }
}