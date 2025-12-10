import 'dart:convert';
import 'dart:async'; // Required for Timeout
import 'package:http/http.dart' as http;
import '../models/entities/workflow_node.dart';

class AIService {
  final String _geminiApiKey = "AIzaSyCpLMWak0THJIeAduww7fZM0SePiqTgt2Y"; // Keep your key here
  final String _deepSeekApiKey = "sk-5c6ca16010da4970b161f9fa50255e5b"; 

  // Unified fetch method
  Future<List<WorkflowNode>> generateSteps(String prompt, bool useGemini) async {
    if (useGemini) {
      return _fetchGeminiSteps(prompt);
    } else {
      return _fetchDeepSeekSteps(prompt);
    }
  }

  // --- GEMINI LOGIC ---
  Future<List<WorkflowNode>> _fetchGeminiSteps(String prompt) async {
    final List<String> modelCandidates = ["gemini-2.5-flash", "gemini-1.5-flash"];
    
    for (final modelName in modelCandidates) {
      final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$_geminiApiKey");
      try {
        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "contents": [{ "parts": [{ "text": prompt }] }],
            "generationConfig": { "responseMimeType": "application/json" }
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final rawText = data['candidates'][0]['content']['parts'][0]['text'];
          final json = _parseJson(rawText);
          return (json['steps'] as List).map((e) => WorkflowNode.fromJson(e)).toList();
        } else if (response.statusCode == 503) {
          continue; // Try next model
        }
      } catch (_) { continue; }
    }
    throw Exception("Gemini models are busy or unreachable.");
  }

  // --- DEEPSEEK LOGIC ---
  Future<List<WorkflowNode>> _fetchDeepSeekSteps(String prompt) async {
    final request = http.Request('POST', Uri.parse("https://api.deepseek.com/chat/completions"));
    request.headers.addAll({
      "Content-Type": "application/json",
      "Authorization": "Bearer $_deepSeekApiKey",
    });
    request.body = jsonEncode({
      "model": "deepseek-chat",
      "messages": [{"role": "user", "content": prompt}],
      "stream": true,
      "max_tokens": 4000,
    });

    final client = http.Client();
    StringBuffer buffer = StringBuffer();

    try {
      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 10));

      if (streamedResponse.statusCode != 200) {
        throw Exception("DeepSeek Error: ${streamedResponse.statusCode}");
      }

      await for (final line in streamedResponse.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.startsWith("data: ")) {
          final jsonString = line.substring(6);
          if (jsonString.trim() == "[DONE]") break;
          try {
             final jsonMap = jsonDecode(jsonString);
             final content = jsonMap['choices'][0]['delta']['content'] ?? "";
             buffer.write(content);
          } catch (_) {}
        }
      }
      
      final json = _parseJson(buffer.toString());
      return (json['steps'] as List).map((e) => WorkflowNode.fromJson(e)).toList();
    } finally {
      client.close();
    }
  }

  // Helper
  Map<String, dynamic> _parseJson(String raw) {
    String clean = raw.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');
    clean = clean.replaceAll('```json', '').replaceAll('```', '');
    int start = clean.indexOf('{');
    int end = clean.lastIndexOf('}');
    if (start == -1) throw FormatException("No JSON found");
    return jsonDecode(clean.substring(start, end + 1));
  }
}