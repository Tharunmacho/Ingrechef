import 'package:flutter/material.dart';
import 'dart:async';
import 'api_service.dart';

class MealDetailScreen extends StatefulWidget {
  final String mealName, emoji, userEmail;
  final int cookTime, calories;
  final String? difficulty;
  final Map<String, dynamic>? nutrition;
  const MealDetailScreen({super.key,
    required this.mealName, required this.emoji,
    required this.cookTime, required this.calories,
    required this.userEmail,
    this.difficulty, this.nutrition});
  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> with TickerProviderStateMixin {
  bool _isFavorite    = false;
  int  _userRating    = 0;
  bool _isCookingMode = false;
  int  _currentStep   = 0;
  int  _timerSeconds  = 0;
  bool _timerRunning  = false;
  bool _savingFav     = false;
  Timer? _timer;
  late TabController _tabController;
  late AnimationController _favController;
  late Animation<double> _favScale;

  final List<Map<String, dynamic>> _steps = [
    {'step': 'Boil a pot of salted water and cook the pasta until al dente (about 8 minutes). Reserve ½ cup pasta water before draining.', 'timer': 480, 'icon': '🍝'},
    {'step': 'Heat 2 tbsp olive oil in a pan over medium heat. Add minced garlic and sauté for 1 minute until fragrant.', 'timer': 60, 'icon': '🧄'},
    {'step': 'Add cherry tomatoes. Season with salt and pepper. Cook 4–5 minutes until tomatoes start to burst.', 'timer': 300, 'icon': '🍅'},
    {'step': 'Add fresh spinach and toss until wilted, about 2 minutes. Add pasta water if needed.', 'timer': 120, 'icon': '🌿'},
    {'step': 'Drain pasta and toss with the vegetables over low heat. Adjust seasoning and serve with fresh basil.', 'timer': 0, 'icon': '🍽️'},
  ];

  final List<Map<String, dynamic>> _ingredients = [
    {'name': 'Pasta',           'amount': '200g',    'emoji': '🍝', 'have': true},
    {'name': 'Cherry Tomatoes', 'amount': '1 cup',   'emoji': '🍅', 'have': true},
    {'name': 'Fresh Spinach',   'amount': '2 cups',  'emoji': '🌿', 'have': true},
    {'name': 'Garlic',          'amount': '3 cloves','emoji': '🧄', 'have': true},
    {'name': 'Olive Oil',       'amount': '3 tbsp',  'emoji': '🫙', 'have': true},
    {'name': 'Fresh Basil',     'amount': 'handful', 'emoji': '🌱', 'have': false},
    {'name': 'Parmesan',        'amount': '50g',     'emoji': '🧀', 'have': false},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _favController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _favScale = Tween<double>(begin: 1.0, end: 1.4).animate(CurvedAnimation(parent: _favController, curve: Curves.elasticOut));
  }

  @override
  void dispose() { _tabController.dispose(); _favController.dispose(); _timer?.cancel(); super.dispose(); }

  Future<void> _toggleFav() async {
    if (_savingFav) return;
    setState(() { _savingFav = true; });
    if (!_isFavorite) {
      await ApiService.saveMeal(
        userEmail: widget.userEmail, mealName: widget.mealName,
        emoji: widget.emoji, cookTime: widget.cookTime,
        calories: widget.calories, difficulty: widget.difficulty ?? 'Easy',
        rating: _userRating > 0 ? _userRating.toDouble() : null);
    } else {
      // unsave not implemented here for simplicity - just toggle visually
    }
    setState(() { _isFavorite = !_isFavorite; _savingFav = false; });
    _favController.forward().then((_) => _favController.reverse());
  }

  void _startTimer(int seconds) {
    setState(() { _timerSeconds = seconds; _timerRunning = true; });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timerSeconds <= 0) { t.cancel(); setState(() => _timerRunning = false); }
      else { setState(() => _timerSeconds--); }
    });
  }

  String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2,'0')}:${(s % 60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) => _isCookingMode ? _buildCookingMode(context) : _buildDetail(context);

  Widget _buildDetail(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      body: CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
        SliverAppBar(expandedHeight: 260, pinned: true, backgroundColor: const Color(0xFF1E3A1E),
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
          actions: [
            AnimatedBuilder(animation: _favScale, builder: (_, __) => Transform.scale(scale: _favScale.value,
              child: IconButton(icon: Icon(_isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isFavorite ? const Color(0xFFE84C4C) : Colors.white, size: 24), onPressed: _toggleFav))),
            IconButton(icon: const Icon(Icons.share_outlined, color: Colors.white, size: 22), onPressed: () {}),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1E3A1E), Color(0xFF2D5A2D)])),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(height: 60),
                Text(widget.emoji, style: const TextStyle(fontSize: 90)),
                const SizedBox(height: 12),
                Text(widget.mealName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _QInfo(icon: Icons.timer_outlined,         label: '${widget.cookTime} min', color: const Color(0xFFE8A84C)),
                  const SizedBox(width: 20),
                  _QInfo(icon: Icons.local_fire_department_outlined, label: '${widget.calories} kcal', color: const Color(0xFF8BBB8B)),
                  const SizedBox(width: 20),
                  _QInfo(icon: Icons.bar_chart_rounded,      label: widget.difficulty ?? 'Easy', color: const Color(0xFF8BB8E8)),
                ]),
              ])),
          ),
          bottom: PreferredSize(preferredSize: const Size.fromHeight(48),
            child: Container(color: const Color(0xFF1E3A1E), child: TabBar(controller: _tabController,
              indicatorColor: const Color(0xFFE8A84C), indicatorWeight: 3,
              labelColor: const Color(0xFFE8A84C), unselectedLabelColor: const Color(0xFF8BBB8B),
              tabs: const [Tab(text: 'Overview'), Tab(text: 'Ingredients'), Tab(text: 'Nutrition')]))),
        ),
        SliverFillRemaining(child: TabBarView(controller: _tabController, children: [
          _buildOverview(),
          _buildIngredientsTab(),
          _buildNutritionTab(),
        ])),
      ]),
    );
  }

  Widget _buildOverview() => SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    // Rating card
    Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Rate this recipe', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E3A1E))),
          const SizedBox(height: 8),
          Row(children: List.generate(5, (i) => GestureDetector(
            onTap: () => setState(() => _userRating = i + 1),
            child: Padding(padding: const EdgeInsets.only(right: 4),
              child: Icon(i < _userRating ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFE8A84C), size: 30))))),
        ]),
        const Spacer(),
        const Column(children: [
          Text('4.5', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF1E3A1E))),
          Text('⭐ community avg', style: TextStyle(fontSize: 11, color: Color(0xFF9A9A8A))),
        ]),
      ])),
    const SizedBox(height: 20),
    const Text('Recipe Steps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E3A1E))),
    const SizedBox(height: 12),
    ..._steps.asMap().entries.map((e) => Container(
      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 30, height: 30, decoration: const BoxDecoration(color: Color(0xFF2D4A2D), shape: BoxShape.circle),
          child: Center(child: Text('${e.key+1}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)))),
        const SizedBox(width: 12),
        Expanded(child: Text(e.value['step'], style: const TextStyle(fontSize: 13, color: Color(0xFF3A4A3A), height: 1.5))),
      ]))),
    const SizedBox(height: 24),
    GestureDetector(
      onTap: () => setState(() => _isCookingMode = true),
      child: Container(width: double.infinity, height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF4A8A4A), Color(0xFF2D5A2D)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFF2D4A2D).withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))]),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('👨‍🍳', style: TextStyle(fontSize: 22)), SizedBox(width: 10),
          Text('Start Cooking Mode', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        ]))),
  ]));

  Widget _buildIngredientsTab() {
    final have    = _ingredients.where((i) => i['have'] == true).toList();
    final missing = _ingredients.where((i) => i['have'] == false).toList();
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _IngSection(title: '✅ In Your Pantry',    items: have),
      const SizedBox(height: 16),
      _IngSection(title: '🛒 Shopping Needed', items: missing, isMissing: true),
    ]));
  }

  Widget _buildNutritionTab() {
    final n = widget.nutrition ?? {'protein': 14, 'carbs': 65, 'fat': 9, 'fiber': 6};
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E3A1E), Color(0xFF2D5A2D)]), borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          const Text('🔥', style: TextStyle(fontSize: 40)), const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${widget.calories}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
            const Text('calories per serving', style: TextStyle(color: Color(0xFF8BBB8B), fontSize: 13)),
          ]),
        ])),
      const SizedBox(height: 20),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
        children: [
          _NutCard(label: 'Protein', value: '${n['protein']}g', emoji: '💪', color: const Color(0xFF5A7BA8)),
          _NutCard(label: 'Carbs',   value: '${n['carbs']}g',   emoji: '🌾', color: const Color(0xFFE8A84C)),
          _NutCard(label: 'Fat',     value: '${n['fat']}g',     emoji: '🫙', color: const Color(0xFF8A5AA8)),
          _NutCard(label: 'Fiber',   value: '${n['fiber']}g',   emoji: '🥦', color: const Color(0xFF4A8A4A)),
        ]),
    ]));
  }

  Widget _buildCookingMode(BuildContext context) {
    final step = _steps[_currentStep];
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A1E),
      appBar: AppBar(backgroundColor: const Color(0xFF1E3A1E),
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => setState(() => _isCookingMode = false)),
        title: const Text('Cooking Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), centerTitle: true),
      body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
        Row(children: [
          Expanded(child: LinearProgressIndicator(
            value: (_currentStep + 1) / _steps.length,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE8A84C)),
            minHeight: 6, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 12),
          Text('Step ${_currentStep+1}/${_steps.length}', style: const TextStyle(color: Color(0xFFE8A84C), fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
        const SizedBox(height: 40),
        Text(step['icon'], style: const TextStyle(fontSize: 80)),
        const SizedBox(height: 28),
        Text(step['step'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.7)),
        const Spacer(),
        if (step['timer'] > 0) ...[
          Container(padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE8A84C).withOpacity(0.3))),
            child: Column(children: [
              Text(_timerRunning ? _fmt(_timerSeconds) : _fmt(step['timer']),
                style: const TextStyle(color: Color(0xFFE8A84C), fontSize: 56, fontWeight: FontWeight.w800, letterSpacing: 4)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _timerRunning
                    ? setState(() { _timer?.cancel(); _timerRunning = false; })
                    : _startTimer(step['timer']),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(color: _timerRunning ? const Color(0xFFE84C4C) : const Color(0xFFE8A84C), borderRadius: BorderRadius.circular(14)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_timerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 6),
                    Text(_timerRunning ? 'Pause' : 'Start Timer', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ]))),
            ])),
          const SizedBox(height: 24),
        ],
        Row(children: [
          if (_currentStep > 0) ...[
            Expanded(child: OutlinedButton.icon(
              onPressed: () => setState(() { _currentStep--; _timer?.cancel(); _timerRunning = false; }),
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
              label: const Text('Previous'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 14)))),
            const SizedBox(width: 12),
          ],
          Expanded(child: ElevatedButton.icon(
            onPressed: _currentStep < _steps.length - 1
                ? () => setState(() { _currentStep++; _timer?.cancel(); _timerRunning = false; })
                : () async {
                    await ApiService.addCookingHistory(userEmail: widget.userEmail, mealName: widget.mealName, emoji: widget.emoji);
                    setState(() => _isCookingMode = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('🎉 Bon appétit! Meal logged!'), backgroundColor: const Color(0xFF2D4A2D),
                      behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                  },
            icon: Icon(_currentStep < _steps.length - 1 ? Icons.arrow_forward_ios_rounded : Icons.check_circle_rounded, size: 18),
            label: Text(_currentStep < _steps.length - 1 ? 'Next Step' : 'Done! 🎉'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8A84C), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 14)))),
        ]),
        const SizedBox(height: 16),
      ])),
    );
  }
}

class _QInfo extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _QInfo({required this.icon, required this.label, required this.color});
  @override Widget build(BuildContext context) => Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500))]);
}
class _IngSection extends StatelessWidget {
  final String title; final List<Map<String,dynamic>> items; final bool isMissing;
  const _IngSection({required this.title, required this.items, this.isMissing = false});
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E3A1E))),
    const SizedBox(height: 10),
    ...items.map((ing) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: isMissing ? Border.all(color: const Color(0xFFE8A84C)) : null),
      child: Row(children: [Text(ing['emoji']!, style: const TextStyle(fontSize: 24)), const SizedBox(width: 12),
        Text(ing['name']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E3A1E))),
        const Spacer(), Text(ing['amount']!, style: const TextStyle(fontSize: 13, color: Color(0xFF7A8A7A)))]))),
  ]);
}
class _NutCard extends StatelessWidget {
  final String label, value, emoji; final Color color;
  const _NutCard({required this.label, required this.value, required this.emoji, required this.color});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
    child: Row(children: [Text(emoji, style: const TextStyle(fontSize: 28)), const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9A9A8A))),
      ])]));
}
