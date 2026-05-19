import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart' show EntryChangeNotifier;
import '../theme/rpg_theme.dart';
import '../models/user_entry.dart';
import '../services/api_service.dart';
import '../widgets/ornamental_border.dart';
import '../widgets/media_card.dart';
import 'detail_screen.dart';
import 'add_entry_screen.dart';

class MediaListScreen extends StatefulWidget {
  final List<String> types;
  final String sectionLabel;

  const MediaListScreen({super.key, required this.types, required this.sectionLabel});

  @override
  State<MediaListScreen> createState() => _MediaListScreenState();
}

class _MediaListScreenState extends State<MediaListScreen> {
  String _status = 'all';
  String _rating = 'all';
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
    setState(() => _loading = true);
    try {
      final entries = await _fetchEntries();
      if (mounted) setState(() { _entries = _applySorting(entries); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  // Keep legacy _load alias for RefreshIndicator
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

  Future<List<UserEntry>> _fetchEntries() async {
    final String? status = _status != 'all' ? _status : null;
    final String? rating = _rating != 'all' ? _rating : null;
    // Only pass server-side q if search query > 2 chars
    final String? q = _searchQuery.length > 2 ? _searchQuery : null;

    if (widget.types.length == 1) {
      return ApiService.getEntries(
        mediaType: widget.types.first,
        status: status,
        rating: rating,
        q: q,
        limit: _currentLimit,
      );
    }

    // Sección multi-tipo (Cómics): carga en paralelo y fusiona
    final futures = widget.types.map((t) => ApiService.getEntries(
      mediaType: t,
      status: status,
      rating: rating,
      q: q,
      limit: _currentLimit,
    ));
    final results = await Future.wait(futures);
    final all = results.expand((e) => e).toList();
    return all;
  }

  // Filter entries locally by search query
  List<UserEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return _entries;
    return _entries.where((e) =>
      (e.media?.title ?? '').toLowerCase().contains(_searchQuery.toLowerCase())).toList();
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

  @override
  Widget build(BuildContext context) {
    final displayed = _filteredEntries;
    return Column(
      children: [
        _buildFilters(),
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

  Widget _buildFilters() {
    return Container(
      color: RpgColors.darkVoid,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          // Inline search field
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar en ${widget.sectionLabel}...',
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
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Toggle vista grid/lista
              GestureDetector(
                onTap: () => setState(() => _view = _view == 'grid' ? 'list' : 'grid'),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: RpgColors.charcoal,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: RpgColors.border),
                  ),
                  child: Icon(
                    _view == 'grid' ? Icons.view_list : Icons.grid_view,
                    color: RpgColors.gold, size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Filtro de estado
              Expanded(
                child: _DropFilter(
                  value: _status,
                  items: const {
                    'all':           'Estado',
                    'watching':      'Viendo',
                    'completed':     'Completado',
                    'plan_to_watch': 'Pendiente',
                    'on_hold':       'En espera',
                    'dropped':       'Abandonado',
                  },
                  onChanged: (v) { setState(() => _status = v); _loadEntries(); },
                ),
              ),
              const SizedBox(width: 6),
              // Filtro de valoración
              Expanded(
                child: _DropFilter(
                  value: _rating,
                  items: _ratingFilterItems,
                  onChanged: (v) { setState(() => _rating = v); _loadEntries(); },
                ),
              ),
              const SizedBox(width: 6),
              // Sort dropdown
              Expanded(
                child: _DropFilter(
                  value: _sort,
                  items: const {
                    'updated':   'Recientes',
                    'title':     'A-Z',
                    'score':     'Puntuación',
                    'year':      'Año',
                    'started':   'Fecha inicio',
                    'completed': 'Fecha fin',
                  },
                  onChanged: (v) { setState(() { _sort = v; _entries = _applySorting(_entries); }); },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<UserEntry> entries) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.52,
      ),
      itemCount: entries.length + (_entries.length >= _currentLimit ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == entries.length) {
          return _buildLoadMoreButton();
        }
        return MediaCard(
          entry: entries[i],
          onTap: () => _openDetail(entries[i]),
        );
      },
    );
  }

  Widget _buildList(List<UserEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length + (_entries.length >= _currentLimit ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == entries.length) {
          return _buildLoadMoreButton();
        }
        return MediaListTile(
          entry: entries[i],
          onTap: () => _openDetail(entries[i]),
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
          child: const Text('Cargar más',
              style: TextStyle(color: RpgColors.accent)),
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
              fontFamily: 'Cinzel', color: RpgColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'Añade tu primer${widget.sectionLabel == 'Cómics' ? ' cómic' : widget.sectionLabel == 'Películas' ? 'a película' : widget.sectionLabel == 'Series' ? 'a serie' : ' ${widget.sectionLabel.toLowerCase()}'}',
            style: const TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson'),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _addNew(),
            icon: const Icon(Icons.add, color: RpgColors.goldLight),
            label: const Text('Añadir', style: TextStyle(color: RpgColors.goldLight, fontFamily: 'Cinzel')),
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
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddEntryScreen(
        initialType: widget.types.first,
        availableTypes: widget.types,
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
    // Ensure value is valid
    final safeValue = items.containsKey(value) ? value : items.keys.first;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: RpgColors.charcoal,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: RpgColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          dropdownColor: RpgColors.surface,
          style: const TextStyle(color: RpgColors.textSecondary, fontSize: 11, fontFamily: 'Crimson'),
          icon: const Icon(Icons.arrow_drop_down, color: RpgColors.textMuted, size: 14),
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
