import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart' show EntryChangeNotifier;
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
  List<UserEntry> _completed = [];
  bool _loading = true;
  bool _fetching = false;
  EntryChangeNotifier? _entryNotifier;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = context.read<EntryChangeNotifier>();
    if (_entryNotifier != notifier) {
      _entryNotifier?.removeListener(_load);
      _entryNotifier = notifier;
      _entryNotifier!.addListener(_load);
    }
  }

  @override
  void dispose() {
    _entryNotifier?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final results = await Future.wait<dynamic>([
        ApiService.getStats(),
        ApiService.getEntries(status: 'watching', limit: 24),
        ApiService.getEntries(status: 'completed', limit: 12),
      ]);
      if (mounted) setState(() {
        _stats = results[0] as Map<String, dynamic>;
        final watching = List<UserEntry>.from(results[1] as List<UserEntry>);
        watching.sort((a, b) {
          final aNew = a.isNewEpisodeToday ? 0 : 1;
          final bNew = b.isNewEpisodeToday ? 0 : 1;
          return aNew.compareTo(bNew);
        });
        _recent = watching;
        final completed = List<UserEntry>.from(results[2] as List<UserEntry>);
        completed.sort((a, b) {
          final ad = a.completedAt ?? a.updatedAt;
          final bd = b.completedAt ?? b.updatedAt;
          return bd.compareTo(ad);
        });
        _completed = completed.take(10).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    } finally {
      _fetching = false;
    }
  }

  Future<void> _showRandomPick() async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _RandomPickDialog(onEntryTap: (e) {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(entry: e)))
          .then((_) => _load());
      }),
    );
  }

  Widget _sectionHeader(String label, Color accent, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(
          color: accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(
          fontSize: 13, color: RpgColors.textSecondary, letterSpacing: 0.3, fontWeight: FontWeight.w600)),
        if (trailing != null) ...[const Spacer(), trailing],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final airing = _recent.where((e) => e.emissionDay != null).toList();

    return RefreshIndicator(
      color: RpgColors.gold,
      backgroundColor: RpgColors.surface,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hola, ${user?.name ?? ''}',
                    style: const TextStyle(fontFamily: 'DMSans', fontSize: 13, color: RpgColors.textMuted)),
                  const Text('Tu colección',
                    style: TextStyle(fontFamily: 'Cinzel', fontSize: 26, fontWeight: FontWeight.w700,
                      color: RpgColors.textPrimary, letterSpacing: 1)),
                ])),
                if (!_loading)
                  GestureDetector(
                    onTap: _showRandomPick,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: RpgColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.shuffle_rounded, color: RpgColors.accent, size: 16),
                        const SizedBox(width: 6),
                        const Text('¿Qué ver?', style: TextStyle(
                          fontFamily: 'DMSans', fontSize: 11,
                          color: RpgColors.textSecondary, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),

          // Stats
          if (!_loading && _stats != null) ...[
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _StatsRow(stats: _stats!),
            )),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _TypeStats(byType: (_stats!['by_type'] as Map<String, dynamic>?) ?? {}),
            )),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: RpgColors.gold)),
            )
          else ...[
            // Emission calendar
            if (airing.isNotEmpty) ...[
              SliverToBoxAdapter(child: _sectionHeader('Calendario de emisión', RpgColors.gold)),
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: _EmissionCalendar(entries: airing, onTap: (e) =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(entry: e)))
                    .then((_) => _load())),
              )),
            ],

            // Viendo ahora
            SliverToBoxAdapter(child: _sectionHeader('Viendo ahora', RpgColors.statusWatching)),
            if (_recent.isEmpty)
              const SliverToBoxAdapter(child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Nada en progreso todavía',
                  style: TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 14))),
              ))
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverLayoutBuilder(builder: (context, constraints) {
                  final w = constraints.crossAxisExtent;
                  final cols = w < 480 ? 3 : w < 720 ? 4 : w < 1000 ? 5 : 6;
                  return SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => MediaCard(
                        entry: _recent[i],
                        onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => DetailScreen(entry: _recent[i]))).then((_) => _load()),
                      ),
                      childCount: _recent.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.55,
                    ),
                  );
                }),
              ),

            // Completadas recientemente
            if (_completed.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(child: _sectionHeader('Completadas recientemente', RpgColors.statusComplete)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverLayoutBuilder(builder: (context, constraints) {
                  final w = constraints.crossAxisExtent;
                  final cols = w < 480 ? 3 : w < 720 ? 4 : w < 1000 ? 5 : 6;
                  return SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => MediaCard(
                        entry: _completed[i],
                        onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => DetailScreen(entry: _completed[i]))).then((_) => _load()),
                      ),
                      childCount: _completed.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.55,
                    ),
                  );
                }),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ],
      ),
    );
  }
}

// ── Emission Calendar ────────────────────────────────────────────────────────

class _EmissionCalendar extends StatelessWidget {
  final List<UserEntry> entries;
  final void Function(UserEntry) onTap;
  const _EmissionCalendar({required this.entries, required this.onTap});

  static const _dayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final todayIdx = DateTime.now().weekday - 1; // 0=Mon…6=Sun
    final byDay = <int, List<UserEntry>>{};
    for (final e in entries) {
      if (e.emissionDay != null) {
        byDay.putIfAbsent(e.emissionDay!, () => []).add(e);
      }
    }
    // First day with entries in calendar order (0=Mon), not insertion order
    final firstFilledDay = byDay.isEmpty ? -1 : byDay.keys.reduce((a, b) => a < b ? a : b);

    return Container(
      decoration: BoxDecoration(
        color: RpgColors.charcoal,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: List.generate(7, (day) {
          final dayEntries = byDay[day] ?? [];
          final isToday = day == todayIdx;
          if (dayEntries.isEmpty) return const SizedBox.shrink();
          return Column(
            children: [
              if (day != firstFilledDay)
                const Divider(height: 1, color: RpgColors.border),
              InkWell(
                onTap: dayEntries.length == 1 ? () => onTap(dayEntries.first) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    // Day label
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: isToday ? RpgColors.gold.withOpacity(0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: isToday ? Border.all(color: RpgColors.gold.withOpacity(0.7)) : null,
                      ),
                      child: Center(child: Text(_dayLabels[day], style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: isToday ? RpgColors.gold : RpgColors.textMuted))),
                    ),
                    const SizedBox(width: 10),
                    // Entry covers / titles
                    Expanded(child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: dayEntries.map((e) => GestureDetector(
                        onTap: () => onTap(e),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: Row(children: [
                            if (e.media?.coverUrl != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(e.media!.coverUrl!, width: 28, height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 28, height: 40, color: RpgColors.surface,
                                    child: const Icon(Icons.broken_image, size: 14, color: RpgColors.textMuted))),
                              ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Text(e.media?.title ?? '', maxLines: 2,
                                style: TextStyle(
                                  fontFamily: 'Crimson', fontSize: 12,
                                  color: isToday ? RpgColors.textPrimary : RpgColors.textSecondary,
                                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal),
                                overflow: TextOverflow.ellipsis),
                            ),
                          ]),
                        ),
                      )).toList()),
                    )),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: RpgColors.gold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: RpgColors.gold.withOpacity(0.5)),
                        ),
                        child: const Text('HOY', style: TextStyle(
                          fontSize: 8, color: RpgColors.gold, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
                      ),
                  ]),
                ),
              ),
            ],
          );
        }).where((w) => w is! SizedBox).toList(),
      ),
    );
  }
}

// ── Random Pick Dialog ────────────────────────────────────────────────────────

class _RandomPickDialog extends StatefulWidget {
  final void Function(UserEntry) onEntryTap;
  const _RandomPickDialog({required this.onEntryTap});

  @override
  State<_RandomPickDialog> createState() => _RandomPickDialogState();
}

class _RandomPickDialogState extends State<_RandomPickDialog> {
  UserEntry? _pick;
  bool _loading = true;
  String? _error;
  String? _filterType;

  static const _typeOptions = [
    (label: 'Todo', value: null),
    (label: 'Película', value: 'MOVIE'),
    (label: 'Serie', value: 'SERIES'),
    (label: 'Dorama', value: 'DORAMA'),
    (label: 'Anime', value: 'ANIME'),
    (label: 'Cómic', value: 'MANGA'),
  ];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final pick = await ApiService.getRandomPick(mediaType: _filterType);
      if (mounted) setState(() { _pick = pick; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.statusCode == 404 ? 'No hay nada pendiente' : e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Error al obtener sugerencia'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: RpgColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.shuffle_rounded, color: RpgColors.gold, size: 18),
            const SizedBox(width: 8),
            const Text('¿Qué ver ahora?', style: TextStyle(
              fontFamily: 'Cinzel', fontSize: 15, color: RpgColors.textPrimary, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 18, color: RpgColors.textMuted),
              padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
          const SizedBox(height: 12),
          // Type filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _typeOptions.map((opt) {
              final selected = _filterType == opt.value;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () { setState(() => _filterType = opt.value); _fetch(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected ? RpgColors.gold.withOpacity(0.18) : RpgColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(opt.label, style: TextStyle(
                      fontFamily: 'DMSans', fontSize: 12,
                      color: selected ? RpgColors.gold : RpgColors.textSecondary)),
                  ),
                ),
              );
            }).toList()),
          ),
          const SizedBox(height: 16),
          // Result
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: RpgColors.gold)))
          else if (_error != null)
            Center(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson'))))
          else if (_pick != null)
            _PickCard(entry: _pick!),
          const SizedBox(height: 12),
          if (!_loading && _error == null && _pick != null)
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Otra', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: RpgColors.textSecondary,
                  side: const BorderSide(color: RpgColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => widget.onEntryTap(_pick!),
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text('Ver detalle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RpgColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              )),
            ]),
        ]),
      ),
    );
  }
}

class _PickCard extends StatelessWidget {
  final UserEntry entry;
  const _PickCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final m = entry.media;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RpgColors.charcoal,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (m?.coverUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(m!.coverUrl!, width: 60, height: 86, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(width: 60, height: 86, color: RpgColors.surface)),
          ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m?.title ?? '', style: const TextStyle(
            fontSize: 13, color: RpgColors.textPrimary, fontWeight: FontWeight.w600),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          if (m?.year != null) ...[
            const SizedBox(height: 3),
            Text('${m!.year}', style: const TextStyle(
              fontFamily: 'Crimson', fontSize: 11, color: RpgColors.textMuted)),
          ],
          if (m?.genres?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 4, children: m!.genres!.take(3).map((g) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: RpgColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(g, style: const TextStyle(
                fontFamily: 'DMSans', fontSize: 10, color: RpgColors.textMuted)),
            )).toList()),
          ],
          if (m?.synopsis != null) ...[
            const SizedBox(height: 6),
            Text(m!.synopsis!, style: const TextStyle(
              fontFamily: 'Crimson', fontSize: 11, color: RpgColors.textSecondary),
              maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ])),
      ]),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _StatBox(value: '${stats['total'] ?? 0}',     label: 'Total',     color: RpgColors.textPrimary),
      const SizedBox(width: 10),
      _StatBox(value: '${stats['watching'] ?? 0}',  label: 'Viendo',    color: RpgColors.statusWatching),
      const SizedBox(width: 10),
      _StatBox(value: '${stats['completed'] ?? 0}', label: 'Completos', color: RpgColors.statusComplete),
      const SizedBox(width: 10),
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: RpgColors.charcoal,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontFamily: 'DMSans', fontSize: 22, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontFamily: 'DMSans', fontSize: 12, color: RpgColors.textMuted)),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: RpgColors.charcoal,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(s.icon, color: RpgColors.gold.withOpacity(0.7), size: 20),
            const SizedBox(height: 5),
            Text('${s.count}', style: const TextStyle(
              fontFamily: 'DMSans', fontSize: 15, color: RpgColors.textPrimary, fontWeight: FontWeight.bold)),
            Text(s.label, style: const TextStyle(
              fontFamily: 'DMSans', fontSize: 10, color: RpgColors.textMuted)),
          ]),
        ),
      )).toList(),
    );
  }
}
