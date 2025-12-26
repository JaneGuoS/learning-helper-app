import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/resource_provider.dart';
import '../../models/entities/resource.dart';
<<<<<<< Updated upstream
import 'draggable_flowchart_screen.dart';
=======
import 'internal_browser_screen.dart';
import 'internal_pdf_viewer.dart';
>>>>>>> Stashed changes
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

  IconData _getIcon(ResourceType type) {
    switch (type) {
      case ResourceType.pdf: return Icons.picture_as_pdf;
      case ResourceType.ppt: return Icons.slideshow;
      case ResourceType.doc: return Icons.description;
      case ResourceType.video: return Icons.play_circle_filled;
      default: return Icons.search;
    }
  }

  // Helper to open resources
  void _handleOpen(BuildContext context, LearningMaterial item, bool isDirectFile) {
    if (isDirectFile && item.type == ResourceType.pdf) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InternalPdfViewer(url: item.url, title: item.title)
        )
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InternalBrowserScreen(url: item.url, title: item.title)
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResourceProvider>();
    
    // Grouping Logic
    final Map<String, List<LearningMaterial>> grouped = {};
    for (var m in provider.materials) {
      if (!grouped.containsKey(m.category)) grouped[m.category] = [];
      grouped[m.category]!.add(m);
    }

    if (grouped.isEmpty) return const Center(child: Text("No materials saved."));

    return ListView(
      padding: const EdgeInsets.all(16),
      // --- THE FIX IS HERE: .toList() ---
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
<<<<<<< Updated upstream
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
=======
              child: Chip(
                avatar: const Icon(Icons.folder_open, size: 16),
                label: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold))
>>>>>>> Stashed changes
              ),
            ),
            ...entry.value.map((item) {
              
              // Determine if Direct or Search
              bool isDirectFile = !item.url.contains("quark.sm.cn") && 
                                  !item.url.contains("baidu.com") &&
                                  (item.url.endsWith(".pdf") || item.url.endsWith(".ppt") || item.url.endsWith(".doc") || item.url.endsWith(".docx"));

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade50,
                    child: Icon(_getIcon(item.type), color: Colors.deepPurple),
                  ),
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    isDirectFile ? "Direct File Download" : "Opens Quark Search",
                    style: TextStyle(
                      fontSize: 12, 
                      color: isDirectFile ? Colors.green[700] : Colors.blue[700],
                      fontWeight: FontWeight.w500
                    )
                  ),
                  trailing: Container(
                    decoration: BoxDecoration(
                      color: isDirectFile ? Colors.green.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDirectFile ? Colors.green.shade200 : Colors.blue.shade200
                      )
                    ),
                    child: IconButton(
                      icon: Icon(
                        isDirectFile ? Icons.file_download_done : Icons.travel_explore,
                        color: isDirectFile ? Colors.green : Colors.blue
                      ),
                      tooltip: isDirectFile ? "Open File" : "Search in Quark",
                      onPressed: () => _handleOpen(context, item, isDirectFile),
                    ),
                  ),
                  onTap: () => _handleOpen(context, item, isDirectFile),
                ),
              );
            })
          ],
        );
      }).toList(), // <--- CRITICAL FIX: Convert Iterable to List
    );
  }
<<<<<<< Updated upstream

  IconData _getIcon(ResourceType type) {
    switch (type) {
      case ResourceType.pdf: return Icons.picture_as_pdf;
      case ResourceType.video: return Icons.play_circle;
      case ResourceType.book: return Icons.menu_book;
      default: return Icons.link;
    }
  }
=======
>>>>>>> Stashed changes
}