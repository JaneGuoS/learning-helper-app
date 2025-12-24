import 'base_node.dart';

// 1. Define the Priority Enum
enum PlanPriority { high, medium, low }

// 2. Define the Checkpoint Class
class PlanCheckpoint {
  String title;
  bool isCompleted;

  PlanCheckpoint({
    required this.title, 
    this.isCompleted = false
  });
}

// 3. Define the Main Plan Node
class PlanNode extends BaseNode {
  DateTime scheduledDate;
  int durationMinutes;
  bool isCompleted;
  List<PlanCheckpoint> checkpoints;
  
  // Advanced Agent Fields
  PlanPriority priority;
  bool isFixed; // If true, Agent cannot move/shrink this

  PlanNode({
    required super.id,
    required super.title,
    super.description,
    required this.scheduledDate,
    this.durationMinutes = 60,
    this.isCompleted = false,
    this.checkpoints = const [],
    this.priority = PlanPriority.medium, // Default
    this.isFixed = false, 
  });

  // Helper to calculate end time
  DateTime get endTime => scheduledDate.add(Duration(minutes: durationMinutes));
}