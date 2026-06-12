import 'package:flutter/material.dart';
import 'api_service.dart';

class IngredientManagementScreen extends StatefulWidget {
  final String userEmail;
  const IngredientManagementScreen({super.key, required this.userEmail});
  @override
  State<IngredientManagementScreen> createState() => _IngredientManagementScreenState();
}

class _IngredientManagementScreenState extends State<IngredientManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _inputController = TextEditingController();
  final _focusNode       = FocusNode();

  List<Map<String, dynamic>> _ingredients = [];
  bool _loading         = true;
  bool _showSuggestions = false;
  String _filterCategory = 'All';

  final List<String> _suggestions = [
    'Bell Pepper','Carrot','Broccoli','Mushrooms','Lemon',
    'Butter','Cheese','Rice','Basil','Cumin','Milk','Bread',
  ];

  final List<Map<String, String>> _history = [
    {'name': 'Milk',     'emoji': '🥛', 'action': 'Used yesterday'},
    {'name': 'Bread',    'emoji': '🍞', 'action': 'Added 2 days ago'},
    {'name': 'Capsicum', 'emoji': '🫑', 'action': 'Used 3 days ago'},
  ];

  final Map<String, String> _emojiMap = {
    'tomato': '🍅','spinach': '🌿','chicken': '🍗','garlic': '🧄',
    'pasta': '🍝','olive': '🫙','egg': '🥚','onion': '🧅',
    'carrot': '🥕','broccoli': '🥦','pepper': '🫑','lemon': '🍋',
    'milk': '🥛','cheese': '🧀','rice': '🍚','bread': '🍞',
    'butter': '🧈','mushroom': '🍄',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _inputController.addListener(() =>
        setState(() => _showSuggestions = _inputController.text.isNotEmpty));
    _loadIngredients();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadIngredients() async {
    setState(() => _loading = true);
    final res = await ApiService.getIngredients(widget.userEmail);
    if (mounted) {
      setState(() {
        _ingredients = res['status'] == 'success'
            ? List<Map<String, dynamic>>.from(res['ingredients'])
            : [];
        _loading = false;
      });
    }
  }

  String _emojiFor(String name) {
    final lower = name.toLowerCase();
    for (final e in _emojiMap.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return '🥗';
  }

  Future<void> _addIngredient(String name) async {
    if (name.trim().isEmpty) return;
    _focusNode.unfocus();
    _inputController.clear();
    setState(() => _showSuggestions = false);

    final res = await ApiService.addIngredient(
      userEmail: widget.userEmail,
      name: name.trim(),
    );
    if (res.containsKey('error')) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['error']), backgroundColor: const Color(0xFFE84C4C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } else {
      _loadIngredients();
    }
  }

  Future<void> _deleteIngredient(int id) async {
    await ApiService.deleteIngredient(id);
    _loadIngredients();
  }

  List<Map<String, dynamic>> get _filtered => _filterCategory == 'All'
      ? _ingredients
      : _ingredients.where((i) => i['category'] == _filterCategory).toList();

  List<String> get _filteredSuggestions => _suggestions
      .where((s) => s.toLowerCase().contains(_inputController.text.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 100, floating: false, pinned: true,
            backgroundColor: const Color(0xFF1E3A1E),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context)),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70),
                onPressed: () => _showClearDialog()),
            ],
            title: const Text('My Ingredients',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            centerTitle: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF1E3A1E), Color(0xFF2D5A2D)]))),
            ),
            bottom: TabBar(controller: _tabController,
              indicatorColor: const Color(0xFFE8A84C), indicatorWeight: 3,
              labelColor: const Color(0xFFE8A84C), unselectedLabelColor: const Color(0xFF8BBB8B),
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [Tab(text: 'Pantry'), Tab(text: 'History')]),
          ),
        ],
        body: TabBarView(controller: _tabController, children: [
          _buildPantryTab(),
          _buildHistoryTab(),
        ]),
      ),
    );
  }

  Widget _buildPantryTab() {
    return Column(children: [
      // Input
      Container(color: Colors.white, padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(child: TextField(
              controller: _inputController, focusNode: _focusNode,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1E3A1E)),
              decoration: InputDecoration(
                hintText: 'Type an ingredient...',
                hintStyle: const TextStyle(color: Color(0xFFBBB6A8), fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6B8B6B), size: 20),
                filled: true, fillColor: const Color(0xFFF0EDE4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF5A8A5A), width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              onSubmitted: _addIngredient)),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _addIngredient(_inputController.text),
              child: Container(width: 50, height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF3D6B3D), Color(0xFF2D4A2D)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: const Color(0xFF2D4A2D).withOpacity(0.35), blurRadius: 10)]),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 26))),
          ]),
          if (_showSuggestions && _filteredSuggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(height: 36, child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filteredSuggestions.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _addIngredient(_filteredSuggestions[i]),
                child: Container(margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFE8F5E8), borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF8BC88B))),
                  child: Row(children: [
                    const Icon(Icons.add_rounded, size: 14, color: Color(0xFF3D6B3D)),
                    const SizedBox(width: 4),
                    Text(_filteredSuggestions[i], style: const TextStyle(fontSize: 12, color: Color(0xFF3D6B3D), fontWeight: FontWeight.w600)),
                  ])))),
            ),
          ],
        ])),

      // Category chips
      SizedBox(height: 52, child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        children: ['All','Vegetables','Protein','Grains','Spices','Condiments','Greens','Other']
            .map((cat) => GestureDetector(
              onTap: () => setState(() => _filterCategory = cat),
              child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _filterCategory == cat ? const Color(0xFF2D4A2D) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)]),
                child: Text(cat, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: _filterCategory == cat ? Colors.white : const Color(0xFF5A7A5A))))))
            .toList())),

      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Text('${_filtered.length} items', style: const TextStyle(fontSize: 13, color: Color(0xFF7A8A7A), fontWeight: FontWeight.w500)),
        ])),

      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D4A2D)))
          : _filtered.isEmpty
              ? const Center(child: Text('No ingredients yet.\nAdd some above! 🥦',
                  textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9A9A8A), fontSize: 14, height: 1.6)))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 1.4, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final ing = _filtered[i];
                    return _IngredientCard(
                      name:     ing['name']     ?? '',
                      quantity: ing['quantity'] ?? '',
                      expiry:   ing['expiry']   ?? '',
                      emoji:    _emojiFor(ing['name'] ?? ''),
                      onDelete: () => _deleteIngredient(ing['id']));
                  })),
    ]);
  }

  Widget _buildHistoryTab() {
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E3A1E))),
      const SizedBox(height: 14),
      ..._history.map((item) => Container(
        margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
        child: Row(children: [
          Container(width: 48, height: 48,
            decoration: BoxDecoration(color: const Color(0xFFEEF5EE), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(item['emoji']!, style: const TextStyle(fontSize: 24)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['name']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E3A1E))),
            Text(item['action']!, style: const TextStyle(fontSize: 12, color: Color(0xFF8A9A8A))),
          ])),
          GestureDetector(
            onTap: () => _addIngredient(item['name']!),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFEEF5EE), borderRadius: BorderRadius.circular(20)),
              child: const Text('Re-add', style: TextStyle(fontSize: 12, color: Color(0xFF3D6B3D), fontWeight: FontWeight.w600)))),
        ]))),
    ]);
  }

  void _showClearDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Clear All Ingredients', style: TextStyle(fontWeight: FontWeight.w700)),
      content: const Text('This will remove all items from your pantry.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await ApiService.clearIngredients(widget.userEmail);
            _loadIngredients();
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE84C4C)),
          child: const Text('Clear All', style: TextStyle(color: Colors.white))),
      ],
    ));
  }
}

class _IngredientCard extends StatelessWidget {
  final String name, quantity, expiry, emoji;
  final VoidCallback onDelete;
  const _IngredientCard({required this.name, required this.quantity, required this.expiry, required this.emoji, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isExpiringSoon = expiry.contains('day') &&
        int.tryParse(expiry.split(' ')[0]) != null &&
        int.parse(expiry.split(' ')[0]) <= 2;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: isExpiringSoon ? Border.all(color: const Color(0xFFE8A84C), width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
      child: Padding(padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const Spacer(),
            GestureDetector(onTap: onDelete,
              child: Container(width: 26, height: 26,
                decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFE84C4C)))),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E3A1E)), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              Text(quantity, style: const TextStyle(fontSize: 11, color: Color(0xFF7A8A7A))),
              const Spacer(),
              if (isExpiringSoon) const Text('⚠️', style: TextStyle(fontSize: 12)),
              Text(expiry, style: TextStyle(fontSize: 10,
                color: isExpiringSoon ? const Color(0xFFE8A84C) : const Color(0xFF9A9A8A),
                fontWeight: isExpiringSoon ? FontWeight.w600 : FontWeight.normal)),
            ]),
          ]),
        ])));
  }
}
