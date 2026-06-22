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
    Real-time AI meal generator using Gemini API based on user's pantry.
    If the API call fails or the key is not valid, it falls back to the local rule-based catalog.
    JSON: { user_email, diet_filter }   diet_filter = 'All'|'Veg'|'Non-Veg'
    """
    # 1. Fallback meal catalogue (same as before)
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

    try:
        data = request.get_json()
        if not data or 'user_email' not in data:
            return jsonify({'error': 'user_email required'}), 400

        email       = data['user_email']
        diet_filter = data.get('diet_filter', 'All')

        # Fetch user's ingredients
        ingredients = Ingredient.query.filter_by(user_email=email).all()
        pantry      = [i.name.strip().lower() for i in ingredients]

        pantry_str = ", ".join(pantry) if pantry else "None (Pantry is empty)"
        
        # Try loading API key from environment variable, then from local file
        import os
        api_key = os.environ.get("GEMINI_API_KEY")
        if not api_key:
            if os.path.exists("api_key.txt"):
                with open("api_key.txt", "r", encoding="utf-8") as f:
                    api_key = f.read().strip()
        
        if not api_key:
            raise Exception("GEMINI_API_KEY not found in environment or local api_key.txt file. Please set it to proceed.")
        
        prompt = f"""
You are an expert chef AI. Based on the user's pantry ingredients, generate 12-15 creative and realistic meal recommendations.
Dietary filter: {diet_filter}

User's Pantry ingredients: {pantry_str}

Please generate the recommendations and output them in a strict JSON format. The response must be a JSON object containing a "meals" array, where each meal follows this exact JSON structure:
{{
  "name": "Meal Name",
  "emoji": "🍳",
  "time": 25,
  "calories": 420,
  "difficulty": "Easy", // Easy, Medium, or Hard
  "tags": ["Vegetarian"], // Tag list (e.g. Vegetarian, Gluten-Free, Non-Veg) matching diet filter: {diet_filter}
  "needs": ["pasta", "tomatoes"], // The complete list of ingredients needed for this recipe (all lowercase)
  "optional": ["cheese"], // Optional ingredients (all lowercase)
  "nutrition": {{
    "protein": 15,
    "carbs": 60,
    "fat": 10,
    "fiber": 5
  }}
}}

CRITICAL INSTRUCTIONS FOR MEAL GENERATION:
1. Generate between 12 and 15 recipes. Try to output as close to 15 recipes as possible to give the user a full list of ideas.
2. The recipes must be diverse:
   - Some recipes should be fully-cookable with the user's current pantry.
   - Importantly, generate several recipes where only some (or even just ONE or TWO) of the user's pantry ingredients are used, and the rest of the essential ingredients are listed in "needs" but are NOT in the user's pantry. This allows the user to see what they can cook if they buy a few extra items.
   - Do NOT restrict yourself to only showing high-matching meals. Include meals with low matching percentages (down to 10-20% match), as long as at least ONE ingredient from the user's pantry is required in the meal.
3. For each meal, evaluate the user's pantry list against the "needs" list:
   - "needs" MUST contain all essential ingredients to make the meal, even if the user does not have them (so the user knows what to purchase).
4. Return ONLY the raw JSON string matching this structure. Do NOT wrap inside markdown block. Just raw JSON.
"""

        import requests
        import json
        
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "responseMimeType": "application/json",
                "temperature": 0.7,
            }
        }
        
        models_to_try = [
            "gemini-2.5-flash",
            "gemini-2.5-flash-lite",
            "gemini-flash-latest",
            "gemini-flash-lite-latest"
        ]
        
        response = None
        last_error_msg = ""
        for model_name in models_to_try:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={api_key}"
            print(f"Calling Gemini API with model {model_name}: {url}")
            try:
                r = requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=30)
                print(f"Gemini API ({model_name}) Status Code: {r.status_code}")
                if r.status_code == 200:
                    response = r
                    break
                else:
                    last_error_msg = f"Model {model_name} returned status code {r.status_code}: {r.text}"
                    print(last_error_msg)
            except Exception as e:
                last_error_msg = f"Model {model_name} request failed: {str(e)}"
                print(last_error_msg)
        
        if response is not None:
            res_data = response.json()
            raw_text = res_data['candidates'][0]['content']['parts'][0]['text']
            ai_data = json.loads(raw_text)
            
            # Defensive parsing of the JSON structure returned by Gemini
            if isinstance(ai_data, list):
                meals = ai_data
            elif isinstance(ai_data, dict):
                meals = ai_data.get('meals', [])
                if not isinstance(meals, list):
                    for key, val in ai_data.items():
                        if isinstance(val, list):
                            meals = val
                            break
                    if not isinstance(meals, list):
                        meals = [ai_data]
            else:
                meals = []
                
            results = []
            for meal in meals:
                if not isinstance(meal, dict):
                    continue
                    
                raw_needs = meal.get('needs', [])
                if not isinstance(raw_needs, list):
                    raw_needs = [raw_needs] if raw_needs else []
                needs = [str(n).lower().strip() for n in raw_needs if n]
                
                have = [n for n in needs if n in pantry]
                missing = [n for n in needs if n not in pantry]
                match = int((len(have) / len(needs)) * 100) if needs else 0
                
                raw_tags = meal.get('tags', [])
                if not isinstance(raw_tags, list):
                    raw_tags = [raw_tags] if raw_tags else []
                tags = [str(t) for t in raw_tags if t]
                
                raw_nutrition = meal.get('nutrition')
                if isinstance(raw_nutrition, dict):
                    nutrition = {
                        'protein': raw_nutrition.get('protein', 10),
                        'carbs': raw_nutrition.get('carbs', 40),
                        'fat': raw_nutrition.get('fat', 10),
                        'fiber': raw_nutrition.get('fiber', 2)
                    }
                else:
                    nutrition = {'protein': 10, 'carbs': 40, 'fat': 10, 'fiber': 2}
                
                # Determine and standardize diet category (Vegetarian vs Non-Veg)
                has_nonveg_tags = any(t.lower() in ['non-veg', 'nonveg', 'meat', 'chicken', 'fish', 'egg', 'eggs'] for t in tags)
                
                # Check ingredients for meat/eggs (including eggs, chicken, beef, pork, fish, turkey, shrimp, mutton, meat)
                has_nonveg_ingredient = any(
                    any(item in ing.lower() for item in ['chicken', 'beef', 'pork', 'fish', 'turkey', 'shrimp', 'mutton', 'meat', 'egg', 'eggs'])
                    for ing in needs
                )
                
                # Check meal name for meat/eggs
                has_nonveg_in_name = any(
                    item in meal.get('name', '').lower() 
                    for item in ['chicken', 'beef', 'pork', 'fish', 'turkey', 'shrimp', 'mutton', 'meat', 'egg', 'eggs']
                )
                
                is_actually_veg = not (has_nonveg_tags or has_nonveg_ingredient or has_nonveg_in_name)
                
                standardized_tags = []
                if is_actually_veg:
                    standardized_tags.append('Vegetarian')
                else:
                    standardized_tags.append('Non-Veg')
                
                for t in tags:
                    if t.lower() not in ['vegetarian', 'veg', 'vegan', 'non-veg', 'nonveg']:
                        standardized_tags.append(t)
                
                results.append({
                    'name': meal.get('name', 'Unknown Meal'),
                    'emoji': meal.get('emoji', '🍽️'),
                    'time': meal.get('time', 30),
                    'calories': meal.get('calories', 350),
                    'difficulty': meal.get('difficulty', 'Easy'),
                    'tags': standardized_tags,
                    'have': have,
                    'missing': missing,
                    'match_pct': match,
                    'nutrition': nutrition,
                    'is_veg': is_actually_veg
                })
            
            # Post-filter strictly by diet_filter
            filtered_results = []
            for item in results:
                if diet_filter == 'Veg' and not item['is_veg']:
                    continue
                if diet_filter == 'Non-Veg' and item['is_veg']:
                    continue
                filtered_results.append(item)
            
            # Sort by match percentage descending
            filtered_results.sort(key=lambda x: x['match_pct'], reverse=True)
            return jsonify({'status': 'success', 'meals': filtered_results}), 200
        else:
            raise Exception(f"All Gemini models failed. Last error: {last_error_msg}")

    except Exception as e:
        import traceback
        print("Gemini API error:")
        traceback.print_exc()
        print(f"Falling back to static catalog: {e}")
        # FALLBACK to static catalog
        results = []
        for meal in all_meals:
            if diet_filter == 'Veg' and 'Vegetarian' not in meal['tags']:
                continue
            if diet_filter == 'Non-Veg' and 'Non-Veg' not in meal['tags']:
                continue

            have    = [i for i in meal['needs'] if i in pantry]
            missing = [i for i in meal['needs'] if i not in pantry]
            match   = int((len(have) / len(meal['needs'])) * 100) if meal['needs'] else 0

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

        results.sort(key=lambda x: x['match_pct'], reverse=True)
        return jsonify({'status': 'success', 'meals': results}), 200


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
