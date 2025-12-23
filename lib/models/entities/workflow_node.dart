import 'dart:math';
import 'base_node.dart';

class WorkflowNode extends BaseNode {
  List<WorkflowNode> children;
  bool isLoading;
  bool isExpanded;
  
  // 1. ADD THIS FIELD
  bool isSelected; 

  WorkflowNode({
    String? id,
    required super.title,
    super.description,
    this.children = const [],
    this.isLoading = false,
    this.isExpanded = false,
    this.isSelected = false, // Default to false
  }) : super(id: id ?? "${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}");

  factory WorkflowNode.fromJson(Map<String, dynamic> json) {
    return WorkflowNode(
      title: json['title'] ?? "New Step",
      description: json['description'] ?? "",
      children: (json['steps'] as List?)
              ?.map((e) => WorkflowNode.fromJson(e))
              .toList() ?? [],
    );
  }
}