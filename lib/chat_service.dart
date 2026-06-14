import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

class ChefChatService {
  static const String _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'YOUR_GEMINI_API_KEY_HERE',
  );

  static const String _model = 'gemini-2.5-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static const String _systemPrompt = '''You are Ingrechef AI, a friendly and expert personal sous-chef assistant. 
You specialise in:
- Turning leftover and pantry ingredients into delicious meals
- Zero-waste cooking tips and hacks
- Nutritional information and healthy eating advice
- Step-by-step cooking instructions for any skill level
- Ingredient substitutions when something is missing
- Meal prep and planning strategies
- Shopping list optimisation

Always give practical, concise, and encouraging advice. 
Use emojis where appropriate to keep the conversation fun. 
If the user lists ingredients, always suggest at least 2-3 specific meal ideas.''';

  /// Send text-only or image + text message to the AI sous-chef
  Future<String> sendMessage({String? message, File? imageFile}) async {
    if (message == null && imageFile == null) {
      return 'Please type a question or attach a photo of your ingredients.';
    }

    try {
      if (imageFile != null) {
        return await _sendImageRequest(imageFile, message);
      } else {
        return await _sendTextRequest(message!);
      }
    } catch (e) {
      print('Gemini API Error: $e');
      return "I'm a little busy right now. Please try again in a moment!";
    }
  }

  /// Text-only request
  Future<String> _sendTextRequest(String message) async {
    final url = Uri.parse('$_baseUrl?key=$_apiKey');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': message}
            ]
          }
        ],
        'systemInstruction': {
          'parts': [
            {'text': _systemPrompt}
          ]
        },
        'generationConfig': {
          'temperature': 0.75,
          'maxOutputTokens': 1024,
          'topP': 0.9,
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      try {
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        return text.trim();
      } catch (e) {
        throw Exception('Failed to parse Gemini response: ${response.body}');
      }
    } else {
      throw Exception('Gemini API Error ${response.statusCode}: ${response.body}');
    }
  }

  /// Image + optional text request
  Future<String> _sendImageRequest(File imageFile, String? additionalText) async {
    final fileSize = await imageFile.length();
    if (fileSize > 4 * 1024 * 1024) {
      return 'Image is too large. Please use an image smaller than 4 MB.';
    }

    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);
    final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';

    final prompt = '''Analyse this image as a culinary AI assistant. Please:

🥦 **Identify Ingredients**: List all food items or ingredients you can see
🍳 **Meal Suggestions**: Suggest 2-3 meals that can be made with these ingredients
♻️ **Zero Waste Tips**: Mention any tips to use every part without waste
⚡ **Quick Tip**: Give one immediate cooking tip or hack

${additionalText != null ? 'User note: $additionalText' : ''}

Keep the response practical and encouraging!''';

    final url = Uri.parse('$_baseUrl?key=$_apiKey');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
              {
                'inlineData': {
                  'mimeType': mimeType,
                  'data': base64Image,
                }
              }
            ]
          }
        ],
        'systemInstruction': {
          'parts': [
            {'text': _systemPrompt}
          ]
        },
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 1024,
          'topP': 0.9,
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      try {
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        return text.trim();
      } catch (e) {
        throw Exception('Failed to parse Gemini response: ${response.body}');
      }
    } else {
      throw Exception('Gemini API Error ${response.statusCode}: ${response.body}');
    }
  }
}

class ChatMessage {
  final String content;
  final bool isBot;
  final DateTime timestamp;
  final File? imageFile;

  ChatMessage({
    required this.content,
    required this.isBot,
    required this.timestamp,
    this.imageFile,
  });
}
