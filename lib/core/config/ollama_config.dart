import 'package:http/http.dart' as http;

class OllamaConfig {
  // Local development (Windows/Mac/Linux)
  static const String baseUrl = 'http://localhost:11434';
  
  // Model configuration
  static const String defaultModel = 'llama3.2';
  static const String codeModel = 'codellama'; // For code-related tasks
  
  // Timeout settings
  static const int shortTimeout = 30; // For quick responses
  static const int longTimeout = 120; // For complex tasks
  
  // API endpoints
  static const String generateEndpoint = '/api/generate';
  static const String chatEndpoint = '/api/chat';
  static const String tagsEndpoint = '/api/tags';
  
  // CORS handling for web
  static bool get isWeb => identical(0, 0.0);
  static bool get isLocalhost => baseUrl.contains('localhost');
  
  // Helper to check if Ollama is available
  static Future<bool> checkAvailability() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$tagsEndpoint'),
      ).timeout(Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}