import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/rpg_theme.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';

const _mediaTypes = {
  'DORAMA': 'Dorama',
  'MOVIE':  'Película',
  'SERIES': 'Serie',
  'MANGA':  'Manga',
  'MANHWA': 'Manhwa',
  'MANHUA': 'Manhua',
  'ANIME':  'Anime',
};

const _statuses = {
  'plan_to_watch': 'Pendiente',
  'watching':      'Viendo',
  'completed':     'Completado',
  'on_hold':       'En espera',
  'dropped':       'Abandonado',
};

const _ratings = {
  'sin_valorar': '· Sin valorar',
  'must':        '★ Must',
  'me_encanta':  '♥ Me encanta',
  'muy_bonita':  '✦ Es muy bonita',
  'bonita':      '◆ Es bonita',
  'pasable':     '◇ Pasable',
  'no_me_gusto': '✕ No me ha gustado',
  'abandonado':  '— Abandonado',
};

class AddEntryScreen extends StatefulWidget {
  final String? initialType;
  const AddEntryScreen({super.key, this.initialType});

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  String _type = 'DORAMA';
  String _status = 'plan_to_watch';
  String _rating = 'sin_valorar';

  final _searchCtrl   = TextEditingController();
  final _progressCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  final _platformCtrl = TextEditingController();
  final _scoreCtrl    = TextEditingController();
  final _titleCtrl    = TextEditingController();

  List<SearchResult> _results = [];
  SearchResult? _selected;
  bool _searching = false;
  bool _saving = false;
  bool _manualMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) _type = widget.initialType!;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _progressCtrl.dispose();
    _notesCtrl.dispose();
    _platformCtrl.dispose();
    _scoreCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_searchCtrl.text.length < 2) return;
    setState(() { _searching = true; _results = []; });
    try {
      final results = await ApiService.searchMetadata(_searchCtrl.text, _type);
      if (mounted) setState(() { _results = results; _searching = false; });
    } catch (_) {
      if (mounted) setState(() { _searching = false; });
    }
  }

  Future<void> _save() async {
    if (_selected == null && !_manualMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una obra primero'), backgroundColor: RpgColors.goldDark));
      return;
    }
    setState(() => _saving = true);
    try {
      // 1. Create or find the media
      late int mediaId;
      if (_selected != null) {
        final media = await ApiService.createMedia({
          'type':           _type,
          'title':          _selected!.title,
          'title_original': _selected!.titleOriginal,
          'year':           _selected!.year,
          'genres':         _selected!.genres,
          'synopsis':       _selected!.synopsis,
          'cover_url':      _selected!.coverUrl,
          'country':        _selected!.country,
          'external_score': _selected!.score,
          if (_selected!.source == 'tmdb') 'tmdb_id':    int.tryParse(_selected!.externalId),
          if (_selected!.source == 'anilist') 'anilist_id': int.tryParse(_selected!.externalId),
        });
        mediaId = media.id;
      } else {
        final media = await ApiService.createMedia({
          'type':  _type,
          'title': _titleCtrl.text.trim(),
        });
        mediaId = media.id;
      }

      // 2. Create user entry
      await ApiService.createEntry({
        'media_id':     mediaId,
        'status':       _status,
        'rating_label': _rating,
        'progress':     _progressCtrl.text.isEmpty ? null : _progressCtrl.text,
        'notes':        _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        'platform':     _platformCtrl.text.isEmpty ? null : _platformCtrl.text,
        'score':        double.tryParse(_scoreCtrl.text),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Añadido al grimorio ✓'), backgroundColor: RpgColors.statusComplete));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: RpgColors.ratingNoMeGusto));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Añadir obra')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type selector
            const _SectionLabel('Tipo'),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _mediaTypes.entries.map((e) {
                  final sel = _type == e.key;
                  return GestureDetector(
                    onTap: () { setState(() { _type = e.key; _results = []; _selected = null; }); },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: sel ? RpgColors.goldDark.withOpacity(0.7) : RpgColors.charcoal,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: sel ? RpgColors.gold : RpgColors.border),
                      ),
                      child: Center(child: Text(e.value, style: TextStyle(
                        color: sel ? RpgColors.goldLight : RpgColors.textSecondary,
                        fontSize: 13, fontFamily: 'Crimson',
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                      ))),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            if (!_manualMode) ...[
              // Search
              const _SectionLabel('Buscar'),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Título de la obra...',
                      prefixIcon: Icon(Icons.search, color: RpgColors.gold, size: 18),
                    ),
                    style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _search,
                  child: const Text('Buscar', style: TextStyle(fontFamily: 'Cinzel', fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => setState(() { _manualMode = true; _selected = null; }),
                child: const Text('→ Añadir manualmente sin buscar', style: TextStyle(color: RpgColors.textMuted, fontSize: 12)),
              ),

              if (_searching)
                const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: RpgColors.gold),
                )),

              if (_results.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...(_results.map((r) => _SearchResultTile(
                  result: r,
                  selected: _selected == r,
                  onTap: () => setState(() => _selected = r),
                ))),
                const SizedBox(height: 8),
              ],

              if (_selected != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: RpgColors.amethyst.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: RpgColors.amethystLight.withOpacity(0.5)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle, color: RpgColors.statusComplete, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Seleccionado: ${_selected!.title}',
                      style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
                    )),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
            ] else ...[
              const _SectionLabel('Título'),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(hintText: 'Título de la obra'),
                style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => setState(() { _manualMode = false; _titleCtrl.clear(); }),
                child: const Text('→ Volver a búsqueda automática', style: TextStyle(color: RpgColors.textMuted, fontSize: 12)),
              ),
              const SizedBox(height: 8),
            ],

            const GoldDividerLocal(),
            const SizedBox(height: 12),

            // Status
            const _SectionLabel('Estado'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _status,
              dropdownColor: RpgColors.surface,
              decoration: const InputDecoration(isDense: true),
              style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
              items: _statuses.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) { if (v != null) setState(() => _status = v); },
            ),
            const SizedBox(height: 12),

            // Rating
            const _SectionLabel('Valoración'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _rating,
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
              onChanged: (v) { if (v != null) setState(() => _rating = v); },
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _progressCtrl,
              decoration: const InputDecoration(
                labelText: 'Progreso (ej: Cap 5, T1 E3)',
                prefixIcon: Icon(Icons.bookmark_outline, color: RpgColors.gold, size: 18),
              ),
              style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _scoreCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Mi puntuación',
                prefixIcon: Icon(Icons.star_outline, color: RpgColors.gold, size: 18),
              ),
              style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _platformCtrl,
              decoration: const InputDecoration(
                labelText: 'Plataforma',
                prefixIcon: Icon(Icons.devices_outlined, color: RpgColors.gold, size: 18),
              ),
              style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _notesCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Notas / reseña personal',
                alignLabelWithHint: true,
              ),
              style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson', height: 1.5),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: RpgColors.goldDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: _saving
                  ? const CircularProgressIndicator(strokeWidth: 2, color: RpgColors.gold)
                  : const Text('AÑADIR AL GRIMORIO', style: TextStyle(
                      fontFamily: 'Cinzel', letterSpacing: 2, color: RpgColors.goldLight, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final bool selected;
  final VoidCallback onTap;

  const _SearchResultTile({required this.result, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? RpgColors.amethyst.withOpacity(0.2) : RpgColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? RpgColors.amethystLight : RpgColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (result.coverUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: result.coverUrl!,
                  width: 36, height: 50, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 36, height: 50, color: RpgColors.charcoal,
                    child: const Icon(Icons.broken_image, color: RpgColors.border, size: 16),
                  ),
                ),
              )
            else
              Container(width: 36, height: 50, color: RpgColors.charcoal,
                child: const Icon(Icons.auto_stories, color: RpgColors.border, size: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.title, style: const TextStyle(
                    color: RpgColors.textPrimary, fontFamily: 'Crimson',
                    fontSize: 14, fontWeight: FontWeight.w600)),
                  if (result.year != null)
                    Text('${result.year}', style: const TextStyle(
                      color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 12)),
                  if (result.score != null)
                    Text('★ ${result.score!.toStringAsFixed(1)}', style: const TextStyle(
                      color: RpgColors.gold, fontFamily: 'Crimson', fontSize: 12)),
                ],
              ),
            ),
            Text(result.source.toUpperCase(), style: const TextStyle(
              color: RpgColors.textMuted, fontSize: 10, fontFamily: 'Cinzel')),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontFamily: 'Cinzel', fontSize: 11, color: RpgColors.textMuted, letterSpacing: 1.5),
  );
}

class GoldDividerLocal extends StatelessWidget {
  const GoldDividerLocal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, RpgColors.goldDark.withOpacity(0.6), Colors.transparent],
        ),
      ),
    );
  }
}
