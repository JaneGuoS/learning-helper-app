import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/plan_provider.dart';
import '../../models/entities/plan_node.dart';

class LearningPlanScreen extends StatelessWidget {
  const LearningPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlanProvider>();
    final nodes = provider.planNodes;

    // Group nodes by Date Key (e.g., "2023-10-25")
    final Map<String, List<PlanNode>> groupedNodes = {};
    for (var node in nodes) {
      String dateKey = DateFormat('yyyy-MM-dd').format(node.scheduledDate);
      if (!groupedNodes.containsKey(dateKey)) {
        groupedNodes[dateKey] = [];
      }
      groupedNodes[dateKey]!.add(node);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Learning Schedule"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {}, // Future: Calendar View
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedNodes.keys.length,
        itemBuilder: (context, index) {
          String dateKey = groupedNodes.keys.elementAt(index);
          List<PlanNode> dailyTasks = groupedNodes[dateKey]!;
          DateTime date = DateTime.parse(dateKey);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- DATE HEADER ---
              _buildDateHeader(date),
              
              // --- TASK LIST FOR THAT DAY ---
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
              color: isToday ? Colors.blue : Colors.grey[800]
            ),
          ),
          if (isToday)
            Container(
              margin: const EdgeInsets.only(left: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(12)),
              child: const Text("Today", style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Time & Title
            Row(
              children: [
                Column(
                  children: [
                    Text(
                      DateFormat('h:mm a').format(node.scheduledDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      "${node.durationMinutes}m",
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Container(width: 2, height: 40, color: Colors.blue.shade100),
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
                        Text(node.description, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                    ],
                  ),
                ),
                Checkbox(
                  value: node.isCompleted, 
                  onChanged: (val) => provider.toggleTaskCompletion(node)
                )
              ],
            ),
            
            // Row 2: Checkpoints (If any)
            if (node.checkpoints.isNotEmpty && !node.isCompleted) ...[
              const Divider(),
              ...node.checkpoints.asMap().entries.map((entry) {
                int idx = entry.key;
                PlanCheckpoint cp = entry.value;
                return InkWell(
                  onTap: () => provider.toggleCheckpoint(node, idx),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Row(
                      children: [
                        Icon(
                          cp.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 16,
                          color: cp.isCompleted ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cp.title,
                          style: TextStyle(
                            fontSize: 13,
                            color: cp.isCompleted ? Colors.grey : Colors.black87
                          ),
                        )
                      ],
                    ),
                  ),
                );
              }),
            ]
          ],
        ),
      ),
    );
  }
}