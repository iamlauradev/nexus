import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/rpg_theme.dart';
import '../models/user_entry.dart';
import '../services/api_service.dart';
import '../widgets/ornamental_border.dart';

const _statuses = {
  'plan_to_watch': 'Pendiente',
  'watching':      'Viendo',
  'completed':     'Completado',
  'on_hold':       'En espera',
  'dropped':       'Abandonado',
};

const _ratings = {
  'must':        '★ Must',
  'me_encanta':  '♥ Me encanta',
  'muy_bonita':  '✦ Es muy bonita',
  'bonita':      '◆ Es bonita',
  'pasable':     '◇ Pasable',
  'no_me_gusto': '✕ No me ha gustado',
  'abandonado':  '— Abandonado',
  'sin_valorar': '· Sin valorar',
};

class DetailScreen extends StatefulWidget {
  final UserEntry entry;
  const DetailScreen({super.key, required this.entry});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late UserEntry _entry;
  bool _editing = false;
  bool _saving = false;

  late String _status;
  late String? _ratingLabel;
  late String? _progress;
  late String? _notes;
  late String? _platform;
  double? _score;

  final _progressCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  final _platformCtrl = TextEditingController();
  final _scoreCtrl    = TextEditingController();

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _initFields();
  }

  void _initFields() {
    _status      = _entry.status;
    _ratingLabel = _entry.ratingLabel ?? 'sin_valorar';
    _progress    = _entry.progress;
    _notes       = _entry.notes;
    _platform    = _entry.platform;
    _score       = _entry.score;
    _progressCtrl.text = _entry.progress ?? '';
    _notesCtrl.text    = _entry.notes ?? '';
    _platformCtrl.text = _entry.platform ?? '';
    _scoreCtrl.text    = _entry.score?.toString() ?? '';
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _notesCtrl.dispose();
    _platformCtrl.dispose();
    _scoreCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await ApiService.updateEntry(_entry.id, {
        'status':       _status,
        'rating_label': _ratingLabel,
        'progress':     _progressCtrl.text.isEmpty ? null : _progressCtrl.text,
        'notes':        _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        'platform':     _platformCtrl.text.isEmpty ? null : _platformCtrl.text,
        'score':        double.tryParse(_scoreCtrl.text),
      });
      // Rebuild with existing media since update doesn't return it
      setState(() {
        _entry = UserEntry(
          id: updated.id, userId: updated.userId, mediaId: updated.mediaId,
          status: updated.status, progress: updated.progress, score: updated.score,
          ratingLabel: updated.ratingLabel, notes: updated.notes, platform: updated.platform,
          startedAt: updated.startedAt, completedAt: updated.completedAt,
          updatedAt: updated.updatedAt, media: _entry.media,
        );
        _editing = false;
        _saving = false;
      });
      _initFields();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: RpgColors.ratingNoMeGusto));
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: RpgColors.surface,
        title: const Text('Eliminar entrada', style: TextStyle(color: RpgColors.gold, fontFamily: 'Cinzel')),
        content: Text(
          '¿Eliminar "${_entry.media?.title}" de tu lista?',
          style: const TextStyle(color: RpgColors.textSecondary, fontFamily: 'Crimson'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: RpgColors.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: RpgColors.ratingNoMeGusto),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.deleteEntry(_entry.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = _entry.media;
    return Scaffold(
      appBar: AppBar(
        title: Text(media?.title ?? '', style: const TextStyle(fontSize: 16)),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit, color: RpgColors.gold),
              onPressed: () => setState(() => _editing = true),
            ),
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: RpgColors.ratingNoMeGusto),
              onPressed: _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(media),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _editing ? _buildEditForm() : _buildView(),
            ),
          ],
        ),
      ),
      floatingActionButton: _editing
        ? FloatingActionButton.extended(
            onPressed: _saving ? null : _save,
            backgroundColor: RpgColors.goldDark,
            label: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: RpgColors.gold))
              : const Text('Guardar', style: TextStyle(fontFamily: 'Cinzel', color: RpgColors.goldLight, letterSpacing: 1)),
            icon: const Icon(Icons.save, color: RpgColors.goldLight),
          )
        : null,
    );
  }

  Widget _buildHeader(dynamic media) {
    if (media == null) return const SizedBox.shrink();
    return Stack(
      children: [
        // Background blur cover
        if (media.coverUrl != null)
          SizedBox(
            height: 220,
            width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: media.coverUrl!,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.6),
              colorBlendMode: BlendMode.darken,
            ),
          )
        else
          Container(height: 220, color: RpgColors.charcoal),

        // Bottom gradient
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(height: 80, decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, RpgColors.obsidian],
            ),
          )),
        ),

        // Cover + info row
        Positioned(
          bottom: 12, left: 16, right: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (media.coverUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: media.coverUrl!,
                    width: 90, height: 128, fit: BoxFit.cover,
                  ),
                )
              else
                Container(width: 90, height: 128, decoration: BoxDecoration(
                  color: RpgColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: RpgColors.border),
                )),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(media.title, style: const TextStyle(
                      fontFamily: 'Cinzel', fontSize: 16, color: RpgColors.textPrimary,
                      fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    )),
                    if (media.year != null) Text('${media.year}', style: const TextStyle(
                      fontFamily: 'Crimson', fontSize: 13, color: RpgColors.textSecondary)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: RpgColors.amethyst.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: RpgColors.amethystLight.withOpacity(0.5)),
                        ),
                        child: Text(typeLabel(media.type), style: const TextStyle(
                          color: RpgColors.amethystLight, fontSize: 11, fontFamily: 'Crimson')),
                      ),
                      if (media.externalScore != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.star, color: RpgColors.gold, size: 14),
                        Text(' ${media.externalScore!.toStringAsFixed(1)}',
                          style: const TextStyle(color: RpgColors.gold, fontSize: 13, fontFamily: 'Crimson')),
                      ],
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildView() {
    final media = _entry.media;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rating + status row
        Row(
          children: [
            Expanded(child: _InfoBox(
              label: 'Estado',
              child: Row(children: [
                Icon(Icons.circle, size: 10, color: statusColor(_entry.status)),
                const SizedBox(width: 6),
                Text(statusLabel(_entry.status), style: const TextStyle(
                  color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 14)),
              ]),
            )),
            const SizedBox(width: 10),
            Expanded(child: _InfoBox(
              label: 'Valoración',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ratingColor(_entry.ratingLabel).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(ratingLabel(_entry.ratingLabel), style: TextStyle(
                  color: ratingColor(_entry.ratingLabel), fontFamily: 'Crimson', fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
              ),
            )),
          ],
        ),
        const SizedBox(height: 12),
        if (_entry.progress != null)
          _InfoBox(label: 'Progreso', child: Text(_entry.progress!, style: const TextStyle(
            color: RpgColors.gold, fontFamily: 'Crimson', fontSize: 14))),
        if (_entry.score != null) ...[
          const SizedBox(height: 10),
          _InfoBox(label: 'Mi puntuación', child: Text('${_entry.score}', style: const TextStyle(
            color: RpgColors.gold, fontFamily: 'Cinzel', fontSize: 18))),
        ],
        if (_entry.platform != null) ...[
          const SizedBox(height: 10),
          _InfoBox(label: 'Visto en', child: Text(_entry.platform!, style: const TextStyle(
            color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 14))),
        ],
        if (_entry.notes != null && _entry.notes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoBox(
            label: 'Mis notas',
            child: Text(_entry.notes!, style: const TextStyle(
              color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 14,
              fontStyle: FontStyle.italic, height: 1.5,
            )),
          ),
        ],
        if (media != null) ...[
          const SizedBox(height: 16),
          const GoldDivider(label: 'INFO'),
          const SizedBox(height: 12),
          if (media.duration != null)
            _InfoRow('Duración', media.duration!),
          if (media.country != null)
            _InfoRow('País', media.country!),
          if (media.network != null)
            _InfoRow('Cadena', media.network!),
          if (media.genres != null && media.genres!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: media.genres!.map((g) => Chip(
                label: Text(g, style: const TextStyle(fontSize: 11, color: RpgColors.textSecondary, fontFamily: 'Crimson')),
                backgroundColor: RpgColors.charcoal,
                side: const BorderSide(color: RpgColors.border),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              )).toList(),
            ),
          ],
          if (media.synopsis != null && media.synopsis!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const GoldDivider(label: 'SINOPSIS'),
            const SizedBox(height: 8),
            Text(media.synopsis!, style: const TextStyle(
              color: RpgColors.textSecondary, fontFamily: 'Crimson',
              fontSize: 14, height: 1.6,
            )),
          ],
          if (media.castText != null && media.castText!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const GoldDivider(label: 'REPARTO'),
            const SizedBox(height: 8),
            Text(media.castText!, style: const TextStyle(
              color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 13, height: 1.5)),
          ],
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Estado', style: TextStyle(fontFamily: 'Cinzel', color: RpgColors.textSecondary, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _status,
          dropdownColor: RpgColors.surface,
          decoration: const InputDecoration(isDense: true),
          style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
          items: _statuses.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) { if (v != null) setState(() => _status = v); },
        ),
        const SizedBox(height: 16),
        const Text('Valoración', style: TextStyle(fontFamily: 'Cinzel', color: RpgColors.textSecondary, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _ratingLabel,
          dropdownColor: RpgColors.surface,
          decoration: const InputDecoration(isDense: true),
          style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
          items: _ratings.entries.map((e) => DropdownMenuItem(
            value: e.key,
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(
                color: ratingColor(e.key), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(e.value),
            ]),
          )).toList(),
          onChanged: (v) { if (v != null) setState(() => _ratingLabel = v); },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _progressCtrl,
          decoration: const InputDecoration(
            labelText: 'Progreso (ej: T2 E5, Cap 23)',
            prefixIcon: Icon(Icons.bookmark, color: RpgColors.gold, size: 18),
          ),
          style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _scoreCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Mi puntuación (ej: 9.5)',
            prefixIcon: Icon(Icons.star, color: RpgColors.gold, size: 18),
          ),
          style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _platformCtrl,
          decoration: const InputDecoration(
            labelText: 'Plataforma (ej: Netflix, Crunchyroll)',
            prefixIcon: Icon(Icons.devices, color: RpgColors.gold, size: 18),
          ),
          style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesCtrl,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Mis notas / reseña',
            alignLabelWithHint: true,
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 80),
              child: Icon(Icons.notes, color: RpgColors.gold, size: 18),
            ),
          ),
          style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String label;
  final Widget child;
  const _InfoBox({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: RpgColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: RpgColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(
            fontFamily: 'Cinzel', fontSize: 10, color: RpgColors.textMuted, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(
              color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 13)),
          ),
          const Text(' · ', style: TextStyle(color: RpgColors.border, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(
            color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 13))),
        ],
      ),
    );
  }
}
