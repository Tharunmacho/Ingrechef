from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime
import smtplib
import pymysql
pymysql.install_as_MySQLdb()

app = Flask(__name__)
CORS(app)

# ─────────────────────────────────────────────
# DATABASE CONFIG  →  change user/pass/host/db
# ─────────────────────────────────────────────
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///ingrechef.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SECRET_KEY'] = 'ingrechef_secret_2024'

db = SQLAlchemy(app)

# ─────────────────────────────────────────────
# EMAIL CONFIG  →  replace with your Gmail + app‑password
# ─────────────────────────────────────────────
EMAIL_ADDRESS  = "youremail@gmail.com"
EMAIL_PASSWORD = "your_app_password_here"
SMTP_SERVER    = "smtp.gmail.com"
SMTP_PORT      = 587


# ══════════════════════════════════════════════
#  MODELS
# ══════════════════════════════════════════════

class User(db.Model):
    """Registered users."""
    __tablename__ = 'users'
    id            = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name          = db.Column(db.String(255), nullable=False)
    email         = db.Column(db.String(255), unique=True, nullable=False)
    phone         = db.Column(db.String(50),  nullable=False)
    password      = db.Column(db.String(512), nullable=False)
    diet_pref     = db.Column(db.String(255), nullable=True)   # e.g. "Vegetarian,Gluten-Free"
    allergies     = db.Column(db.String(255), nullable=True)   # e.g. "Peanuts,Soy"
    created_at    = db.Column(db.DateTime,    default=datetime.utcnow)


class ActiveSession(db.Model):
    """Tracks every login – mirrors the pattern from your emergency app."""
    __tablename__ = 'active_sessions'
    id         = db.Column(db.Integer, primary_key=True, autoincrement=True)
    email      = db.Column(db.String(255), nullable=False)
    login_at   = db.Column(db.DateTime,   default=datetime.utcnow)


class Ingredient(db.Model):
    """User's pantry ingredients."""
    __tablename__ = 'ingredients'
    id         = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_email = db.Column(db.String(255), nullable=False)
    name       = db.Column(db.String(255), nullable=False)
    quantity   = db.Column(db.String(100), nullable=True)
    category   = db.Column(db.String(100), nullable=True)
    expiry     = db.Column(db.String(100), nullable=True)
    added_at   = db.Column(db.DateTime,   default=datetime.utcnow)


class SavedMeal(db.Model):
    """Meals the user has favourited."""
    __tablename__ = 'saved_meals'
    id         = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_email = db.Column(db.String(255), nullable=False)
    meal_name  = db.Column(db.String(255), nullable=False)
    emoji      = db.Column(db.String(10),  nullable=True)
    cook_time  = db.Column(db.Integer,     nullable=True)   # minutes
    calories   = db.Column(db.Integer,     nullable=True)
    difficulty = db.Column(db.String(50),  nullable=True)
    rating     = db.Column(db.Float,       nullable=True)
    saved_at   = db.Column(db.DateTime,    default=datetime.utcnow)


class CookingHistory(db.Model):
    """Every time a user cooks / marks a meal as done."""
    __tablename__ = 'cooking_history'
    id         = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_email = db.Column(db.String(255), nullable=False)
    meal_name  = db.Column(db.String(255), nullable=False)
    emoji      = db.Column(db.String(10),  nullable=True)
    servings   = db.Column(db.Integer,     default=1)
    cooked_at  = db.Column(db.DateTime,    default=datetime.utcnow)


class ShoppingItem(db.Model):
    """Items in the user's shopping list."""
    __tablename__ = 'shopping_items'
    id         = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_email = db.Column(db.String(255), nullable=False)
    name       = db.Column(db.String(255), nullable=False)
    quantity   = db.Column(db.String(100), nullable=True)
    emoji      = db.Column(db.String(10),  nullable=True)
    category   = db.Column(db.String(100), nullable=True)
    for_meal   = db.Column(db.String(255), nullable=True)
    is_done    = db.Column(db.Boolean,     default=False)
    added_at   = db.Column(db.DateTime,    default=datetime.utcnow)


# ══════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════

def send_welcome_email(to_email, name):
    subject  = "Welcome to Ingrechef! 🍳"
    body = f"""Subject: {subject}

Hi {name},

Welcome to Ingrechef – your AI-powered kitchen companion!

You can now:
  • Add your fridge ingredients
  • Get AI-generated meal ideas with zero waste
  • Track nutrition and build a shopping list

Happy cooking!
– The Ingrechef Team
"""
    try:
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()
        server.login(EMAIL_ADDRESS, EMAIL_PASSWORD)
        server.sendmail(EMAIL_ADDRESS, to_email, body)
        server.quit()
        return True
    except Exception as e:
        print(f"Email error: {e}")
        return False


def get_current_user():
    """Return the User object for the most‑recently logged‑in session."""
    last = ActiveSession.query.order_by(ActiveSession.id.desc()).first()
    if not last:
        return None
    return User.query.filter_by(email=last.email).first()


# ══════════════════════════════════════════════
#  AUTH  ROUTES
# ══════════════════════════════════════════════

@app.route('/signup', methods=['POST'])
def signup():
    """
    Register a new user.
    Required JSON fields:
        name, email, phone, password, confirm_password
    """
    try:
        data = request.get_json()

        required = ['name', 'email', 'phone', 'password', 'confirm_password']
        if not data or not all(k in data for k in required):
            return jsonify({'error': 'Missing required fields'}), 400

        if data['password'] != data['confirm_password']:
            return jsonify({'error': 'Passwords do not match'}), 400

        if User.query.filter_by(email=data['email']).first():
            return jsonify({'error': 'Email already registered'}), 409

        hashed_pw = generate_password_hash(data['password'])

        new_user = User(
            name      = data['name'],
            email     = data['email'],
            phone     = data['phone'],
            password  = hashed_pw,
            diet_pref = data.get('diet_pref', ''),
            allergies = data.get('allergies', '')
        )
        db.session.add(new_user)
        db.session.commit()

        # Send welcome email (non‑blocking failure)
        send_welcome_email(data['email'], data['name'])

        return jsonify({'message': 'User registered successfully'}), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': f'Server error: {str(e)}'}), 500


@app.route('/login', methods=['POST'])
def login():
    """
    Login with email + password.
    Backend verifies password hash before allowing in.
    On success, logs entry in active_sessions table.
    """
    try:
        data = request.get_json()

        if not data or 'email' not in data or 'password' not in data:
            return jsonify({'error': 'Email and password required'}), 400

        # 1. Find user
        user = User.query.filter_by(email=data['email']).first()
        if not user:
            return jsonify({'error': 'Invalid credentials'}), 401

        # 2. Check password hash  ← backend verification
        if not check_password_hash(user.password, data['password']):
            return jsonify({'error': 'Invalid credentials'}), 401

        # 3. Record active session
        session_entry = ActiveSession(email=user.email)
        db.session.add(session_entry)
        db.session.commit()

        return jsonify({
            'message': 'Login successful',
            'user': {
                'id'       : user.id,
                'name'     : user.name,
                'email'    : user.email,
                'phone'    : user.phone,
                'diet_pref': user.diet_pref,
                'allergies': user.allergies
            }
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': f'Server error: {str(e)}'}), 500


@app.route('/logout', methods=['POST'])
def logout():
    """Just an endpoint the Flutter app can call – no server‑side session to destroy."""
    return jsonify({'message': 'Logged out successfully'}), 200


# ══════════════════════════════════════════════
#  CURRENT USER HELPER
# ══════════════════════════════════════════════

@app.route('/get_current_user', methods=['GET'])
def get_current_user_endpoint():
    """Return full profile of the most‑recently logged‑in user."""
    try:
        user = get_current_user()
        if not user:
            return jsonify({'status': 'error', 'message': 'No active user'}), 404

        return jsonify({
            'status': 'success',
            'user': {
                'id'        : user.id,
                'name'      : user.name,
                'email'     : user.email,
                'phone'     : user.phone,
                'diet_pref' : user.diet_pref,
                'allergies' : user.allergies,
                'created_at': user.created_at.strftime('%Y-%m-%d')
            }
        }), 200
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500


# ══════════════════════════════════════════════
#  PROFILE  ROUTES
# ══════════════════════════════════════════════

@app.route('/update_profile', methods=['POST'])
def update_profile():
    """
    Update name, phone, diet_pref, allergies for a user.
    JSON: { email, name, phone, diet_pref, allergies }
    """
    try:
        data = request.get_json()
        if not data or 'email' not in data:
            return jsonify({'error': 'Email required'}), 400

        user = User.query.filter_by(email=data['email']).first()
        if not user:
            return jsonify({'error': 'User not found'}), 404

        user.name      = data.get('name',      user.name)
        user.phone     = data.get('phone',     user.phone)
        user.diet_pref = data.get('diet_pref', user.diet_pref)
        user.allergies = data.get('allergies', user.allergies)
        db.session.commit()

        return jsonify({'message': 'Profile updated successfully'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500



# Helper to auto-detect ingredient category
def get_ingredient_category(name):
    name_lower = name.lower()
    if any(k in name_lower for k in ['chicken', 'beef', 'pork', 'fish', 'turkey', 'shrimp', 'tofu', 'egg', 'meat', 'parmesan', 'cheese']):
        return 'Protein'
    elif any(k in name_lower for k in ['tomato', 'onion', 'garlic', 'carrot', 'broccoli', 'pepper', 'mushroom', 'lettuce', 'potato', 'cucumber']):
        return 'Vegetables'
    elif any(k in name_lower for k in ['pasta', 'spaghetti', 'rice', 'bread', 'oats', 'quinoa', 'flour']):
        return 'Grains'
    elif any(k in name_lower for k in ['cumin', 'pepper', 'salt', 'oregano', 'paprika', 'cinnamon', 'turmeric']):
        return 'Spices'
    elif any(k in name_lower for k in ['oil', 'sauce', 'vinegar', 'ketchup', 'mayo', 'soy']):
        return 'Condiments'
    elif any(k in name_lower for k in ['spinach', 'lettuce', 'basil', 'cilantro', 'parsley', 'cabbage', 'greens']):
        return 'Greens'
    return 'Other'


# ══════════════════════════════════════════════
#  INGREDIENT  ROUTES
# ══════════════════════════════════════════════

@app.route('/add_ingredient', methods=['POST'])
def add_ingredient():
    """
    Add one ingredient to pantry.
    JSON: { user_email, name, quantity, category, expiry }
    """
    try:
        data = request.get_json()
        if not data or 'user_email' not in data or 'name' not in data:
            return jsonify({'error': 'user_email and name required'}), 400

        name = data['name']
        category = data.get('category', 'Other')
        if category == 'Other':
            category = get_ingredient_category(name)

        ing = Ingredient(
            user_email = data['user_email'],
            name       = name,
            quantity   = data.get('quantity', '1 pc'),
            category   = category,
            expiry     = data.get('expiry', 'Unknown')
        )
        db.session.add(ing)
        db.session.commit()
        return jsonify({'message': 'Ingredient added', 'id': ing.id}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@app.route('/get_ingredients', methods=['GET'])
def get_ingredients():
    """
    Get all ingredients for a user.
    Query param: ?email=user@example.com
    """
    try:
        email = request.args.get('email')
        if not email:
            return jsonify({'error': 'Email query param required'}), 400

        items = Ingredient.query.filter_by(user_email=email).order_by(
            Ingredient.added_at.desc()).all()

        return jsonify({
            'status': 'success',
            'ingredients': [{
                'id'      : i.id,
                'name'    : i.name,
                'quantity': i.quantity,
                'category': i.category,
                'expiry'  : i.expiry,
                'added_at': i.added_at.strftime('%Y-%m-%d')
            } for i in items]
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/delete_ingredient', methods=['DELETE'])
def delete_ingredient():
    """
    Delete one ingredient by id.
    JSON: { id }
    """
    try:
        data = request.get_json()
        if not data or 'id' not in data:
            return jsonify({'error': 'Ingredient id required'}), 400

        ing = Ingredient.query.get(data['id'])
        if not ing:
            return jsonify({'error': 'Ingredient not found'}), 404

        db.session.delete(ing)
        db.session.commit()
        return jsonify({'message': 'Ingredient deleted'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@app.route('/clear_ingredients', methods=['DELETE'])
def clear_ingredients():
    """
    Delete ALL ingredients for a user.
    JSON: { user_email }
    """
    try:
        data = request.get_json()
        if not data or 'user_email' not in data:
            return jsonify({'error': 'user_email required'}), 400

        Ingredient.query.filter_by(user_email=data['user_email']).delete()
        db.session.commit()
        return jsonify({'message': 'All ingredients cleared'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


# ══════════════════════════════════════════════
#  MEAL GENERATION  ROUTE
# ══════════════════════════════════════════════

@app.route('/generate_meals', methods=['POST'])
def generate_meals():
    """
    Simple rule‑based meal generator based on available ingredients.
    (Swap the logic below with an OpenAI / Gemini API call for real AI.)
    JSON: { user_email, diet_filter }   diet_filter = 'All'|'Veg'|'Non-Veg'
    """
    try:
        data = request.get_json()
        if not data or 'user_email' not in data:
            return jsonify({'error': 'user_email required'}), 400

        email       = data['user_email']
        diet_filter = data.get('diet_filter', 'All')

        # Fetch user's ingredients
        ingredients = Ingredient.query.filter_by(user_email=email).all()
        pantry      = [i.name.lower() for i in ingredients]

        # Meal catalogue
        all_meals = [
            {
                'name'        : 'Pasta Primavera',
                'emoji'       : '🍝',
                'time'        : 25,
                'calories'    : 380,
                'difficulty'  : 'Easy',
                'tags'        : ['Vegetarian'],
                'needs'       : ['pasta', 'tomatoes', 'spinach', 'garlic', 'olive oil'],
                'optional'    : ['basil', 'parmesan'],
                'nutrition'   : {'protein': 14, 'carbs': 65, 'fat': 9, 'fiber': 6}
            },
            {
                'name'        : 'Chicken Stir Fry',
                'emoji'       : '🥘',
                'time'        : 20,
                'calories'    : 450,
                'difficulty'  : 'Easy',
                'tags'        : ['Non-Veg', 'High Protein'],
                'needs'       : ['chicken', 'onion', 'garlic', 'olive oil'],
                'optional'    : ['soy sauce', 'bell pepper'],
                'nutrition'   : {'protein': 38, 'carbs': 12, 'fat': 14, 'fiber': 3}
            },
            {
                'name'        : 'Spinach Frittata',
                'emoji'       : '🍳',
                'time'        : 30,
                'calories'    : 310,
                'difficulty'  : 'Medium',
                'tags'        : ['Vegetarian', 'High Protein'],
                'needs'       : ['eggs', 'spinach', 'onion', 'garlic'],
                'optional'    : ['cheese', 'cream'],
                'nutrition'   : {'protein': 22, 'carbs': 8, 'fat': 18, 'fiber': 2}
            },
            {
                'name'        : 'Tomato Egg Drop Soup',
                'emoji'       : '🍲',
                'time'        : 15,
                'calories'    : 180,
                'difficulty'  : 'Easy',
                'tags'        : ['Vegetarian'],
                'needs'       : ['eggs', 'tomatoes', 'garlic', 'onion'],
                'optional'    : ['spring onion'],
                'nutrition'   : {'protein': 10, 'carbs': 14, 'fat': 7, 'fiber': 2}
            },
            {
                'name'        : 'Garlic Spaghetti (Aglio e Olio)',
                'emoji'       : '🍝',
                'time'        : 20,
                'calories'    : 340,
                'difficulty'  : 'Easy',
                'tags'        : ['Vegetarian'],
                'needs'       : ['pasta', 'garlic', 'olive oil'],
                'optional'    : ['parmesan', 'chilli flakes'],
                'nutrition'   : {'protein': 10, 'carbs': 58, 'fat': 10, 'fiber': 3}
            },
        ]

        results = []
        for meal in all_meals:
            # Diet filter
            if diet_filter == 'Veg' and 'Vegetarian' not in meal['tags']:
                continue
            if diet_filter == 'Non-Veg' and 'Non-Veg' not in meal['tags']:
                continue

            # Calculate which required ingredients the user has
            have    = [i for i in meal['needs'] if i in pantry]
            missing = [i for i in meal['needs'] if i not in pantry]
            match   = int((len(have) / len(meal['needs'])) * 100) if meal['needs'] else 0

            # Only suggest if user has at least 50 % of required ingredients
            if match < 50:
                continue

            results.append({
                'name'       : meal['name'],
                'emoji'      : meal['emoji'],
                'time'       : meal['time'],
                'calories'   : meal['calories'],
                'difficulty' : meal['difficulty'],
                'tags'       : meal['tags'],
                'have'       : have,
                'missing'    : missing,
                'match_pct'  : match,
                'nutrition'  : meal['nutrition']
            })

        # Sort by match percentage descending
        results.sort(key=lambda x: x['match_pct'], reverse=True)

        return jsonify({'status': 'success', 'meals': results}), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ══════════════════════════════════════════════
#  SAVED MEALS  ROUTES
# ══════════════════════════════════════════════

@app.route('/save_meal', methods=['POST'])
def save_meal():
    """
    Favourite / save a meal.
    JSON: { user_email, meal_name, emoji, cook_time, calories, difficulty, rating }
    """
    try:
        data = request.get_json()
        if not data or 'user_email' not in data or 'meal_name' not in data:
            return jsonify({'error': 'user_email and meal_name required'}), 400

        # Prevent duplicates
        existing = SavedMeal.query.filter_by(
            user_email=data['user_email'], meal_name=data['meal_name']).first()
        if existing:
            return jsonify({'message': 'Meal already saved'}), 200

        meal = SavedMeal(
            user_email = data['user_email'],
            meal_name  = data['meal_name'],
            emoji      = data.get('emoji', '🍽️'),
            cook_time  = data.get('cook_time'),
            calories   = data.get('calories'),
            difficulty = data.get('difficulty'),
            rating     = data.get('rating')
        )
        db.session.add(meal)
        db.session.commit()
        return jsonify({'message': 'Meal saved', 'id': meal.id}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@app.route('/get_saved_meals', methods=['GET'])
def get_saved_meals():
    """Query param: ?email=user@example.com"""
    try:
        email = request.args.get('email')
        if not email:
            return jsonify({'error': 'Email required'}), 400

        meals = SavedMeal.query.filter_by(user_email=email).order_by(
            SavedMeal.saved_at.desc()).all()

        return jsonify({
            'status': 'success',
            'saved_meals': [{
                'id'        : m.id,
                'meal_name' : m.meal_name,
                'emoji'     : m.emoji,
                'cook_time' : m.cook_time,
                'calories'  : m.calories,
                'difficulty': m.difficulty,
                'rating'    : m.rating,
                'saved_at'  : m.saved_at.strftime('%Y-%m-%d')
            } for m in meals]
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/unsave_meal', methods=['DELETE'])
def unsave_meal():
    """JSON: { id }"""
    try:
        data = request.get_json()
        meal = SavedMeal.query.get(data.get('id'))
        if not meal:
            return jsonify({'error': 'Saved meal not found'}), 404
        db.session.delete(meal)
        db.session.commit()
        return jsonify({'message': 'Meal removed from favourites'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


# ══════════════════════════════════════════════
#  COOKING HISTORY  ROUTES
# ══════════════════════════════════════════════

@app.route('/add_cooking_history', methods=['POST'])
def add_cooking_history():
    """
    Called when user taps "Done" in cooking mode.
    JSON: { user_email, meal_name, emoji, servings }
    """
    try:
        data = request.get_json()
        if not data or 'user_email' not in data or 'meal_name' not in data:
            return jsonify({'error': 'user_email and meal_name required'}), 400

        entry = CookingHistory(
            user_email = data['user_email'],
            meal_name  = data['meal_name'],
            emoji      = data.get('emoji', '🍽️'),
            servings   = int(data.get('servings', 1))
        )
        db.session.add(entry)
        db.session.commit()
        return jsonify({'message': 'Cooking history saved', 'id': entry.id}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@app.route('/get_cooking_history', methods=['GET'])
def get_cooking_history():
    """Query param: ?email=user@example.com"""
    try:
        email = request.args.get('email')
        if not email:
            return jsonify({'error': 'Email required'}), 400

        history = CookingHistory.query.filter_by(user_email=email).order_by(
            CookingHistory.cooked_at.desc()).all()

        return jsonify({
            'status': 'success',
            'history': [{
                'id'       : h.id,
                'meal_name': h.meal_name,
                'emoji'    : h.emoji,
                'servings' : h.servings,
                'cooked_at': h.cooked_at.strftime('%Y-%m-%d')
            } for h in history]
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ══════════════════════════════════════════════
#  SHOPPING LIST  ROUTES
# ══════════════════════════════════════════════

@app.route('/add_shopping_item', methods=['POST'])
def add_shopping_item():
    """
    JSON: { user_email, name, quantity, emoji, category, for_meal }
    """
    try:
        data = request.get_json()
        if not data or 'user_email' not in data or 'name' not in data:
            return jsonify({'error': 'user_email and name required'}), 400

        item = ShoppingItem(
            user_email = data['user_email'],
            name       = data['name'],
            quantity   = data.get('quantity', '1 pc'),
            emoji      = data.get('emoji', '🛒'),
            category   = data.get('category', 'Other'),
            for_meal   = data.get('for_meal', 'General')
        )
        db.session.add(item)
        db.session.commit()
        return jsonify({'message': 'Item added', 'id': item.id}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@app.route('/get_shopping_list', methods=['GET'])
def get_shopping_list():
    """Query param: ?email=user@example.com"""
    try:
        email = request.args.get('email')
        if not email:
            return jsonify({'error': 'Email required'}), 400

        items = ShoppingItem.query.filter_by(user_email=email).order_by(
            ShoppingItem.added_at.desc()).all()

        return jsonify({
            'status': 'success',
            'items': [{
                'id'      : i.id,
                'name'    : i.name,
                'quantity': i.quantity,
                'emoji'   : i.emoji,
                'category': i.category,
                'for_meal': i.for_meal,
                'is_done' : i.is_done
            } for i in items]
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/toggle_shopping_item', methods=['POST'])
def toggle_shopping_item():
    """Toggle is_done flag. JSON: { id }"""
    try:
        data = request.get_json()
        item = ShoppingItem.query.get(data.get('id'))
        if not item:
            return jsonify({'error': 'Item not found'}), 404
        item.is_done = not item.is_done
        db.session.commit()
        return jsonify({'message': 'Toggled', 'is_done': item.is_done}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@app.route('/delete_shopping_item', methods=['DELETE'])
def delete_shopping_item():
    """JSON: { id }"""
    try:
        data = request.get_json()
        item = ShoppingItem.query.get(data.get('id'))
        if not item:
            return jsonify({'error': 'Item not found'}), 404
        db.session.delete(item)
        db.session.commit()
        return jsonify({'message': 'Item deleted'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@app.route('/clear_completed_shopping', methods=['DELETE'])
def clear_completed_shopping():
    """Remove all is_done=True items for a user and add them to ingredients pantry. JSON: { user_email }"""
    try:
        data = request.get_json()
        if not data or 'user_email' not in data:
            return jsonify({'error': 'user_email required'}), 400

        completed_items = ShoppingItem.query.filter_by(
            user_email=data['user_email'], is_done=True).all()

        for item in completed_items:
            # Check if this ingredient already exists in the pantry (case-insensitive)
            existing = Ingredient.query.filter(
                Ingredient.user_email == data['user_email'],
                db.func.lower(Ingredient.name) == db.func.lower(item.name)
            ).first()
            if not existing:
                ing = Ingredient(
                    user_email = data['user_email'],
                    name       = item.name,
                    quantity   = item.quantity or '1 pc',
                    category   = get_ingredient_category(item.name),
                    expiry     = 'Unknown'
                )
                db.session.add(ing)

        ShoppingItem.query.filter_by(
            user_email=data['user_email'], is_done=True).delete()
        db.session.commit()
        return jsonify({'message': 'Completed items cleared and added to pantry'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@app.route('/clear_all_shopping', methods=['DELETE'])
def clear_all_shopping():
    """Remove all shopping items for a user to allow a clean test start. JSON: { user_email }"""
    try:
        data = request.get_json()
        if not data or 'user_email' not in data:
            return jsonify({'error': 'user_email required'}), 400

        ShoppingItem.query.filter_by(user_email=data['user_email']).delete()
        db.session.commit()
        return jsonify({'message': 'All shopping items cleared'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@app.route('/clear_user_data', methods=['DELETE'])
def clear_user_data():
    """Remove all user-created records (ingredients, shopping list, saved meals, cooking history) for clean test runs. JSON: { user_email }"""
    try:
        data = request.get_json()
        if not data or 'user_email' not in data:
            return jsonify({'error': 'user_email required'}), 400

        email = data['user_email']
        Ingredient.query.filter_by(user_email=email).delete()
        ShoppingItem.query.filter_by(user_email=email).delete()
        SavedMeal.query.filter_by(user_email=email).delete()
        CookingHistory.query.filter_by(user_email=email).delete()
        db.session.commit()
        return jsonify({'message': 'All user data cleared'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


# ══════════════════════════════════════════════
#  STATS  ROUTE
# ══════════════════════════════════════════════

@app.route('/get_user_stats', methods=['GET'])
def get_user_stats():
    """
    Returns dashboard stats for a user.
    Query param: ?email=user@example.com
    """
    try:
        email = request.args.get('email')
        if not email:
            return jsonify({'error': 'Email required'}), 400

        ingredient_count = Ingredient.query.filter_by(user_email=email).count()
        saved_count      = SavedMeal.query.filter_by(user_email=email).count()
        cooked_count     = CookingHistory.query.filter_by(user_email=email).count()
        shopping_pending = ShoppingItem.query.filter_by(
            user_email=email, is_done=False).count()

        return jsonify({
            'status'          : 'success',
            'ingredient_count': ingredient_count,
            'saved_meals'     : saved_count,
            'meals_cooked'    : cooked_count,
            'shopping_pending': shopping_pending
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ══════════════════════════════════════════════
#  EMAIL ALERT  ROUTE  (kept for parity)
# ══════════════════════════════════════════════

@app.route('/send_meal_reminder', methods=['POST'])
def send_meal_reminder():
    """
    Send an email reminding the user about expiring ingredients.
    JSON: { email, expiring_items: ['Spinach', 'Tomatoes'] }
    """
    try:
        data  = request.get_json()
        email = data.get('email')
        items = data.get('expiring_items', [])

        if not email:
            return jsonify({'status': 'error', 'message': 'Email required'}), 400

        subject   = "⚠️ Ingredients Expiring Soon – Ingrechef"
        item_list = '\n'.join([f"  • {i}" for i in items])
        body = f"""Subject: {subject}

Hi there,

The following items in your pantry are expiring soon:

{item_list}

Log into Ingrechef now to generate a quick meal before they go to waste!

Happy cooking,
– The Ingrechef Team
"""
        try:
            server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
            server.starttls()
            server.login(EMAIL_ADDRESS, EMAIL_PASSWORD)
            server.sendmail(EMAIL_ADDRESS, email, body)
            server.quit()
            return jsonify({'status': 'success', 'message': 'Reminder sent'}), 200
        except Exception as mail_err:
            return jsonify({'status': 'error', 'message': str(mail_err)}), 500

    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500


# ══════════════════════════════════════════════
#  RUN
# ══════════════════════════════════════════════

if __name__ == '__main__':
    with app.app_context():
        db.create_all()   # creates tables if they don't exist
    app.run(debug=True, host='0.0.0.0', port=5000)
