import 'package:flutter/material.dart';
import 'api_service.dart';
import 'ingredient_management_screen.dart';
import 'ai_meal_generation_screen.dart';
import 'meal_detail_screen.dart';
import 'shopping_screen.dart';
import 'profile_screen.dart';
import 'ai_chat_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  const DashboardScreen({super.key, required this.userName, required this.userEmail});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _ingredientCount = 0;
  int _savedMeals      = 0;
  int _mealsCooked     = 0;
  int _shoppingPending = 0;
  bool _loadingStats   = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final res = await ApiService.getUserStats(widget.userEmail);
    if (mounted && res['status'] == 'success') {
      setState(() {
        _ingredientCount = res['ingredient_count'] ?? 0;
        _savedMeals      = res['saved_meals']      ?? 0;
        _mealsCooked     = res['meals_cooked']      ?? 0;
        _shoppingPending = res['shopping_pending']  ?? 0;
        _loadingStats    = false;
      });
    } else {
      setState(() => _loadingStats = false);
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning!';
    if (h < 17) return 'Good afternoon!';
    return 'Good evening!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          color: const Color(0xFF2D4A2D),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildHeader(context),
              _buildBanner(),
              _buildQuickStats(),
              _buildSectionTitle('Kitchen Actions'),
              _buildMainGrid(context),
              _buildSectionTitle("Today's Suggestions"),
              _buildMealPreviewRow(context),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ProfileScreen(userEmail: widget.userEmail, userName: widget.userName))),
          child: Container(width: 46, height: 46,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF3D6B3D), Color(0xFF2D4A2D)]),
              boxShadow: [BoxShadow(color: const Color(0xFF2D4A2D).withOpacity(0.3), blurRadius: 10)]),
            child: const Center(child: Text('👨‍🍳', style: TextStyle(fontSize: 22)))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_greeting, style: const TextStyle(fontSize: 13, color: Color(0xFF7A8A7A))),
          Text(widget.userName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1E3A1E))),
        ])),
        Stack(children: [
          Container(width: 46, height: 46,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)]),
            child: const Icon(Icons.notifications_outlined, color: Color(0xFF3A5A3A), size: 22)),
          if (_shoppingPending > 0)
            Positioned(right: 10, top: 10,
              child: Container(width: 16, height: 16,
                decoration: const BoxDecoration(color: Color(0xFFE84C4C), shape: BoxShape.circle),
                child: Center(child: Text('$_shoppingPending',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))))),
        ]),
      ]),
    );
  }

  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A1E), Color(0xFF2D5A2D)]),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: const Color(0xFF1E3A1E).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))]),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFE8A84C).withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: const Text('🌿 Zero Waste', style: TextStyle(color: Color(0xFFE8A84C), fontSize: 11, fontWeight: FontWeight.w600))),
            const SizedBox(height: 10),
            Text(
              _loadingStats
                  ? 'Loading your pantry...'
                  : 'You have $_ingredientCount ingredient${_ingredientCount == 1 ? '' : 's'}\nready to cook!',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, height: 1.3)),
            const SizedBox(height: 8),
            const Text('Tap Generate to get meal ideas', style: TextStyle(color: Color(0xFF8BBB8B), fontSize: 12)),
          ])),
          const Text('🥗', style: TextStyle(fontSize: 64)),
        ]),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(children: [
        _StatChip(label: 'Ingredients', value: '$_ingredientCount', emoji: '🥦'),
        const SizedBox(width: 10),
        _StatChip(label: 'Saved Meals', value: '$_savedMeals',      emoji: '❤️'),
        const SizedBox(width: 10),
        _StatChip(label: 'Cooked',      value: '$_mealsCooked',     emoji: '🍽️'),
      ]),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E3A1E), letterSpacing: 0.3)),
    );
  }

  Widget _buildMainGrid(BuildContext context) {
    final items = [
      _DashItem(emoji: '🥦', title: 'My Ingredients', subtitle: '$_ingredientCount items tracked',
          color1: const Color(0xFF4A8A4A), color2: const Color(0xFF2D5A2D),
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => IngredientManagementScreen(userEmail: widget.userEmail))).then((_) => _loadStats())),
      _DashItem(emoji: '✨', title: 'Generate Meals', subtitle: 'AI-powered ideas',
          color1: const Color(0xFFE8A84C), color2: const Color(0xFFD4873A),
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AiMealGenerationScreen(userEmail: widget.userEmail)))),
      _DashItem(emoji: '🛒', title: 'Shopping List', subtitle: '$_shoppingPending pending',
          color1: const Color(0xFF5A7BA8), color2: const Color(0xFF3A5A88),
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ShoppingScreen(userEmail: widget.userEmail))).then((_) => _loadStats())),
      _DashItem(emoji: '🤖', title: 'AI Chef Chat', subtitle: 'Ask anything',
          color1: const Color(0xFF8A5AA8), color2: const Color(0xFF6A3A88),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen()))),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.count(crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.05,
        children: items.map((i) => _DashCard(item: i)).toList()),
    );
  }

  Widget _buildMealPreviewRow(BuildContext context) {
    final meals = [
      {'emoji': '🍝', 'name': 'Pasta Primavera',   'time': '25 min', 'cal': '380 kcal'},
      {'emoji': '🥘', 'name': 'Veggie Curry',       'time': '35 min', 'cal': '420 kcal'},
      {'emoji': '🥗', 'name': 'Fresh Buddha Bowl',  'time': '15 min', 'cal': '310 kcal'},
    ];
    return SizedBox(height: 170, child: ListView.builder(
      padding: const EdgeInsets.only(left: 24),
      scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
      itemCount: meals.length,
      itemBuilder: (_, i) {
        final m = meals[i];
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => MealDetailScreen(
                mealName: m['name']!, emoji: m['emoji']!,
                cookTime: int.parse(m['time']!.split(' ')[0]),
                calories: int.parse(m['cal']!.split(' ')[0]),
                userEmail: widget.userEmail,
              ))),
          child: Container(width: 155, margin: const EdgeInsets.only(right: 14), padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 14, offset: const Offset(0, 4))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(m['emoji']!, style: const TextStyle(fontSize: 40)),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m['name']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E3A1E)), maxLines: 2),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.timer_outlined, size: 12, color: Color(0xFF7A8A7A)),
                  const SizedBox(width: 3),
                  Text(m['time']!, style: const TextStyle(fontSize: 11, color: Color(0xFF7A8A7A))),
                  const SizedBox(width: 8),
                  const Icon(Icons.local_fire_department_outlined, size: 12, color: Color(0xFFE8A84C)),
                  const SizedBox(width: 3),
                  Text(m['cal']!, style: const TextStyle(fontSize: 11, color: Color(0xFFE8A84C), fontWeight: FontWeight.w600)),
                ]),
              ]),
            ])),
        );
      },
    ));
  }
}

class _StatChip extends StatelessWidget {
  final String label, value, emoji;
  const _StatChip({required this.label, required this.value, required this.emoji});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2D4A2D))),
      Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF8A9A8A)), textAlign: TextAlign.center),
    ])));
}

class _DashItem {
  final String emoji, title, subtitle;
  final Color color1, color2;
  final VoidCallback onTap;
  _DashItem({required this.emoji, required this.title, required this.subtitle,
    required this.color1, required this.color2, required this.onTap});
}

class _DashCard extends StatelessWidget {
  final _DashItem item;
  const _DashCard({required this.item});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: item.onTap,
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [item.color1, item.color2]),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: item.color2.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))]),
      child: Padding(padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 22)))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(item.subtitle, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11)),
          ]),
        ]))));
}
