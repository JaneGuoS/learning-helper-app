import '../services/base_llm_client.dart';
import '../models/entities/workflow_node.dart';
import '../models/entities/plan_node.dart';

class PlanAgent {
  final BaseLLMClient _client = BaseLLMClient();

  Future<List<Map<String, dynamic>>> incorporateWorkflow({
    required List<WorkflowNode> newWorkflow,
    required String currentPlanContext,
    String preference = "Optimize for learning speed",
    bool useGemini = true,
  }) async {
    
    final stepsText = newWorkflow.map((s) => "- ${s.title} (Desc: ${s.description})").join("\n");
    final now = DateTime.now().toIso8601String().substring(0, 16);

    final systemInstruction = """
      You are an Elite Executive Assistant and Time Manager.
      
      YOUR GOAL:
      Fit new learning tasks into the User's Schedule by intelligently adjusting existing items.
      
      CRITICAL REASONING (DO THIS FIRST):
      1. Analyze the 'EXISTING SCHEDULE'.
      2. INFER the priority of existing tasks based on their Title/Description:
         - **High/Fixed:** Work, Exams, Meetings, Medical, Sleep. (DO NOT TOUCH).
         - **Medium:** Chores, Errands, Routine Maintenance. (Move if necessary).
         - **Low/Flexible:** Entertainment, Gaming, TV, Social Media, "Relaxing". (SHRINK or MOVE these to make space).
      
      RULES:
      1. If the schedule is full, look for inferred 'Low' or 'Medium' tasks.
      2. You are authorized to use the 'update_plan_node' tool to:
         - Reduce the duration of Leisure activities (e.g. shorten 'Gaming' from 2h to 30m).
         - Move flexible tasks to a later time.
      3. Create 'create_plan_node' actions for the new learning steps.
      4. Split large learning steps into smaller chunks (e.g. 45m) if needed.

      OUTPUT SCHEMA (JSON):
      {
        "actions": [
          {
            "tool": "create_plan_node",
            "title": "Title",
            "description": "Reasoning",
            "start_time": "YYYY-MM-DD HH:MM",
            "duration_minutes": 60,
            "priority": "high"
          },
          {
            "tool": "update_plan_node",
            "target_id": "ID_OF_EXISTING_NODE", 
            "reason": "Shrinking leisure time to fit study",
            "new_start_time": "YYYY-MM-DD HH:MM",
            "new_duration_minutes": 30
          }
        ]
      }
    """;

    final userPrompt = """
      CURRENT TIME: $now
      
      EXISTING SCHEDULE (CONTEXT):
      $currentPlanContext

      NEW TASKS TO ADD:
      $stepsText

      USER PREFERENCE:
      $preference
    """;

    final fullPrompt = "$systemInstruction\n\nUSER REQUEST:\n$userPrompt";

    final result = await _client.request(prompt: fullPrompt, useGemini: useGemini);

    if (result.containsKey('actions')) {
      return List<Map<String, dynamic>>.from(result['actions']);
    }
    return [];
  }
}