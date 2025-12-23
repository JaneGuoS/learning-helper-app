import '../services/base_llm_client.dart';
import '../models/entities/workflow_node.dart';

class WorkflowGenerator {
  final BaseLLMClient _client = BaseLLMClient();

  // FIX: Change parameters to accept Topic + Context + useGemini
  Future<List<WorkflowNode>> generateSteps(String topic, String context, bool useGemini) async {
    
    // 1. Construct the prompt HERE (Encapsulation)
    final prompt = "You are a learning coach. Topic: '$topic'. Context: '$context'. "
        "Generate a 3-5 step workflow. "
        "Strictly follow this JSON schema: { \"steps\": [ { \"title\": \"Step Title\", \"description\": \"Step details\" } ] }";

    // 2. Call Base Client
    final json = await _client.request(prompt: prompt, useGemini: useGemini);
    
    // 3. Parse
    if (json.containsKey('steps')) {
      return (json['steps'] as List)
          .map((e) => WorkflowNode.fromJson(e))
          .toList();
    }
    return [];
  }
}