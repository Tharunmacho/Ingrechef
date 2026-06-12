import 'package:flutter/material.dart';
import 'api_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userEmail, userName;
  const ProfileScreen({super.key, required this.userEmail, required this.userName});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isEditing  = false;
  bool _isSaving   = false;
  bool _loadingSaved   = true;
  bool _loadingHistory = true;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  List<String> _selectedDiets   = [];
  List<String> _selectedAllergies = [];
  List<Map<String, dynamic>> _savedMeals = [];
  List<Map<String, dynamic>> _history    = [];

  final List<String> _allDiets = ['Vegetarian','Vegan','Gluten-Free','Keto','Paleo','Dairy-Free','Low-Carb','Mediterranean'];
  final List<String> _allAllergens = ['Peanuts','Tree Nuts','Milk','Eggs','Wheat','Soy','Fish','Shellfish'];

  @override
  void initState() {
    super.initState();
    _tabController   = TabController(length: 3, vsync: this);
    _nameController  = TextEditingController(text: widget.userName);
    _phoneController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() { _tabController.dispose(); _nameController.dispose(); _phoneController.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    // Load current user profile for diet/allergy prefs
    final userRes = await ApiService.getCurrentUser();
    if (mounted && userRes['status'] == 'success') {
      final u = userRes['user'];
      final dietStr    = (u['diet_pref'] ?? '') as String;
      final allergyStr = (u['allergies'] ?? '') as String;
      setState(() {
        _selectedDiets     = dietStr.isNotEmpty    ? dietStr.split(',').map((s) => s.trim()).toList()    : [];
        _selectedAllergies = allergyStr.isNotEmpty ? allergyStr.split(',').map((s) => s.trim()).toList() : [];
        _phoneController.text = u['phone'] ?? '';
      });
    }

    // Load saved meals
    final savedRes = await ApiService.getSavedMeals(widget.userEmail);
    if (mounted) {
      setState(() {
        _savedMeals  = savedRes['status'] == 'success' ? List<Map<String,dynamic>>.from(savedRes['saved_meals']) : [];
        _loadingSaved = false;
      });
    }

    // Load cooking history
    final histRes = await ApiService.getCookingHistory(widget.userEmail);
    if (mounted) {
      setState(() {
        _history        = histRes['status'] == 'success' ? List<Map<String,dynamic>>.from(histRes['history']) : [];
        _loadingHistory = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    await ApiService.updateProfile(
      email:     widget.userEmail,
      name:      _nameController.text.trim(),
      phone:     _phoneController.text.trim(),
      dietPref:  _selectedDiets.join(','),
      allergies: _selectedAllergies.join(','),
    );
    setState(() { _isSaving = false; _isEditing = false; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Profile updated ✅'),
      backgroundColor: const Color(0xFF2D4A2D), behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(expandedHeight: 240, pinned: true, backgroundColor: const Color(0xFF1E3A1E),
            leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
            actions: [
              if (_isSaving)
                const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFFE8A84C), strokeWidth: 2)))
              else
                IconButton(
                  icon: Icon(_isEditing ? Icons.check_rounded : Icons.edit_outlined, color: const Color(0xFFE8A84C)),
                  onPressed: _isEditing ? _saveProfile : () => setState(() => _isEditing = true)),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E3A1E), Color(0xFF2D5A2D)])),
                child: Padding(padding: const EdgeInsets.fromLTRB(24,80,24,16),
                  child: Row(children: [
                    Container(width: 84, height: 84,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [Color(0xFFE8A84C), Color(0xFFD4873A)]),
                        boxShadow: [BoxShadow(color: const Color(0xFFE8A84C).withOpacity(0.35), blurRadius: 16)]),
                      child: const Center(child: Text('👨‍🍳', style: TextStyle(fontSize: 42)))),
                    const SizedBox(width: 16),
                    Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _isEditing
                          ? TextField(controller: _nameController,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                              decoration: const InputDecoration(border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8A84C))), isDense: true))
                          : Text(widget.userName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(widget.userEmail, style: const TextStyle(color: Color(0xFF8BBB8B), fontSize: 13)),
                      if (_isEditing) ...[
                        const SizedBox(height: 6),
                        TextField(controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          decoration: const InputDecoration(hintText: 'Phone...', hintStyle: TextStyle(color: Colors.white38),
                            border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8BBB8B))), isDense: true)),
                      ],
                    ])),
                  ])),
              )),
            bottom: TabBar(controller: _tabController,
              indicatorColor: const Color(0xFFE8A84C), indicatorWeight: 3,
              labelColor: const Color(0xFFE8A84C), unselectedLabelColor: const Color(0xFF8BBB8B),
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [Tab(text: 'Preferences'), Tab(text: 'Saved'), Tab(text: 'History')]),
          ),
        ],
        body: TabBarView(controller: _tabController, children: [
          _buildPrefsTab(),
          _buildSavedTab(),
          _buildHistoryTab(),
        ]),
      ),
      bottomNavigationBar: _buildLogoutBar(context),
    );
  }

  Widget _buildPrefsTab() {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('🌱 Diet Preferences', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E3A1E))),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: _allDiets.map((d) {
        final sel = _selectedDiets.contains(d);
        return GestureDetector(
          onTap: () => setState(() => sel ? _selectedDiets.remove(d) : _selectedDiets.add(d)),
          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: sel ? const Color(0xFF2D4A2D) : Colors.white, borderRadius: BorderRadius.circular(22),
              border: Border.all(color: sel ? const Color(0xFF2D4A2D) : const Color(0xFFDDD9CE)),
              boxShadow: sel ? [BoxShadow(color: const Color(0xFF2D4A2D).withOpacity(0.25), blurRadius: 8)] : []),
            child: Text(d, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : const Color(0xFF5A7A5A)))));
      }).toList()),
      const SizedBox(height: 24),
      const Text('⚠️ Allergies & Intolerances', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E3A1E))),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: _allAllergens.map((a) {
        final sel = _selectedAllergies.contains(a);
        return GestureDetector(
          onTap: () => setState(() => sel ? _selectedAllergies.remove(a) : _selectedAllergies.add(a)),
          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFFE84C4C).withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: sel ? const Color(0xFFE84C4C) : const Color(0xFFDDD9CE))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (sel) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFE84C4C))),
              Text(a, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? const Color(0xFFE84C4C) : const Color(0xFF5A7A5A))),
            ])));
      }).toList()),
      if (_isEditing) ...[
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _saveProfile,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D4A2D), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('Save Preferences', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      ],
    ]));
  }

  Widget _buildSavedTab() {
    if (_loadingSaved) return const Center(child: CircularProgressIndicator(color: Color(0xFF2D4A2D)));
    if (_savedMeals.isEmpty) return const Center(child: Text('No saved meals yet.\nTap ❤️ on any recipe!',
        textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9A9A8A), fontSize: 14, height: 1.6)));
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: _savedMeals.length, itemBuilder: (_, i) {
      final m = _savedMeals[i];
      return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
        child: Row(children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFFEEF5EE), borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(m['emoji'] ?? '🍽️', style: const TextStyle(fontSize: 30)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m['meal_name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E3A1E))),
            const SizedBox(height: 4),
            Text(m['saved_at'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF9A9A8A))),
          ])),
          if (m['rating'] != null)
            Row(children: List.generate(5, (s) => Icon(
              s < ((m['rating'] as num).round()) ? Icons.star_rounded : Icons.star_border_rounded,
              color: const Color(0xFFE8A84C), size: 16))),
        ]));
    });
  }

  Widget _buildHistoryTab() {
    if (_loadingHistory) return const Center(child: CircularProgressIndicator(color: Color(0xFF2D4A2D)));
    if (_history.isEmpty) return const Center(child: Text('No cooking history yet.\nStart cooking! 👨‍🍳',
        textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9A9A8A), fontSize: 14, height: 1.6)));
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: _history.length, itemBuilder: (_, i) {
      final h = _history[i];
      return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF2D4A2D), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(h['cooked_at']?.toString().substring(5,10) ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)))),
          const SizedBox(width: 12),
          Text(h['emoji'] ?? '🍽️', style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(child: Text(h['meal_name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E3A1E)))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFF0EDE4), borderRadius: BorderRadius.circular(10)),
            child: Text('${h['servings']} serving', style: const TextStyle(fontSize: 11, color: Color(0xFF6A8A6A)))),
        ]));
    });
  }

  Widget _buildLogoutBar(BuildContext context) {
    return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(24,8,24,16),
      child: GestureDetector(
        onTap: () => showDialog(context: context, builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700)),
          content: const Text('Are you sure you want to log out?', style: TextStyle(color: Color(0xFF5A7A5A), height: 1.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Color(0xFF7A9A7A)))),
            ElevatedButton(
              onPressed: () async {
                await ApiService.logout();
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE84C4C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          ])),
        child: Container(height: 54,
          decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE84C4C).withOpacity(0.3))),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.logout_rounded, color: Color(0xFFE84C4C), size: 20), SizedBox(width: 8),
            Text('Log Out', style: TextStyle(color: Color(0xFFE84C4C), fontWeight: FontWeight.w700, fontSize: 15)),
          ])))));
  }
}
