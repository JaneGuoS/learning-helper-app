import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/resource_provider.dart';
import '../../models/entities/resource.dart';
import 'draggable_flowchart_screen.dart';
import 'mindmap_screen.dart'; // Reuse your visualizer

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Resource Library"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.hub), text: "Mind Maps"),
              Tab(icon: Icon(Icons.library_books), text: "Materials"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MindMapList(),
            _MaterialList(),
          ],
        ),
      ),
    );
  }
}

class _MindMapList extends StatelessWidget {
  const _MindMapList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResourceProvider>();
    
    if (provider.mindMaps.isEmpty) {
      return const Center(child: Text("No Mind Maps generated yet."));
    }

    return ListView.builder(
      itemCount: provider.mindMaps.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final map = provider.mindMaps[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.hub)),
            title: Text(map.title),
            subtitle: Text("Created: ${map.createdAt.toString().substring(0,10)}"),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => provider.deleteMindMap(map),
            ),
            onTap: () {
              // Open your existing Draggable Flowchart
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => MindmapScreen(nodes: map.nodes)
              ));
            },
          ),
        );
      },
    );
  }
}

class _MaterialList extends StatelessWidget {
  const _MaterialList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResourceProvider>();
    
    // Group by Category
    final Map<String, List<LearningMaterial>> grouped = {};
    for (var m in provider.materials) {
      if (!grouped.containsKey(m.category)) grouped[m.category] = [];
      grouped[m.category]!.add(m);
    }

    if (grouped.isEmpty) return const Center(child: Text("No materials saved."));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Chip(label: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold))),
            ),
            ...entry.value.map((item) => Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(_getIcon(item.type), color: Colors.deepPurple),
                title: Text(item.title),
                subtitle: Text(item.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => provider.deleteMaterial(item),
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Opening Link... (Simulated)"))
                  );
                },
              ),
            ))
          ],
        );
      }).toList(),
    );
  }

  IconData _getIcon(ResourceType type) {
    switch (type) {
      case ResourceType.pdf: return Icons.picture_as_pdf;
      case ResourceType.video: return Icons.play_circle;
      case ResourceType.book: return Icons.menu_book;
      default: return Icons.link;
    }
  }
}