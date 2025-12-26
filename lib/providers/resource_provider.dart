import 'package:flutter/material.dart';
import '../models/entities/resource.dart';
import '../models/entities/workflow_node.dart';
import '../agents/resource_agent.dart';
import '../services/smart_file_resolver.dart';

class ResourceProvider extends ChangeNotifier {
  final ResourceAgent _agent = ResourceAgent();
  final SmartFileResolver _resolver = SmartFileResolver(); // <--- Use Resolver
  
  // Storage
  final List<LearningMaterial> _materials = [];
  final List<SavedMindMap> _mindMaps = [];
  
  bool _isLoading = false;

  List<LearningMaterial> get materials => _materials;
  List<SavedMindMap> get mindMaps => _mindMaps;
  bool get isLoading => _isLoading;

  // --- ACTIONS ---

  Future<void> fetchAndSaveMaterials(String topic, bool useGemini) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 1. Get Search Queries from Agent
      final rawMaterials = await _agent.findMaterials(topic, useGemini);
      
      List<LearningMaterial> resolvedMaterials = [];

      for (var item in rawMaterials) {
        print('[DEBUG] Raw Material: ${item.title}, URL: ${item.url}, Type: ${item.type}');
        String finalUrl = item.url; // Starts as the  URL
        String description = item.description;

        // 1. Extract query from the  URL we built in Agent
        // item.url looks like "https://.sm.cn/s?q=xxxx"
        // We decode the 'q' param to get the raw query string for the Resolver
        String rawQuery = "";
        try {
          Uri uri = Uri.parse(item.url);
          rawQuery = uri.queryParameters['q'] ?? item.title;
        } catch (_) {
          rawQuery = item.title;
        }

        // 2. Try to resolve DIRECT file link
        if (item.type == ResourceType.pdf || item.type == ResourceType.ppt || item.type == ResourceType.doc) {
          
          String? directLink = await _resolver.findDirectFileLink(rawQuery);
          
          if (directLink != null) {
            finalUrl = directLink;
            description = "Direct Download Available"; 
          } else {
  
            // thanks to the fix in ResourceAgent.
            description = "Opens in  Search";
          }
        }

        resolvedMaterials.add(LearningMaterial(
          id: item.id,
          title: item.title,
          url: finalUrl,
          description: description,
          type: item.type,
          category: item.category
        ));
      }

      _materials.addAll(resolvedMaterials);
    } catch (e) {
      print("Material Error: $e");
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


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