import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/rpg_theme.dart';
import '../models/user_entry.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
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
      final stats  = await ApiService.getStats();
      final recent = await ApiService.getEntries(status: 'watching', limit: 12);
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
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, ${user?.name ?? ''}',
                    style: const TextStyle(fontFamily: 'Crimson', fontSize: 16, color: RpgColors.textSecondary),
                  ),
                  const Text(
                    'Tu colección',
                    style: TextStyle(fontFamily: 'Cinzel', fontSize: 26, fontWeight: FontWeight.bold,
                      color: RpgColors.textPrimary, letterSpacing: 2),
                  ),
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
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          if (!_loading && _stats != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _TypeStats(byType: (_stats!['by_type'] as Map<String, dynamic>?) ?? {}),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: RpgColors.gold)),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(children: [
                  Container(width: 3, height: 14, decoration: BoxDecoration(
                    color: RpgColors.statusWatching, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  const Text('Viendo ahora', style: TextStyle(
                    fontFamily: 'Cinzel', fontSize: 13, color: RpgColors.textSecondary, letterSpacing: 1)),
                ]),
              ),
            ),
            if (_recent.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text(
                    'Nada en progreso todavía',
                    style: TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 14),
                  )),
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
                    crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.55,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _StatBox(value: '${stats['total'] ?? 0}',     label: 'Total',     color: RpgColors.textPrimary),
      const SizedBox(width: 8),
      _StatBox(value: '${stats['watching'] ?? 0}',  label: 'Viendo',    color: RpgColors.statusWatching),
      const SizedBox(width: 8),
      _StatBox(value: '${stats['completed'] ?? 0}', label: 'Completos', color: RpgColors.statusComplete),
      const SizedBox(width: 8),
      _StatBox(value: '${stats['plan'] ?? 0}',      label: 'Pendiente', color: RpgColors.statusPlan),
    ]);
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
          color: RpgColors.charcoal,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: RpgColors.border),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontFamily: 'Cinzel', fontSize: 20, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontFamily: 'Crimson', fontSize: 11, color: RpgColors.textMuted)),
        ]),
      ),
    );
  }
}

class _TypeStats extends StatelessWidget {
  final Map<String, dynamic> byType;
  const _TypeStats({required this.byType});

  int _sum(List<String> keys) =>
      keys.fold(0, (acc, k) => acc + ((byType[k] as int?) ?? 0));

  @override
  Widget build(BuildContext context) {
    final sections = [
      (label: 'Películas', icon: Icons.movie,         count: _sum(['MOVIE'])),
      (label: 'Doramas',   icon: Icons.live_tv,       count: _sum(['DORAMA'])),
      (label: 'Series',    icon: Icons.tv,             count: _sum(['SERIES'])),
      (label: 'Cómics',    icon: Icons.auto_stories,  count: _sum(['MANGA', 'MANHWA', 'MANHUA', 'WEBTOON'])),
      (label: 'Anime',     icon: Icons.animation,      count: _sum(['ANIME'])),
    ];

    return Row(
      children: sections.map((s) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: RpgColors.charcoal,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: RpgColors.border),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(s.icon, color: RpgColors.gold.withOpacity(0.7), size: 18),
            const SizedBox(height: 4),
            Text('${s.count}', style: const TextStyle(
              fontFamily: 'Cinzel', fontSize: 14, color: RpgColors.textPrimary, fontWeight: FontWeight.bold)),
            Text(s.label, style: const TextStyle(
              fontFamily: 'Crimson', fontSize: 9, color: RpgColors.textMuted)),
          ]),
        ),
      )).toList(),
    );
  }
}
