import 'package:flutter/material.dart';
import '../theme/rpg_theme.dart';
import '../models/user_entry.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';
import '../widgets/media_card.dart';
import 'detail_screen.dart';
import 'add_entry_screen.dart';

const _mediaTypes = {
  'ANIME':   'Anime',
  'DORAMA':  'Dorama',
  'MOVIE':   'Película',
  'SERIES':  'Serie',
  'MANGA':   'Manga',
  'MANHWA':  'Manhwa',
  'MANHUA':  'Manhua',
  'WEBTOON': 'Webtoon',
  'NOVEL':   'Novela',
};

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  String? _selectedType;

  List<UserEntry> _localResults = [];
  List<SearchResult> _externalResults = [];
  bool _loadingLocal = false;
  bool _loadingExternal = false;
  bool _searched = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_searchCtrl.text == value) _search(value);
    });
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _localResults = [];
        _externalResults = [];
        _searched = false;
      });
      return;
    }

    setState(() {
      _loadingLocal = true;
      _loadingExternal = _selectedType != null;
      _searched = true;
    });

    // Búsqueda local siempre (filtrada por tipo si hay tipo seleccionado)
    ApiService.getEntries(q: q, limit: 100, mediaType: _selectedType).then((entries) {
      if (mounted) setState(() { _localResults = entries; _loadingLocal = false; });
    }).catchError((_) {
      if (mounted) setState(() { _loadingLocal = false; });
    });

    // Búsqueda externa solo si hay tipo seleccionado
    if (_selectedType != null) {
      setState(() => _externalResults = []);
      ApiService.searchMetadata(q, _selectedType!).then((results) {
        // Solo los que NO están ya en la colección (los que tienen entryId van en la sección local)
        final nuevos = results.where((r) => r.entryId == null).toList();
        if (mounted) setState(() { _externalResults = nuevos; _loadingExternal = false; });
      }).catchError((_) {
        if (mounted) setState(() { _loadingExternal = false; });
      });
    } else {
      setState(() { _externalResults = []; _loadingExternal = false; });
    }
  }

  void _onTypeToggle(String type) {
    final nuevoTipo = _selectedType == type ? null : type;
    setState(() => _selectedType = nuevoTipo);
    if (_searchCtrl.text.trim().isNotEmpty) _search(_searchCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          onChanged: _onChanged,
          onSubmitted: _search,
          decoration: InputDecoration(
            hintText: 'Buscar en tu lista y en el catálogo…',
            hintStyle: TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson'),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            fillColor: Colors.transparent,
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close, color: RpgColors.textMuted, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() { _localResults = []; _externalResults = []; _searched = false; });
                    },
                  )
                : null,
          ),
          style: TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          _buildTypeChips(),
          Divider(height: 1, color: RpgColors.border),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildTypeChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: _mediaTypes.entries.map((e) {
          final sel = _selectedType == e.key;
          return GestureDetector(
            onTap: () => _onTypeToggle(e.key),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: sel ? RpgColors.gold.withOpacity(0.15) : RpgColors.charcoal,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? RpgColors.gold : RpgColors.border),
              ),
              child: Center(
                child: Text(e.value, style: TextStyle(
                  color: sel ? RpgColors.goldLight : RpgColors.textSecondary,
                  fontSize: 12,
                  fontFamily: 'Crimson',
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (!_searched) return _buildPrompt();

    final noResultados = !_loadingLocal && !_loadingExternal
        && _localResults.isEmpty && _externalResults.isEmpty;
    if (noResultados) return _buildEmpty();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Sección: colección del usuario
        if (_loadingLocal)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(color: RpgColors.gold, strokeWidth: 2)),
          )
        else if (_localResults.isNotEmpty) ...[
          _SectionHeader(title: 'En tu lista', count: _localResults.length),
          ..._localResults.map((e) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: MediaListTile(
              entry: e,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailScreen(entry: e)),
              ).then((_) => _search(_searchCtrl.text)),
            ),
          )),
        ],

        // Sección: catálogo externo (solo si hay tipo seleccionado)
        if (_selectedType != null) ...[
          if (_loadingExternal)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: RpgColors.gold, strokeWidth: 2)),
            )
          else if (_externalResults.isNotEmpty) ...[
            _SectionHeader(title: 'Añadir al registro', count: _externalResults.length),
            ..._externalResults.map((r) => _ExternalResultTile(
              result: r,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddEntryScreen(
                  initialType: r.type,
                  initialResult: r,
                )),
              ).then((_) => _search(_searchCtrl.text)),
            )),
          ],
        ],
      ],
    );
  }

  Widget _buildPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, color: RpgColors.border, size: 56),
          const SizedBox(height: 16),
          Text('Busca en toda tu colección',
            style: TextStyle(color: RpgColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 8),
          Text('Filtra por tipo para buscar también en el catálogo',
            style: TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, color: RpgColors.border, size: 48),
          const SizedBox(height: 16),
          Text('Sin resultados para "${_searchCtrl.text}"',
            style: TextStyle(color: RpgColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          if (_selectedType == null)
            Text('Selecciona un tipo para buscar también en el catálogo',
              style: TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 13)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Text(title, style: const TextStyle(
            color: RpgColors.gold,
            fontFamily: 'Crimson',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          )),
          const SizedBox(width: 6),
          Text('($count)', style: TextStyle(
            color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 12)),
        ],
      ),
    );
  }
}

class _ExternalResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;
  const _ExternalResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: result.coverUrl != null
                  ? Image.network(result.coverUrl!, width: 38, height: 54,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: RpgColors.textPrimary,
                      fontFamily: 'Crimson',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    )),
                  if (result.titleOriginal != null && result.titleOriginal != result.title)
                    Text(result.titleOriginal!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 12)),
                  const SizedBox(height: 3),
                  Row(children: [
                    if (result.year != null) ...[
                      Text('${result.year}',
                        style: TextStyle(color: RpgColors.textMuted, fontSize: 11)),
                      const SizedBox(width: 8),
                    ],
                    if (result.score != null)
                      Row(children: [
                        const Icon(Icons.star, size: 10, color: RpgColors.gold),
                        const SizedBox(width: 2),
                        Text(result.score!.toStringAsFixed(1),
                          style: TextStyle(color: RpgColors.textMuted, fontSize: 11)),
                      ]),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: RpgColors.gold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: RpgColors.gold.withOpacity(0.5)),
              ),
              child: const Icon(Icons.add, size: 16, color: RpgColors.gold),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _placeholder() => Container(
    width: 38, height: 54,
    decoration: BoxDecoration(
      color: RpgColors.charcoal,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Icon(Icons.image_not_supported_outlined, size: 14, color: RpgColors.border),
  );
}
