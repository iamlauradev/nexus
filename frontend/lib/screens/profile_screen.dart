import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/rpg_theme.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl    = TextEditingController();
  final _avatarCtrl  = TextEditingController();
  final _currPwCtrl  = TextEditingController();
  final _newPwCtrl   = TextEditingController();
  final _confPwCtrl  = TextEditingController();
  bool _savingProfile = false;
  bool _savingPw      = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl.text   = user?.displayName ?? '';
    _avatarCtrl.text = user?.avatarUrl ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _avatarCtrl.dispose();
    _currPwCtrl.dispose(); _newPwCtrl.dispose(); _confPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    try {
      await ApiService.updateProfile(
        displayName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        avatarUrl: _avatarCtrl.text.trim().isEmpty ? null : _avatarCtrl.text.trim(),
      );
      await context.read<AuthProvider>().refreshUser();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado'), backgroundColor: Color(0xFF22C55E)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: RpgColors.statusDropped));
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPwCtrl.text != _confPwCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: RpgColors.statusDropped));
      return;
    }
    setState(() => _savingPw = true);
    try {
      await ApiService.changePassword(_currPwCtrl.text, _newPwCtrl.text);
      _currPwCtrl.clear(); _newPwCtrl.clear(); _confPwCtrl.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña cambiada'), backgroundColor: Color(0xFF22C55E)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: RpgColors.statusDropped));
    } finally {
      if (mounted) setState(() => _savingPw = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Avatar
          Center(child: CircleAvatar(
            radius: 48,
            backgroundColor: RpgColors.charcoal,
            backgroundImage: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: (user?.avatarUrl == null || user!.avatarUrl!.isEmpty)
                ? const Icon(Icons.person_outline, size: 48, color: RpgColors.textMuted)
                : null,
          )),
          const SizedBox(height: 8),
          Center(child: Text('@${user?.username ?? ''}',
            style: const TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 14))),
          const SizedBox(height: 24),

          const _SectionTitle('INFORMACIÓN'),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre visible',
              prefixIcon: Icon(Icons.badge_outlined, color: RpgColors.accent, size: 18)),
            style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _avatarCtrl,
            decoration: const InputDecoration(
              labelText: 'URL de avatar',
              hintText: 'https://...',
              prefixIcon: Icon(Icons.image_outlined, color: RpgColors.accent, size: 18)),
            style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savingProfile ? null : _saveProfile,
              child: _savingProfile
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar cambios'),
            ),
          ),

          const SizedBox(height: 28),
          const _SectionTitle('CAMBIAR CONTRASEÑA'),
          const SizedBox(height: 12),
          TextField(
            controller: _currPwCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña actual',
              prefixIcon: Icon(Icons.lock_outline, color: RpgColors.accent, size: 18)),
            style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _newPwCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Nueva contraseña (mín. 8, letra + número)',
              prefixIcon: Icon(Icons.lock_reset_outlined, color: RpgColors.accent, size: 18)),
            style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confPwCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirmar nueva contraseña',
              prefixIcon: Icon(Icons.lock_reset_outlined, color: RpgColors.accent, size: 18)),
            style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savingPw ? null : _changePassword,
              style: ElevatedButton.styleFrom(backgroundColor: RpgColors.goldDark),
              child: _savingPw
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Cambiar contraseña'),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(
    fontFamily: 'DMSans', fontSize: 12, color: RpgColors.accent,
    letterSpacing: 0.5, fontWeight: FontWeight.w700));
}
