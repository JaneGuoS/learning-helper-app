import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class BaseLLMClient {
  final String _geminiApiKey = "YOUR_GEMINI_API_KEY"; // Replace with yours
  final String _deepSeekApiKey = "sk-5c6ca16010da4970b161f9fa50255e5b"; 

  /// The main entry point.
  /// It connects, streams the response chunk-by-chunk into a buffer, 
  /// and then parses the accumulated result into JSON.
  Future<Map<String, dynamic>> request({
    required String prompt,
    bool useGemini = true,
  }) async {
    final StringBuffer buffer = StringBuffer();

    try {
      if (useGemini) {
        await _streamGemini(prompt, buffer);
      } else {
        await _streamDeepSeek(prompt, buffer);
      }

      // Once the stream is finished, we have the full text in 'buffer'.
      // Now we clean and parse it.
      return _cleanAndParseJson(buffer.toString());

    } catch (e) {
      print("LLM Streaming Error: $e");
      // If we gathered partial data, print it to help debugging
      if (buffer.isNotEmpty) {
        print("Partial Buffer: ${buffer.toString().substring(0, minimum(buffer.length, 500))}...");
      }
      rethrow;
    }
  }

  int minimum(int a, int b) => (a < b) ? a : b;

  // --- 1. DEEPSEEK STREAMING (Based on your provided code) ---
  Future<void> _streamDeepSeek(String prompt, StringBuffer buffer) async {
    const String apiUrl = "https://api.deepseek.com/chat/completions";
    
    final request = http.Request('POST', Uri.parse(apiUrl));
    request.headers.addAll({
      "Content-Type": "application/json",
      "Authorization": "Bearer $_deepSeekApiKey",
    });
    
    request.body = jsonEncode({
      "model": "deepseek-chat",
      "messages": [{"role": "user", "content": prompt}],
      "stream": true, // <--- CRITICAL: Enable Streaming
      "max_tokens": 8000,
    });

    final client = http.Client();
    try {
      // 1. Connection Timeout only applies to establishing the link
      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 50),
        onTimeout: () => throw TimeoutException("DeepSeek Connection Timed Out"),
      );

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        throw Exception("DeepSeek API Error (${streamedResponse.statusCode}): $errorBody");
      }

      // 2. Read chunks as they arrive
      await for (final line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        
        if (line.startsWith("data: ")) {
          final jsonString = line.substring(6);
          if (jsonString.trim() == "[DONE]") break;
          
          try {
            final jsonMap = jsonDecode(jsonString);
            final content = jsonMap['choices'][0]['delta']['content'] ?? "";
            buffer.write(content); // <--- Accumulate chunk
          } catch (_) {
            // Ignore intermediate parse errors
          }
        }
      }
    } finally {
      client.close();
    }
  }

  // --- 2. GEMINI STREAMING ---
  Future<void> _streamGemini(String prompt, StringBuffer buffer) async {
    // Use the 'streamGenerateContent' endpoint
    final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?key=$_geminiApiKey");
    
    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      "contents": [{ "parts": [{ "text": prompt }] }],
      "generationConfig": { "responseMimeType": "application/json" }
    });

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 10),
         onTimeout: () => throw TimeoutException("Gemini Connection Timed Out"),
      );

      if (streamedResponse.statusCode != 200) {
         throw Exception("Gemini Error: ${streamedResponse.statusCode}");
      }

      // Gemini returns a stream of JSON objects in an array: [ {...}, {...} ]
      // We will buffer the raw JSON response
      final rawBuffer = StringBuffer();
      
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        rawBuffer.write(chunk);
      }
      
      // Parse the full Gemini array response
      // Gemini Structure: [ { "candidates": [ { "content": { "parts": [ { "text": "..." } ] } } ] } ]
      try {
        final List<dynamic> jsonChunks = jsonDecode(rawBuffer.toString());
        for (var chunk in jsonChunks) {
          if (chunk['candidates'] != null && (chunk['candidates'] as List).isNotEmpty) {
            final part = chunk['candidates'][0]['content']['parts'][0]['text'];
            buffer.write(part);
          }
        }
      } catch (e) {
        // Fallback: If array parsing fails, maybe it wasn't valid JSON array (rare)
        print("Gemini Stream Parse Warning: $e");
        buffer.write(rawBuffer.toString()); 
      }
    } finally {
      client.close();
    }
  }

  // --- 3. CLEAN & PARSE (Robust) ---
  Map<String, dynamic> _cleanAndParseJson(String raw) {
    // A. Remove DeepSeek "Think" blocks
    String clean = raw.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');
    
    // B. Remove Markdown wrappers
    clean = clean.replaceAll('```json', '').replaceAll('```', '').trim();
    
    // C. Find JSON Object boundaries
    int start = clean.indexOf('{');
    int end = clean.lastIndexOf('}');
    
    if (start == -1 || end == -1) {
      // Emergency: Try to find a List boundaries if Object failed
      start = clean.indexOf('[');
      end = clean.lastIndexOf(']');
      
      if (start != -1 && end != -1) {
         // It returned a list directly, wrap it
         final listStr = clean.substring(start, end + 1);
         return { "steps": jsonDecode(listStr) };
      }
      
      throw FormatException("No valid JSON object found in response");
    }

    // D. Extract and Parse
    final jsonStr = clean.substring(start, end + 1);
    
    try {
      return jsonDecode(jsonStr);
    } catch (e) {
      // E. Attempt simple repair for truncated JSON (missing brackets)
      print("JSON Error, attempting repair...");
      try {
        return jsonDecode("$jsonStr}"); 
      } catch (_) {
        try { return jsonDecode("$jsonStr]}"); } catch(__) { rethrow; }
      }
    }
  }
}