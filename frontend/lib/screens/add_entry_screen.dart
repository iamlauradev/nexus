import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../theme/rpg_theme.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';

const _allMediaTypes = {
  'DORAMA':  'Dorama',
  'MOVIE':   'Película',
  'SERIES':  'Serie',
  'MANGA':   'Manga',
  'MANHWA':  'Manhwa',
  'MANHUA':  'Manhua',
  'WEBTOON': 'Webtoon',
  'NOVEL':   'Novela',
  'ANIME':   'Anime',
};

const _statuses = {
  'plan_to_watch': 'Pendiente',
  'watching':      'Viendo',
  'completed':     'Completado',
  'on_hold':       'En espera',
  'dropped':       'Abandonado',
};

const _emissionStatuses = {
  '':          'Desconocido',
  'AIRING':    'En emisión',
  'FINISHED':  'Finalizada',
  'UPCOMING':  'Próximamente',
  'CANCELLED': 'Cancelada',
  'HIATUS':    'En hiato',
};

class AddEntryScreen extends StatefulWidget {
  final String? initialType;
  final List<String>? availableTypes;
  const AddEntryScreen({super.key, this.initialType, this.availableTypes});

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  String _type = 'DORAMA';
  String _status = 'plan_to_watch';
  String _ratingLabel = 'sin_valorar';
  String _emissionStatus = '';
  int? _emissionDay;   // 0=lunes … 6=domingo, null=no configurado
  String? _startedAt;
  String? _completedAt;
  int _epCurrent = 0;
  int? _epTotal;
  int _rewatchCount = 0;

  final _searchCtrl   = TextEditingController();
  final _progressCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  final _platformCtrl = TextEditingController();
  final _titleCtrl    = TextEditingController();

  List<SearchResult> _results = [];
  final List<SearchResult> _selectedItems = [];
  bool _searching = false;
  bool _saving = false;
  bool _manualMode = false;

  Map<String, String> get _visibleTypes {
    final available = widget.availableTypes;
    if (available == null || available.isEmpty) return _allMediaTypes;
    return Map.fromEntries(
      _allMediaTypes.entries.where((e) => available.contains(e.key)),
    );
  }

  bool get _showTypeSelector => _visibleTypes.length > 1;

  @override
  void initState() {
    super.initState();
    final configs = RatingConfigCache.configs;
    final keys = configs.map((c) => c['key'] as String).toList();
    if (!keys.contains(_ratingLabel)) {
      _ratingLabel = keys.isNotEmpty ? keys.last : 'sin_valorar';
    }
    if (widget.initialType != null) _type = widget.initialType!;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _progressCtrl.dispose();
    _notesCtrl.dispose();
    _platformCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = DateTime.tryParse(isStart ? (_startedAt ?? '') : (_completedAt ?? '')) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: RpgColors.gold,
            onPrimary: RpgColors.obsidian,
            surface: RpgColors.surface,
            onSurface: RpgColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final formatted = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        if (isStart) _startedAt = formatted;
        else _completedAt = formatted;
      });
    }
  }

  String _formatDate(String? raw) {
    if (raw == null) return 'Sin fecha';
    try { return DateFormat('dd/MM/yyyy').format(DateTime.parse(raw)); } catch (_) { return raw; }
  }

  bool get _hasEpisodes => _type != 'MOVIE';

  void _toggleSelection(SearchResult r) {
    if (r.entryId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya está en tu biblioteca'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF4A4570),
        ),
      );
      return;
    }
    setState(() {
      final idx = _selectedItems.indexWhere((s) => s.externalId == r.externalId);
      if (idx >= 0) {
        _selectedItems.removeAt(idx);
      } else {
        _selectedItems.add(r);
        // Auto-fill emission status and ep total from the first selected item
        if (_selectedItems.length == 1) {
          _emissionStatus = r.emissionStatus ?? '';
          if (r.episodes != null && r.episodes! > 0) {
            _epTotal = r.episodes;
            _epCurrent = 0;
          }
        }
      }
    });
  }

  bool _isSelected(SearchResult r) =>
      _selectedItems.any((s) => s.externalId == r.externalId);

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
    if (_selectedItems.isEmpty && !_manualMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una obra'), backgroundColor: RpgColors.statusDropped));
      return;
    }
    setState(() => _saving = true);

    // Manual mode: single item
    if (_manualMode) {
      try {
        final media = await ApiService.createMedia({
          'type':  _type,
          'title': _titleCtrl.text.trim(),
          'emission_status': _emissionStatus.isEmpty ? null : _emissionStatus,
        });
        await ApiService.createEntry(_buildEntryPayload(media.id));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Añadido correctamente ✓'), backgroundColor: RpgColors.statusComplete));
          Navigator.pop(context);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: RpgColors.statusDropped));
      }
      return;
    }

    // Multi-select: save each item
    int saved = 0;
    for (final r in _selectedItems) {
      try {
        final media = await ApiService.createMedia({
          'type':             _type,
          'title':            r.title,
          'title_original':   r.titleOriginal,
          'year':             r.year,
          'genres':           r.genres,
          'synopsis':         r.synopsis,
          'cover_url':        r.coverUrl,
          'country':          r.country,
          'duration':         r.duration,
          'network':          r.network,
          'cast_text':        r.castText,
          'external_score':   r.score,
          'emission_status':  r.emissionStatus?.isEmpty == false ? r.emissionStatus : (_emissionStatus.isEmpty ? null : _emissionStatus),
          if (r.source == 'tmdb')    'tmdb_id':    int.tryParse(r.externalId),
          if (r.source == 'anilist') 'anilist_id': int.tryParse(r.externalId),
        });

        // For multi-select ep_total comes from each result individually
        final epTotal = (r.episodes != null && r.episodes! > 0) ? r.episodes
            : (_selectedItems.length == 1 ? _epTotal : null);
        final epCurrent = _selectedItems.length == 1 ? _epCurrent : 0;

        await ApiService.createEntry({
          ...(_buildEntryPayload(media.id)),
          if (_hasEpisodes) 'ep_current': epCurrent,
          if (_hasEpisodes && epTotal != null) 'ep_total': epTotal,
        });
        saved++;
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _saving = false);
      final msg = saved == _selectedItems.length
          ? (saved == 1 ? 'Añadido correctamente ✓' : '$saved obras añadidas ✓')
          : '$saved de ${_selectedItems.length} añadidas (algunos errores)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: saved > 0 ? RpgColors.statusComplete : RpgColors.statusDropped));
      if (saved > 0) Navigator.pop(context);
    }
  }

  Map<String, dynamic> _buildEntryPayload(int mediaId) => {
    'media_id':      mediaId,
    'status':        _status,
    'rating_label':  _ratingLabel,
    'progress':      _progressCtrl.text.isEmpty ? null : _progressCtrl.text,
    'notes':         _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
    'platform':      _platformCtrl.text.isEmpty ? null : _platformCtrl.text,
    if (_startedAt != null) 'started_at': _startedAt,
    if (_completedAt != null) 'completed_at': _completedAt,
    'rewatch_count': _rewatchCount,
    'emission_day':  _emissionDay,
  };

  @override
  Widget build(BuildContext context) {
    final ratings = RatingConfigCache.configs;
    final ratingKeys = ratings.map((r) => r['key'] as String).toList();
    final effectiveRating = ratingKeys.contains(_ratingLabel)
        ? _ratingLabel
        : (ratingKeys.isNotEmpty ? ratingKeys.last : null);

    final singleSelected = _selectedItems.length == 1 && !_manualMode;

    return Scaffold(
      backgroundColor: RpgColors.surface,
      appBar: AppBar(title: const Text('Añadir')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type selector
            if (_showTypeSelector) ...[
              _Label('Tipo'),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _visibleTypes.entries.map((e) {
                    final sel = _type == e.key;
                    return GestureDetector(
                      onTap: () => setState(() { _type = e.key; _results = []; _selectedItems.clear(); }),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: sel ? RpgColors.gold.withOpacity(0.15) : RpgColors.charcoal,
                          borderRadius: BorderRadius.circular(6),
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
            ],

            // Search or manual
            if (!_manualMode) ...[
              _Label('Buscar'),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Título…',
                      prefixIcon: Icon(Icons.search, color: RpgColors.gold, size: 18),
                    ),
                    style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _search,
                  child: const Text('Buscar', style: TextStyle(fontFamily: 'DMSans', fontSize: 12))),
              ]),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => setState(() { _manualMode = true; _selectedItems.clear(); }),
                child: const Text('→ Añadir manualmente', style: TextStyle(color: RpgColors.textMuted, fontSize: 12)),
              ),

              // Results dropdown (compact, fixed-height container)
              if (_searching)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: RpgColors.gold))),
              if (_results.isNotEmpty) ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: RpgColors.charcoal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${_results.length} resultado${_results.length != 1 ? "s" : ""}',
                              style: const TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 12)),
                            if (_results.length > 1)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_selectedItems.length == _results.length) {
                                      _selectedItems.removeWhere((s) => _results.any((r) => r.externalId == s.externalId));
                                    } else {
                                      for (final r in _results) {
                                        if (!_isSelected(r)) _selectedItems.add(r);
                                      }
                                    }
                                  });
                                },
                                child: Text(
                                  _selectedItems.length == _results.length ? 'Deseleccionar todo' : 'Seleccionar todo',
                                  style: const TextStyle(color: RpgColors.gold, fontFamily: 'Crimson', fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: RpgColors.border),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: RpgColors.border, indent: 10, endIndent: 10),
                          itemBuilder: (_, i) => _CompactResultTile(
                            result: _results[i],
                            selected: _isSelected(_results[i]),
                            onTap: () => _toggleSelection(_results[i]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Selected chips
              if (_selectedItems.isNotEmpty) ...[
                _Label('Seleccionados (${_selectedItems.length})'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _selectedItems.map((r) => Container(
                    padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
                    decoration: BoxDecoration(
                      color: RpgColors.gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: RpgColors.gold.withOpacity(0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 13)),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _selectedItems.removeWhere((s) => s.externalId == r.externalId)),
                        child: const Icon(Icons.close, size: 14, color: RpgColors.textMuted),
                      ),
                    ]),
                  )).toList(),
                ),
                const SizedBox(height: 12),
              ],
            ] else ...[
              _Label('Título'),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(hintText: 'Título de la obra'),
                style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => setState(() { _manualMode = false; _titleCtrl.clear(); }),
                child: const Text('→ Volver a la búsqueda', style: TextStyle(color: RpgColors.textMuted, fontSize: 12)),
              ),
              const SizedBox(height: 8),
            ],

            const Divider(color: RpgColors.border, height: 24),

            // Status
            _Label('Mi estado'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _status,
              dropdownColor: RpgColors.charcoal,
              decoration: const InputDecoration(isDense: true),
              style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
              items: _statuses.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) { if (v != null) setState(() => _status = v); },
            ),
            const SizedBox(height: 12),

            // Emission status (not for movies, not for multi-select — each item brings its own)
            if (_type != 'MOVIE' && _selectedItems.length <= 1) ...[
              _Label('Estado de emisión'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _emissionStatus,
                dropdownColor: RpgColors.charcoal,
                decoration: const InputDecoration(isDense: true),
                style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
                items: _emissionStatuses.entries.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Row(children: [
                    if (e.key.isNotEmpty) Container(
                      width: 8, height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: emissionColor(e.key), shape: BoxShape.circle),
                    ),
                    Text(e.value),
                  ]),
                )).toList(),
                onChanged: (v) { if (v != null) setState(() => _emissionStatus = v); },
              ),
              const SizedBox(height: 12),
              _Label('Día de emisión (opcional)'),
              const SizedBox(height: 6),
              _EmissionDayPicker(
                value: _emissionDay,
                onChanged: (v) => setState(() => _emissionDay = v),
              ),
              const SizedBox(height: 12),
            ],

            // Rating
            _Label('Valoración'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: effectiveRating,
              dropdownColor: RpgColors.charcoal,
              decoration: const InputDecoration(isDense: true),
              style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
              items: ratings.map((r) {
                final color = RatingConfigCache.colorFor(r['key']);
                return DropdownMenuItem(
                  value: r['key'] as String,
                  child: Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(r['label'] as String),
                  ]),
                );
              }).toList(),
              onChanged: (v) { if (v != null) setState(() => _ratingLabel = v); },
            ),
            const SizedBox(height: 12),

            // Episode stepper: only when 0 or 1 items selected (not batch)
            if (_hasEpisodes && (singleSelected || _manualMode)) ...[
              _EpisodeStepper(
                label: _type == 'MANGA' || _type == 'MANHWA' || _type == 'MANHUA' || _type == 'WEBTOON' || _type == 'NOVEL'
                    ? 'CAPÍTULO'
                    : 'EPISODIO',
                current: _epCurrent,
                total: _epTotal,
                onChanged: (v) => setState(() => _epCurrent = v),
                onTotalChanged: (v) => setState(() => _epTotal = v),
              ),
              const SizedBox(height: 12),
            ],

            // Rewatch counter: only single or manual
            if (singleSelected || _manualMode) ...[
              _RewatchCounter(
                count: _rewatchCount,
                label: _type == 'MANGA' || _type == 'MANHWA' || _type == 'MANHUA' || _type == 'WEBTOON' || _type == 'NOVEL'
                    ? 'RELECTURAS'
                    : _type == 'MOVIE' ? 'REVISIONES' : 'REVISIONADOS',
                onChanged: (v) => setState(() => _rewatchCount = v),
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _progressCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas de progreso (T2 E5, arc X…)',
                prefixIcon: Icon(Icons.bookmark_outline, color: RpgColors.gold, size: 18),
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
                labelText: 'Notas / reseña',
                alignLabelWithHint: true,
              ),
              style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson', height: 1.5),
            ),
            const SizedBox(height: 12),

            // Date pickers
            _Label('Fechas (opcional)'),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(isStart: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: RpgColors.charcoal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.play_circle_outline, size: 14, color: RpgColors.statusWatching),
                      const SizedBox(width: 6),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('INICIO', style: TextStyle(
                          fontSize: 8, color: RpgColors.textMuted, letterSpacing: 0.6, fontWeight: FontWeight.w500)),
                        Text(_formatDate(_startedAt),
                          style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 13)),
                      ])),
                      if (_startedAt != null)
                        GestureDetector(
                          onTap: () => setState(() => _startedAt = null),
                          child: const Icon(Icons.close, size: 14, color: RpgColors.textMuted),
                        ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(isStart: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: RpgColors.charcoal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline, size: 14, color: RpgColors.statusComplete),
                      const SizedBox(width: 6),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('FIN', style: TextStyle(
                          fontSize: 8, color: RpgColors.textMuted, letterSpacing: 0.6, fontWeight: FontWeight.w500)),
                        Text(_formatDate(_completedAt),
                          style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 13)),
                      ])),
                      if (_completedAt != null)
                        GestureDetector(
                          onTap: () => setState(() => _completedAt = null),
                          child: const Icon(Icons.close, size: 14, color: RpgColors.textMuted),
                        ),
                    ]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    : Text(
                        _selectedItems.isEmpty
                            ? 'AÑADIR'
                            : _selectedItems.length == 1
                                ? 'AÑADIR (1)'
                                : 'AÑADIR ${_selectedItems.length} OBRAS',
                        style: const TextStyle(
                          fontFamily: 'DMSans', letterSpacing: 1, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact result tile (dropdown style)
// ---------------------------------------------------------------------------

class _CompactResultTile extends StatelessWidget {
  final SearchResult result;
  final bool selected;
  final VoidCallback onTap;
  const _CompactResultTile({required this.result, required this.selected, required this.onTap});

  static const _statusLabels = {
    'plan_to_watch': 'Pendiente',
    'watching':      'Viendo',
    'completed':     'Completado',
    'on_hold':       'En espera',
    'dropped':       'Abandonado',
  };

  Color _statusColor(String? s) {
    switch (s) {
      case 'watching':      return RpgColors.statusWatching;
      case 'completed':     return RpgColors.statusComplete;
      case 'plan_to_watch': return RpgColors.statusPlan;
      case 'on_hold':       return RpgColors.statusOnHold;
      case 'dropped':       return RpgColors.statusDropped;
      default:              return RpgColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inLibrary = result.entryId != null;
    final statusColor = _statusColor(result.entryStatus);

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: inLibrary
            ? BoxDecoration(
                color: statusColor.withOpacity(0.07),
                border: Border(left: BorderSide(color: statusColor, width: 3)),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            // Checkbox (hidden when already in library)
            if (!inLibrary)
              Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: selected ? RpgColors.gold.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: selected ? RpgColors.gold : RpgColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 12, color: RpgColors.gold)
                    : null,
              )
            else
              Icon(Icons.check_circle, size: 18, color: statusColor),
            const SizedBox(width: 8),

            // Small cover
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: result.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: result.coverUrl!,
                      width: 28, height: 40, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _nocover(),
                    )
                  : _nocover(),
            ),
            const SizedBox(width: 8),

            // Title + meta + library badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    result.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: inLibrary
                          ? RpgColors.textMuted
                          : (selected ? RpgColors.goldLight : RpgColors.textPrimary),
                      fontFamily: 'Crimson', fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (inLibrary)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        'Ya en tu lista · ${_statusLabels[result.entryStatus] ?? "En tu lista"}',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    )
                  else
                    Row(children: [
                      if (result.year != null)
                        Text('${result.year}', style: const TextStyle(
                          color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 11)),
                      if (result.year != null && result.score != null)
                        const Text('  ·  ', style: TextStyle(color: RpgColors.textMuted, fontSize: 11)),
                      if (result.score != null)
                        Text('★ ${result.score!.toStringAsFixed(1)}',
                          style: const TextStyle(color: RpgColors.statusPlan, fontFamily: 'Crimson', fontSize: 11)),
                    ]),
                ],
              ),
            ),

            // Source badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: RpgColors.surface,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(result.source.toUpperCase(),
                style: const TextStyle(color: RpgColors.textMuted, fontSize: 8, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nocover() => Container(
    width: 28, height: 40, color: RpgColors.surface,
    child: const Icon(Icons.image_outlined, color: RpgColors.border, size: 12),
  );
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Supporting widgets
// ---------------------------------------------------------------------------

class _EmissionDayPicker extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  const _EmissionDayPicker({required this.value, required this.onChanged});

  static const _days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _full = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final sel = value == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(sel ? null : i),
            child: Tooltip(
              message: _full[i],
              child: Container(
                margin: EdgeInsets.only(right: i < 6 ? 4 : 0),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? RpgColors.gold.withOpacity(0.18) : RpgColors.charcoal,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: sel ? RpgColors.gold : RpgColors.border,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(_days[i], style: TextStyle(
                    fontFamily: 'DMSans', fontSize: 11,
                    color: sel ? RpgColors.gold : RpgColors.textMuted,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  )),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(fontFamily: 'DMSans', fontSize: 10, color: RpgColors.textMuted, letterSpacing: 0.5),
  );
}

class _EpisodeStepper extends StatelessWidget {
  final String label;
  final int current;
  final int? total;
  final ValueChanged<int> onChanged;
  final ValueChanged<int?> onTotalChanged;

  const _EpisodeStepper({
    required this.label,
    required this.current,
    required this.total,
    required this.onChanged,
    required this.onTotalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (total != null && total! > 0) ? (current / total!).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RpgColors.charcoal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(
            fontSize: 9, color: RpgColors.textMuted, letterSpacing: 0.8, fontWeight: FontWeight.w500)),
          Row(children: [
            GestureDetector(
              onTap: current > 0 ? () => onChanged(current - 1) : null,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: current > 0 ? RpgColors.surface : RpgColors.obsidian,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.remove, size: 14,
                  color: current > 0 ? RpgColors.textPrimary : RpgColors.textMuted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                total != null ? '$current / $total' : '$current',
                style: const TextStyle(
                  color: RpgColors.gold, fontFamily: 'DMSans', fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            GestureDetector(
              onTap: (total == null || current < total!) ? () => onChanged(current + 1) : null,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: (total == null || current < total!) ? RpgColors.gold.withOpacity(0.15) : RpgColors.obsidian,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (total == null || current < total!) ? RpgColors.gold : RpgColors.border),
                ),
                child: Icon(Icons.add, size: 14,
                  color: (total == null || current < total!) ? RpgColors.gold : RpgColors.textMuted),
              ),
            ),
          ]),
        ]),
        if (total != null && total! > 0) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(children: [
              Container(height: 5, color: RpgColors.surface),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(height: 5, color: RpgColors.gold),
              ),
            ]),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Row(children: [
            const Text('Total: ', style: TextStyle(
              color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 12)),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Desconocido',
                  isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 13),
                onChanged: (v) => onTotalChanged(int.tryParse(v)),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}


class _RewatchCounter extends StatelessWidget {
  final int count;
  final String label;
  final ValueChanged<int> onChanged;

  const _RewatchCounter({
    required this.count,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: RpgColors.charcoal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        const Icon(Icons.replay_outlined, size: 16, color: RpgColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(
              fontSize: 9, color: RpgColors.textMuted, letterSpacing: 0.8, fontWeight: FontWeight.w500)),
            Text(
              count == 0 ? 'Sin revisiones' : 'x$count ${count == 1 ? "vez" : "veces"}',
              style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 13),
            ),
          ]),
        ),
        if (count > 0)
          GestureDetector(
            onTap: () => onChanged(count - 1),
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: RpgColors.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.remove, size: 14, color: RpgColors.textMuted),
            ),
          ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => onChanged(count + 1),
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: RpgColors.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: RpgColors.gold),
            ),
            child: const Icon(Icons.add, size: 14, color: RpgColors.gold),
          ),
        ),
      ]),
    );
  }
}
