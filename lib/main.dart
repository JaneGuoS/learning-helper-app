import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:math'; // Add this import at the top
import 'dart:async';

void main() {
  runApp(const MyApp());
}

// 1. DATA MODEL
// We create a class to hold the step data nicely

class WorkflowStep {
  String title;
  String description;
  final String key; 

  WorkflowStep({
    required this.title, 
    required this.description, 
    String? key
  }) : key = key ?? "${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}";
  
  factory WorkflowStep.fromJson(Map<String, dynamic> json) {
    return WorkflowStep(
      title: json['title'] ?? "New Step",
      description: json['description'] ?? "",
    );
  }
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini Workflow Editor',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const WorkflowGeneratorScreen(),
    );
  }
}


class WorkflowGeneratorScreen extends StatefulWidget {
  const WorkflowGeneratorScreen({super.key});

  @override
  State<WorkflowGeneratorScreen> createState() => _WorkflowGeneratorScreenState();
}

class _WorkflowGeneratorScreenState extends State<WorkflowGeneratorScreen> {
    // 1. Create a ScrollController
  final ScrollController _listScrollController = ScrollController();
  final TextEditingController _promptController = TextEditingController();
  // ADD THIS variable to force-refresh the list
  Key _listKey = UniqueKey(); 
  
  // State: Now using a List of our custom class 'WorkflowStep'
  List<WorkflowStep> _steps = [];
  bool _isLoading = false;

  // Add a toggle to select backend
  bool _useGemini = true; // true = Gemini, false = DeepSeek

  // *** PASTE YOUR GEMINI API KEY HERE ***
  final String _apiKey = "AIzaSyCpLMWak0THJIeAduww7fZM0SePiqTgt2Y";

  // --- LOGIC: CALL AI ---
  Future<void> _generateWorkflow() async {
    FocusScope.of(context).unfocus(); // Closes the keyboard automatically
    final problem = _promptController.text.trim();
    if (problem.isEmpty) return;
    setState(() {
      _isLoading = true;
      _steps = [];
    });
    try {
      if (_useGemini) {
        await _generateWithGemini(problem);
      } else {
        await _generateWithDeepSeek(problem);
      }
    } catch (e) {
      _showError("App Error: $e");
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // Helper for Gemini
  Future<void> _generateWithGemini(String problem) async {
    final List<String> modelCandidates = [
      "gemini-2.5-flash",
      "gemini-2.5-flash-lite",
      "gemini-1.5-flash",
      "gemini-1.5-flash-8b"
    ];
    http.Response? response;
    String usedModel = "";
    for (final modelName in modelCandidates) {
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$_apiKey"
      );
      final requestBody = {
        "contents": [{
          "parts": [{
            "text": "You are a learning coach. The user has this problem: '$problem'. "
                    "Generate a 3-5 step workflow to solve it. "
                    "Strictly follow this JSON schema: "
                    "{ \"steps\": [ { \"title\": \"Step Title\", \"description\": \"Step details\" } ] }"
          }]
        }],
        "generationConfig": { "responseMimeType": "application/json" }
      };
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          response = await http.post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(requestBody),
          );
          if (response != null && response.statusCode == 200) {
            usedModel = modelName;
            final data = jsonDecode(response.body);
            final String rawJsonText = data['candidates'][0]['content']['parts'][0]['text'];
            final workflowData = jsonDecode(rawJsonText);
            final List<dynamic> jsonSteps = workflowData['steps'];
            setState(() {
              _steps = jsonSteps.map((e) => WorkflowStep.fromJson(e)).toList();
              _listKey = UniqueKey();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Plan generated using $usedModel"),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
            return;
          }
          if (response.statusCode == 503) {
            await Future.delayed(const Duration(seconds: 2));
          } else {
            break;
          }
        } catch (e) {
          print("Network error on $modelName: $e");
        }
      }
      if (response != null && response.statusCode == 200) {
        break;
      }
    }
    if (response == null || response.statusCode != 200) {
      _showError("Servers are busy right now (All models returned 503). Try again in a minute.");
    }
  }

  // Helper for DeepSeek (streaming)
  Future<void> _generateWithDeepSeek(String problem) async {
  // 1. Set Loading State (Optional, but recommended)
  setState(() => _isLoading = true);

  final deepSeekStream = DeepSeekStreamService();
  
  // 2. Enhanced Prompt: Explicitly ask to exclude markdown for cleaner output
  final prompt = "You are a learning coach. The user has this problem: '$problem'. "
      "Generate a 3-5 step workflow to solve it. "
      "Output ONLY raw JSON. Do not use Markdown blocks. Do not add conversational text. "
      "Strictly follow this schema: "
      "{ \"steps\": [ { \"title\": \"Step Title\", \"description\": \"Step details\" } ] }";

  StringBuffer buffer = StringBuffer();

  try {
    // 3. The Stream Loop
    await for (final chunk in deepSeekStream.streamChat(prompt)) {
      buffer.write(chunk);
      // Note: We cannot parse JSON mid-stream because it is incomplete.
      // If you want to show text while it loads, set a _rawResponse variable here.
    }

    final fullResponse = buffer.toString();
    print("DeepSeek Full Response: $fullResponse");

    // 4. Robust JSON Extraction (Helper function below)
    final jsonString = _extractJsonFromResponse(fullResponse);

    // 5. Parse and Update UI
    final workflowData = jsonDecode(jsonString);
    
    if (workflowData['steps'] == null) {
      throw Exception("JSON does not contain 'steps' list");
    }

    final List<dynamic> jsonSteps = workflowData['steps'];

    setState(() {
      _steps = jsonSteps.map((e) => WorkflowStep.fromJson(e)).toList();
      _listKey = UniqueKey(); // Force list rebuild
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Plan generated successfully!")),
    );

  } catch (e) {
    setState(() => _isLoading = false);
    print("DeepSeek Parse Error: $e");
    _showError("Failed to generate plan. Please try again.");
  }
}

// --- HELPER: Cleans the messy LLM output ---
String _extractJsonFromResponse(String response) {
  // 1. Remove DeepSeek R1 "<think>...</think>" blocks if present
  String clean = response.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');

  // 2. Remove Markdown code blocks (```json ... ```)
  clean = clean.replaceAll('```json', '').replaceAll('```', '');

  // 3. Find the first '{' and last '}' to strip any conversational text
  final int startIndex = clean.indexOf('{');
  final int endIndex = clean.lastIndexOf('}');

  if (startIndex == -1 || endIndex == -1 || startIndex > endIndex) {
    throw FormatException("No valid JSON object found in response");
  }

  // 4. Return the clean JSON substring
  return clean.substring(startIndex, endIndex + 1);
}

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // --- LOGIC: LIST MANIPULATION ---

  // 1. REORDER
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, item);
    });
  }

  // 2. DELETE
  void _deleteStep(int index) {
    setState(() {
      _steps.removeAt(index);
    });
  }

  // 3. ADD / EDIT DIALOG
  void _showStepDialog({WorkflowStep? step, int? index}) {
    final titleController = TextEditingController(text: step?.title ?? "");
    final descController = TextEditingController(text: step?.description ?? "");
    final isEditing = step != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? "Edit Step" : "Add New Step"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Title", hintText: "e.g. Watch tutorial"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: "Description"),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isEmpty) return;
              
              setState(() {
                if (isEditing && index != null) {
                  // Update existing
                  _steps[index].title = titleController.text;
                  _steps[index].description = descController.text;
                } else {
                  // Add new
                  _steps.add(WorkflowStep(
                    title: titleController.text, 
                    description: descController.text
                  ));
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

    @override
  void dispose() {
  _listScrollController.dispose();
  _promptController.dispose();
  super.dispose();
  }

  // Removed unused _handleSubmit method.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Workflow Generator")),
      body: Column(
        children: [
          // --- TOP SECTION: Input + Submit Button ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      labelText: "Describe your problem",
                      border: OutlineInputBorder(),
                      hintText: "e.g., How to bake a cake",
                    ),
                    onSubmitted: (_) => _generateWorkflow(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _isLoading ? null : _generateWorkflow,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  tooltip: "Generate Plan",
                ),
              ],
            ),
          ),
          // --- MIDDLE SECTION: Scrollable & Reorderable List ---
          // Backend toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Gemini"),
              Switch(
                value: _useGemini,
                onChanged: (val) {
                  setState(() {
                    _useGemini = val;
                  });
                },
              ),
              const Text("DeepSeek"),
            ],
          ),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                scrollbars: false,
                dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
              ),
              child: Scrollbar(
                controller: _listScrollController,
                thumbVisibility: true,
                child: ReorderableListView.builder(
                  key: _listKey,
                  scrollController: _listScrollController,
                  itemCount: _steps.length,
                  padding: const EdgeInsets.only(bottom: 80),
                  onReorder: _onReorder,
                  itemBuilder: (context, index) {
                    final step = _steps[index];
                    return Card(
                      key: ValueKey(step.key),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(step.title),
                        subtitle: Text(step.description),
                        leading: CircleAvatar(child: Text("${index + 1}")),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _deleteStep(index),
                        ),
                        onTap: () => _showStepDialog(step: step, index: index),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // --- BOTTOM SECTION: Manual Add Button ---
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _steps.add(WorkflowStep(title: "New Step", description: "Details..."));
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_listScrollController.hasClients) {
                      _listScrollController.jumpTo(_listScrollController.position.maxScrollExtent);
                    }
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text("Add Manual Step"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DeepSeekStreamService {
  final String apiKey = "sk-5c6ca16010da4970b161f9fa50255e5b";
  final String apiUrl = "https://api.deepseek.com/chat/completions";


  // Returns a Stream that yields text chunks as they arrive
  Stream<String> streamChat(String prompt) async* {
    final request = http.Request('POST', Uri.parse(apiUrl));
    
    request.headers.addAll({
      "Content-Type": "application/json",
      "Authorization": "Bearer $apiKey",
    });

    request.body = jsonEncode({
      "model": "deepseek-chat",
      "messages": [
        {"role": "user", "content": prompt}
      ],
      "stream": true, // <--- CRITICAL: Enable Streaming
      "max_tokens": 8192,
    });

    final client = http.Client();
    
    try {
      // Send the request
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception("Error ${streamedResponse.statusCode}");
      }

      // Process the stream line by line
      await for (final line in streamedResponse.stream
          .transform(utf8.decoder)       // Decode bytes to text
          .transform(const LineSplitter())) { // Split by newlines
        
        if (line.startsWith("data: ")) {
          // Remove the "data: " prefix
          final jsonString = line.substring(6);

          // Check for the "DONE" signal
          if (jsonString.trim() == "[DONE]") break;

          try {
            final jsonMap = jsonDecode(jsonString);
            final content = jsonMap['choices'][0]['delta']['content'] ?? "";
            
            // Yield the chunk to your UI
            if (content.isNotEmpty) {
              yield content; 
            }
          } catch (e) {
            // Ignore parse errors for empty/keep-alive lines
          }
        }
      }
    } catch (e) {
      throw Exception("Streaming error: $e");
    } finally {
      client.close();
    }
  }
}