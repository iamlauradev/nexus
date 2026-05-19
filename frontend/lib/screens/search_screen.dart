import 'package:flutter/material.dart';
import '../theme/rpg_theme.dart';
import '../models/user_entry.dart';
import '../services/api_service.dart';
import '../widgets/media_card.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  List<UserEntry> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _results = []; _searched = false; });
      return;
    }
    setState(() => _loading = true);
    try {
      final entries = await ApiService.getEntries(q: query.trim(), limit: 100);
      if (mounted) setState(() { _results = entries; _loading = false; _searched = true; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _searched = true; });
    }
  }

  void _onChanged(String value) {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_searchCtrl.text == value) _search(value);
    });
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
            hintText: 'Buscar en tu colección...',
            hintStyle: const TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson'),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            fillColor: Colors.transparent,
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: RpgColors.textMuted, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() { _results = []; _searched = false; });
                    },
                  )
                : null,
          ),
          style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 16),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: RpgColors.gold))
          : !_searched
              ? _buildPrompt()
              : _results.isEmpty
                  ? _buildEmpty()
                  : _buildResults(),
    );
  }

  Widget _buildPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search, color: RpgColors.border, size: 56),
          const SizedBox(height: 16),
          const Text('Busca en toda tu colección', style: TextStyle(
            fontFamily: 'Cinzel', color: RpgColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 8),
          const Text('Películas, series, anime, cómics…', style: TextStyle(
            color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, color: RpgColors.border, size: 48),
          const SizedBox(height: 16),
          Text('Sin resultados para "${_searchCtrl.text}"', style: const TextStyle(
            fontFamily: 'Cinzel', color: RpgColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          const Text('Prueba con otro término', style: TextStyle(
            color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text('${_results.length} resultado${_results.length != 1 ? 's' : ''}',
            style: const TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 13)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _results.length,
            itemBuilder: (context, i) => MediaListTile(
              entry: _results[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailScreen(entry: _results[i])),
              ).then((_) => _search(_searchCtrl.text)),
            ),
          ),
        ),
      ],
    );
  }
}
