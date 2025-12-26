import 'package:flutter/material.dart';
import 'package:flutter_cached_pdfview/flutter_cached_pdfview.dart';
import 'internal_browser_screen.dart'; // Import Browser

class InternalPdfViewer extends StatelessWidget {
  final String url;
  final String title;

  const InternalPdfViewer({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 14)),
        actions: [
          // Fallback button
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: "Open in Web View",
            onPressed: () {
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (_) => InternalBrowserScreen(url: url, title: title))
              );
            },
          )
        ],
      ),
      body: const PDF(
        swipeHorizontal: true,
      ).cachedFromUrl(
        url,
        placeholder: (progress) => Center(child: Text('$progress %')),
        errorWidget: (error) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 10),
              const Text("Could not render PDF directly."),
              const Text("(Likely protected or requires login)"),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context, 
                    MaterialPageRoute(builder: (_) => InternalBrowserScreen(url: url, title: title))
                  );
                },
                child: const Text("Try Opening in Web Browser"),
              )
            ],
          ),
        ),
      ),
    );
  }
}