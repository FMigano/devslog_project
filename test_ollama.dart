import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('Testing Ollama connection...\n');
  
  try {
    final response = await http.post(
      Uri.parse('http://localhost:11434/api/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': 'llama3.2',
        'prompt': 'Say "Ollama is working!" in one sentence.',
        'stream': false,
      }),
    ).timeout(Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('✅ SUCCESS!');
      print('Response: ${data['response']}');
    } else {
      print('❌ Error: ${response.statusCode}');
      print(response.body);
    }
  } catch (e) {
    print('❌ Connection failed: $e');
    print('\nMake sure:');
    print('1. Ollama is installed');
    print('2. Model is downloaded: ollama pull llama3.2');
    print('3. Ollama service is running: ollama serve');
  }
}