import '../services/base_llm_client.dart';
import '../models/entities/resource.dart';
import '../models/entities/workflow_node.dart';

class ResourceAgent {
  final BaseLLMClient _client = BaseLLMClient();

  // 1. Generate Learning Materials
  Future<List<LearningMaterial>> findMaterials(String topic, bool useGemini) async {
    final system = """
<<<<<<< Updated upstream
      You are a Research Librarian.
      GOAL: Find the 3-5 best learning resources for the topic.
      TYPES: PDF, Video, Website, Book.
      OUTPUT JSON: { "resources": [ { "title": "...", "url": "...", "type": "pdf/video/website", "description": "..." } ] }
=======
      You are a Research Librarian using Quark Search.
      GOAL: Find downloadable documents (PDF, PPT).
      
      INSTRUCTIONS:
      1. RETURN 3 RESOURCES MAX.
      2. 'search_query' MUST include 'filetype:pdf' or 'filetype:ppt'.
      3. Use Chinese keywords (e.g. '课件', '讲义').
      
      OUTPUT JSON:
      { 
        "resources": [ 
          { 
            "title": "Topic Slides (PPT)", 
            "search_query": "filetype:ppt 植物神经调节 课件", 
            "type": "ppt", 
            "description": "University Lecture Slides" 
          }
        ] 
      }
>>>>>>> Stashed changes
    """;
    
    final prompt = "Find resources for: '$topic'.";

    final result = await _client.request(
      prompt: "$system\n\nUSER REQUEST: $prompt", 
      useGemini: useGemini
    );


    if (result.containsKey('resources')) {
      return (result['resources'] as List).map((r) {
<<<<<<< Updated upstream
        // Map string type to Enum
        ResourceType type = ResourceType.website;
        if (r['type'].toString().toLowerCase().contains('pdf')) type = ResourceType.pdf;
        if (r['type'].toString().toLowerCase().contains('video')) type = ResourceType.video;
        if (r['type'].toString().toLowerCase().contains('book')) type = ResourceType.book;
=======
        ResourceType type = _parseType(r['type']);
        String query = r['search_query'] ?? r['title'];
        
        // --- FIX: FORCE FILETYPE IN FALLBACK URL ---
        
        // 2. FORCE DOCUMENT MODE PARAMETERS
        // style=doc : Tells the engine to use Document style
        // m_vs=doc  : Vertical Search = Doc
        String encodedQuery = Uri.encodeComponent(query);
        String quarkUrl = "https://quark.sm.cn/?qtab=library&q=$encodedQuery&style=doc&m_vs=doc";
>>>>>>> Stashed changes

        return LearningMaterial(
          id: DateTime.now().millisecondsSinceEpoch.toString() + r['title'].hashCode.toString(),
          title: r['title'],
<<<<<<< Updated upstream
          url: r['url'],
=======
          url: quarkUrl, // Default to Quark Search
>>>>>>> Stashed changes
          description: r['description'] ?? "",
          category: topic, // Use topic as category
          type: type,
        );
      }).toList();
    }
    return [];
  }

  ResourceType _parseType(String? t) {
    if (t == null) return ResourceType.website;
    String lower = t.toLowerCase();
    if (lower.contains('pdf')) return ResourceType.pdf;
    if (lower.contains('ppt')) return ResourceType.ppt;
    if (lower.contains('doc')) return ResourceType.doc;
    if (lower.contains('video')) return ResourceType.video;
    return ResourceType.website;
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
        print("DEBUG: result: ${result}");
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