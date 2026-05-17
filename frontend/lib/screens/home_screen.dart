import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/rpg_theme.dart';
import '../models/user_entry.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../widgets/ornamental_border.dart';
import '../widgets/media_card.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _stats;
  List<UserEntry> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stats = await ApiService.getStats();
      final recent = await ApiService.getEntries(status: 'watching', limit: 10);
      if (mounted) setState(() { _stats = stats; _recent = recent; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return RefreshIndicator(
      color: RpgColors.gold,
      backgroundColor: RpgColors.surface,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenida, ${user?.name ?? ''}',
                    style: const TextStyle(
                      fontFamily: 'Crimson',
                      fontSize: 18,
                      color: RpgColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Nexus',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: RpgColors.gold,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (!_loading && _stats != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _StatsRow(stats: _stats!),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: RpgColors.gold)),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildTypeStats(),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: GoldDivider(label: 'VIENDO AHORA'),
              ),
            ),
            if (_recent.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'Nada en progreso — empieza tu aventura',
                      style: TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 14),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => MediaCard(
                      entry: _recent[i],
                      onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => DetailScreen(entry: _recent[i]))).then((_) => _load()),
                    ),
                    childCount: _recent.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.55,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeStats() {
    if (_stats == null) return const SizedBox.shrink();
    final byType = (_stats!['by_type'] as Map?) ?? {};
    final types = ['DORAMA', 'MOVIE', 'SERIES', 'MANGA', 'MANHWA', 'MANHUA', 'ANIME'];
    final icons = [Icons.tv, Icons.movie, Icons.theaters, Icons.auto_stories, Icons.menu_book, Icons.book, Icons.live_tv];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: types.length,
      itemBuilder: (context, i) {
        final count = byType[types[i]] ?? 0;
        return Container(
          decoration: BoxDecoration(
            color: RpgColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: RpgColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icons[i], color: RpgColors.amethystLight, size: 22),
              const SizedBox(height: 4),
              Text('$count', style: const TextStyle(
                fontFamily: 'Cinzel', fontSize: 16, color: RpgColors.gold, fontWeight: FontWeight.bold)),
              Text(typeLabel(types[i]), style: const TextStyle(
                fontFamily: 'Crimson', fontSize: 10, color: RpgColors.textMuted)),
            ],
          ),
        );
      },
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatBox(value: '${stats['total'] ?? 0}', label: 'Total', color: RpgColors.gold),
        const SizedBox(width: 8),
        _StatBox(value: '${stats['watching'] ?? 0}', label: 'Viendo', color: RpgColors.statusWatching),
        const SizedBox(width: 8),
        _StatBox(value: '${stats['completed'] ?? 0}', label: 'Completas', color: RpgColors.statusComplete),
        const SizedBox(width: 8),
        _StatBox(value: '${stats['plan'] ?? 0}', label: 'Pendientes', color: RpgColors.statusPlan),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatBox({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: RpgColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontFamily: 'Cinzel', fontSize: 20, color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontFamily: 'Crimson', fontSize: 11, color: RpgColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
