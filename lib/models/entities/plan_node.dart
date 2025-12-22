import 'base_node.dart';

class PlanCheckpoint {
  String title;
  bool isCompleted;

  PlanCheckpoint({required this.title, this.isCompleted = false});
}

class PlanNode extends BaseNode {
  DateTime scheduledDate;
  bool isCompleted;
  List<PlanCheckpoint> checkpoints;
  int durationMinutes;

  PlanNode({
    required super.id,
    required super.title,
    super.description,
    required this.scheduledDate,
    this.isCompleted = false,
    this.checkpoints = const [],
    this.durationMinutes = 60,
  });

  // Helper to get formatted time (e.g. "10:00 AM")
  // Note: formatting logic usually goes in UI, but this is a quick helper
  DateTime get endTime => scheduledDate.add(Duration(minutes: durationMinutes));
}