import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini Learning Architect',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple, // Changed color to distinguish it
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
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _steps = [];
  bool _isLoading = false;

  // REPLACE THIS WITH YOUR GOOGLE GEMINI API KEY
  // Get it here: https://aistudio.google.com/app/apikey
  final String _apiKey = "AIzaSyCpLMWak0THJIeAduww7fZM0SePiqTgt2Y"; 

  Future<void> _generateWorkflow() async {
    final problem = _controller.text.trim();
    if (problem.isEmpty) return;

    setState(() {
      _isLoading = true;
      _steps = [];
    });

    try {
      // 1. Gemini API Endpoint (using gemini-2.5-flash)
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey"
      );

      // 2. The Prompt & Configuration
      // We set responseMimeType to 'application/json' to force structured output
      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": "You are a learning coach. The user has this problem: '$problem'. "
                        "Generate a 3-5 step workflow to solve it. "
                        "Strictly follow this JSON schema: "
                        "{ \"steps\": [ { \"title\": \"Step Title\", \"description\": \"Step details\" } ] }"
              }
            ]
          }
        ],
        "generationConfig": {
          "responseMimeType": "application/json"
        }
      };

      // 3. Send Request
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // 4. Parse Gemini Response Structure
        // Gemini returns: candidates -> content -> parts -> text
        final String rawJsonText = data['candidates'][0]['content']['parts'][0]['text'];
        
        // Decode the actual JSON content provided by the AI
        final workflowData = jsonDecode(rawJsonText);

        setState(() {
          _steps = workflowData['steps'];
        });
      } else {
        print("Error: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response.statusCode}")),
        );
      }
    } catch (e) {
      print("Exception: $e");
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text("Failed to connect: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gemini Workflow Generator")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "What do you want to learn?",
                hintText: "e.g., I want to understand Quantum Physics...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lightbulb_outline),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _generateWorkflow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                icon: _isLoading 
                  ? const SizedBox.shrink() 
                  : const Icon(Icons.auto_awesome),
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Generate Plan with Gemini"),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            Expanded(
              child: _steps.isEmpty
                  ? const Center(
                      child: Text(
                        "Describe your goal above to start!",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _steps.length,
                      itemBuilder: (context, index) {
                        final step = _steps[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.deepPurple.shade100,
                                      foregroundColor: Colors.deepPurple,
                                      radius: 14,
                                      child: Text("${index + 1}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        step['title'] ?? "Step",
                                        style: const TextStyle(
                                          fontSize: 18, 
                                          fontWeight: FontWeight.bold
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  step['description'] ?? "",
                                  style: TextStyle(
                                    fontSize: 14, 
                                    color: Colors.grey[700],
                                    height: 1.4
                                  ),
                                ),
                              ],
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