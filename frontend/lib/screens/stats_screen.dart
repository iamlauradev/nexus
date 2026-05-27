import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../main.dart' show EntryChangeNotifier;
import '../theme/rpg_theme.dart';
import '../services/api_service.dart';
import '../widgets/ornamental_border.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic>? _stats;
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
      final s = await ApiService.getStats();
      if (mounted) setState(() { _stats = s; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    } finally {
      _fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RpgColors.obsidian,
      appBar: AppBar(
        backgroundColor: RpgColors.darkVoid,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: RpgColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('ESTADÍSTICAS', style: TextStyle(
          fontFamily: 'Cinzel', fontSize: 15, color: RpgColors.textPrimary, letterSpacing: 1)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_outlined, color: RpgColors.textMuted),
            onPressed: _load,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: RpgColors.gold,
        backgroundColor: RpgColors.surface,
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: _loading
              ? Center(child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: RpgColors.gold)))
              : _stats == null
                  ? Center(child: Text('Sin datos', style: TextStyle(color: RpgColors.textMuted)))
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final byType   = Map<String, int>.from((_stats!['by_type'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v as int)));
    final byStatus = Map<String, int>.from((_stats!['by_status'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v as int)));
    final byRating = Map<String, int>.from((_stats!['by_rating'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v as int)));
    final total    = (_stats!['total'] ?? 0) as int;

    // New optional fields
    final timeSpent        = (_stats!['time_spent_hours'] as num?)?.toDouble() ?? 0.0;
    final timeSpentMinutes = (_stats!['time_spent_minutes'] as num?)?.toInt() ?? (timeSpent * 60).toInt();

    final scoreDistList = (_stats!['score_distribution'] as List?) ?? [];
    final scoreDist = Map<String, int>.fromEntries(
      scoreDistList.map((item) => MapEntry(
        (item['score'] as num).toInt().toString(),
        (item['count'] as num).toInt())));

    final monthlyList = (_stats!['monthly_added'] as List?) ?? [];
    final monthlyAdded = Map<String, int>.fromEntries(
      monthlyList.map((item) => MapEntry(
        item['month'].toString(),
        (item['count'] as num).toInt())));

    final genresList = (_stats!['top_genres'] as List?) ?? [];
    final topGenres = Map<String, int>.fromEntries(
      genresList.map((item) => MapEntry(
        item['genre'].toString(),
        (item['count'] as num).toInt())));
    final noGenreCount = (_stats!['no_genre_count'] as num?)?.toInt() ?? 0;
    final completedThisYear = (_stats!['completed_this_year'] as num?)?.toInt() ?? 0;

    final topGenresByCat = Map<String, List<Map<String, dynamic>>>.from(
      ((_stats!['top_genres_by_category'] as Map?) ?? {}).map((k, v) =>
        MapEntry(k.toString(), List<Map<String, dynamic>>.from(
          (v as List).map((item) => Map<String, dynamic>.from(item as Map))))));

    final recentActivity = (_stats!['recent_activity'] as List?) ?? [];

    final contentTypeStats = Map<String, Map<String, int>>.from(
      ((_stats!['content_type_stats'] as Map?) ?? {}).map((k, v) =>
        MapEntry(k.toString(), Map<String, int>.from(
          (v as Map).map((sk, sv) => MapEntry(sk.toString(), (sv as num).toInt()))))));

    final avgScoreByType = Map<String, double>.from(
      ((_stats!['avg_score_by_type'] as Map?) ?? {}).map((k, v) =>
        MapEntry(k.toString(), (v as num).toDouble())));

    final topRewatchedList = (_stats!['top_rewatched'] as List?) ?? [];

    final decadeList = (_stats!['decade_distribution'] as List?) ?? [];
    final decadeDistribution = Map<String, int>.fromEntries(
      decadeList.map((item) => MapEntry(
        '${(item['decade'] as num).toInt()}',
        (item['count'] as num).toInt())));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ESTADÍSTICAS', style: TextStyle(
              fontFamily: 'DMSans', fontSize: 20, color: RpgColors.textPrimary,
              fontWeight: FontWeight.w700, letterSpacing: 2)),
            SizedBox(height: 4),
            Text('$total obras en tu colección', style: TextStyle(
              fontFamily: 'Crimson', color: RpgColors.textSecondary, fontSize: 14)),
          ])),
          if (completedThisYear > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: RpgColors.statusComplete.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(children: [
                Text('$completedThisYear', style: TextStyle(
                  fontFamily: 'DMSans', fontSize: 20, color: RpgColors.statusComplete, fontWeight: FontWeight.bold)),
                Text('este año', style: TextStyle(
                  fontFamily: 'DMSans', fontSize: 10, color: RpgColors.textMuted)),
              ]),
            ),
        ]),
        SizedBox(height: 20),

        const GoldDivider(label: 'POR CATEGORÍA'),
        SizedBox(height: 12),
        _SectionGrid(data: byType),

        SizedBox(height: 20),
        const GoldDivider(label: 'POR ESTADO'),
        SizedBox(height: 12),
        _StatusBars(data: byStatus, total: total),

        SizedBox(height: 20),
        const GoldDivider(label: 'VALORACIONES'),
        SizedBox(height: 12),
        _RatingBars(data: byRating, total: total),

        // Tiempo invertido
        if (timeSpentMinutes > 0) ...[
          SizedBox(height: 20),
          const GoldDivider(label: 'TIEMPO INVERTIDO'),
          SizedBox(height: 12),
          _TimeSpentBox(totalMinutes: timeSpentMinutes),
        ],

        // Distribución de puntuaciones
        if (scoreDist.isNotEmpty) ...[
          SizedBox(height: 20),
          const GoldDivider(label: 'DISTRIBUCIÓN DE PUNTUACIONES'),
          SizedBox(height: 12),
          _ScoreDistributionChart(data: scoreDist),
        ],

        // Actividad mensual
        if (monthlyAdded.isNotEmpty) ...[
          SizedBox(height: 20),
          const GoldDivider(label: 'ACTIVIDAD MENSUAL'),
          SizedBox(height: 12),
          _MonthlyChart(data: monthlyAdded),
        ],

        // Estadísticas por tipo de contenido
        if (contentTypeStats.isNotEmpty) ...[
          SizedBox(height: 20),
          const GoldDivider(label: 'POR TIPO DE CONTENIDO'),
          SizedBox(height: 12),
          _ContentTypeBreakdown(data: contentTypeStats),
        ],

        // Top géneros
        if (topGenres.isNotEmpty || noGenreCount > 0) ...[
          SizedBox(height: 20),
          const GoldDivider(label: 'TOP GÉNEROS'),
          SizedBox(height: 12),
          if (topGenres.isNotEmpty) _GenreBars(data: topGenres),
          if (noGenreCount > 0) ...[
            if (topGenres.isNotEmpty) SizedBox(height: 8),
            Row(children: [
              Icon(Icons.info_outline, size: 13, color: RpgColors.textMuted),
              SizedBox(width: 5),
              Text('$noGenreCount obras sin datos de género',
                style: TextStyle(fontFamily: 'Crimson', fontSize: 12, color: RpgColors.textMuted)),
            ]),
          ],
        ],

        // Géneros por categoría
        if (topGenresByCat.isNotEmpty) ...[
          SizedBox(height: 20),
          const GoldDivider(label: 'GÉNEROS POR CATEGORÍA'),
          SizedBox(height: 12),
          _GenresByCategory(data: topGenresByCat),
        ],

        // Actividad reciente
        if (recentActivity.isNotEmpty) ...[
          SizedBox(height: 20),
          const GoldDivider(label: 'ACTIVIDAD RECIENTE'),
          SizedBox(height: 12),
          _RecentActivity(list: recentActivity),
        ],

        // Puntuación media por tipo
        if (avgScoreByType.isNotEmpty) ...[
          SizedBox(height: 20),
          const GoldDivider(label: 'PUNTUACIÓN MEDIA POR TIPO'),
          SizedBox(height: 12),
          _AvgScoreByType(data: avgScoreByType),
        ],

        // Más revisionados
        if (topRewatchedList.isNotEmpty) ...[
          SizedBox(height: 20),
          const GoldDivider(label: 'MÁS REVISIONADOS'),
          SizedBox(height: 12),
          _TopRewatched(list: topRewatchedList),
        ],

        // Distribución por década
        if (decadeDistribution.isNotEmpty) ...[
          SizedBox(height: 20),
          const GoldDivider(label: 'POR DÉCADA'),
          SizedBox(height: 12),
          _DecadeChart(data: decadeDistribution),
        ],

        SizedBox(height: 40),
      ],
    );
  }
}

// ---- Existing widgets ----

class _SectionGrid extends StatelessWidget {
  final Map<String, int> data;
  const _SectionGrid({required this.data});

  int _sum(List<String> keys) =>
      keys.fold(0, (acc, k) => acc + (data[k] ?? 0));

  @override
  Widget build(BuildContext context) {
    final sections = [
      (label: 'Películas', icon: Icons.movie,        count: _sum(['MOVIE'])),
      (label: 'Doramas',   icon: Icons.live_tv,      count: _sum(['DORAMA'])),
      (label: 'Series',    icon: Icons.tv,            count: _sum(['SERIES'])),
      (label: 'Cómics',    icon: Icons.auto_stories, count: _sum(['MANGA', 'MANHWA', 'MANHUA', 'WEBTOON', 'NOVEL'])),
      (label: 'Anime',     icon: Icons.animation,     count: _sum(['ANIME'])),
    ];

    // Detailed type breakdown for comics
    final comicBreakdown = [
      ('MANGA', 'Manga'), ('MANHWA', 'Manhwa'), ('MANHUA', 'Manhua'), ('WEBTOON', 'Webtoon'), ('NOVEL', 'Novela'),
    ].where((t) => (data[t.$1] ?? 0) > 0).toList();

    return Column(
      children: [
        Row(
          children: sections.map((s) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: RpgColors.charcoal,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(s.icon, color: RpgColors.gold.withOpacity(0.8), size: 20),
                SizedBox(height: 4),
                Text('${s.count}', style: TextStyle(
                  fontFamily: 'DMSans', fontSize: 16, color: RpgColors.textPrimary, fontWeight: FontWeight.bold)),
                Text(s.label, style: TextStyle(
                  fontFamily: 'DMSans', fontSize: 9, color: RpgColors.textMuted)),
              ]),
            ),
          )).toList(),
        ),
        if (comicBreakdown.isNotEmpty) ...[
          SizedBox(height: 8),
          Row(
            children: comicBreakdown.map((t) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: RpgColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(children: [
                  Text('${data[t.$1] ?? 0}', style: TextStyle(
                    fontSize: 13, color: RpgColors.gold, fontWeight: FontWeight.bold)),
                  Text(t.$2, style: TextStyle(
                    fontFamily: 'DMSans', fontSize: 9, color: RpgColors.textMuted)),
                ]),
              ),
            )).toList(),
          ),
        ],
      ],
    );
  }
}

class _StatusBars extends StatelessWidget {
  final Map<String, int> data;
  final int total;
  const _StatusBars({required this.data, required this.total});

  @override
  Widget build(BuildContext context) {
    final order = ['watching', 'completed', 'plan_to_watch', 'on_hold', 'dropped'];
    return Column(
      children: order.map((status) {
        final count = data[status] ?? 0;
        final pct   = total > 0 ? count / total : 0.0;
        final color = statusColor(status);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            SizedBox(
              width: 82,
              child: Text(statusLabel(status), style: TextStyle(
                color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 13)),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(children: [
                  Container(height: 20, color: RpgColors.charcoal),
                  FractionallySizedBox(
                    widthFactor: pct.clamp(0, 1).toDouble(),
                    child: Container(height: 20, color: color.withOpacity(0.75)),
                  ),
                ]),
              ),
            ),
            SizedBox(width: 8),
            SizedBox(
              width: 34,
              child: Text('$count', textAlign: TextAlign.right, style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

class _RatingBars extends StatelessWidget {
  final Map<String, int> data;
  final int total;
  const _RatingBars({required this.data, required this.total});

  @override
  Widget build(BuildContext context) {
    // Use dynamic rating config order
    final configs = RatingConfigCache.configs;
    final filtered = configs.where((r) => (data[r['key']] ?? 0) > 0).toList();

    if (filtered.isEmpty) {
      return Text('Sin valoraciones aún',
        style: TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson'));
    }

    return Column(
      children: filtered.map((r) {
        final key   = r['key'] as String;
        final label = r['label'] as String;
        final count = data[key] ?? 0;
        final pct   = total > 0 ? count / total : 0.0;
        final color = RatingConfigCache.colorFor(key);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            SizedBox(
              width: 110,
              child: Text(label, style: TextStyle(
                color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(children: [
                  Container(height: 18, color: RpgColors.charcoal),
                  FractionallySizedBox(
                    widthFactor: pct.clamp(0, 1).toDouble(),
                    child: Container(height: 18, color: color.withOpacity(0.8)),
                  ),
                ]),
              ),
            ),
            SizedBox(width: 8),
            SizedBox(
              width: 28,
              child: Text('$count', textAlign: TextAlign.right, style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

// ---- New chart widgets ----

class _TimeSpentBox extends StatelessWidget {
  final int totalMinutes;
  const _TimeSpentBox({required this.totalMinutes});

  String _format() {
    if (totalMinutes < 60) {
      return '$totalMinutes min';
    }
    final hours = totalMinutes ~/ 60;
    final mins  = totalMinutes % 60;
    if (hours < 24) {
      return mins > 0 ? '${hours}h ${mins}min' : '${hours}h';
    }
    final days    = hours ~/ 24;
    final remHours = hours % 24;
    if (remHours > 0) return '$days días ${remHours}h';
    return '$days días';
  }

  String _subtitle() {
    if (totalMinutes < 60) return 'minutos';
    if (totalMinutes < 1440) return 'horas vistas';
    return 'tiempo invertido';
  }

  @override
  Widget build(BuildContext context) {
    final hours = totalMinutes / 60.0;
    final days  = hours / 24.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RpgColors.charcoal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Column(children: [
          Icon(Icons.schedule_outlined, color: RpgColors.gold, size: 28),
          SizedBox(height: 6),
          Text('~${_format()}', style: TextStyle(
            fontFamily: 'DMSans', fontSize: 18, color: RpgColors.textPrimary, fontWeight: FontWeight.bold)),
          Text(_subtitle(), style: TextStyle(
            fontFamily: 'Crimson', fontSize: 12, color: RpgColors.textMuted)),
        ]),
        if (hours >= 24) ...[
          Container(width: 1, height: 50, color: RpgColors.border),
          Column(children: [
            Icon(Icons.calendar_today_outlined, color: RpgColors.amethystLight, size: 28),
            SizedBox(height: 6),
            Text('~${days.toStringAsFixed(1)} días', style: TextStyle(
              fontFamily: 'DMSans', fontSize: 18, color: RpgColors.textPrimary, fontWeight: FontWeight.bold)),
            Text('equivalente', style: TextStyle(
              fontFamily: 'Crimson', fontSize: 12, color: RpgColors.textMuted)),
          ]),
        ],
      ]),
    );
  }
}

class _ScoreDistributionChart extends StatelessWidget {
  final Map<String, int> data;
  const _ScoreDistributionChart({required this.data});

  Color _scoreColor(int score) {
    if (score <= 3) return const Color(0xFFF85149);
    if (score <= 5) return const Color(0xFFD29922);
    if (score <= 7) return const Color(0xFF58A6FF);
    return const Color(0xFF3FB950);
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);

    final groups = <BarChartGroupData>[];
    for (int s = 1; s <= 10; s++) {
      final count = data['$s'] ?? 0;
      groups.add(BarChartGroupData(
        x: s,
        barRods: [BarChartRodData(
          toY: count.toDouble(),
          color: _scoreColor(s),
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        )],
      ));
    }

    return SizedBox(
      height: 150,
      child: BarChart(BarChartData(
        barGroups: groups,
        maxY: maxVal.toDouble() * 1.2,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            drawBelowEverything: false,
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${val.toInt()}',
                  style: TextStyle(color: RpgColors.textMuted, fontSize: 10, fontFamily: 'Crimson'),
                ),
              ),
              reservedSize: 20,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barTouchData: BarTouchData(enabled: false),
      )),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  final Map<String, int> data;
  const _MonthlyChart({required this.data});

  static const _monthNames = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
                               'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

  @override
  Widget build(BuildContext context) {
    // Sort by date key (YYYY-MM) and take last 6 months with data (or all if less)
    final sorted = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final display = sorted.length > 6 ? sorted.sublist(sorted.length - 6) : sorted;

    if (display.isEmpty) return const SizedBox.shrink();

    final maxVal = display.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    final groups = display.asMap().entries.map((e) {
      final idx = e.key;
      final entry = e.value;
      return BarChartGroupData(
        x: idx,
        barRods: [BarChartRodData(
          toY: entry.value.toDouble(),
          color: RpgColors.gold,
          width: 20,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        )],
      );
    }).toList();

    return SizedBox(
      height: 150,
      child: BarChart(BarChartData(
        barGroups: groups,
        maxY: maxVal.toDouble() * 1.2,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            drawBelowEverything: false,
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= display.length) return const SizedBox.shrink();
                final key = display[idx].key; // "YYYY-MM"
                final parts = key.split('-');
                if (parts.length >= 2) {
                  final month = int.tryParse(parts[1]) ?? 1;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _monthNames[(month - 1).clamp(0, 11)],
                      style: TextStyle(color: RpgColors.textMuted, fontSize: 10, fontFamily: 'Crimson'),
                    ),
                  );
                }
                return Text(key, style: TextStyle(color: RpgColors.textMuted, fontSize: 9));
              },
              reservedSize: 20,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barTouchData: BarTouchData(enabled: false),
      )),
    );
  }
}

class _ContentTypeBreakdown extends StatelessWidget {
  final Map<String, Map<String, int>> data;
  const _ContentTypeBreakdown({required this.data});

  @override
  Widget build(BuildContext context) {
    final groups = [
      (label: 'Películas', icon: Icons.movie,        types: ['MOVIE']),
      (label: 'Series',    icon: Icons.tv,            types: ['SERIES']),
      (label: 'Doramas',   icon: Icons.live_tv,      types: ['DORAMA']),
      (label: 'Anime',     icon: Icons.animation,     types: ['ANIME']),
      (label: 'Cómics',    icon: Icons.auto_stories, types: ['MANGA', 'MANHWA', 'MANHUA', 'WEBTOON', 'NOVEL']),
    ];

    final widgets = <Widget>[];
    for (final group in groups) {
      final statusMap = <String, int>{};
      for (final type in group.types) {
        (data[type] ?? {}).forEach((status, count) {
          statusMap[status] = (statusMap[status] ?? 0) + count;
        });
      }
      final total = statusMap.values.fold(0, (a, b) => a + b);
      if (total == 0) continue;
      widgets.add(_ContentTypeCard(
        label: group.label, icon: group.icon,
        statusMap: statusMap, total: total,
      ));
    }
    return Column(children: widgets);
  }
}

class _ContentTypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Map<String, int> statusMap;
  final int total;
  const _ContentTypeCard({required this.label, required this.icon, required this.statusMap, required this.total});

  @override
  Widget build(BuildContext context) {
    const order = ['completed', 'watching', 'plan_to_watch', 'on_hold', 'dropped'];
    final active = order.where((s) => (statusMap[s] ?? 0) > 0).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RpgColors.charcoal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: RpgColors.gold.withOpacity(0.8), size: 16),
          SizedBox(width: 8),
          Text(label, style: TextStyle(
            fontSize: 12, color: RpgColors.textPrimary, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('$total', style: TextStyle(
            fontFamily: 'DMSans', fontSize: 14, color: RpgColors.gold, fontWeight: FontWeight.bold)),
          Text('  obras', style: TextStyle(
            fontFamily: 'Crimson', fontSize: 12, color: RpgColors.textMuted)),
        ]),
        if (active.isNotEmpty) ...[
          SizedBox(height: 10),
          ...active.map((status) {
            final count = statusMap[status] ?? 0;
            final pct   = total > 0 ? count / total : 0.0;
            final color = statusColor(status);
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                SizedBox(width: 80, child: Text(statusLabel(status), style: TextStyle(
                  color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 11))),
                SizedBox(width: 6),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Stack(children: [
                      Container(height: 14, color: RpgColors.surface),
                      FractionallySizedBox(
                        widthFactor: pct.clamp(0.0, 1.0),
                        child: Container(height: 14, color: color.withOpacity(0.75)),
                      ),
                    ]),
                  ),
                ),
                SizedBox(width: 6),
                SizedBox(width: 28, child: Text('$count', textAlign: TextAlign.right, style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold))),
              ]),
            );
          }),
        ],
      ]),
    );
  }
}

class _GenreBars extends StatelessWidget {
  final Map<String, int> data;
  const _GenreBars({required this.data});

  @override
  Widget build(BuildContext context) {
    final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(12).toList();
    final maxVal = top.isNotEmpty ? top.first.value : 1;
    final totalWithGenre = top.fold(0, (s, e) => s + e.value);

    return Column(
      children: top.map((e) {
        final pct = maxVal > 0 ? e.value / maxVal : 0.0;
        final pctOfTotal = totalWithGenre > 0 ? (e.value / totalWithGenre * 100).round() : 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(children: [
            SizedBox(
              width: 100,
              child: Text(e.key, style: TextStyle(
                color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(children: [
                  Container(height: 16, color: RpgColors.charcoal),
                  FractionallySizedBox(
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: Container(height: 16, color: RpgColors.amethyst.withOpacity(0.7)),
                  ),
                ]),
              ),
            ),
            SizedBox(width: 8),
            SizedBox(
              width: 42,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('${e.value}', style: TextStyle(
                  color: RpgColors.amethystLight, fontSize: 11, fontWeight: FontWeight.bold)),
                Text(' $pctOfTotal%', style: TextStyle(
                  color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 10)),
              ]),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

class _AvgScoreByType extends StatelessWidget {
  final Map<String, double> data;
  const _AvgScoreByType({required this.data});

  static const _typeLabels = {
    'MOVIE': 'Películas', 'SERIES': 'Series', 'ANIME': 'Anime',
    'DORAMA': 'Doramas', 'MANGA': 'Manga', 'MANHWA': 'Manhwa',
    'MANHUA': 'Manhua', 'WEBTOON': 'Webtoon', 'NOVEL': 'Novela',
  };

  Color _scoreColor(double score) {
    if (score <= 3) return const Color(0xFFF85149);
    if (score <= 5) return const Color(0xFFD29922);
    if (score <= 7) return const Color(0xFF58A6FF);
    return const Color(0xFF3FB950);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: sorted.map((e) {
        final label = _typeLabels[e.key] ?? e.key;
        final pct = e.value / 10.0;
        final color = _scoreColor(e.value);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            SizedBox(width: 80, child: Text(label, style: TextStyle(
              color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
            SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(children: [
                  Container(height: 20, color: RpgColors.charcoal),
                  FractionallySizedBox(
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: Container(height: 20, color: color.withOpacity(0.75)),
                  ),
                ]),
              ),
            ),
            SizedBox(width: 8),
            SizedBox(width: 36, child: Text(e.value.toStringAsFixed(1), textAlign: TextAlign.right,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))),
          ]),
        );
      }).toList(),
    );
  }
}

class _TopRewatched extends StatelessWidget {
  final List<dynamic> list;
  const _TopRewatched({required this.list});

  static const _typeLabels = {
    'MOVIE': 'Película', 'SERIES': 'Serie', 'ANIME': 'Anime',
    'DORAMA': 'Dorama', 'MANGA': 'Manga', 'MANHWA': 'Manhwa',
    'MANHUA': 'Manhua', 'WEBTOON': 'Webtoon', 'NOVEL': 'Novela',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: list.asMap().entries.map((e) {
        final i = e.key;
        final item = e.value as Map;
        final title = item['title']?.toString() ?? '';
        final type  = item['type']?.toString() ?? '';
        final count = (item['count'] as num).toInt();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: RpgColors.charcoal,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: RpgColors.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(child: Text('${i + 1}', style: TextStyle(
                fontSize: 11, color: RpgColors.gold, fontWeight: FontWeight.bold))),
            ),
            SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(
                color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 14),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(_typeLabels[type] ?? type, style: TextStyle(
                color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 11)),
            ])),
            Row(children: [
              Icon(Icons.replay_outlined, size: 14, color: RpgColors.amethystLight),
              SizedBox(width: 4),
              Text('x$count', style: TextStyle(
                fontSize: 13, color: RpgColors.amethystLight, fontWeight: FontWeight.bold)),
            ]),
          ]),
        );
      }).toList(),
    );
  }
}

class _DecadeChart extends StatelessWidget {
  final Map<String, int> data;
  const _DecadeChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final sorted = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxVal = sorted.isNotEmpty ? sorted.map((e) => e.value).reduce((a, b) => a > b ? a : b) : 1;

    return Column(
      children: sorted.map((e) {
        final pct = maxVal > 0 ? e.value / maxVal : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(width: 52, child: Text('${e.key}s', style: TextStyle(
              color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 13))),
            SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(children: [
                  Container(height: 20, color: RpgColors.charcoal),
                  FractionallySizedBox(
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: Container(height: 20, color: RpgColors.gold.withOpacity(0.6)),
                  ),
                ]),
              ),
            ),
            SizedBox(width: 8),
            SizedBox(width: 28, child: Text('${e.value}', textAlign: TextAlign.right,
              style: TextStyle(color: RpgColors.gold, fontFamily: 'DMSans', fontSize: 12, fontWeight: FontWeight.bold))),
          ]),
        );
      }).toList(),
    );
  }
}

class _GenresByCategory extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> data;
  const _GenresByCategory({required this.data});

  static const _catOrder = ['Películas', 'Series', 'Doramas', 'Anime', 'Cómics'];
  static const _catColors = {
    'Películas': Color(0xFF58A6FF),
    'Series':    Color(0xFF3FB950),
    'Doramas':   Color(0xFFFF7B72),
    'Anime':     Color(0xFFD29922),
    'Cómics':    Color(0xFFBB9AF7),
  };

  @override
  Widget build(BuildContext context) {
    final ordered = _catOrder.where(data.containsKey).toList()
      ..addAll(data.keys.where((k) => !_catOrder.contains(k)));

    return Column(
      children: ordered.map((cat) {
        final genres = data[cat]!;
        if (genres.isEmpty) return const SizedBox.shrink();
        final color = _catColors[cat] ?? RpgColors.amethyst;
        final maxVal = genres.isNotEmpty ? (genres.first['count'] as num).toInt() : 1;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: RpgColors.charcoal,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cat, style: TextStyle(
              fontFamily: 'DMSans', fontSize: 11, color: color,
              fontWeight: FontWeight.bold, letterSpacing: 0.3)),
            SizedBox(height: 8),
            ...genres.map((g) {
              final count = (g['count'] as num).toInt();
              final pct = maxVal > 0 ? count / maxVal : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(children: [
                  SizedBox(width: 90, child: Text(g['genre'].toString(),
                    style: TextStyle(color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                  SizedBox(width: 6),
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Stack(children: [
                      Container(height: 12, color: RpgColors.surface),
                      FractionallySizedBox(
                        widthFactor: pct.clamp(0.0, 1.0),
                        child: Container(height: 12, color: color.withOpacity(0.6)),
                      ),
                    ]),
                  )),
                  SizedBox(width: 6),
                  SizedBox(width: 22, child: Text('$count', textAlign: TextAlign.right,
                    style: TextStyle(color: color, fontFamily: 'DMSans', fontSize: 10, fontWeight: FontWeight.bold))),
                ]),
              );
            }),
          ]),
        );
      }).toList(),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  final List<dynamic> list;
  const _RecentActivity({required this.list});

  static const _statusLabels = {
    'plan_to_watch': 'Pendiente', 'watching': 'Viendo',
    'completed': 'Completado', 'on_hold': 'En espera', 'dropped': 'Abandonado',
  };

  Color _statusColor(String status) {
    switch (status) {
      case 'watching':      return RpgColors.statusWatching;
      case 'completed':     return RpgColors.statusComplete;
      case 'plan_to_watch': return RpgColors.statusPlan;
      case 'on_hold':       return RpgColors.statusOnHold;
      case 'dropped':       return RpgColors.statusDropped;
      default:              return RpgColors.textMuted;
    }
  }

  String _timeAgo(String isoDate) {
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return 'Hace ${(diff.inDays / 7).floor()}sem';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: list.map((item) {
        final m = item as Map;
        final title = m['title']?.toString() ?? '';
        final from = m['from']?.toString() ?? '';
        final to = m['to']?.toString() ?? '';
        final when = m['when']?.toString() ?? '';
        final toColor = _statusColor(to);
        return Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: RpgColors.charcoal,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Container(width: 3, height: 36,
              decoration: BoxDecoration(color: toColor, borderRadius: BorderRadius.circular(2))),
            SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(
                color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              SizedBox(height: 2),
              Row(children: [
                Text(_statusLabels[from] ?? from, style: TextStyle(
                  color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 11)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(Icons.arrow_forward, size: 10, color: RpgColors.textMuted)),
                Text(_statusLabels[to] ?? to, style: TextStyle(
                  color: toColor, fontFamily: 'Crimson', fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ])),
            Text(_timeAgo(when), style: TextStyle(
              color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 10)),
          ]),
        );
      }).toList(),
    );
  }
}
