import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/rpg_theme.dart';
import '../services/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _register = false;
  final _displayCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _displayCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    final auth = context.read<AuthProvider>();
    try {
      if (_register) {
        await auth.register(
          _usernameCtrl.text.trim(),
          _passwordCtrl.text,
          displayName: _displayCtrl.text.trim().isEmpty ? null : _displayCtrl.text.trim(),
        );
      } else {
        await auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [RpgColors.darkVoid, RpgColors.obsidian, Color(0xFF050814)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: RpgColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: RpgColors.border),
                boxShadow: [BoxShadow(
                  color: RpgColors.accent.withOpacity(0.15),
                  blurRadius: 40, spreadRadius: 0,
                )],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/logo.png', width: 96, height: 96),
                  const SizedBox(height: 12),
                  const Text('Media Tracker', style: TextStyle(
                    fontFamily: 'Crimson', fontSize: 14,
                    color: RpgColors.textSecondary, letterSpacing: 2)),
                  const SizedBox(height: 32),
                  if (_register) ...[
                    TextField(
                      controller: _displayCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre visible (opcional)',
                        prefixIcon: Icon(Icons.person, color: RpgColors.accent, size: 18),
                      ),
                      style: const TextStyle(color: RpgColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                  ],
                  AutofillGroup(
                    child: Column(
                      children: [
                        TextField(
                          controller: _usernameCtrl,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(
                            labelText: 'Usuario',
                            prefixIcon: Icon(Icons.shield, color: RpgColors.accent, size: 18),
                          ),
                          style: const TextStyle(color: RpgColors.textPrimary),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: Icon(Icons.lock, color: RpgColors.accent, size: 18),
                          ),
                          style: const TextStyle(color: RpgColors.textPrimary),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: RpgColors.statusDropped.withOpacity(0.15),
                        border: Border.all(color: RpgColors.statusDropped.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_error!, style: const TextStyle(color: RpgColors.statusDropped, fontSize: 13)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RpgColors.goldDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: RpgColors.goldLight))
                        : Text(
                            _register ? 'CREAR CUENTA' : 'ENTRAR',
                            style: const TextStyle(fontFamily: 'Cinzel', letterSpacing: 2, color: RpgColors.goldLight),
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() { _register = !_register; _error = null; }),
                    child: Text(
                      _register ? '¿Ya tienes cuenta? Inicia sesión' : '¿Sin cuenta? Regístrate',
                      style: const TextStyle(color: RpgColors.amethystLight, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
