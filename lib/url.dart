class Url {
  // ── Change ONLY this one line when your backend IP changes ──
  static const String base = 'http://10.123.213.10:5000';

  // ── Auth ──
  static const String signup           = '$base/signup';
  static const String login            = '$base/login';
  static const String logout           = '$base/logout';
  static const String getCurrentUser   = '$base/get_current_user';

  // ── Profile ──
  static const String updateProfile    = '$base/update_profile';

  // ── Ingredients ──
  static const String addIngredient    = '$base/add_ingredient';
  static const String getIngredients   = '$base/get_ingredients';
  static const String deleteIngredient = '$base/delete_ingredient';
  static const String clearIngredients = '$base/clear_ingredients';

  // ── Meal Generation ──
  static const String generateMeals   = '$base/generate_meals';

  // ── Saved Meals ──
  static const String saveMeal        = '$base/save_meal';
  static const String getSavedMeals   = '$base/get_saved_meals';
  static const String unsaveMeal      = '$base/unsave_meal';

  // ── Cooking History ──
  static const String addHistory      = '$base/add_cooking_history';
  static const String getHistory      = '$base/get_cooking_history';

  // ── Shopping ──
  static const String addShoppingItem         = '$base/add_shopping_item';
  static const String getShoppingList         = '$base/get_shopping_list';
  static const String toggleShoppingItem      = '$base/toggle_shopping_item';
  static const String deleteShoppingItem      = '$base/delete_shopping_item';
  static const String clearCompletedShopping  = '$base/clear_completed_shopping';

  // ── Stats ──
  static const String getUserStats     = '$base/get_user_stats';

  // ── Email ──
  static const String sendMealReminder = '$base/send_meal_reminder';
}
