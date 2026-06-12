import 'package:flutter/material.dart';
import 'api_service.dart';

class ShoppingScreen extends StatefulWidget {
  final String userEmail;
  const ShoppingScreen({super.key, required this.userEmail});
  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _addController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  final List<Map<String, dynamic>> _smartSuggestions = [
    {'name': 'Cherry Tomatoes', 'reason': 'Low in pantry',    'emoji': '🍅'},
    {'name': 'Garlic Powder',   'reason': 'Used frequently',  'emoji': '🧄'},
    {'name': 'Greek Yogurt',    'reason': 'Pairs with 3 meals','emoji': '🥛'},
    {'name': 'Lemon',           'reason': 'Common ingredient','emoji': '🍋'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadItems();
  }

  @override
  void dispose() { _tabController.dispose(); _addController.dispose(); super.dispose(); }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    final res = await ApiService.getShoppingList(widget.userEmail);
    if (mounted) {
      setState(() {
        _items  = res['status'] == 'success' ? List<Map<String,dynamic>>.from(res['items']) : [];
        _loading = false;
      });
    }
  }

  int get _completedCount => _items.where((i) => i['is_done'] == true).length;

  Future<void> _toggle(int id) async {
    await ApiService.toggleShoppingItem(id);
    _loadItems();
  }

  Future<void> _delete(int id) async {
    await ApiService.deleteShoppingItem(id);
    _loadItems();
  }

  Future<void> _addItem(String name) async {
    if (name.trim().isEmpty) return;
    await ApiService.addShoppingItem(userEmail: widget.userEmail, name: name.trim());
    _addController.clear();
    Navigator.pop(context);
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A1E),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Shopping List', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white70), onPressed: _loadItems)],
        bottom: TabBar(controller: _tabController,
          indicatorColor: const Color(0xFFE8A84C), indicatorWeight: 3,
          labelColor: const Color(0xFFE8A84C), unselectedLabelColor: const Color(0xFF8BBB8B),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'My List'), Tab(text: 'Smart Picks')]),
      ),
      body: Column(children: [
        // Progress banner
        Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(20,14,20,14),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('$_completedCount of ${_items.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E3A1E))),
                const Text(' items done', style: TextStyle(fontSize: 14, color: Color(0xFF6A8A6A))),
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _items.isEmpty ? 0 : _completedCount / _items.length,
                backgroundColor: const Color(0xFFE0DDD4),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A8A4A)),
                minHeight: 6, borderRadius: BorderRadius.circular(3)),
            ])),
            const SizedBox(width: 16),
            Container(width: 52, height: 52,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: _completedCount == _items.length && _items.isNotEmpty ? const Color(0xFF4A8A4A) : const Color(0xFFF0EDE4)),
              child: Icon(_completedCount == _items.length && _items.isNotEmpty ? Icons.check_circle_rounded : Icons.shopping_cart_outlined,
                color: _completedCount == _items.length && _items.isNotEmpty ? Colors.white : const Color(0xFF5A7A5A), size: 26)),
          ])),

        Expanded(child: TabBarView(controller: _tabController, children: [
          _buildMyList(),
          _buildSmartPicks(),
        ])),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        backgroundColor: const Color(0xFF2D4A2D),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
    );
  }

  Widget _buildMyList() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF2D4A2D)));
    if (_items.isEmpty) return const Center(child: Text('Your list is empty!\nTap + to add items 🛒',
        textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9A9A8A), fontSize: 14, height: 1.6)));

    // Group by for_meal
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in _items) {
      final meal = item['for_meal'] ?? 'General';
      grouped.putIfAbsent(meal, () => []).add(item);
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16,16,16,100), physics: const BouncingScrollPhysics(), children: [
      ...grouped.entries.map((entry) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(bottom: 10), child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFF2D4A2D), borderRadius: BorderRadius.circular(20)),
          child: Text(entry.key, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)))),
        ...entry.value.map((item) => _ShoppingTile(
          item: item,
          onToggle: () => _toggle(item['id']),
          onDelete: () => _delete(item['id']))),
        const SizedBox(height: 12),
      ])),
      if (_completedCount > 0) TextButton.icon(
        onPressed: () async { await ApiService.clearCompletedShopping(widget.userEmail); _loadItems(); },
        icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFE84C4C), size: 18),
        label: const Text('Clear completed', style: TextStyle(color: Color(0xFFE84C4C), fontWeight: FontWeight.w600))),
    ]);
  }

  Widget _buildSmartPicks() {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF5A7BA8), Color(0xFF3A5A88)]), borderRadius: BorderRadius.circular(16)),
        child: const Row(children: [
          Text('🤖', style: TextStyle(fontSize: 24)), SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AI-Powered Suggestions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            Text('Based on your cooking habits', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ])),
        ])),
      const SizedBox(height: 16),
      ..._smartSuggestions.map((s) => Container(
        margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
        child: Row(children: [
          Text(s['emoji']!, style: const TextStyle(fontSize: 30)), const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['name']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E3A1E))),
            Text(s['reason']!, style: const TextStyle(fontSize: 12, color: Color(0xFF7A8A7A))),
          ])),
          GestureDetector(
            onTap: () async {
              await ApiService.addShoppingItem(userEmail: widget.userEmail, name: s['name']!, emoji: s['emoji']!);
              _loadItems();
              _tabController.animateTo(0);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Added ${s['name']}!'), backgroundColor: const Color(0xFF2D4A2D),
                behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
            },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3D6B3D), Color(0xFF2D4A2D)]), borderRadius: BorderRadius.circular(12)),
              child: const Text('+ Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)))),
        ]))),
    ]));
  }

  void _showAddSheet() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Add to Shopping List', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1E3A1E))),
          const SizedBox(height: 18),
          TextField(controller: _addController, autofocus: true,
            decoration: InputDecoration(hintText: 'Item name...', hintStyle: const TextStyle(color: Color(0xFFBBB6A8)),
              filled: true, fillColor: const Color(0xFFF0EDE4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF5A8A5A), width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _addItem(_addController.text),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D4A2D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('Add to List', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
          const SizedBox(height: 24),
        ])));
  }
}

class _ShoppingTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onToggle, onDelete;
  const _ShoppingTile({required this.item, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDone = item['is_done'] == true;
    return Dismissible(
      key: Key('${item['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: const Color(0xFFE84C4C), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24)),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(onTap: onToggle,
        child: AnimatedContainer(duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDone ? const Color(0xFFF0F5F0) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isDone ? Border.all(color: const Color(0xFF8BBB8B)) : null,
            boxShadow: isDone ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
          child: Row(children: [
            AnimatedContainer(duration: const Duration(milliseconds: 200), width: 26, height: 26,
              decoration: BoxDecoration(color: isDone ? const Color(0xFF4A8A4A) : Colors.transparent, shape: BoxShape.circle,
                border: isDone ? null : Border.all(color: const Color(0xFFCCC9BC), width: 2)),
              child: isDone ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null),
            const SizedBox(width: 12),
            Text(item['emoji'] ?? '🛒', style: TextStyle(fontSize: 24, color: isDone ? Colors.black.withOpacity(0.4) : Colors.black)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['name'] ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                color: isDone ? const Color(0xFF9A9A9A) : const Color(0xFF1E3A1E),
                decoration: isDone ? TextDecoration.lineThrough : null)),
              Text(item['quantity'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF9A9A8A))),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFF0EDE4), borderRadius: BorderRadius.circular(8)),
              child: Text(item['category'] ?? '', style: const TextStyle(fontSize: 10, color: Color(0xFF7A8A7A), fontWeight: FontWeight.w500))),
          ]))));
  }
}
