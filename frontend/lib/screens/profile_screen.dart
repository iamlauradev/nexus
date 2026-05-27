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

  // password visibility
  bool _showCurrPw  = false;
  bool _showNewPw   = false;
  bool _showConfPw  = false;

  // live avatar preview
  String _avatarPreview = '';

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl.text   = user?.displayName ?? '';
    _avatarCtrl.text = user?.avatarUrl ?? '';
    _avatarPreview   = user?.avatarUrl ?? '';
    _avatarCtrl.addListener(() {
      final url = _avatarCtrl.text.trim();
      if (url != _avatarPreview) setState(() => _avatarPreview = url);
    });
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
    if (_newPwCtrl.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 8 caracteres'), backgroundColor: RpgColors.statusDropped));
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
      appBar: AppBar(title: Text('Mi perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Avatar
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                _AvatarPreview(url: _avatarPreview, radius: 52),
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: RpgColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: RpgColors.obsidian, width: 2),
                  ),
                  child: Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Center(child: Text(
            user?.displayName != null && user!.displayName!.isNotEmpty
                ? user.displayName!
                : '@${user?.username ?? ''}',
            style: TextStyle(
              color: RpgColors.textPrimary, fontFamily: 'Cinzel', fontSize: 16, fontWeight: FontWeight.w600),
          )),
          Center(child: Text('@${user?.username ?? ''}',
            style: TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 13))),
          SizedBox(height: 28),

          const _SectionTitle('INFORMACIÓN'),
          SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre visible',
              prefixIcon: Icon(Icons.badge_outlined, color: RpgColors.accent, size: 18)),
            style: TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _avatarCtrl,
            decoration: const InputDecoration(
              labelText: 'URL de avatar',
              hintText: 'https://...',
              prefixIcon: Icon(Icons.image_outlined, color: RpgColors.accent, size: 18)),
            style: TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
            keyboardType: TextInputType.url,
          ),
          // Live avatar preview when URL is set
          if (_avatarPreview.isNotEmpty) ...[
            SizedBox(height: 10),
            Row(children: [
              Icon(Icons.preview_outlined, size: 13, color: RpgColors.textMuted),
              SizedBox(width: 6),
              Text('Vista previa', style: TextStyle(
                fontSize: 11, color: RpgColors.textMuted, fontFamily: 'DMSans')),
              SizedBox(width: 10),
              _AvatarPreview(url: _avatarPreview, radius: 20),
            ]),
          ],
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savingProfile ? null : _saveProfile,
              child: _savingProfile
                  ? SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Guardar cambios'),
            ),
          ),

          SizedBox(height: 32),
          const _SectionTitle('CAMBIAR CONTRASEÑA'),
          SizedBox(height: 12),
          TextField(
            controller: _currPwCtrl,
            obscureText: !_showCurrPw,
            decoration: InputDecoration(
              labelText: 'Contraseña actual',
              prefixIcon: Icon(Icons.lock_outline, color: RpgColors.accent, size: 18),
              suffixIcon: IconButton(
                icon: Icon(_showCurrPw ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: RpgColors.textMuted, size: 18),
                onPressed: () => setState(() => _showCurrPw = !_showCurrPw),
              ),
            ),
            style: TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _newPwCtrl,
            obscureText: !_showNewPw,
            decoration: InputDecoration(
              labelText: 'Nueva contraseña (mín. 8 caracteres)',
              prefixIcon: Icon(Icons.lock_reset_outlined, color: RpgColors.accent, size: 18),
              suffixIcon: IconButton(
                icon: Icon(_showNewPw ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: RpgColors.textMuted, size: 18),
                onPressed: () => setState(() => _showNewPw = !_showNewPw),
              ),
            ),
            style: TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _confPwCtrl,
            obscureText: !_showConfPw,
            decoration: InputDecoration(
              labelText: 'Confirmar nueva contraseña',
              prefixIcon: Icon(Icons.lock_reset_outlined, color: RpgColors.accent, size: 18),
              suffixIcon: IconButton(
                icon: Icon(_showConfPw ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: RpgColors.textMuted, size: 18),
                onPressed: () => setState(() => _showConfPw = !_showConfPw),
              ),
            ),
            style: TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savingPw ? null : _changePassword,
              style: ElevatedButton.styleFrom(backgroundColor: RpgColors.goldDark),
              child: _savingPw
                  ? SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Cambiar contraseña'),
            ),
          ),
          SizedBox(height: 40),
        ]),
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  final String url;
  final double radius;
  const _AvatarPreview({required this.url, required this.radius});

  @override
  Widget build(BuildContext context) {
    final hasUrl = url.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: RpgColors.charcoal,
      child: hasUrl
          ? ClipOval(
              child: Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.broken_image_outlined,
                  size: radius * 0.8,
                  color: RpgColors.textMuted,
                ),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : SizedBox(
                        width: radius,
                        height: radius,
                        child: const CircularProgressIndicator(
                          strokeWidth: 1.5, color: RpgColors.accent),
                      ),
              ),
            )
          : Icon(Icons.person_outline, size: radius * 0.8, color: RpgColors.textMuted),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(
    fontFamily: 'DMSans', fontSize: 11, color: RpgColors.accent,
    letterSpacing: 0.8, fontWeight: FontWeight.w700));
}
