import 'package:http/http.dart' as http;

class SmartFileResolver {
  
  /// Scans Bing CN results for any direct file link.
  /// Uses Regex instead of HTML parsing for robustness.
  Future<String?> findDirectFileLink(String query) async {
    print("SmartResolver: Hunting for file with query: '$query'...");
    
    try {
      // Use Bing CN. It is the friendliest for direct links in China.
      final uri = Uri.parse("https://cn.bing.com/search?q=${Uri.encodeComponent(query)}");
      
      final response = await http.get(uri, headers: {
        // Pretend to be a real Desktop Browser to get full HTML
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml",
        "Cookie": "SRCHHPGUSR=CW=1600&CH=900; _EDGE_S=F=1;"
      });

      if (response.statusCode != 200) return null;

      final body = response.body;

      // --- STRATEGY: REGEX HUNTING ---
      // Instead of parsing DOM, look for patterns like: href="http....pdf"
      // This bypasses complex DOM structures.
      
      // 1. Find all http/https links ending in typical document extensions
      final regex = RegExp(r'href="(https?://[^"]+\.(pdf|pptx|ppt|docx|doc))"', caseSensitive: false);
      final matches = regex.allMatches(body);

      for (final match in matches) {
        String? url = match.group(1);
        if (url != null) {
          // Filter out garbage (sometimes tracking pixels end in .doc)
          if (url.contains("bing.com") || url.contains("microsoft.com")) continue;
          
          print("SmartResolver: FOUND DIRECT LINK -> $url");
          return url;
        }
      }
      
      print("SmartResolver: No direct links found in HTML.");
    } catch (e) {
      print("SmartResolver Error: $e");
    }
    return null;
  }
}