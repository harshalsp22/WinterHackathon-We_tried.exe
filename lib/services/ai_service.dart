import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/diagnostic_plan.dart';

class AIService {
  // ✅ Define model as a constant for easy switching
  static const String _model = 'gemini-2.5-flash';

  Future<DiagnosticPlan> generatePlan(String prompt) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key not found');
    }
    final res = await http.get(
      Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey'
      ),
    );

    print('Available Models:');
    print(res.body);

    final url = 'https://generativelanguage.googleapis.com/v1beta/models/'
        '$_model:generateContent?key=$apiKey';

    print('Using model: $_model');

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "role": "user",
            "parts": [{"text": prompt}]
          }
        ],
        "generationConfig": {
          "temperature": 0.2,
          "responseMimeType": "application/json"
        }
      }),
    );

    print('Status Code: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('Gemini API failed: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    final text = decoded['candidates']?[0]?['content']?['parts']?[0]?['text'];

    if (text == null) {
      throw Exception('No text in response');
    }

    // Clean markdown if present
    String cleanedText = text.trim();
    if (cleanedText.startsWith('```json')) {
      cleanedText = cleanedText.substring(7);
    }
    if (cleanedText.startsWith('```')) {
      cleanedText = cleanedText.substring(3);
    }
    if (cleanedText.endsWith('```')) {
      cleanedText = cleanedText.substring(0, cleanedText.length - 3);
    }

    return DiagnosticPlan.fromJson(jsonDecode(cleanedText.trim()));
  }
}