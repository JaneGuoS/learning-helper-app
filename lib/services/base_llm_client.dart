import 'dart:convert';
import 'dart:async'; // Required for Timeout
import 'package:http/http.dart' as http;

/// Layer 1: The Raw Pipe
/// Handles API Keys, Network Calls, and JSON Cleaning.
/// Returns raw Map<String, dynamic> data.
class BaseLLMClient {
  final String _geminiApiKey = "AIzaSyCpLMWak0THJIeAduww7fZM0SePiqTgt2Y"; 
  final String _deepSeekApiKey = "sk-5c6ca16010da4970b161f9fa50255e5b"; 

  /// Sends a prompt to the selected AI and returns a parsed JSON Object (Map).
  Future<Map<String, dynamic>> request({
    required String prompt,
    bool useGemini = true,
  }) async {
    if (useGemini) {
      return _callGemini(prompt);
    } else {
      return _callDeepSeek(prompt);
    }
  }

  // --- GEMINI LOGIC ---
  Future<Map<String, dynamic>> _callGemini(String prompt) async {
    final List<String> modelCandidates = ["gemini-2.5-flash", "gemini-1.5-flash"];
    
    for (final modelName in modelCandidates) {
      final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$_geminiApiKey");
      try {
        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "contents": [{ "parts": [{ "text": prompt }] }],
            // Force JSON mode for Gemini 1.5+
            "generationConfig": { "responseMimeType": "application/json" }
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final rawText = data['candidates'][0]['content']['parts'][0]['text'];
          return _cleanAndParseJson(rawText);
        } else if (response.statusCode == 503) {
          continue; // Try next model
        }
      } catch (_) { 
        continue; 
      }
    }
    throw Exception("Gemini models are busy or unreachable.");
  }

  // --- DEEPSEEK LOGIC (Streaming) ---
  Future<Map<String, dynamic>> _callDeepSeek(String prompt) async {
    final request = http.Request('POST', Uri.parse("https://api.deepseek.com/chat/completions"));
    request.headers.addAll({
      "Content-Type": "application/json",
      "Authorization": "Bearer $_deepSeekApiKey",
    });
    request.body = jsonEncode({
      "model": "deepseek-chat",
      "messages": [{"role": "user", "content": prompt}],
      "stream": true, // Keeping your streaming implementation
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
      
      return _cleanAndParseJson(buffer.toString());
    } finally {
      client.close();
    }
  }

  // --- SHARED HELPER ---
  /// Cleans markdown (```json), removes <think> tags, and parses JSON.
  Map<String, dynamic> _cleanAndParseJson(String raw) {
    // 1. Remove <think> tags (Common in DeepSeek R1/V3)
    String clean = raw.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');
    
    // 2. Remove Markdown code blocks
    clean = clean.replaceAll('```json', '').replaceAll('```', '');
    
    // 3. Find the first '{' and last '}'
    int start = clean.indexOf('{');
    int end = clean.lastIndexOf('}');
    
    if (start == -1 || end == -1) throw FormatException("No JSON found in response: $clean");
    
    // 4. Parse
    return jsonDecode(clean.substring(start, end + 1));
  }
}