import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

class LinkService {
  
  Future<String?> fetchFirstRealLink(String query) async {
    try {
      // 1. Request  Search Page
      final uri = Uri.parse("https://.sm.cn/s?q=${Uri.encodeComponent(query)}");
      
      final response = await http.get(uri, headers: {
        "User-Agent": "Mozilla/5.0 (Linux; Android 10; SM-G960F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Mobile Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      });

      if (response.statusCode != 200) return null;

      // 2. Parse HTML
      var document = parser.parse(response.body);
      
      // 3. Find Result Links
      //  mobile web results often use specific classes. 
      // We look for general 'a' tags that look like external file links.
      var linkTags = document.getElementsByTagName('a');
      
      for (var link in linkTags) {
        String? href = link.attributes['href'];
        
        // Filter for interesting files
        if (href != null && href.startsWith("http")) {
          // If it looks like a direct file
          if (href.endsWith(".pdf") || href.endsWith(".doc") || href.endsWith(".ppt")) {
            print(" Resolved: $href");
            return href;
          }
        }
      }
    } catch (e) {
      print(" Scrape Error: $e");
    }
    
    // --- FALLBACK (Since simple scraping is hard on modern sites) ---
    // If we can't scrape a "Real" URL (because of JS rendering), 
    // we return NULL. The UI will then open the  Search Page 
    // in the internal browser, which is the standard behavior for aggregators.
    
    // DEMO ONLY: If you want to see the PDF Viewer open for testing:
    if (query.contains("pdf")) {
       // return "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf";
    }
    
    return null;
  }
}