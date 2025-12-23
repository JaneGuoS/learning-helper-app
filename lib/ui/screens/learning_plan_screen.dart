import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/plan_provider.dart';
import '../../models/entities/plan_node.dart';
import '../../models/entities/base_node.dart'; // Ensure ID generation

class LearningPlanScreen extends StatefulWidget {
  const LearningPlanScreen({super.key});

  @override
  State<LearningPlanScreen> createState() => _LearningPlanScreenState();
}

class _LearningPlanScreenState extends State<LearningPlanScreen> {
  
  // Open the Editor Dialog
  void _showEditor(BuildContext context, {PlanNode? node}) {
    showDialog(
      context: context,
      builder: (context) => _PlanEditorDialog(existingNode: node),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlanProvider>();
    final nodes = provider.planNodes;

    // Group nodes by Date
    final Map<String, List<PlanNode>> groupedNodes = {};
    for (var node in nodes) {
      String dateKey = DateFormat('yyyy-MM-dd').format(node.scheduledDate);
      if (!groupedNodes.containsKey(dateKey)) groupedNodes[dateKey] = [];
      groupedNodes[dateKey]!.add(node);
    }

    return Scaffold(
      appBar: AppBar(title: const Text("My Learning Schedule")),
      
      // ADD BUTTON
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(context),
        child: const Icon(Icons.add),
      ),

      body: nodes.isEmpty 
        ? const Center(child: Text("No plans yet. Tap + to add."))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedNodes.keys.length,
            itemBuilder: (context, index) {
              String dateKey = groupedNodes.keys.elementAt(index);
              List<PlanNode> dailyTasks = groupedNodes[dateKey]!;
              DateTime date = DateTime.parse(dateKey);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateHeader(date),
                  ...dailyTasks.map((node) => _buildTaskCard(context, node, provider)),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    bool isToday = DateFormat('yyyy-MM-dd').format(date) == 
                   DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            DateFormat('EEE, MMM d').format(date),
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: isToday ? Colors.deepPurple : Colors.grey[800]
            ),
          ),
          if (isToday)
            Container(
              margin: const EdgeInsets.only(left: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.deepPurple.shade100, borderRadius: BorderRadius.circular(12)),
              child: const Text("Today", style: TextStyle(color: Colors.deepPurple, fontSize: 12, fontWeight: FontWeight.bold)),
            )
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, PlanNode node, PlanProvider provider) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // TAP TO EDIT
        onTap: () => _showEditor(context, node: node),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    children: [
                      Text(DateFormat('h:mm a').format(node.scheduledDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text("${node.durationMinutes}m", style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Container(width: 2, height: 40, color: Colors.deepPurple.shade100),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.title, 
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.w600,
                            decoration: node.isCompleted ? TextDecoration.lineThrough : null,
                            color: node.isCompleted ? Colors.grey : Colors.black,
                          )
                        ),
                        if (node.description.isNotEmpty)
                          Text(node.description, style: TextStyle(color: Colors.grey[700], fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: node.isCompleted, 
                    onChanged: (val) => provider.toggleTaskCompletion(node)
                  )
                ],
              ),
              if (node.checkpoints.isNotEmpty && !node.isCompleted) ...[
                const Divider(),
                ...node.checkpoints.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                    child: Row(
                      children: [
                        Icon(entry.value.isCompleted ? Icons.check_circle : Icons.circle_outlined, size: 12, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(entry.value.title, style: const TextStyle(fontSize: 12, color: Colors.grey))
                      ],
                    ),
                  );
                }),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// --- THE EDITOR DIALOG ---
class _PlanEditorDialog extends StatefulWidget {
  final PlanNode? existingNode;

  const _PlanEditorDialog({this.existingNode});

  @override
  State<_PlanEditorDialog> createState() => _PlanEditorDialogState();
}

class _PlanEditorDialogState extends State<_PlanEditorDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _durationController = TextEditingController(text: "60");
  
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  
  // Dynamic Checkpoints (List of Strings for editing)
  List<String> _checkpoints = [];
  final TextEditingController _newCheckpointController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingNode != null) {
      final n = widget.existingNode!;
      _titleController.text = n.title;
      _descController.text = n.description;
      _durationController.text = n.durationMinutes.toString();
      _selectedDate = n.scheduledDate;
      _selectedTime = TimeOfDay.fromDateTime(n.scheduledDate);
      // Clone checkpoints to avoid modifying original until save
      _checkpoints = n.checkpoints.map((c) => c.title).toList();
    } else {
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, 
      initialDate: _selectedDate, 
      firstDate: DateTime.now().subtract(const Duration(days: 365)), 
      lastDate: DateTime.now().add(const Duration(days: 365))
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _save() {
    if (_titleController.text.isEmpty) return;

    final fullDateTime = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute
    );

    final provider = context.read<PlanProvider>();
    final newCheckpoints = _checkpoints.map((t) => PlanCheckpoint(title: t)).toList();

    if (widget.existingNode != null) {
      // UPDATE
      final updatedNode = PlanNode(
        id: widget.existingNode!.id,
        title: _titleController.text,
        description: _descController.text,
        scheduledDate: fullDateTime,
        durationMinutes: int.tryParse(_durationController.text) ?? 60,
        isCompleted: widget.existingNode!.isCompleted,
        checkpoints: newCheckpoints, // Simplification: resets completion of checkpoints on edit
      );
      provider.updatePlan(widget.existingNode!, updatedNode);
    } else {
      // ADD
      final newNode = PlanNode(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        description: _descController.text,
        scheduledDate: fullDateTime,
        durationMinutes: int.tryParse(_durationController.text) ?? 60,
        checkpoints: newCheckpoints
      );
      provider.addPlan(newNode);
    }
    Navigator.pop(context);
  }

  void _delete() {
    if (widget.existingNode != null) {
      context.read<PlanProvider>().deletePlan(widget.existingNode!);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingNode == null ? "New Plan" : "Edit Plan"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: "Title"), autofocus: true),
            const SizedBox(height: 10),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: "Description"), maxLines: 2),
            const SizedBox(height: 16),
            
            // DATE & TIME PICKER
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: "Date", border: OutlineInputBorder()),
                      child: Text(DateFormat('MMM d, y').format(_selectedDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _pickTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: "Time", border: OutlineInputBorder()),
                      child: Text(_selectedTime.format(context)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _durationController, 
              decoration: const InputDecoration(labelText: "Duration (min)", suffixText: "min"),
              keyboardType: TextInputType.number,
            ),
            
            const SizedBox(height: 20),
            const Text("Checkpoints", style: TextStyle(fontWeight: FontWeight.bold)),
            
            // ADD CHECKPOINT ROW
            Row(
              children: [
                Expanded(child: TextField(controller: _newCheckpointController, decoration: const InputDecoration(hintText: "Add sub-task..."))),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.deepPurple),
                  onPressed: () {
                    if (_newCheckpointController.text.isNotEmpty) {
                      setState(() {
                        _checkpoints.add(_newCheckpointController.text);
                        _newCheckpointController.clear();
                      });
                    }
                  },
                )
              ],
            ),
            
            // LIST OF CHECKPOINTS
            ..._checkpoints.asMap().entries.map((entry) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text("• ${entry.value}"),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 16), 
                  onPressed: () => setState(() => _checkpoints.removeAt(entry.key))
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        if (widget.existingNode != null)
          TextButton(onPressed: _delete, child: const Text("Delete", style: TextStyle(color: Colors.red))),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: _save, child: const Text("Save")),
      ],
    );
  }
}