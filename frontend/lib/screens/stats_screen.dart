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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ESTADÍSTICAS', style: TextStyle(
          fontFamily: 'Cinzel', fontSize: 22, color: RpgColors.gold,
          fontWeight: FontWeight.bold, letterSpacing: 3)),
        const SizedBox(height: 4),
        Text('$total obras en tu grimorio', style: const TextStyle(
          fontFamily: 'Crimson', color: RpgColors.textSecondary, fontSize: 14,
          fontStyle: FontStyle.italic)),
        const SizedBox(height: 20),

        const GoldDivider(label: 'POR TIPO'),
        const SizedBox(height: 12),
        _TypeGrid(data: byType),

        const SizedBox(height: 20),
        const GoldDivider(label: 'POR ESTADO'),
        const SizedBox(height: 12),
        _StatusBars(data: byStatus, total: total),

        const SizedBox(height: 20),
        const GoldDivider(label: 'VALORACIONES'),
        const SizedBox(height: 12),
        _RatingDonut(data: byRating, total: total),

        const SizedBox(height: 40),
      ],
    );
  }
}

class _TypeGrid extends StatelessWidget {
  final Map<String, int> data;
  const _TypeGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final types = [
      ('DORAMA', Icons.tv),
      ('MOVIE',  Icons.movie),
      ('SERIES', Icons.theaters),
      ('MANGA',  Icons.auto_stories),
      ('MANHWA', Icons.menu_book),
      ('MANHUA', Icons.book),
      ('ANIME',  Icons.live_tv),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8, mainAxisSpacing: 8,
      childAspectRatio: 0.9,
      children: types.map((t) {
        final count = data[t.$1] ?? 0;
        return Container(
          decoration: BoxDecoration(
            color: RpgColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: RpgColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(t.$2, color: RpgColors.amethystLight, size: 20),
              const SizedBox(height: 4),
              Text('$count', style: const TextStyle(
                fontFamily: 'Cinzel', fontSize: 18, color: RpgColors.gold, fontWeight: FontWeight.bold)),
              Text(typeLabel(t.$1), style: const TextStyle(
                fontFamily: 'Crimson', fontSize: 10, color: RpgColors.textMuted)),
            ],
          ),
        );
      }).toList(),
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
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(statusLabel(status), style: const TextStyle(
                  color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(height: 18, decoration: BoxDecoration(
                      color: RpgColors.charcoal,
                      borderRadius: BorderRadius.circular(3),
                    )),
                    FractionallySizedBox(
                      widthFactor: pct.clamp(0, 1).toDouble(),
                      child: Container(height: 18, decoration: BoxDecoration(
                        color: color.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(3),
                      )),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                child: Text('$count', textAlign: TextAlign.right, style: TextStyle(
                  color: color, fontFamily: 'Cinzel', fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RatingDonut extends StatelessWidget {
  final Map<String, int> data;
  final int total;
  const _RatingDonut({required this.data, required this.total});

  @override
  Widget build(BuildContext context) {
    final order = ['must', 'me_encanta', 'muy_bonita', 'bonita', 'pasable', 'no_me_gusto', 'abandonado', 'sin_valorar'];
    final filtered = order.where((r) => (data[r] ?? 0) > 0).toList();

    if (filtered.isEmpty) {
      return const Text('Sin valoraciones aún', style: TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson'));
    }

    return Column(
      children: filtered.map((r) {
        final count = data[r] ?? 0;
        final pct   = total > 0 ? count / total : 0.0;
        final color = ratingColor(r);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(ratingLabel(r), style: const TextStyle(
                  color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 12)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Stack(
                  children: [
                    Container(height: 16, decoration: BoxDecoration(
                      color: RpgColors.charcoal,
                      borderRadius: BorderRadius.circular(3),
                    )),
                    FractionallySizedBox(
                      widthFactor: pct.clamp(0, 1).toDouble(),
                      child: Container(height: 16, decoration: BoxDecoration(
                        color: color.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(3),
                      )),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Text('$count', textAlign: TextAlign.right, style: TextStyle(
                  color: color, fontFamily: 'Cinzel', fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
