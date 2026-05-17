import 'package:flutter/material.dart';
import '../theme/rpg_theme.dart';
import '../models/user_entry.dart';
import '../services/api_service.dart';
import '../widgets/ornamental_border.dart';
import '../widgets/media_card.dart';
import 'detail_screen.dart';
import 'add_entry_screen.dart';

const kMediaTypes = ['DORAMA', 'MOVIE', 'SERIES', 'MANGA', 'MANHWA', 'MANHUA', 'ANIME'];
const kAllTypes = 'ALL';

class MediaListScreen extends StatefulWidget {
  final String? initialType;
  const MediaListScreen({super.key, this.initialType});

  @override
  State<MediaListScreen> createState() => _MediaListScreenState();
}

class _MediaListScreenState extends State<MediaListScreen> {
  String _type = kAllTypes;
  String _status = 'all';
  String _rating = 'all';
  String _view = 'grid';
  String _search = '';
  List<UserEntry> _entries = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? kAllTypes;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final entries = await ApiService.getEntries(
        status:    _status != 'all'  ? _status  : null,
        mediaType: _type   != kAllTypes ? _type    : null,
        rating:    _rating != 'all'  ? _rating  : null,
        q:         _search.isNotEmpty ? _search  : null,
        limit: 200,
      );
      if (mounted) setState(() { _entries = entries; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator(color: RpgColors.gold))
            : _entries.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  color: RpgColors.gold,
                  backgroundColor: RpgColors.surface,
                  onRefresh: _load,
                  child: _view == 'grid' ? _buildGrid() : _buildList(),
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
          // Type filter
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _TypeChip('Todos', kAllTypes),
                _TypeChip('Doramas', 'DORAMA'),
                _TypeChip('Películas', 'MOVIE'),
                _TypeChip('Series', 'SERIES'),
                _TypeChip('Manga', 'MANGA'),
                _TypeChip('Manhwa', 'MANHWA'),
                _TypeChip('Manhua', 'MANHUA'),
                _TypeChip('Anime', 'ANIME'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Search
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) { _search = v; _load(); },
                    decoration: InputDecoration(
                      hintText: 'Buscar...',
                      prefixIcon: const Icon(Icons.search, color: RpgColors.textMuted, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      isDense: true,
                    ),
                    style: const TextStyle(color: RpgColors.textPrimary, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Status filter
              _DropFilter(
                value: _status,
                items: const {'all': 'Estado', 'watching': 'Viendo', 'completed': 'Completado',
                              'plan_to_watch': 'Pendiente', 'on_hold': 'En espera', 'dropped': 'Abandonado'},
                onChanged: (v) { setState(() => _status = v); _load(); },
              ),
              const SizedBox(width: 6),
              // View toggle
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _TypeChip(String label, String value) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () { setState(() => _type = value); _load(); },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? RpgColors.goldDark.withOpacity(0.8) : RpgColors.charcoal,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? RpgColors.gold : RpgColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? RpgColors.goldLight : RpgColors.textSecondary,
              fontSize: 12,
              fontFamily: 'Crimson',
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.52,
      ),
      itemCount: _entries.length,
      itemBuilder: (context, i) => MediaCard(
        entry: _entries[i],
        onTap: () => _openDetail(_entries[i]),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _entries.length,
      itemBuilder: (context, i) => MediaListTile(
        entry: _entries[i],
        onTap: () => _openDetail(_entries[i]),
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
          const Text('Añade tu primera obra para empezar', style: TextStyle(
            color: RpgColors.textMuted, fontFamily: 'Crimson')),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _addNew(),
            icon: const Icon(Icons.add, color: RpgColors.goldLight),
            label: const Text('Añadir obra', style: TextStyle(color: RpgColors.goldLight, fontFamily: 'Cinzel')),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(UserEntry entry) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(entry: entry)));
    _load();
  }

  Future<void> _addNew() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AddEntryScreen(initialType: _type != kAllTypes ? _type : null)));
    _load();
  }
}

class _DropFilter extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final void Function(String) onChanged;

  const _DropFilter({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: RpgColors.charcoal,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: RpgColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: RpgColors.surface,
          style: const TextStyle(color: RpgColors.textSecondary, fontSize: 12, fontFamily: 'Crimson'),
          icon: const Icon(Icons.arrow_drop_down, color: RpgColors.textMuted, size: 16),
          isDense: true,
          items: items.entries.map((e) => DropdownMenuItem(
            value: e.key,
            child: Text(e.value),
          )).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}
