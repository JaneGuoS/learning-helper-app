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

  // B. Generate & Save MindMap
  Future<void> createAndSaveMindMap(String topic, bool useGemini) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 1. Generate the Tree
      final rootChildren = await _agent.generateMindMap(topic, useGemini);
      
      // 2. Wrap it in a single Root Node for the visualizer
      final rootNode = WorkflowNode(
        title: topic, 
        description: "Central Topic", 
        children: rootChildren
      );

      // 3. Save
      _mindMaps.add(SavedMindMap(
        id: DateTime.now().toString(),
        title: topic,
        category: "General",
        createdAt: DateTime.now(),
        nodes: [rootNode], // The visualizer expects a list
      ));

    } catch (e) {
      print("MindMap Error: $e");
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