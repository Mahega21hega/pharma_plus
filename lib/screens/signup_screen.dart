import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data.dart';
import '../theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  bool get _a8Caracteres => _passController.text.length >= 8;
  bool get _aUneMajuscule => _passController.text.contains(RegExp(r'[A-Z]'));
  bool get _aUnChiffre => _passController.text.contains(RegExp(r'[0-9]'));
  bool get _motDePasseValide => _a8Caracteres && _aUneMajuscule && _aUnChiffre;

  void _handleSignup() async {
    if (_nameController.text.isEmpty || _userController.text.isEmpty || _passController.text.isEmpty) {
      setState(() => _error = 'Veuillez remplir tous les champs');
      return;
    }
    if (!_motDePasseValide) {
      setState(() => _error = 'Le mot de passe ne respecte pas tous les critères ci-dessous');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    final success = await context.read<AppData>().registerUser(
          name: _nameController.text,
          username: _userController.text,
          password: _passController.text,
        );

    if (success) {
      if (mounted) Navigator.pop(context);
    } else {
      setState(() {
        _isLoading = false;
        _error = 'Cet identifiant est déjà utilisé';
      });
    }
  }

  Widget _critere(String label, bool valide) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            valide ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: valide ? AppColors.primary : AppColors.danger,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12.5, color: valide ? AppColors.primary : AppColors.danger)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Inscription',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Rejoignez PharmaFody pour gérer votre pharmacie',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 32),
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.danger.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _userController,
                  decoration: const InputDecoration(
                    labelText: 'Identifiant (Pseudo)',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passController,
                  obscureText: _obscurePassword,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                if (_passController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _critere('8 caractères minimum', _a8Caracteres),
                        _critere('Au moins 1 majuscule', _aUneMajuscule),
                        _critere('Au moins 1 chiffre', _aUnChiffre),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Créer mon compte'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
