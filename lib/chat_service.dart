import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

class ChefChatService {
  static const List<String> _apiKeys = [
    String.fromEnvironment('GROQ_API_KEY', defaultValue: 'YOUR_GROQ_API_KEY_HERE')
  ];


  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  static const String _visionModel =
      'meta-llama/llama-4-scout-17b-16e-instruct';
  static const String _textModel = 'llama-3.1-8b-instant';

  /// Send text-only or image + text message to the AI sous-chef
  Future<String> sendMessage({String? message, File? imageFile}) async {
    if (message == null && imageFile == null) {
      return 'Please type a question or attach a photo of your ingredients.';
    }

    for (int i = 0; i < _apiKeys.length; i++) {
      try {
        if (imageFile != null) {
          return await _sendImageRequest(imageFile, _apiKeys[i], message);
        } else {
          return await _sendTextRequest(message!, _apiKeys[i]);
        }
      } catch (e) {
        print('Exception with API key ${i + 1}: $e');
        continue;
      }
    }

    return "I'm a little busy right now. Please try again in a moment!";
  }

  /// Text-only request
  Future<String> _sendTextRequest(String message, String apiKey) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _textModel,
        'messages': [
          {
            'role': 'system',
            'content': '''You are Ingrechef AI, a friendly and expert personal sous-chef assistant. 
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
If the user lists ingredients, always suggest at least 2-3 specific meal ideas.'''
          },
          {'role': 'user', 'content': message}
        ],
        'temperature': 0.75,
        'max_tokens': 1024,
        'top_p': 0.9,
        'stream': false,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['choices'] != null && data['choices'].isNotEmpty) {
        return data['choices'][0]['message']['content'] ?? 'No response received.';
      }
    } else if (response.statusCode == 429) {
      throw Exception('Rate limit exceeded');
    } else {
      throw Exception('API Error ${response.statusCode}: ${response.body}');
    }
    throw Exception('No valid response received');
  }

  /// Image + optional text request
  Future<String> _sendImageRequest(
      File imageFile, String apiKey, String? additionalText) async {
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

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _visionModel,
        'messages': [
          {
            'role': 'system',
            'content':
                '''You are Ingrechef AI, an expert culinary vision assistant. You can look at photos of ingredients, fridges, or dishes and provide:
- Ingredient identification
- Meal ideas using what is visible
- Zero-waste cooking tips
- Nutrition estimates
- Step-by-step cooking guidance

Always be encouraging, fun, and practical.'''
          },
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mimeType;base64,$base64Image'
                }
              }
            ]
          }
        ],
        'temperature': 0.7,
        'max_completion_tokens': 1024,
        'top_p': 0.9,
        'stream': false,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['choices'] != null && data['choices'].isNotEmpty) {
        return data['choices'][0]['message']['content'] ?? 'No response received.';
      }
    } else if (response.statusCode == 429) {
      throw Exception('Rate limit exceeded');
    } else {
      throw Exception('API Error ${response.statusCode}: ${response.body}');
    }
    throw Exception('No valid response received');
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
