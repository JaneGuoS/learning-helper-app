import '../services/base_llm_client.dart';
import '../models/entities/resource.dart';
import '../models/entities/workflow_node.dart';

class ResourceAgent {
  final BaseLLMClient _client = BaseLLMClient();

  // 1. Generate Learning Materials
  // --- 1. BAIDU MATERIALS SEARCH ---
  Future<List<LearningMaterial>> findMaterials(String topic, bool useGemini) async {
    final system = """
      You are a Chinese Research Librarian (百度搜索专家).
      GOAL: Find the best learning resources using Baidu Search syntax.
      
      INSTRUCTIONS:
      1. Analyze the topic to determine the file type (PDF, PPT, DOC, or Video).
      2. Generate a 'search_query' optimized for Baidu.
         - For Documents: Use 'filetype:pdf' or 'filetype:ppt' or 'filetype:doc'.
         - For Slides/Notes: You can also use 'site:wenku.baidu.com'.
         - For Videos: Use keywords like '视频教程'.
      
      OUTPUT JSON:
      { 
        "resources": [ 
          { 
            "title": "Title in Chinese", 
            "search_query": "filetype:ppt 植物神经系统 课件", 
            "type": "ppt", 
            "description": "Short reasoning..." 
          }
        ] 
      }
    """;
    
    final result = await _client.request(
      prompt: "$system\n\nUSER TOPIC: '$topic'", 
      useGemini: useGemini
    );

    if (result.containsKey('resources')) {
      return (result['resources'] as List).map((r) {
        ResourceType type = ResourceType.website;
        String tStr = r['type'].toString().toLowerCase();
        if (tStr.contains('pdf')) type = ResourceType.pdf;
        if (tStr.contains('ppt')) type = ResourceType.ppt;
        if (tStr.contains('doc')) type = ResourceType.doc; // New for Baidu
        if (tStr.contains('video')) type = ResourceType.video;

        // --- BAIDU URL CONSTRUCTION ---
        // We construct a Baidu Search URL. 
        // The Internal Browser will open this, giving the user the best results.
        String query = Uri.encodeComponent(r['search_query'] ?? r['title']);
        String realUrl = "https://www.baidu.com/s?wd=$query";
        
        return LearningMaterial(
          id: DateTime.now().millisecondsSinceEpoch.toString() + r['title'].hashCode.toString(),
          title: r['title'],
          url: realUrl, 
          description: r['description'] ?? "",
          category: topic,
          type: type,
        );
      }).toList();
    }
    return [];
  }

  // --- 2. GENERATIVE KNOWLEDGE MAP (The Professor Mode) ---
// --- FIXED MIND MAP GENERATION ---
  Future<List<WorkflowNode>> generateMindMap({
    required String topic, 
    required String content, 
    required bool useGemini
  }) async {
    
    // 1. We construct a specialized prompt that forbids "Study Advice"
    final system = """
      You are an Advanced Biological Knowledge Graph Generator.
      
      GOAL:
      Convert the User's Request directly into a nested JSON Knowledge Tree.
      
      STRICT RULES:
      1. Do NOT give advice on how to study (e.g., "First, analyze..."). 
      2. GENERATE THE ACTUAL CONTENT. If the user asks about "Sympathetic Nerves", output nodes for "Norepinephrine", "Fight or Flight", "Heart Rate Up".
      3. HIERARCHY:
         - Level 1: The Topic Name.
         - Level 2: The Key Points requested (e.g., "Structure vs Function", "Antagonism").
         - Level 3 & 4: The specific scientific details, chemicals, and organ reactions.
      4. OUTPUT FORMAT:
         You must return a single JSON object with a recursive 'steps' structure.
    """;

    final userPrompt = """
      TARGET TOPIC: "$topic"
      
      DETAILED REQUIREMENTS (Cover these points in depth):
      "$content"
      
      REQUIRED JSON SCHEMA:
      {
        "steps": [
          {
            "title": "Root Topic",
            "description": "Brief Definition",
            "steps": [
              {
                "title": "Sub-concept",
                "description": "Scientific Detail",
                "steps": [ ...more details... ]
              }
            ]
          }
        ]
      }
    """;

    print("--- SENDING PROMPT TO AI ---");
    print("TOPIC: $topic, UseGemini: $useGemini");
    
    try {
      final result = await _client.request(
        prompt: "$system\n\nUSER REQUEST:\n$userPrompt", 
        useGemini: useGemini
      );
      
      // Robust Parsing
      if (result.containsKey('steps')) {
        return (result['steps'] as List)
            .map((e) => WorkflowNode.fromJson(e))
            .toList();
      } 
      // Handle case where AI wraps it in a root object
      else if (result.containsKey('title') && result.containsKey('steps')) {
         return [WorkflowNode.fromJson(result)];
      }

      print("DEBUG: JSON structure was valid but keys were unexpected: ${result.keys}");
      return [];

    } catch (e) {
      print("MindMap Generation Error: $e");
      rethrow;
    }
  }
}