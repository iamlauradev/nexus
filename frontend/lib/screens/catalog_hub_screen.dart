import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/rpg_theme.dart';
import '../services/api_service.dart';

// ---------------------------------------------------------------------------
// Category definitions
// ---------------------------------------------------------------------------

class _Category {
  final String label;
  final List<String> types; // empty = all types
  final IconData icon;
  final Color color;
  const _Category({
    required this.label,
    required this.types,
    required this.icon,
    required this.color,
  });
}

const _categories = [
  _Category(
    label: 'Anime',
    types: ['ANIME'],
    icon: Icons.animation,
    color: RpgColors.statusComplete,
  ),
  _Category(
    label: 'Manga',
    types: ['MANGA', 'MANHWA', 'MANHUA', 'WEBTOON'],
    icon: Icons.auto_stories,
    color: RpgColors.amethyst,
  ),
  _Category(
    label: 'Novelas',
    types: ['NOVEL'],
    icon: Icons.local_library,
    color: RpgColors.statusPlan,
  ),
  _Category(
    label: 'Doramas',
    types: ['DORAMA'],
    icon: Icons.live_tv,
    color: RpgColors.statusOnHold,
  ),
  _Category(
    label: 'Pelis & Series',
    types: ['MOVIE', 'SERIES'],
    icon: Icons.theaters,
    color: RpgColors.statusDropped,
  ),
  _Category(
    label: 'Todo',
    types: [],
    icon: Icons.apps_rounded,
    color: RpgColors.accent,
  ),
];

// ---------------------------------------------------------------------------
// Hub screen
// ---------------------------------------------------------------------------

class CatalogHubScreen extends StatefulWidget {
  const CatalogHubScreen({super.key});

  @override
  State<CatalogHubScreen> createState() => _CatalogHubScreenState();
}

class _CatalogHubScreenState extends State<CatalogHubScreen> {
  Map<String, int> _countsByType = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final stats = await ApiService.getStats();
      final raw = stats['by_type'] as Map? ?? {};
      final byType = raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      if (mounted) setState(() { _countsByType = Map<String, int>.from(byType); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _countFor(_Category cat) {
    if (cat.types.isEmpty) {
      return _countsByType.values.fold(0, (a, b) => a + b);
    }
    return cat.types.fold(0, (sum, t) => sum + (_countsByType[t] ?? 0));
  }

  void _open(_Category cat) {
    context.push('/catalog/media', extra: {
      'types': cat.types.isEmpty ? null : cat.types,
      'label': cat.label,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RpgColors.obsidian,
      appBar: AppBar(title: Text('Catálogo')),
      body: RefreshIndicator(
        onRefresh: _loadCounts,
        color: RpgColors.accent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _SearchHint(
              onTap: () => context.push('/catalog/media', extra: {
                'types': null,
                'label': 'Catálogo',
              }),
            ),
            SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: _categories.length,
              itemBuilder: (_, i) => _CategoryCard(
                category: _categories[i],
                count: _loading ? null : _countFor(_categories[i]),
                onTap: () => _open(_categories[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search hint
// ---------------------------------------------------------------------------

class _SearchHint extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchHint({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: RpgColors.charcoal,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: RpgColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: RpgColors.textMuted, size: 18),
            SizedBox(width: 10),
            Text(
              'Buscar en todo el catálogo...',
              style: TextStyle(color: RpgColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category card
// ---------------------------------------------------------------------------

class _CategoryCard extends StatelessWidget {
  final _Category category;
  final int? count;
  final VoidCallback onTap;
  const _CategoryCard({
    required this.category,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withAlpha(40), RpgColors.surface],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(46),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withAlpha(38),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(category.icon, color: color, size: 20),
            ),
            const Spacer(),
            Text(
              category.label,
              style: TextStyle(
                fontFamily: 'Cinzel',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: RpgColors.textPrimary,
                height: 1.3,
              ),
            ),
            SizedBox(height: 4),
            if (count == null)
              SizedBox(
                width: 48,
                height: 6,
                child: LinearProgressIndicator(
                  backgroundColor: RpgColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(RpgColors.textMuted),
                ),
              )
            else
              Text(
                '$count ${count == 1 ? "entrada" : "entradas"}',
                style: TextStyle(
                  fontSize: 11,
                  color: RpgColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

