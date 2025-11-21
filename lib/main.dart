import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:math'; // Add this import at the top

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
  final ScrollController _listScrollController = ScrollController();
  final TextEditingController _promptController = TextEditingController();
  // ADD THIS variable to force-refresh the list
  Key _listKey = UniqueKey(); 
  
  // State: Now using a List of our custom class 'WorkflowStep'
  List<WorkflowStep> _steps = [];
  bool _isLoading = false;

  // *** PASTE YOUR GEMINI API KEY HERE ***
  final String _apiKey = "AIzaSyCpLMWak0THJIeAduww7fZM0SePiqTgt2Y";

  // --- LOGIC: CALL AI ---
  Future<void> _generateWorkflow() async {
    FocusScope.of(context).unfocus(); // Closes the keyboard automatically
    final problem = _promptController.text.trim();
    if (problem.isEmpty) return;
    
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _steps = [];
    });

    // 1. Define the models we will try (Priority: Standard -> Lite -> Old Reliable)
    final List<String> modelCandidates = [
      "gemini-2.5-flash",       // Best quality/speed balance
      "gemini-2.5-flash-lite",  // Often less congested
      "gemini-1.5-flash"        // Old reliable backup
    ];

    try {
      http.Response? response;
      String usedModel = "";

      // 2. Retry Loop: Try each model in the list
      for (final modelName in modelCandidates) {
        print("Attempting to connect to: $modelName...");
        
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

        // Try the request up to 2 times per model (handling 503s)
        for (int attempt = 0; attempt < 2; attempt++) {
          try {
            response = await http.post(
              url,
              headers: {"Content-Type": "application/json"},
              body: jsonEncode(requestBody),
            );

            // If success (200), break the retry loop
            if (response != null && response.body != null && response.statusCode == 200) {
              
              usedModel = modelName;

              setState(() {
                usedModel = modelName;

                final data = jsonDecode(response?.body?? "");
                final String rawJsonText = data['candidates'][0]['content']['parts'][0]['text'];
                final workflowData = jsonDecode(rawJsonText);
                final List<dynamic> jsonSteps = workflowData['steps'];
                _steps = jsonSteps.map((e) => WorkflowStep.fromJson(e)).toList();
            
                // ADD THIS LINE: This forces the list to repaint immediately
                _listKey = UniqueKey(); 
              });
              break;
            }
            
            // If 503 (Server Busy), wait 2 seconds and loop again
            if (response.statusCode == 503) {
              print("Server 503 busy on $modelName. Waiting...");
              await Future.delayed(const Duration(seconds: 2));
            } else {
              // If it's a 400/404 error, this model might be wrong, stop retrying IT and move to next model
              break; 
            }
          } catch (e) {
            print("Network error on $modelName: $e");
          }
        }

        // If we found a valid response, stop checking other models
        if (response != null && response.statusCode == 200) {
          break;
        }
      }

      // 3. Process the Result
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String rawJsonText = data['candidates'][0]['content']['parts'][0]['text'];
        final workflowData = jsonDecode(rawJsonText);
        
        final List<dynamic> jsonSteps = workflowData['steps'];
        setState(() {
          _steps = jsonSteps.map((e) => WorkflowStep.fromJson(e)).toList();
        });
        
        // Optional: Show a tiny message telling you which model actually worked
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Plan generated using $usedModel"), 
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          )
        );
        
      } else {
        _showError("Servers are busy right now (All models returned 503). Try again in a minute.");
      }
    } catch (e) {
      _showError("App Error: $e");
    } finally {
      setState(() { _isLoading = false; });
    }
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Workflow Editor")),
      // Floating Action Button to Add New Steps manually
      floatingActionButton: _steps.isNotEmpty ? FloatingActionButton(
        onPressed: () => _showStepDialog(),
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
      
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Input Area
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      labelText: "Describe your goal...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _isLoading ? null : _generateWorkflow,
                  icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                  style: IconButton.styleFrom(backgroundColor: Colors.deepPurple),
                )
              ],
            ),
            
            const SizedBox(height: 10),
            if (_steps.isEmpty && !_isLoading) 
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text("Enter a goal to generate a plan!", style: TextStyle(color: Colors.grey)),
              ),

            const Divider(),

            // THE LIST AREA
            // ... inside the Column ...

            // THE FIXED LIST AREA
            // ... Inside the Column ...
            
            Expanded(
              child: _steps.isEmpty
                  ? const Center(child: Text("Ready to generate!"))
                  : ReorderableListView.builder(
                      // FIX 1: This Key forces the widget to rebuild when data changes
                      key: _listKey,
                      
                      // FIX 2: Ensure there is always padding at the bottom so FAB doesn't cover the last item
                      padding: const EdgeInsets.fromLTRB(0, 10, 0, 80),
                      
                      itemCount: _steps.length,
                      onReorder: _onReorder,
                      itemBuilder: (context, index) {
                        final step = _steps[index];
                        return Card(
                          // FIX 3: Unique keys are now guaranteed by our new class update
                          key: ValueKey(step.key), 
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle, color: Colors.grey),
                            ),
                            title: Text(
                              step.title, 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(step.description),
                            ),
                            onTap: () => _showStepDialog(step: step, index: index),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _deleteStep(index),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}