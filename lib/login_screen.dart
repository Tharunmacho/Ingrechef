import 'package:flutter/material.dart';
import 'api_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _isLoading       = false;

  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _phoneController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFE84C4C) : const Color(0xFF2D4A2D),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showSnack('Please enter email and password');
      return;
    }
    setState(() => _isLoading = true);
    final res = await ApiService.login(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (res.containsKey('error')) {
      _showSnack(res['error'] ?? 'Login failed');
    } else {
      final user = res['user'];
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => DashboardScreen(
          userName: user['name'] ?? '',
          userEmail: user['email'] ?? '',
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ));
    }
  }

  Future<void> _handleSignup() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _confirmController.text.trim().isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }
    setState(() => _isLoading = true);
    final res = await ApiService.signup(
      name:            _nameController.text.trim(),
      email:           _emailController.text.trim(),
      phone:           _phoneController.text.trim(),
      password:        _passwordController.text.trim(),
      confirmPassword: _confirmController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (res.containsKey('error')) {
      _showSnack(res['error'] ?? 'Signup failed');
    } else {
      _showSnack('Account created! Please sign in.', isError: false);
      setState(() {
        _isLogin = true;
        _nameController.clear();
        _phoneController.clear();
        _passwordController.clear();
        _confirmController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF1A2E1A), Color(0xFF2D4A2D)]),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              const SizedBox(height: 40),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 52, height: 52,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Color(0xFFE8A84C), Color(0xFFD4873A)]),
                    boxShadow: [BoxShadow(color: const Color(0xFFE8A84C).withOpacity(0.3), blurRadius: 16)]),
                  child: const Center(child: Text('🍳', style: TextStyle(fontSize: 26)))),
                const SizedBox(width: 12),
                RichText(text: const TextSpan(children: [
                  TextSpan(text: 'Ingre', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300, color: Color(0xFFF5F0E8))),
                  TextSpan(text: 'Chef',     style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFFE8A84C))),
                ])),
              ]),
              const SizedBox(height: 10),
              const Text('Zero waste. Maximum flavor.',
                  style: TextStyle(color: Color(0xFF8BAB82), fontSize: 13, letterSpacing: 0.5)),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(color: const Color(0xFFFAF8F2), borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 10))]),
                padding: const EdgeInsets.all(28),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Tab switcher
                  Container(height: 50,
                    decoration: BoxDecoration(color: const Color(0xFFEEEBE0), borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      _TabBtn(label: 'Sign In', active: _isLogin,  onTap: () { if (!_isLogin) setState(() => _isLogin = true); }),
                      _TabBtn(label: 'Sign Up', active: !_isLogin, onTap: () { if (_isLogin)  setState(() => _isLogin = false); }),
                    ]),
                  ),
                  const SizedBox(height: 28),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 350),
                    crossFadeState: _isLogin ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    firstChild: _buildLoginForm(),
                    secondChild: _buildSignupForm(),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _isLoading ? null : (_isLogin ? _handleLogin : _handleSignup),
                    child: Container(height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF2D4A2D), Color(0xFF3D6B3D)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: const Color(0xFF2D4A2D).withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))]),
                      child: Center(child: _isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(_isLogin ? 'Sign In' : 'Create Account',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() => Column(children: [
    _InputField(controller: _emailController, label: 'Email Address', hint: 'you@example.com', icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress),
    const SizedBox(height: 16),
    _InputField(controller: _passwordController, label: 'Password', hint: '••••••••', icon: Icons.lock_outline_rounded, obscure: _obscurePassword,
        suffix: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF8B8577), size: 20),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword))),
  ]);

  Widget _buildSignupForm() => Column(children: [
    _InputField(controller: _nameController,     label: 'Full Name',        hint: 'Gordon Ramsay',  icon: Icons.person_outline_rounded),
    const SizedBox(height: 14),
    _InputField(controller: _emailController,    label: 'Email Address',    hint: 'you@example.com', icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress),
    const SizedBox(height: 14),
    _InputField(controller: _phoneController,    label: 'Phone Number',     hint: '9876543210',      icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
    const SizedBox(height: 14),
    _InputField(controller: _passwordController, label: 'Password',         hint: '••••••••',        icon: Icons.lock_outline_rounded, obscure: _obscurePassword,
        suffix: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF8B8577), size: 20),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword))),
    const SizedBox(height: 14),
    _InputField(controller: _confirmController,  label: 'Confirm Password', hint: '••••••••',        icon: Icons.lock_outline_rounded, obscure: _obscureConfirm,
        suffix: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF8B8577), size: 20),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm))),
  ]);
}

class _TabBtn extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _TabBtn({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(onTap: onTap,
    child: AnimatedContainer(duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF2D4A2D) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)] : []),
      child: Center(child: Text(label, style: TextStyle(
        color: active ? Colors.white : const Color(0xFF6B7B6B), fontWeight: FontWeight.w600, fontSize: 14))))));
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint; final IconData icon;
  final bool obscure; final Widget? suffix; final TextInputType? keyboardType;
  const _InputField({required this.controller, required this.label, required this.hint,
    required this.icon, this.obscure = false, this.suffix, this.keyboardType});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5A4A), letterSpacing: 0.5)),
    const SizedBox(height: 8),
    TextField(controller: controller, obscureText: obscure, keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: Color(0xFF2A3A2A)),
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Color(0xFFBBB6A8), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF6B8B6B), size: 20), suffixIcon: suffix,
        filled: true, fillColor: const Color(0xFFF0EDE4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF5A8A5A), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
  ]);
}
