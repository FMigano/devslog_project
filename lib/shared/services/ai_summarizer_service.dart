import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/ollama_config.dart';

class AiSummarizerService {
  final String _baseUrl = OllamaConfig.baseUrl;
  bool _isAvailable = false;
  
  AiSummarizerService() {
    _checkAvailability();
  }
  
  Future<void> _checkAvailability() async {
    _isAvailable = await OllamaConfig.checkAvailability();
    if (!_isAvailable) {
      print('⚠️ Ollama is not available. AI features will be disabled.');
      print('💡 Start Ollama with: ollama serve');
    } else {
      print('✅ Ollama is available and ready!');
    }
  }
  
  /// Check if AI features are available
  Future<bool> isAvailable() async {
    if (!_isAvailable) {
      await _checkAvailability();
    }
    return _isAvailable;
  }
  
  /// Generate topic suggestions from post content
  Future<List<String>> generateTopicSuggestions(String title, String content) async {
    if (!await isAvailable()) {
      print('⚠️ AI not available, returning empty tags');
      return [];
    }

    try {
      final cleanContent = _stripHtml(content);
      final prompt = '''
Analyze this developer forum post and suggest 5-8 relevant technical tags/topics.
Return ONLY a comma-separated list of lowercase tags, no explanations.

Title: $title
Content: ${cleanContent.length > 500 ? cleanContent.substring(0, 500) + '...' : cleanContent}

Examples: flutter, dart, firebase, api, debugging, performance, ui-ux, android, ios, web

Tags:''';

      print('🤖 Sending request to Ollama...');
      
      final response = await http.post(
        Uri.parse('$_baseUrl${OllamaConfig.generateEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': OllamaConfig.defaultModel,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': 0.7,
            'top_p': 0.9,
            'num_predict': 50,
          }
        }),
      ).timeout(Duration(seconds: OllamaConfig.shortTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tagsText = (data['response'] as String)
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s,\-]'), '');
        
        final tags = tagsText
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty && tag.length > 2 && tag.length < 30)
            .toList();
        
        print('✅ Generated ${tags.length} tags: $tags');
        return tags.take(8).toList();
      }
      
      print('⚠️ Ollama returned status: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ AI Tag Generation Error: $e');
      return [];
    }
  }
  
  /// Generate post summary for previews
  Future<String> generateSummary(String content) async {
    if (!await isAvailable()) {
      return _extractFirstSentences(content, 2);
    }

    try {
      final cleanContent = _stripHtml(content);
      final prompt = '''
Summarize this technical post in 2-3 concise sentences.

Content: ${cleanContent.length > 1000 ? cleanContent.substring(0, 1000) + '...' : cleanContent}

Summary:''';

      final response = await http.post(
        Uri.parse('$_baseUrl${OllamaConfig.generateEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': OllamaConfig.defaultModel,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': 0.5,
            'num_predict': 150,
          }
        }),
      ).timeout(Duration(seconds: OllamaConfig.shortTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final summary = (data['response'] as String).trim();
        return summary.isNotEmpty ? summary : _extractFirstSentences(content, 2);
      }
      
      return _extractFirstSentences(content, 2);
    } catch (e) {
      print('Summary Error: $e');
      return _extractFirstSentences(content, 2);
    }
  }
  
  /// Generate search query suggestions
  Future<List<String>> generateSearchSuggestions(String query) async {
    if (!await isAvailable() || query.length < 3) {
      return [];
    }

    try {
      final prompt = '''
Given the search query "$query", suggest 3 related search terms.
Return only comma-separated terms.

Suggestions:''';

      final response = await http.post(
        Uri.parse('$_baseUrl${OllamaConfig.generateEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': OllamaConfig.defaultModel,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': 0.8,
            'num_predict': 30,
          }
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['response'] as String)
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .take(3)
            .toList();
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }
  
  // ==================== NEW FEATURES ====================
  
  /// 1. Post Content Enhancement - Suggest improvements to post content
  Future<Map<String, dynamic>> enhancePostContent(String title, String content) async {
    if (!await isAvailable()) {
      return {
        'suggestions': <String>[],
        'improvedTitle': title,
        'error': 'AI not available',
      };
    }

    try {
      final cleanContent = _stripHtml(content);
      final prompt = '''
Analyze this developer forum post and provide improvement suggestions.

Title: $title
Content: ${cleanContent.substring(0, cleanContent.length > 800 ? 800 : cleanContent.length)}

Provide:
1. Three specific suggestions to improve the post (one per line)
2. An improved, more engaging title (on a new line after "TITLE:")

Format:
SUGGESTIONS:
- [suggestion 1]
- [suggestion 2]
- [suggestion 3]
TITLE:
[improved title]
''';

      final response = await http.post(
        Uri.parse('$_baseUrl${OllamaConfig.generateEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': OllamaConfig.defaultModel,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': 0.7,
            'num_predict': 200,
          }
        }),
      ).timeout(Duration(seconds: OllamaConfig.longTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['response'] as String;
        
        // Parse the response
        final suggestions = <String>[];
        String improvedTitle = title;
        
        final lines = result.split('\n');
        bool inSuggestions = false;
        bool inTitle = false;
        
        for (var line in lines) {
          line = line.trim();
          if (line.contains('SUGGESTIONS:')) {
            inSuggestions = true;
            continue;
          }
          if (line.contains('TITLE:')) {
            inSuggestions = false;
            inTitle = true;
            continue;
          }
          
          if (inSuggestions && line.startsWith('-')) {
            suggestions.add(line.substring(1).trim());
          } else if (inTitle && line.isNotEmpty) {
            improvedTitle = line;
            break;
          }
        }
        
        return {
          'suggestions': suggestions.take(3).toList(),
          'improvedTitle': improvedTitle,
        };
      }
      
      return {
        'suggestions': <String>[],
        'improvedTitle': title,
      };
    } catch (e) {
      print('Content Enhancement Error: $e');
      return {
        'suggestions': <String>[],
        'improvedTitle': title,
        'error': e.toString(),
      };
    }
  }
  
  /// 2. Generate helpful comment suggestions
  Future<List<String>> generateCommentSuggestions(String postTitle, String postContent) async {
    if (!await isAvailable()) {
      return [];
    }

    try {
      final cleanContent = _stripHtml(postContent);
      final prompt = '''
Based on this developer post, suggest 3 helpful comments or questions that would add value to the discussion.

Title: $postTitle
Content: ${cleanContent.substring(0, cleanContent.length > 500 ? 500 : cleanContent.length)}

Provide 3 constructive comments (one per line):
1.
2.
3.
''';

      final response = await http.post(
        Uri.parse('$_baseUrl${OllamaConfig.generateEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': OllamaConfig.defaultModel,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': 0.8,
            'num_predict': 150,
          }
        }),
      ).timeout(Duration(seconds: OllamaConfig.shortTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['response'] as String;
        
        return result
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty && line.length > 10)
            .map((line) => line.replaceFirst(RegExp(r'^[\d\.\-\*]+\s*'), ''))
            .take(3)
            .toList();
      }
      
      return [];
    } catch (e) {
      print('Comment Suggestions Error: $e');
      return [];
    }
  }
  
  /// 3. Code Review - Provide feedback on code snippets
  Future<Map<String, dynamic>> reviewCode(String code, String language) async {
    if (!await isAvailable()) {
      return {
        'review': 'AI not available for code review',
        'suggestions': <String>[],
        'severity': 'info',
      };
    }

    try {
      final prompt = '''
Review this $language code and provide:
1. Overall assessment (Good/Needs Improvement/Critical Issues)
2. Specific suggestions for improvement (max 4)
3. Security or performance concerns

Code:
```$language
$code
```

Format:
ASSESSMENT: [Good/Needs Improvement/Critical Issues]
SUGGESTIONS:
- [suggestion 1]
- [suggestion 2]
CONCERNS:
- [concern if any]
''';

      final response = await http.post(
        Uri.parse('$_baseUrl${OllamaConfig.generateEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': OllamaConfig.codeModel,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': 0.3,
            'num_predict': 300,
          }
        }),
      ).timeout(Duration(seconds: OllamaConfig.longTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['response'] as String;
        
        String assessment = 'Good';
        final suggestions = <String>[];
        final concerns = <String>[];
        
        final lines = result.split('\n');
        String currentSection = '';
        
        for (var line in lines) {
          line = line.trim();
          if (line.contains('ASSESSMENT:')) {
            assessment = line.split(':').last.trim();
            continue;
          }
          if (line.contains('SUGGESTIONS:')) {
            currentSection = 'suggestions';
            continue;
          }
          if (line.contains('CONCERNS:')) {
            currentSection = 'concerns';
            continue;
          }
          
          if (line.startsWith('-') && line.length > 2) {
            if (currentSection == 'suggestions') {
              suggestions.add(line.substring(1).trim());
            } else if (currentSection == 'concerns') {
              concerns.add(line.substring(1).trim());
            }
          }
        }
        
        return {
          'assessment': assessment,
          'suggestions': suggestions.take(4).toList(),
          'concerns': concerns,
          'severity': concerns.isNotEmpty ? 'warning' : 'info',
        };
      }
      
      return {
        'review': 'Unable to review code',
        'suggestions': <String>[],
        'severity': 'info',
      };
    } catch (e) {
      print('Code Review Error: $e');
      return {
        'review': 'Error reviewing code: $e',
        'suggestions': <String>[],
        'severity': 'error',
      };
    }
  }
  
  /// 4. Duplicate Detection - Find similar posts
  Future<double> calculateSimilarity(String title1, String content1, String title2, String content2) async {
    if (!await isAvailable()) {
      // Fallback: simple keyword matching
      final keywords1 = _extractKeywords(title1 + ' ' + content1);
      final keywords2 = _extractKeywords(title2 + ' ' + content2);
      
      final intersection = keywords1.toSet().intersection(keywords2.toSet()).length;
      final union = keywords1.toSet().union(keywords2.toSet()).length;
      
      return union > 0 ? intersection / union : 0.0;
    }

    try {
      final clean1 = _stripHtml(content1).substring(0, 300);
      final clean2 = _stripHtml(content2).substring(0, 300);
      
      final prompt = '''
Compare these two posts and rate their similarity from 0-100.
Return ONLY a number.

Post 1:
Title: $title1
Content: $clean1

Post 2:
Title: $title2
Content: $clean2

Similarity score (0-100):''';

      final response = await http.post(
        Uri.parse('$_baseUrl${OllamaConfig.generateEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': OllamaConfig.defaultModel,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': 0.3,
            'num_predict': 10,
          }
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final scoreText = (data['response'] as String).trim();
        final score = double.tryParse(scoreText.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
        return score / 100.0; // Normalize to 0-1
      }
      
      return 0.0;
    } catch (e) {
      print('Similarity Calculation Error: $e');
      return 0.0;
    }
  }
  
  /// 5. Smart Notifications - Prioritize notifications
  Future<Map<String, dynamic>> prioritizeNotification(
    String notificationType,
    String content,
    Map<String, dynamic> userPreferences,
  ) async {
    if (!await isAvailable()) {
      // Default prioritization
      return {
        'priority': 'medium',
        'shouldNotify': true,
        'reason': 'Default prioritization',
      };
    }

    try {
      final prompt = '''
Analyze this notification and determine its priority for the user.

Type: $notificationType
Content: $content
User interests: ${userPreferences['interests'] ?? 'general development'}

Respond with:
PRIORITY: [high/medium/low]
NOTIFY: [yes/no]
REASON: [one sentence explanation]
''';

      final response = await http.post(
        Uri.parse('$_baseUrl${OllamaConfig.generateEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': OllamaConfig.defaultModel,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': 0.5,
            'num_predict': 80,
          }
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['response'] as String;
        
        String priority = 'medium';
        bool shouldNotify = true;
        String reason = 'Standard notification';
        
        for (var line in result.split('\n')) {
          if (line.contains('PRIORITY:')) {
            priority = line.split(':').last.trim().toLowerCase();
          } else if (line.contains('NOTIFY:')) {
            shouldNotify = line.split(':').last.trim().toLowerCase() == 'yes';
          } else if (line.contains('REASON:')) {
            reason = line.split(':').last.trim();
          }
        }
        
        return {
          'priority': priority,
          'shouldNotify': shouldNotify,
          'reason': reason,
        };
      }
      
      return {
        'priority': 'medium',
        'shouldNotify': true,
        'reason': 'Unable to analyze',
      };
    } catch (e) {
      print('Notification Prioritization Error: $e');
      return {
        'priority': 'medium',
        'shouldNotify': true,
        'reason': 'Error in analysis',
      };
    }
  }
  
  // Helper methods
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .trim();
  }
  
  String _extractFirstSentences(String text, int count) {
    final clean = _stripHtml(text);
    if (clean.isEmpty) return '';
    
    final sentences = clean.split(RegExp(r'[.!?]\s+'));
    final result = sentences.take(count).join('. ');
    
    if (result.isEmpty) {
      return clean.length > 150 ? clean.substring(0, 150) + '...' : clean;
    }
    
    return result + (sentences.length > count ? '...' : '');
  }
  
  List<String> _extractKeywords(String text) {
    final clean = _stripHtml(text).toLowerCase();
    return clean
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 3)
        .take(20)
        .toList();
  }
}