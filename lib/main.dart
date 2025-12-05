import 'draggable_flowchart_screen.dart';
import 'dart:convert';
import 'dart:ui'; // Required for mouse scroll
import 'package:flutter/gestures.dart'; 
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

// --- 1. DATA MODEL ---
class WorkflowStep {
  String id;
  String title;
  String description;
  List<WorkflowStep> children; 
  bool isLoading;
  bool isExpanded;

  WorkflowStep({
    required this.title,
    required this.description,
    this.children = const [],
    this.isLoading = false,
    this.isExpanded = false,
  }) : id = "${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}";

  factory WorkflowStep.fromJson(Map<String, dynamic> json) {
    return WorkflowStep(
      title: json['title'] ?? "New Step",
      description: json['description'] ?? "",
      children: (json['steps'] as List?)
              ?.map((e) => WorkflowStep.fromJson(e))
              .toList() ?? [],
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Workflow Editor',
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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _promptController = TextEditingController();
  
  List<WorkflowStep> _steps = []; 
  bool _isLoadingRoot = false; 
  bool _useGemini = true; 
  final String _geminiApiKey = "AIzaSyCpLMWak0THJIeAduww7fZM0SePiqTgt2Y"; 

  @override
  void dispose() {
    _scrollController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  // --- 2. RESTORED DIALOG FUNCTION ---
  void _showStepDialog({WorkflowStep? step, WorkflowStep? parentNode, bool isAddingChild = false}) {
    final titleController = TextEditingController(text: isAddingChild ? "" : (step?.title ?? ""));
    final descController = TextEditingController(text: isAddingChild ? "" : (step?.description ?? ""));
    final isEditing = step != null && !isAddingChild;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAddingChild 
            ? "Add Sub-Step to '${parentNode?.title}'" 
            : (isEditing ? "Edit Step" : "Add New Root Step")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Title", hintText: "e.g. Research Topic"),
              autofocus: true,
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isEmpty) return;
              setState(() {
                if (isAddingChild && parentNode != null) {
                  // Add Manual Child
                  parentNode.children.add(WorkflowStep(
                    title: titleController.text, 
                    description: descController.text
                  ));
                  parentNode.isExpanded = true;
                } else if (isEditing && step != null) {
                  // Edit Existing
                  step.title = titleController.text;
                  step.description = descController.text;
                } else {
                  // Add Manual Root
                  _steps.add(WorkflowStep(
                    title: titleController.text, 
                    description: descController.text
                  ));
                  _scrollToBottom();
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

  // --- 3. REORDER LOGIC (Restored) ---
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, item);
    });
  }

  // --- 4. API & GENERATION LOGIC ---
  Future<void> _generateRootWorkflow() async {
    FocusScope.of(context).unfocus();
    final problem = _promptController.text.trim();
    if (problem.isEmpty) return;

    setState(() => _isLoadingRoot = true);
    
    try {
      final prompt = "You are a learning coach. Problem: '$problem'. "
        "Generate a 3-5 step workflow. "
        "Strictly follow this JSON schema: { \"steps\": [ { \"title\": \"Step Title\", \"description\": \"Step details\" } ] }";
      
      List<WorkflowStep> newSteps = [];
      if (_useGemini) {
        newSteps = await _fetchGeminiSteps(prompt);
      } else {
        newSteps = await _fetchDeepSeekSteps(prompt);
      }
      setState(() => _steps = newSteps);
      _scrollToBottom();
    } catch (e) {
      _showError("Error: $e");
    } finally {
      setState(() => _isLoadingRoot = false);
    }
  }

  Future<void> _expandNode(WorkflowStep parentNode) async {
    setState(() => parentNode.isLoading = true);
    final String prompt = "Topic: '${parentNode.title}'. Details: '${parentNode.description}'. "
        "Generate 3-5 sub-steps. "
        "Output JSON only. Schema: { \"steps\": [ { \"title\": \"Title\", \"description\": \"Details\" } ] }";

    try {
      List<WorkflowStep> newChildren = [];
      if (_useGemini) {
        newChildren = await _fetchGeminiSteps(prompt);
      } else {
        newChildren = await _fetchDeepSeekSteps(prompt);
      }
      setState(() {
        parentNode.children.addAll(newChildren);
        parentNode.isExpanded = true; 
        parentNode.isLoading = false;
      });
    } catch (e) {
      setState(() => parentNode.isLoading = false);
      _showError("Failed: $e");
    }
  }

  // --- API HELPER: GEMINI ---
  Future<List<WorkflowStep>> _fetchGeminiSteps(String prompt) async {
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
          return (json['steps'] as List).map((e) => WorkflowStep.fromJson(e)).toList();
        } else if (response.statusCode == 503) continue; 
      } catch (_) {}
    }
    throw Exception("Gemini busy.");
  }

  // --- API HELPER: DEEPSEEK ---
  Future<List<WorkflowStep>> _fetchDeepSeekSteps(String prompt) async {
    final service = DeepSeekStreamService();
    StringBuffer buffer = StringBuffer();
    await for (final chunk in service.streamChat(prompt)) {
      buffer.write(chunk);
    }
    final json = _parseJson(buffer.toString());
    return (json['steps'] as List).map((e) => WorkflowStep.fromJson(e)).toList();
  }

  Map<String, dynamic> _parseJson(String raw) {
    String clean = raw.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');
    clean = clean.replaceAll('```json', '').replaceAll('```', '');
    int start = clean.indexOf('{');
    int end = clean.lastIndexOf('}');
    if (start == -1) throw FormatException("No JSON found");
    return jsonDecode(clean.substring(start, end + 1));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  // --- 5. RECURSIVE WIDGET BUILDER ---
  // Renders children (non-draggable to keep UI simple, but editable)
  Widget _buildRecursiveChildren(WorkflowStep node, int depth) {
    if (node.children.isEmpty) return const SizedBox.shrink();
    return Column(
      children: node.children.map((child) => _buildNodeTile(child, depth + 1, node.children)).toList(),
    );
  }

  // The Individual Node Tile
  Widget _buildNodeTile(WorkflowStep step, int depth, List<WorkflowStep> parentList) {
    // Determine indentation
    return Padding(
      padding: EdgeInsets.only(left: 10.0 * depth), 
      child: Card(
        key: ValueKey(step.id), // Required for drag/drop tracking
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: ExpansionTile(
          key: PageStorageKey(step.id),
          initiallyExpanded: step.isExpanded,
          onExpansionChanged: (val) => step.isExpanded = val,
          shape: const Border(), // remove divider
          
          leading: CircleAvatar(
            radius: 12,
            backgroundColor: Colors.deepPurple.shade100,
            child: Text(depth == 0 ? "${parentList.indexOf(step) + 1}" : "•", 
                   style: const TextStyle(fontSize: 12, color: Colors.deepPurple)),
          ),
          
          title: Text(step.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: step.description.isNotEmpty ? Text(step.description) : null,
          
          // --- RESTORED: BUTTONS FOR EDIT / ADD / DELETE ---
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (step.isLoading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  icon: const Icon(Icons.auto_awesome, color: Colors.blue),
                  tooltip: "Generate Sub-steps",
                  onPressed: () => _expandNode(step),
                ),
              // EDIT BUTTON
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                tooltip: "Edit Step",
                onPressed: () => _showStepDialog(step: step),
              ),
              // ADD CHILD MANUAL BUTTON
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                tooltip: "Add Manual Child",
                onPressed: () => _showStepDialog(parentNode: step, isAddingChild: true),
              ),
              // DELETE BUTTON
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => setState(() => parentList.remove(step)),
              ),
            ],
          ),
          
          // Recursion
          children: [_buildRecursiveChildren(step, depth)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Workflow Editor")),
       body: Column(
         children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.device_hub),
                label: const Text("Try Freeform Flowchart Demo"),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => DraggableFlowchartScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
          // INPUT
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(labelText: "Describe your goal", border: OutlineInputBorder()),
                    onSubmitted: (_) => _generateRootWorkflow(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _isLoadingRoot ? null : _generateRootWorkflow,
                  icon: _isLoadingRoot 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                    : const Icon(Icons.send),
                ),
              ],
            ),
          ),

          // MODEL SWITCH
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Gemini"),
              Switch(
                value: _useGemini,
                activeColor: Colors.blue,
                onChanged: (val) => setState(() => _useGemini = val),
              ),
              const Text("DeepSeek"),
            ],
          ),

          // LIST (Draggable + Scroll Fix)
          Expanded(
            child: Listener(
              onPointerSignal: (pointerSignal) {
                if (pointerSignal is PointerScrollEvent) {
                  final newOffset = _scrollController.offset + pointerSignal.scrollDelta.dy;
                  if (newOffset >= _scrollController.position.minScrollExtent &&
                      newOffset <= _scrollController.position.maxScrollExtent) {
                    _scrollController.jumpTo(newOffset);
                  }
                }
              },
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
                  scrollbars: false,
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ReorderableListView.builder(
                    scrollController: _scrollController,
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: _steps.length,
                    onReorder: _onReorder, // RESTORED DRAG & DROP FOR ROOTS
                    itemBuilder: (context, index) {
                      final step = _steps[index];
                      // Wrap in container with KEY for ReorderableListView
                      return Container(
                        key: ValueKey(step.id), 
                        child: _buildNodeTile(step, 0, _steps),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          
          // MANUAL ADD ROOT BUTTON
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showStepDialog(), // Opens "Add Root" dialog
              icon: const Icon(Icons.add),
              label: const Text("Add Root Step"),
            ),
          )
        ],
      ),
    );
  }
}

class DeepSeekStreamService {
  final String apiKey = "sk-5c6ca16010da4970b161f9fa50255e5b"; 
  final String apiUrl = "https://api.deepseek.com/chat/completions";

// inside DeepSeekStreamService class

  Stream<String> streamChat(String prompt) async* {
    final request = http.Request('POST', Uri.parse(apiUrl));
    request.headers.addAll({
      "Content-Type": "application/json",
      "Authorization": "Bearer $apiKey",
    });
    request.body = jsonEncode({
      "model": "deepseek-chat",
      "messages": [{"role": "user", "content": prompt}],
      "stream": true,
      "max_tokens": 4000,
    });

    final client = http.Client();
    try {
      // 1. Add Connection Timeout (10 seconds to establish connection)
      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException("Connection to DeepSeek timed out"),
      );

      // 2. Check for Server Errors (e.g., 503 Busy, 401 Unauthorized)
      if (streamedResponse.statusCode != 200) {
        // Try to read the error body
        final errorBody = await streamedResponse.stream.bytesToString();
        throw Exception("DeepSeek API Error (${streamedResponse.statusCode}): $errorBody");
      }

      // 3. Process Stream
      await for (final line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        
        if (line.startsWith("data: ")) {
          final jsonString = line.substring(6);
          if (jsonString.trim() == "[DONE]") break;
          
          try {
            final jsonMap = jsonDecode(jsonString);
            final content = jsonMap['choices'][0]['delta']['content'] ?? "";
            if (content.isNotEmpty) yield content;
          } catch (e) {
            // If JSON fails, it might be an error message sent as data
            print("Stream Parse Error: $e in line: $jsonString");
          }
        } 
        // 4. Handle Error JSON sent purely as text (rare but happens)
        else if (line.contains('"error":')) {
           throw Exception("Stream Error: $line");
        }
      }
    } catch (e) {
      // Rethrow so the UI knows something went wrong
      throw Exception("DeepSeek Connection Failed: $e");
    } finally {
      client.close();
    }
  }
}