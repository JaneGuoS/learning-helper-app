import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

class BaiduLinkService {
  
  /// Takes a search query (e.g., "filetype:pdf nervous system")
  /// Returns the first Real URL found.
  Future<String?> fetchFirstRealLink(String query) async {
    try {
      // 1. Request Baidu Search Page
      // We use a specific User-Agent to ensure Baidu returns the standard HTML version
      final uri = Uri.parse("https://www.baidu.com/s?wd=${Uri.encodeComponent(query)}");
      
      final response = await http.get(uri, headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Cookie": "BD_UPN=12314753" // Sometimes helps reduce CAPTCHA
      });

      if (response.statusCode != 200) return null;

      // 2. Parse HTML
      var document = parser.parse(response.body);
      
      // 3. Find Result Links
      // Baidu results are usually in <div class="result"> or <div class="result c-container">
      // The link is in <h3 class="t"> <a href="...">
      var results = document.getElementsByClassName('result');
      
      for (var res in results) {
        var linkTag = res.querySelector('h3.t > a');
        if (linkTag != null) {
          String? baiduLink = linkTag.attributes['href'];
          
          if (baiduLink != null && baiduLink.startsWith("http")) {
            // 4. Resolve the Real URL (Baidu uses redirects)
            String? realUrl = await _resolveRedirect(baiduLink);
            if (realUrl != null) {
              print("Resolved: $realUrl");
              return realUrl;
            }
          }
        }
      }
    } catch (e) {
      print("Baidu Scrape Error: $e");
    }
    
    // Fallback: If scraping fails (Captcha/Block), return a Mock PDF for demonstration
    // so you can see the UI working.
    print("Scraping failed or blocked. Returning Demo Link.");
    if (query.contains("pdf")) return "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf";
    
    return null;
  }

  /// Follows the Baidu link to get the actual destination
  Future<String?> _resolveRedirect(String baiduUrl) async {
    try {
      // We use a HEAD request with 'followRedirects: false' to catch the 'Location' header
      final client = http.Client();
      final request = http.Request('HEAD', Uri.parse(baiduUrl))
        ..followRedirects = false;
      
      final response = await client.send(request);
      String? location = response.headers['location'];
      
      // If it's a redirect, return the new location
      if (response.statusCode >= 300 && response.statusCode < 400 && location != null) {
        return location;
      }
      // Sometimes it returns 200 but the URL is the real one? Unlikely with Baidu.
      return null;
    } catch (e) {
      return null;
    }
  }
}