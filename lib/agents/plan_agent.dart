import '../services/base_llm_client.dart';
import '../models/entities/workflow_node.dart';
import '../models/entities/plan_node.dart';

class PlanAgent {
  final BaseLLMClient _client = BaseLLMClient();

  Future<List<PlanNode>> incorporateWorkflow({
    required List<WorkflowNode> newWorkflow,
    required String currentPlanContext,
    String preference = "Spread out over next few days",
    bool useGemini = true, // Added flag to control model
  }) async {
    
    // 1. Context Construction
    final stepsText = newWorkflow.map((s) => "- ${s.title} (${s.description})").join("\n");
    final now = DateTime.now().toIso8601String().substring(0, 16);

    final systemInstruction = """
      You are an expert Scheduling Agent.
      YOUR GOAL: Merge a new learning workflow into an existing user schedule.
      CURRENT TIME: $now
      RULES:
      1. Analyze the 'EXISTING SCHEDULE' to find gaps.
      2. Do not double-book the user.
      3. Respect 'USER PREFERENCE'.
      4. Default duration: 45 mins.
      
      OUTPUT SCHEMA (JSON ONLY):
      {
        "proposed_additions": [
          {
            "title": "Step Title",
            "description": "Reasoning",
            "start_time": "YYYY-MM-DD HH:MM", 
            "duration_minutes": 60
          }
        ]
      }
    """;

    final userPrompt = """
      EXISTING SCHEDULE:
      $currentPlanContext

      NEW WORKFLOW TO INSERT:
      $stepsText

      USER PREFERENCE:
      $preference
    """;

    // 2. The Fix: Combine prompts and call 'request'
    final fullPrompt = "$systemInstruction\n\nUSER REQUEST:\n$userPrompt";

    final result = await _client.request(
      prompt: fullPrompt, 
      useGemini: useGemini
    );

    // 3. Parse Results
    if (result.containsKey('proposed_additions')) {
      List<dynamic> proposals = result['proposed_additions'];
      List<PlanNode> actionableNodes = [];

      for (var prop in proposals) {
        actionableNodes.add(PlanNode(
          id: DateTime.now().millisecondsSinceEpoch.toString() + prop['title'].hashCode.toString(),
          title: prop['title'],
          description: prop['description'] ?? "Scheduled by Agent",
          scheduledDate: DateTime.parse(prop['start_time']),
          durationMinutes: prop['duration_minutes'] ?? 45,
        ));
      }
      return actionableNodes;
    }
    
    return [];
  }
}