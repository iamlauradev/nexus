import 'package:flutter/material.dart';
import '../theme/rpg_theme.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';

// Colores predefinidos para elegir
const _presetColors = [
  '#F0C040', '#FFD700', '#FFA500', '#FF6B35',
  '#F85149', '#FF69B4', '#DA70D6', '#BC8CFF',
  '#667EEA', '#58A6FF', '#79C0FF', '#00BFFF',
  '#56CC9D', '#3FB950', '#6BCB77', '#ADFF2F',
  '#D29922', '#A0522D', '#8B7355', '#484F58',
];

class RatingConfigScreen extends StatefulWidget {
  const RatingConfigScreen({super.key});

  @override
  State<RatingConfigScreen> createState() => _RatingConfigScreenState();
}

class _RatingConfigScreenState extends State<RatingConfigScreen> {
  List<RatingConfig> _configs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final configs = await ApiService.getRatingConfigs();
      if (mounted) setState(() { _configs = configs; _loading = false; });
      // Refresh cache
      RatingConfigCache.update(configs.map((c) => {
        'key': c.key, 'label': c.label, 'color': c.color, 'sort_order': c.sortOrder,
      }).toList());
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar: $e'), backgroundColor: RpgColors.statusDropped));
      }
    }
  }

  Future<void> _delete(RatingConfig cfg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: RpgColors.surface,
        title: Text('Eliminar "${cfg.label}"', style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Cinzel', fontSize: 16)),
        content: const Text('¿Eliminar esta valoración?', style: TextStyle(color: RpgColors.textSecondary, fontFamily: 'Crimson')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: RpgColors.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: RpgColors.statusDropped),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.deleteRatingConfig(cfg.id);
      _load();
    }
  }

  void _openEditor({RatingConfig? cfg}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: RpgColors.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _RatingEditor(
        existing: cfg,
        onSaved: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RpgColors.surface,
      appBar: AppBar(title: const Text('Mis valoraciones')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: RpgColors.gold))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Define tus categorías de valoración con el nombre y color que quieras.',
                    style: const TextStyle(color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 13),
                  ),
                ),
                if (_configs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text(
                      'Cargando valoraciones...',
                      style: TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson'))),
                  )
                else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _configs.length,
                    itemBuilder: (_, i) {
                      final cfg = _configs[i];
                      final color = RatingConfigCache.colorFor(cfg.key);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: RpgColors.charcoal,
                          borderRadius: BorderRadius.circular(8),
                          border: Border(left: BorderSide(color: color, width: 4)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          title: Text(cfg.label, style: const TextStyle(
                            color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 15)),
                          subtitle: Text(cfg.key, style: const TextStyle(
                            color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: RpgColors.textSecondary, size: 20),
                                onPressed: () => _openEditor(cfg: cfg),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: RpgColors.statusDropped, size: 20),
                                onPressed: () => _delete(cfg),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: RpgColors.gold,
        icon: const Icon(Icons.add, color: RpgColors.obsidian),
        label: const Text('Añadir', style: TextStyle(
          fontFamily: 'Cinzel', color: RpgColors.obsidian, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _RatingEditor extends StatefulWidget {
  final RatingConfig? existing;
  final VoidCallback onSaved;

  const _RatingEditor({this.existing, required this.onSaved});

  @override
  State<_RatingEditor> createState() => _RatingEditorState();
}

class _RatingEditorState extends State<_RatingEditor> {
  late TextEditingController _keyCtrl;
  late TextEditingController _labelCtrl;
  String _color = '#F0C040';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final cfg = widget.existing;
    _keyCtrl   = TextEditingController(text: cfg?.key ?? '');
    _labelCtrl = TextEditingController(text: cfg?.label ?? '');
    _color     = cfg?.color ?? '#F0C040';
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_labelCtrl.text.trim().isEmpty || _keyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rellena nombre y clave'), backgroundColor: RpgColors.statusDropped));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        'key': _keyCtrl.text.trim(),
        'label': _labelCtrl.text.trim(),
        'color': _color,
        'sort_order': widget.existing?.sortOrder ?? 99,
      };
      if (widget.existing != null) {
        await ApiService.updateRatingConfig(widget.existing!.id, data);
      } else {
        await ApiService.createRatingConfig(data);
      }
      if (mounted) Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: RpgColors.statusDropped));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = RatingConfigCache.colorFor(_color);
    return Container(
      color: RpgColors.charcoal,
      child: Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing != null ? 'Editar valoración' : 'Nueva valoración',
            style: const TextStyle(fontFamily: 'Cinzel', color: RpgColors.textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelCtrl,
            decoration: const InputDecoration(labelText: 'Nombre visible (ej: Obra maestra)'),
            style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
          ),
          const SizedBox(height: 12),
          if (widget.existing == null)
            TextField(
              controller: _keyCtrl,
              decoration: const InputDecoration(
                labelText: 'Clave interna (ej: obra_maestra, sin espacios)',
                helperText: 'Identificador único, no se puede cambiar después',
                helperStyle: TextStyle(color: RpgColors.textMuted, fontSize: 11),
              ),
              style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
            ),
          const SizedBox(height: 16),
          const Text('Color', style: TextStyle(fontFamily: 'Cinzel', color: RpgColors.textSecondary, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _presetColors.map((hex) {
              final c = RatingConfigCache.colorFor(hex) == RpgColors.ratingSinValorar
                  ? _hexColorLocal(hex)
                  : _hexColorLocal(hex);
              final isSelected = _color == hex;
              return GestureDetector(
                onTap: () => setState(() => _color = hex),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2.5)
                        : Border.all(color: Colors.transparent, width: 2.5),
                    boxShadow: isSelected ? [BoxShadow(color: c.withOpacity(0.6), blurRadius: 6)] : [],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: selectedColor),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.existing != null ? 'Guardar cambios' : 'Crear valoración',
                      style: const TextStyle(fontFamily: 'Cinzel', color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    ));
  }
}

Color _hexColorLocal(String hex) {
  final clean = hex.replaceFirst('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}
