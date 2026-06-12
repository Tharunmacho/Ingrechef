import 'package:flutter/material.dart';
import 'api_service.dart';
import 'meal_detail_screen.dart';

class AiMealGenerationScreen extends StatefulWidget {
  final String userEmail;
  const AiMealGenerationScreen({super.key, required this.userEmail});
  @override
  State<AiMealGenerationScreen> createState() => _AiMealGenerationScreenState();
}

class _AiMealGenerationScreenState extends State<AiMealGenerationScreen>
    with SingleTickerProviderStateMixin {
  bool _isGenerating = false;
  bool _hasResults   = false;
  List<Map<String, dynamic>> _meals = [];
  String _dietFilter = 'All';
  String _sortBy     = 'Time';
  String? _error;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseController.dispose(); super.dispose(); }

  Future<void> _generateMeals() async {
    setState(() { _isGenerating = true; _error = null; });

    final res = await ApiService.generateMeals(
      userEmail: widget.userEmail,
      dietFilter: _dietFilter,
    );

    if (!mounted) return;
    if (res.containsKey('error')) {
      setState(() { _isGenerating = false; _error = res['error']; });
    } else {
      setState(() {
        _isGenerating = false;
        _hasResults   = true;
        _meals = List<Map<String, dynamic>>.from(res['meals'] ?? []);
      });
    }
  }

  List<Map<String, dynamic>> get _sortedMeals {
    final list = List<Map<String, dynamic>>.from(_meals);
    list.sort((a, b) {
      if (_sortBy == 'Time')     return (a['time']     as int).compareTo(b['time']     as int);
      if (_sortBy == 'Calories') return (a['calories'] as int).compareTo(b['calories'] as int);
      return 0;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A1E),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('AI Meal Generator', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          if (_hasResults) IconButton(icon: const Icon(Icons.refresh_rounded, color: Color(0xFFE8A84C), size: 22), onPressed: _generateMeals),
        ],
      ),
      body: _isGenerating ? _buildGeneratingState() : !_hasResults ? _buildTriggerState() : _buildResultsState(),
    );
  }

  Widget _buildTriggerState() {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 20),
      Center(child: AnimatedBuilder(animation: _pulseAnim,
        builder: (_, __) => Transform.scale(scale: _pulseAnim.value,
          child: Container(width: 160, height: 160,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF2D5A2D), Color(0xFF1E3A1E)]),
              boxShadow: [BoxShadow(color: const Color(0xFF2D4A2D).withOpacity(0.4), blurRadius: 40, spreadRadius: 5)]),
            child: const Center(child: Text('✨', style: TextStyle(fontSize: 70))))))),
      const SizedBox(height: 32),
      const Text('AI-Powered\nMeal Magic', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF1E3A1E), height: 1.2)),
      const SizedBox(height: 14),
      const Text('Our AI analyses your pantry ingredients and generates personalised meal ideas with zero waste.',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Color(0xFF6A8A6A), height: 1.6)),
      const SizedBox(height: 24),

      // Diet filter before generating
      Row(mainAxisAlignment: MainAxisAlignment.center, children: ['All','Veg','Non-Veg'].map((f) =>
        GestureDetector(onTap: () => setState(() => _dietFilter = f),
          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _dietFilter == f ? const Color(0xFF2D4A2D) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
            child: Text(f, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: _dietFilter == f ? Colors.white : const Color(0xFF5A7A5A)))))).toList()),

      const SizedBox(height: 32),
      if (_error != null) ...[
        Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE84C4C).withOpacity(0.3))),
          child: Text(_error!, style: const TextStyle(color: Color(0xFFE84C4C), fontSize: 13))),
      ],
      GestureDetector(onTap: _generateMeals,
        child: Container(height: 62,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE8A84C), Color(0xFFD4873A)]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: const Color(0xFFE8A84C).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))]),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('✨', style: TextStyle(fontSize: 22)),
            SizedBox(width: 10),
            Text('Generate My Meals', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ]))),
    ]));
  }

  Widget _buildGeneratingState() {
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 6.28), duration: const Duration(seconds: 3),
        builder: (_, v, __) => Transform.rotate(angle: v, child: const Text('✨', style: TextStyle(fontSize: 80)))),
      const SizedBox(height: 32),
      const Text('Cooking up ideas...', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1E3A1E))),
      const SizedBox(height: 8),
      const Text('Checking your pantry & matching recipes', style: TextStyle(fontSize: 14, color: Color(0xFF6A8A6A))),
      const SizedBox(height: 36),
      const CircularProgressIndicator(color: Color(0xFF2D4A2D), strokeWidth: 3),
    ])));
  }

  Widget _buildResultsState() {
    return Column(children: [
      // Filter & Sort bar
      Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(16,14,16,14),
        child: Row(children: [
          Expanded(child: Row(children: ['All','Veg','Non-Veg'].map((f) =>
            GestureDetector(onTap: () => setState(() => _dietFilter = f),
              child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _dietFilter == f ? const Color(0xFF2D4A2D) : const Color(0xFFF0EDE4),
                  borderRadius: BorderRadius.circular(20)),
                child: Text(f, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: _dietFilter == f ? Colors.white : const Color(0xFF5A7A5A)))))).toList())),
          GestureDetector(
            onTap: () => showModalBottomSheet(context: context, backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              builder: (_) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Sort By', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                ...['Time','Calories'].map((s) => ListTile(
                  leading: Icon(s == 'Time' ? Icons.timer_outlined : Icons.local_fire_department_outlined, color: const Color(0xFF3D6B3D)),
                  title: Text(s),
                  trailing: _sortBy == s ? const Icon(Icons.check_circle_rounded, color: Color(0xFF3D6B3D)) : null,
                  onTap: () { setState(() => _sortBy = s); Navigator.pop(context); })),
              ]))),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFF0EDE4), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const Icon(Icons.sort_rounded, size: 16, color: Color(0xFF5A7A5A)),
                const SizedBox(width: 4),
                Text(_sortBy, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5A7A5A))),
              ]))),
        ])),

      Expanded(child: _sortedMeals.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🍽️', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              const Text('No meals found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E3A1E))),
              const SizedBox(height: 8),
              Text('Try adding more ingredients\nor changing the filter', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7A8A7A), fontSize: 14)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _generateMeals,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D4A2D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Try Again', style: TextStyle(color: Colors.white))),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              itemCount: _sortedMeals.length,
              itemBuilder: (_, i) => _MealCard(
                meal: _sortedMeals[i],
                userEmail: widget.userEmail,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => MealDetailScreen(
                    mealName: _sortedMeals[i]['name'],
                    emoji: _sortedMeals[i]['emoji'] ?? '🍽️',
                    cookTime: _sortedMeals[i]['time'] ?? 30,
                    calories: _sortedMeals[i]['calories'] ?? 0,
                    userEmail: widget.userEmail,
                    difficulty: _sortedMeals[i]['difficulty'],
                    nutrition: _sortedMeals[i]['nutrition'],
                  )))),
            )),
    ]);
  }
}

class _MealCard extends StatelessWidget {
  final Map<String, dynamic> meal;
  final String userEmail;
  final VoidCallback onTap;
  const _MealCard({required this.meal, required this.userEmail, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final missing = (meal['missing'] as List?) ?? [];
    final waste   = (meal['match_pct'] as int?) ?? 0;
    return GestureDetector(onTap: onTap,
      child: Container(margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 14, offset: const Offset(0, 4))]),
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(18), child: Row(children: [
            Container(width: 70, height: 70,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF2D5A2D).withOpacity(0.1), const Color(0xFFE8A84C).withOpacity(0.1)]),
                borderRadius: BorderRadius.circular(18)),
              child: Center(child: Text(meal['emoji'] ?? '🍽️', style: const TextStyle(fontSize: 40)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(meal['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E3A1E))),
              const SizedBox(height: 6),
              Row(children: [
                _InfoBadge(icon: Icons.timer_outlined,                  label: '${meal['time']}m',           color: const Color(0xFF5A7BA8)),
                const SizedBox(width: 8),
                _InfoBadge(icon: Icons.local_fire_department_outlined,  label: '${meal['calories']} kcal',   color: const Color(0xFFE8A84C)),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: ((meal['tags'] as List?) ?? []).map<Widget>((tag) =>
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: tag == 'Vegetarian' ? const Color(0xFFEEF5EE) : const Color(0xFFFFF5E8), borderRadius: BorderRadius.circular(10)),
                  child: Text(tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: tag == 'Vegetarian' ? const Color(0xFF3D6B3D) : const Color(0xFFD4873A))))).toList()),
            ])),
          ])),

          Padding(padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(children: [
              const Text('♻️', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Ingredient match', style: TextStyle(fontSize: 11, color: Color(0xFF7A8A7A))),
                  Text('$waste%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF3D6B3D))),
                ]),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: waste / 100,
                  backgroundColor: const Color(0xFFE8EDE8),
                  valueColor: AlwaysStoppedAnimation<Color>(waste == 100 ? const Color(0xFF3D6B3D) : const Color(0xFF8BBB8B)),
                  minHeight: 5, borderRadius: BorderRadius.circular(3)),
              ])),
            ])),

          if (missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(children: [
                const Icon(Icons.shopping_cart_outlined, size: 14, color: Color(0xFF5A7BA8)),
                const SizedBox(width: 6),
                Expanded(child: Text('Need: ${missing.join(', ')}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5A7BA8), fontWeight: FontWeight.w500))),
              ])),
          ],

          Padding(padding: const EdgeInsets.fromLTRB(18,14,18,18),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () async {
                  for (final item in missing) {
                    await ApiService.addShoppingItem(userEmail: userEmail, name: item, forMeal: meal['name'] ?? '');
                  }
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Missing items added to shopping list 🛒'),
                    backgroundColor: const Color(0xFF2D4A2D), behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                },
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF5A8A5A)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 10)),
                child: const Text('Add to List', style: TextStyle(color: Color(0xFF3D6B3D), fontWeight: FontWeight.w600, fontSize: 13)))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D4A2D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 10)),
                child: const Text('View Recipe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)))),
            ])),
        ])));
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _InfoBadge({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: color), const SizedBox(width: 3),
    Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
  ]);
}