import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ApiService.getStats();
      if (mounted) setState(() { _stats = s; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: RpgColors.gold,
      backgroundColor: RpgColors.surface,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: RpgColors.gold)))
            : _stats == null
                ? const Center(child: Text('Sin datos', style: TextStyle(color: RpgColors.textMuted)))
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final byType   = Map<String, int>.from((_stats!['by_type'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v as int)));
    final byStatus = Map<String, int>.from((_stats!['by_status'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v as int)));
    final byRating = Map<String, int>.from((_stats!['by_rating'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v as int)));
    final total    = (_stats!['total'] ?? 0) as int;

    // New optional fields
    final timeSpent   = (_stats!['time_spent_hours'] as num?)?.toDouble() ?? 0.0;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ESTADÍSTICAS', style: TextStyle(
          fontFamily: 'Cinzel', fontSize: 20, color: RpgColors.textPrimary,
          fontWeight: FontWeight.bold, letterSpacing: 3)),
        const SizedBox(height: 4),
        Text('$total obras en tu colección', style: const TextStyle(
          fontFamily: 'Crimson', color: RpgColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 20),

        const GoldDivider(label: 'POR CATEGORÍA'),
        const SizedBox(height: 12),
        _SectionGrid(data: byType),

        const SizedBox(height: 20),
        const GoldDivider(label: 'POR ESTADO'),
        const SizedBox(height: 12),
        _StatusBars(data: byStatus, total: total),

        const SizedBox(height: 20),
        const GoldDivider(label: 'VALORACIONES'),
        const SizedBox(height: 12),
        _RatingBars(data: byRating, total: total),

        // Tiempo invertido
        if (timeSpent > 0) ...[
          const SizedBox(height: 20),
          const GoldDivider(label: 'TIEMPO INVERTIDO'),
          const SizedBox(height: 12),
          _TimeSpentBox(hours: timeSpent),
        ],

        // Distribución de puntuaciones
        if (scoreDist.isNotEmpty) ...[
          const SizedBox(height: 20),
          const GoldDivider(label: 'DISTRIBUCIÓN DE PUNTUACIONES'),
          const SizedBox(height: 12),
          _ScoreDistributionChart(data: scoreDist),
        ],

        // Actividad mensual
        if (monthlyAdded.isNotEmpty) ...[
          const SizedBox(height: 20),
          const GoldDivider(label: 'ACTIVIDAD MENSUAL'),
          const SizedBox(height: 12),
          _MonthlyChart(data: monthlyAdded),
        ],

        // Top géneros
        if (topGenres.isNotEmpty) ...[
          const SizedBox(height: 20),
          const GoldDivider(label: 'TOP GÉNEROS'),
          const SizedBox(height: 12),
          _GenreBars(data: topGenres),
        ],

        const SizedBox(height: 40),
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
                border: Border.all(color: RpgColors.border),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(s.icon, color: RpgColors.gold.withOpacity(0.8), size: 20),
                const SizedBox(height: 4),
                Text('${s.count}', style: const TextStyle(
                  fontFamily: 'Cinzel', fontSize: 16, color: RpgColors.textPrimary, fontWeight: FontWeight.bold)),
                Text(s.label, style: const TextStyle(
                  fontFamily: 'Crimson', fontSize: 9, color: RpgColors.textMuted)),
              ]),
            ),
          )).toList(),
        ),
        if (comicBreakdown.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: comicBreakdown.map((t) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: RpgColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: RpgColors.border),
                ),
                child: Column(children: [
                  Text('${data[t.$1] ?? 0}', style: const TextStyle(
                    fontFamily: 'Cinzel', fontSize: 13, color: RpgColors.gold, fontWeight: FontWeight.bold)),
                  Text(t.$2, style: const TextStyle(
                    fontFamily: 'Crimson', fontSize: 9, color: RpgColors.textMuted)),
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
              child: Text(statusLabel(status), style: const TextStyle(
                color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 13)),
            ),
            const SizedBox(width: 8),
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
            const SizedBox(width: 8),
            SizedBox(
              width: 34,
              child: Text('$count', textAlign: TextAlign.right, style: TextStyle(
                color: color, fontFamily: 'Cinzel', fontSize: 13, fontWeight: FontWeight.bold)),
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
      return const Text('Sin valoraciones aún',
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
              child: Text(label, style: const TextStyle(
                color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 6),
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
            const SizedBox(width: 8),
            SizedBox(
              width: 28,
              child: Text('$count', textAlign: TextAlign.right, style: TextStyle(
                color: color, fontFamily: 'Cinzel', fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

// ---- New chart widgets ----

class _TimeSpentBox extends StatelessWidget {
  final double hours;
  const _TimeSpentBox({required this.hours});

  @override
  Widget build(BuildContext context) {
    final days = (hours / 24).toStringAsFixed(1);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RpgColors.charcoal,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: RpgColors.border),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Column(children: [
          const Icon(Icons.schedule_outlined, color: RpgColors.gold, size: 28),
          const SizedBox(height: 6),
          Text('~${hours.toStringAsFixed(0)} h', style: const TextStyle(
            fontFamily: 'Cinzel', fontSize: 18, color: RpgColors.textPrimary, fontWeight: FontWeight.bold)),
          const Text('horas vistas', style: TextStyle(
            fontFamily: 'Crimson', fontSize: 12, color: RpgColors.textMuted)),
        ]),
        Container(width: 1, height: 50, color: RpgColors.border),
        Column(children: [
          const Icon(Icons.calendar_today_outlined, color: RpgColors.amethystLight, size: 28),
          const SizedBox(height: 6),
          Text('~$days días', style: const TextStyle(
            fontFamily: 'Cinzel', fontSize: 18, color: RpgColors.textPrimary, fontWeight: FontWeight.bold)),
          const Text('tiempo total', style: TextStyle(
            fontFamily: 'Crimson', fontSize: 12, color: RpgColors.textMuted)),
        ]),
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
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) => Text(
                '${val.toInt()}',
                style: const TextStyle(color: RpgColors.textMuted, fontSize: 10, fontFamily: 'Crimson'),
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
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= display.length) return const SizedBox.shrink();
                final key = display[idx].key; // "YYYY-MM"
                final parts = key.split('-');
                if (parts.length >= 2) {
                  final month = int.tryParse(parts[1]) ?? 1;
                  return Text(
                    _monthNames[(month - 1).clamp(0, 11)],
                    style: const TextStyle(color: RpgColors.textMuted, fontSize: 10, fontFamily: 'Crimson'),
                  );
                }
                return Text(key, style: const TextStyle(color: RpgColors.textMuted, fontSize: 9));
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

class _GenreBars extends StatelessWidget {
  final Map<String, int> data;
  const _GenreBars({required this.data});

  @override
  Widget build(BuildContext context) {
    final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top8 = sorted.take(8).toList();
    final maxVal = top8.isNotEmpty ? top8.first.value : 1;

    return Column(
      children: top8.map((e) {
        final pct = maxVal > 0 ? e.value / maxVal : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(
              width: 100,
              child: Text(e.key, style: const TextStyle(
                color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
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
            const SizedBox(width: 8),
            SizedBox(
              width: 28,
              child: Text('${e.value}', textAlign: TextAlign.right, style: const TextStyle(
                color: RpgColors.amethystLight, fontFamily: 'Cinzel', fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
        );
      }).toList(),
    );
  }
}
