import 'dart:convert';
import 'package:http/http.dart' as http;
import 'url.dart';

class ApiService {
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // ── generic helpers ────────────────────────────────────────

  static Future<Map<String, dynamic>> _post(
      String url, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(Uri.parse(url),
              headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> _get(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> _delete(
      String url, Map<String, dynamic> body) async {
    try {
      final res = await http
          .delete(Uri.parse(url),
              headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }

  // ── AUTH ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    String dietPref = '',
    String allergies = '',
  }) =>
      _post(Url.signup, {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'confirm_password': confirmPassword,
        'diet_pref': dietPref,
        'allergies': allergies,
      });

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) =>
      _post(Url.login, {'email': email, 'password': password});

  static Future<Map<String, dynamic>> logout() =>
      _post(Url.logout, {});

  static Future<Map<String, dynamic>> getCurrentUser() =>
      _get(Url.getCurrentUser);

  // ── PROFILE ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> updateProfile({
    required String email,
    String? name,
    String? phone,
    String? dietPref,
    String? allergies,
  }) =>
      _post(Url.updateProfile, {
        'email': email,
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (dietPref != null) 'diet_pref': dietPref,
        if (allergies != null) 'allergies': allergies,
      });

  // ── INGREDIENTS ────────────────────────────────────────────

  static Future<Map<String, dynamic>> addIngredient({
    required String userEmail,
    required String name,
    String quantity = '1 pc',
    String category = 'Other',
    String expiry = 'Unknown',
  }) =>
      _post(Url.addIngredient, {
        'user_email': userEmail,
        'name': name,
        'quantity': quantity,
        'category': category,
        'expiry': expiry,
      });

  static Future<Map<String, dynamic>> getIngredients(String email) =>
      _get('${Url.getIngredients}?email=$email');

  static Future<Map<String, dynamic>> deleteIngredient(int id) =>
      _delete(Url.deleteIngredient, {'id': id});

  static Future<Map<String, dynamic>> clearIngredients(String userEmail) =>
      _delete(Url.clearIngredients, {'user_email': userEmail});

  // ── MEAL GENERATION ────────────────────────────────────────

  static Future<Map<String, dynamic>> generateMeals({
    required String userEmail,
    String dietFilter = 'All',
  }) =>
      _post(Url.generateMeals, {
        'user_email': userEmail,
        'diet_filter': dietFilter,
      });

  // ── SAVED MEALS ────────────────────────────────────────────

  static Future<Map<String, dynamic>> saveMeal({
    required String userEmail,
    required String mealName,
    String emoji = '🍽️',
    int? cookTime,
    int? calories,
    String? difficulty,
    double? rating,
  }) =>
      _post(Url.saveMeal, {
        'user_email': userEmail,
        'meal_name': mealName,
        'emoji': emoji,
        if (cookTime != null) 'cook_time': cookTime,
        if (calories != null) 'calories': calories,
        if (difficulty != null) 'difficulty': difficulty,
        if (rating != null) 'rating': rating,
      });

  static Future<Map<String, dynamic>> getSavedMeals(String email) =>
      _get('${Url.getSavedMeals}?email=$email');

  static Future<Map<String, dynamic>> unsaveMeal(int id) =>
      _delete(Url.unsaveMeal, {'id': id});

  // ── COOKING HISTORY ────────────────────────────────────────

  static Future<Map<String, dynamic>> addCookingHistory({
    required String userEmail,
    required String mealName,
    String emoji = '🍽️',
    int servings = 1,
  }) =>
      _post(Url.addHistory, {
        'user_email': userEmail,
        'meal_name': mealName,
        'emoji': emoji,
        'servings': servings,
      });

  static Future<Map<String, dynamic>> getCookingHistory(String email) =>
      _get('${Url.getHistory}?email=$email');

  // ── SHOPPING LIST ──────────────────────────────────────────

  static Future<Map<String, dynamic>> addShoppingItem({
    required String userEmail,
    required String name,
    String quantity = '1 pc',
    String emoji = '🛒',
    String category = 'Other',
    String forMeal = 'General',
  }) =>
      _post(Url.addShoppingItem, {
        'user_email': userEmail,
        'name': name,
        'quantity': quantity,
        'emoji': emoji,
        'category': category,
        'for_meal': forMeal,
      });

  static Future<Map<String, dynamic>> getShoppingList(String email) =>
      _get('${Url.getShoppingList}?email=$email');

  static Future<Map<String, dynamic>> toggleShoppingItem(int id) =>
      _post(Url.toggleShoppingItem, {'id': id});

  static Future<Map<String, dynamic>> deleteShoppingItem(int id) =>
      _delete(Url.deleteShoppingItem, {'id': id});

  static Future<Map<String, dynamic>> clearCompletedShopping(
          String userEmail) =>
      _delete(Url.clearCompletedShopping, {'user_email': userEmail});

  // ── STATS ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getUserStats(String email) =>
      _get('${Url.getUserStats}?email=$email');

  // ── EMAIL ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> sendMealReminder({
    required String email,
    required List<String> expiringItems,
  }) =>
      _post(Url.sendMealReminder, {
        'email': email,
        'expiring_items': expiringItems,
      });
}
