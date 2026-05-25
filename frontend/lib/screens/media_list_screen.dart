import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart' show EntryChangeNotifier;
import '../theme/rpg_theme.dart';
import '../models/user_entry.dart';
import '../services/api_service.dart';
import '../utils/responsive.dart';
import '../widgets/ornamental_border.dart';
import '../widgets/media_card.dart';
import 'detail_screen.dart';
import 'add_entry_screen.dart';

class MediaListScreen extends StatefulWidget {
  /// Optional type filter preset. When null, all types are shown and a
  /// type-selector dropdown is shown in the filter bar.
  final List<String>? types;
  final String? sectionLabel;

  const MediaListScreen({super.key, this.types, this.sectionLabel});

  @override
  State<MediaListScreen> createState() => _MediaListScreenState();
}

const _allTypes = [
  'MOVIE', 'DORAMA', 'SERIES', 'MANGA', 'MANHWA', 'MANHUA', 'WEBTOON', 'ANIME', 'NOVEL'
];

// Virtual group: selects all readable/book types at once
const _lecturaTypes = ['NOVEL', 'MANGA', 'MANHWA', 'MANHUA', 'WEBTOON'];

const _typeLabels = {
  'all':      'Tipo',
  'LECTURA':  'Libros / Novelas',
  'NOVEL':    'Novela',
  'MANGA':    'Manga',
  'MANHWA':   'Manhwa',
  'MANHUA':   'Manhua',
  'WEBTOON':  'Webtoon',
  'MOVIE':    'Películas',
  'DORAMA':   'Doramas',
  'SERIES':   'Series',
  'ANIME':    'Anime',
};

class _MediaListScreenState extends State<MediaListScreen> {
  String _status = 'all';
  String _rating = 'all';
  String _genre  = 'all';
  String _typeFilter = 'all'; // only active when widget.types is null
  String _sort = 'updated';
  String _view = 'grid';
  String _searchQuery = '';
  int _currentLimit = 50;

  List<UserEntry> _entries = [];
  bool _loading = true;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  EntryChangeNotifier? _entryNotifier;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = context.read<EntryChangeNotifier>();
    if (_entryNotifier != notifier) {
      _entryNotifier?.removeListener(_loadEntries);
      _entryNotifier = notifier;
      _entryNotifier!.addListener(_loadEntries);
    }
  }

  @override
  void dispose() {
    _entryNotifier?.removeListener(_loadEntries);
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final entries = await _fetchEntries();
      if (mounted) setState(() { _entries = _applySorting(entries); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _load() => _loadEntries();

  List<UserEntry> _applySorting(List<UserEntry> entries) {
    final sorted = List<UserEntry>.from(entries);
    switch (_sort) {
      case 'title':
        sorted.sort((a, b) =>
          (a.media?.title ?? '').toLowerCase().compareTo((b.media?.title ?? '').toLowerCase()));
        break;
      case 'score':
        sorted.sort((a, b) {
          final sa = a.score;
          final sb = b.score;
          if (sa == null && sb == null) return 0;
          if (sa == null) return 1;
          if (sb == null) return -1;
          return sb.compareTo(sa);
        });
        break;
      case 'year':
        sorted.sort((a, b) {
          final ya = a.media?.year;
          final yb = b.media?.year;
          if (ya == null && yb == null) return 0;
          if (ya == null) return 1;
          if (yb == null) return -1;
          return yb.compareTo(ya);
        });
        break;
      case 'started':
        sorted.sort((a, b) =>
          (b.startedAt ?? DateTime(0)).compareTo(a.startedAt ?? DateTime(0)));
        break;
      case 'completed':
        sorted.sort((a, b) =>
          (b.completedAt ?? DateTime(0)).compareTo(a.completedAt ?? DateTime(0)));
        break;
      case 'updated':
      default:
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }
    return sorted;
  }

  List<String> get _activeTypes {
    if (widget.types != null) return widget.types!;
    if (_typeFilter == 'LECTURA') return _lecturaTypes;
    if (_typeFilter != 'all') return [_typeFilter];
    return _allTypes;
  }

  Future<List<UserEntry>> _fetchEntries() async {
    final String? status = _status != 'all' ? _status : null;
    final String? rating = _rating != 'all' ? _rating : null;
    final String? q = _searchQuery.length > 2 ? _searchQuery : null;
    final types = _activeTypes;

    if (types.length == 1) {
      return ApiService.getEntries(
        mediaType: types.first,
        status: status,
        rating: rating,
        q: q,
        limit: _currentLimit,
      );
    }

    final futures = types.map((t) => ApiService.getEntries(
      mediaType: t,
      status: status,
      rating: rating,
      q: q,
      limit: _currentLimit,
    ));
    final results = await Future.wait(futures);
    return results.expand((e) => e).toList();
  }

  List<UserEntry> get _filteredEntries {
    var result = _entries;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((e) {
        final title     = (e.media?.title         ?? '').toLowerCase();
        final titleOrig = (e.media?.titleOriginal ?? '').toLowerCase();
        return title.contains(q) || titleOrig.contains(q);
      }).toList();
    }
    if (_genre != 'all') {
      result = result.where((e) => (e.media?.genres ?? []).contains(_genre)).toList();
    }
    return result;
  }

  // Genres present in loaded entries, sorted by frequency (min 2 entries)
  List<String> get _availableGenres {
    final counts = <String, int>{};
    for (final e in _entries) {
      for (final g in (e.media?.genres ?? [])) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.where((e) => e.value >= 2).map((e) => e.key).toList();
  }

  Map<String, String> get _ratingFilterItems {
    final items = <String, String>{'all': 'Valoración'};
    for (final cfg in RatingConfigCache.configs) {
      items[cfg['key'] as String] = cfg['label'] as String;
    }
    return items;
  }

  void _onSearchChanged(String v) {
    setState(() => _searchQuery = v);
    _debounce?.cancel();
    if (v.length > 2) {
      _debounce = Timer(const Duration(milliseconds: 400), () {
        _loadEntries();
      });
    }
  }

  // +1 episode: optimistic UI update + API call
  Future<void> _quickEpisodePlus(UserEntry entry) async {
    final newEp = (entry.epCurrent ?? 0) + 1;
    // Optimistic update
    setState(() {
      final idx = _entries.indexWhere((e) => e.id == entry.id);
      if (idx >= 0) {
        final old = _entries[idx];
        _entries[idx] = UserEntry(
          id: old.id, userId: old.userId, mediaId: old.mediaId,
          status: old.status, progress: old.progress, score: old.score,
          ratingLabel: old.ratingLabel, notes: old.notes, platform: old.platform,
          startedAt: old.startedAt, completedAt: old.completedAt,
          epCurrent: newEp, epTotal: old.epTotal,
          rewatchCount: old.rewatchCount, emissionDay: old.emissionDay,
          updatedAt: DateTime.now(), media: old.media,
        );
      }
    });
    try {
      await ApiService.updateEntry(entry.id, {'ep_current': newEp});
    } catch (_) {
      if (mounted) _loadEntries();
    }
  }

  // Long press → quick status change bottom sheet
  void _showQuickStatus(BuildContext context, UserEntry entry) {
    const labels = {
      'watching':      'Viendo',
      'completed':     'Completado',
      'plan_to_watch': 'Pendiente',
      'on_hold':       'En espera',
      'dropped':       'Abandonado',
    };
    const colors = {
      'watching':      RpgColors.statusWatching,
      'completed':     RpgColors.statusComplete,
      'plan_to_watch': RpgColors.statusPlan,
      'on_hold':       RpgColors.statusOnHold,
      'dropped':       RpgColors.statusDropped,
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: RpgColors.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: RpgColors.border,
                  borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              entry.media?.title ?? '',
              style: const TextStyle(fontSize: 13, color: RpgColors.textPrimary, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            const Text('Cambiar estado:', style: TextStyle(
              fontFamily: 'Crimson', fontSize: 12, color: RpgColors.textMuted)),
            const SizedBox(height: 10),
            ...labels.entries.map((e) => InkWell(
              onTap: () async {
                Navigator.pop(context);
                if (e.key == entry.status) return;
                // Optimistic update
                setState(() {
                  final idx = _entries.indexWhere((en) => en.id == entry.id);
                  if (idx >= 0) {
                    final old = _entries[idx];
                    _entries[idx] = UserEntry(
                      id: old.id, userId: old.userId, mediaId: old.mediaId,
                      status: e.key, progress: old.progress, score: old.score,
                      ratingLabel: old.ratingLabel, notes: old.notes, platform: old.platform,
                      startedAt: old.startedAt, completedAt: old.completedAt,
                      epCurrent: old.epCurrent, epTotal: old.epTotal,
                      rewatchCount: old.rewatchCount, emissionDay: old.emissionDay,
                      updatedAt: DateTime.now(), media: old.media,
                    );
                  }
                });
                try {
                  await ApiService.updateEntry(entry.id, {'status': e.key});
                } catch (_) {
                  if (mounted) _loadEntries();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: colors[e.key] ?? RpgColors.border,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(e.value, style: TextStyle(
                    fontFamily: 'Crimson', fontSize: 15,
                    color: entry.status == e.key ? RpgColors.gold : RpgColors.textPrimary,
                    fontWeight: entry.status == e.key ? FontWeight.w600 : FontWeight.normal,
                  )),
                  if (entry.status == e.key) ...[
                    const Spacer(),
                    const Icon(Icons.check, size: 14, color: RpgColors.gold),
                  ],
                ]),
              ),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _filteredEntries;
    return Column(
      children: [
        _buildFilters(context),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: RpgColors.gold))
              : displayed.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: RpgColors.gold,
                      backgroundColor: RpgColors.surface,
                      onRefresh: _load,
                      child: _view == 'grid'
                          ? _buildGrid(displayed)
                          : _buildList(displayed),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    final isDesktop = context.isDesktop;
    final statusItems = const {
      'all':           'Estado',
      'watching':      'Viendo',
      'completed':     'Completado',
      'plan_to_watch': 'Pendiente',
      'on_hold':       'En espera',
      'dropped':       'Abandonado',
    };
    final sortItems = const {
      'updated':   'Recientes',
      'title':     'A-Z',
      'score':     'Puntuación',
      'year':      'Año',
      'started':   'Fecha inicio',
      'completed': 'Fecha fin',
    };

    final sectionLabel = widget.sectionLabel ?? 'Catálogo';
    final showTypeFilter = widget.types == null;

    final searchField = TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Buscar en $sectionLabel...',
        prefixIcon: const Icon(Icons.search, color: RpgColors.textMuted, size: 18),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: RpgColors.charcoal,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: RpgColors.border),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      ),
      style: const TextStyle(color: RpgColors.textPrimary, fontSize: 14),
      onChanged: _onSearchChanged,
    );

    final viewToggle = GestureDetector(
      onTap: () => setState(() => _view = _view == 'grid' ? 'list' : 'grid'),
      child: Container(
        width: isDesktop ? 38 : 32,
        height: isDesktop ? 38 : 32,
        decoration: BoxDecoration(
          color: RpgColors.charcoal,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          _view == 'grid' ? Icons.view_list : Icons.grid_view,
          color: RpgColors.gold,
          size: isDesktop ? 20 : 18,
        ),
      ),
    );

    final genres = _availableGenres;
    final genreChips = genres.isEmpty ? const SizedBox.shrink() : SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _GenreChip(
            label: 'Todos',
            selected: _genre == 'all',
            onTap: () => setState(() => _genre = 'all'),
          ),
          ...genres.map((g) => _GenreChip(
            label: g,
            selected: _genre == g,
            onTap: () => setState(() => _genre = _genre == g ? 'all' : g),
          )),
        ],
      ),
    );

    if (isDesktop) {
      return Container(
        color: RpgColors.darkVoid,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(flex: 3, child: searchField),
                const SizedBox(width: 10),
                viewToggle,
                if (showTypeFilter) ...[
                  const SizedBox(width: 10),
                  SizedBox(width: 130, child: _DropFilter(
                    value: _typeFilter, items: _typeLabels,
                    onChanged: (v) { setState(() { _typeFilter = v; _currentLimit = 50; }); _loadEntries(); },
                  )),
                ],
                const SizedBox(width: 10),
                SizedBox(width: 140, child: _DropFilter(
                  value: _status, items: statusItems,
                  onChanged: (v) { setState(() => _status = v); _loadEntries(); },
                )),
                const SizedBox(width: 10),
                SizedBox(width: 140, child: _DropFilter(
                  value: _rating, items: _ratingFilterItems,
                  onChanged: (v) { setState(() => _rating = v); _loadEntries(); },
                )),
                const SizedBox(width: 10),
                SizedBox(width: 140, child: _DropFilter(
                  value: _sort, items: sortItems,
                  onChanged: (v) { setState(() { _sort = v; _entries = _applySorting(_entries); }); },
                )),
              ],
            ),
            if (genres.isNotEmpty) ...[
              const SizedBox(height: 8),
              genreChips,
            ],
          ],
        ),
      );
    }

    // Mobile layout
    return Container(
      color: RpgColors.darkVoid,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          searchField,
          const SizedBox(height: 6),
          Row(
            children: [
              viewToggle,
              const SizedBox(width: 6),
              if (showTypeFilter) ...[
                Expanded(child: _DropFilter(
                  value: _typeFilter, items: _typeLabels,
                  onChanged: (v) { setState(() { _typeFilter = v; _currentLimit = 50; }); _loadEntries(); },
                )),
                const SizedBox(width: 6),
              ],
              Expanded(child: _DropFilter(
                value: _status, items: statusItems,
                onChanged: (v) { setState(() => _status = v); _loadEntries(); },
              )),
              const SizedBox(width: 6),
              Expanded(child: _DropFilter(
                value: _rating, items: _ratingFilterItems,
                onChanged: (v) { setState(() => _rating = v); _loadEntries(); },
              )),
              const SizedBox(width: 6),
              Expanded(child: _DropFilter(
                value: _sort, items: sortItems,
                onChanged: (v) { setState(() { _sort = v; _entries = _applySorting(_entries); }); },
              )),
            ],
          ),
          if (genres.isNotEmpty) ...[
            const SizedBox(height: 6),
            genreChips,
          ],
        ],
      ),
    );
  }

  Widget _buildGrid(List<UserEntry> entries) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w < 480 ? 3 : w < 720 ? 4 : w < 1000 ? 5 : 6;
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.52,
          ),
          itemCount: entries.length + (_entries.length >= _currentLimit ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == entries.length) return _buildLoadMoreButton();
            return MediaCard(
              entry: entries[i],
              onTap: () => _openDetail(entries[i]),
              onEpisodePlus: () => _quickEpisodePlus(entries[i]),
              onLongPress: () => _showQuickStatus(context, entries[i]),
            );
          },
        );
      },
    );
  }

  Widget _buildList(List<UserEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length + (_entries.length >= _currentLimit ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == entries.length) return _buildLoadMoreButton();
        return MediaListTile(
          entry: entries[i],
          onTap: () => _openDetail(entries[i]),
          onEpisodePlus: () => _quickEpisodePlus(entries[i]),
          onLongPress: () => _showQuickStatus(context, entries[i]),
        );
      },
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: TextButton(
          onPressed: () async {
            setState(() => _currentLimit += 50);
            await _loadEntries();
          },
          child: const Text('Cargar más', style: TextStyle(color: RpgColors.accent)),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_stories, color: RpgColors.border, size: 56),
          const SizedBox(height: 16),
          const Text('El grimorio está vacío', style: TextStyle(
              color: RpgColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'Añade tu primera entrada al catálogo',
            style: TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson'),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addNew,
            icon: const Icon(Icons.add, color: RpgColors.goldLight),
            label: const Text('Añadir', style: TextStyle(color: RpgColors.goldLight)),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(UserEntry entry) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(entry: entry)));
    _loadEntries();
  }

  Future<void> _addNew() async {
    final types = _activeTypes;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddEntryScreen(
        initialType: types.first,
        availableTypes: types,
      ),
    ));
    _loadEntries();
  }
}

class _DropFilter extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final void Function(String) onChanged;

  const _DropFilter({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final safeValue = items.containsKey(value) ? value : items.keys.first;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: RpgColors.charcoal,
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          dropdownColor: RpgColors.surface,
          style: const TextStyle(color: RpgColors.textSecondary, fontSize: 12, fontFamily: 'Crimson'),
          icon: const Icon(Icons.arrow_drop_down, color: RpgColors.textMuted, size: 16),
          isDense: true,
          isExpanded: true,
          items: items.entries.map((e) => DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GenreChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? RpgColors.gold.withOpacity(0.18) : RpgColors.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: selected ? Border.all(color: RpgColors.gold, width: 1.5) : null,
        ),
        child: Text(label, style: TextStyle(
          fontFamily: 'Crimson', fontSize: 12,
          color: selected ? RpgColors.goldLight : RpgColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        )),
      ),
    );
  }
}
