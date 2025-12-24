import 'package:flutter/material.dart';
import '../models/entities/resource.dart';
import '../models/entities/workflow_node.dart';
import '../agents/resource_agent.dart';

class ResourceProvider extends ChangeNotifier {
  final ResourceAgent _agent = ResourceAgent();
  
  // Storage
  final List<LearningMaterial> _materials = [];
  final List<SavedMindMap> _mindMaps = [];
  
  bool _isLoading = false;

  List<LearningMaterial> get materials => _materials;
  List<SavedMindMap> get mindMaps => _mindMaps;
  bool get isLoading => _isLoading;

  // --- ACTIONS ---

  // A. Generate & Save Materials
  Future<void> fetchAndSaveMaterials(String topic, bool useGemini) async {
    _isLoading = true;
    notifyListeners();
    try {
      final newMaterials = await _agent.findMaterials(topic, useGemini);
      _materials.addAll(newMaterials);
    } catch (e) {
      print("Material Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 1. Add an error string to state
  String? _error;
  String? get error => _error;

  Future<void> createAndSaveMindMap(String topic, String content, bool useGemini) async {
    _isLoading = true;
    _error = null; // Clear old errors
    notifyListeners();

    try {
      final rootChildren = await _agent.generateMindMap(
        topic: topic, 
        content: content, 
        useGemini: useGemini
      );
      
      if (rootChildren.isEmpty) {
        _error = "AI returned empty content. Please try again.";
      } else {
        // If the AI returns multiple roots (rare), wrap them. 
        // If it returns 1 root, use it directly.
        List<WorkflowNode> finalNodes = rootChildren;
        // Print the finalNodes for debugging

        // Safety check: Ensure we have a valid structure
        if (finalNodes.length > 1) {
           final wrapper = WorkflowNode(title: topic, description: "Knowledge Graph", children: finalNodes);
           finalNodes = [wrapper];
        }

        _mindMaps.add(SavedMindMap(
          id: DateTime.now().toString(),
          title: topic,
          category: "Generated",
          createdAt: DateTime.now(),
          nodes: finalNodes,
        ));
        print('[DEBUG] finalNodes:');
        for (var node in finalNodes) {
          print(node.toString());
        }
      }

    } catch (e) {
      print("Provider Error: $e");
      _error = "Failed to generate: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // C. Delete
  void deleteMaterial(LearningMaterial item) {
    _materials.remove(item);
    notifyListeners();
  }
  
  void deleteMindMap(SavedMindMap item) {
    _mindMaps.remove(item);
    notifyListeners();
  }
}