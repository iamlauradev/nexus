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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image with dark overlay
          Image.asset('assets/images/login.png', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.65)),
          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: RpgColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: RpgColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 48, spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: RpgColors.accent.withOpacity(0.08),
                      blurRadius: 48, spreadRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/logo.png', width: 80, height: 80),
                    const SizedBox(height: 10),
                    const Text('NEXUS', style: TextStyle(
                      fontFamily: 'Cinzel', fontSize: 22,
                      color: RpgColors.textPrimary, letterSpacing: 4,
                      fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Tu colección multimedia', style: TextStyle(
                      fontFamily: 'DMSans', fontSize: 12,
                      color: RpgColors.textMuted, letterSpacing: 0.3)),
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
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_register ? 'Crear cuenta' : 'Entrar'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => setState(() { _register = !_register; _error = null; }),
                    child: Text(
                      _register ? '¿Ya tienes cuenta? Inicia sesión' : '¿Sin cuenta? Regístrate',
                      style: const TextStyle(color: RpgColors.goldLight, fontSize: 13, fontFamily: 'DMSans'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
