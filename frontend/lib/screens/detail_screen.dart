import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show EntryChangeNotifier;
import '../theme/rpg_theme.dart';
import '../models/user_entry.dart';
import '../services/api_service.dart';
import '../utils/responsive.dart';
import '../widgets/ornamental_border.dart';
import 'dart:io';
import 'dart:typed_data';

const _statuses = {
  'plan_to_watch': 'Pendiente',
  'watching':      'Viendo',
  'completed':     'Completado',
  'on_hold':       'En espera',
  'dropped':       'Abandonado',
};

const _emissionStatuses = {
  '':          'Desconocido',
  'AIRING':    'En emisión',
  'FINISHED':  'Finalizada',
  'UPCOMING':  'Próximamente',
  'CANCELLED': 'Cancelada',
  'HIATUS':    'En hiato',
};

class DetailScreen extends StatefulWidget {
  final UserEntry entry;
  const DetailScreen({super.key, required this.entry});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen>
    with TickerProviderStateMixin {
  late UserEntry _entry;
  late TabController _tabController;
  bool _editing = false;
  bool _saving = false;
  bool _synopsisExpanded = false;
  bool _notesExpanded = false;
  List<String> _platforms = [];
  final _platformFocus = FocusNode();

  late String _status;
  late String _ratingLabel;
  late String _emissionStatus;
  int? _emissionDay;
  DateTime? _startedAt;
  DateTime? _completedAt;
  String? _coverUrl;
  int _epCurrent = 0;
  int? _epTotal;
  int _rewatchCount = 0;

  final _progressCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  final _platformCtrl = TextEditingController();
  final _coverUrlCtrl = TextEditingController();

  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _tabController = TabController(length: 3, vsync: this);
    _initFields();
    _platformFocus.addListener(() => setState(() {}));
    ApiService.getPlatforms().then((p) { if (mounted) setState(() => _platforms = p); });
  }

  void _initFields() {
    _status          = _entry.status;
    // Guard against a rating key that no longer exists in configs
    final rl = _entry.ratingLabel ?? 'sin_valorar';
    _ratingLabel = RatingConfigCache.configs.any((c) => c['key'] == rl) ? rl : 'sin_valorar';
    _emissionStatus  = _entry.media?.emissionStatus ?? '';
    _emissionDay     = _entry.emissionDay;
    _startedAt       = _entry.startedAt;
    _completedAt     = _entry.completedAt;
    _coverUrl        = _entry.media?.coverUrl;
    _progressCtrl.text = _entry.progress ?? '';
    _notesCtrl.text    = _entry.notes ?? '';
    _platformCtrl.text = _entry.platform ?? '';
    _coverUrlCtrl.text = _entry.media?.coverUrl ?? '';
    _epCurrent         = _entry.epCurrent ?? 0;
    _epTotal           = _entry.epTotal;
    _rewatchCount      = _entry.rewatchCount;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _progressCtrl.dispose();
    _notesCtrl.dispose();
    _platformCtrl.dispose();
    _platformFocus.dispose();
    _coverUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Update cover if changed
      final newCoverUrl = _coverUrlCtrl.text.trim().isEmpty ? null : _coverUrlCtrl.text.trim();
      if (newCoverUrl != _coverUrl && _entry.media != null) {
        if (newCoverUrl != null) {
          await ApiService.updateCover(_entry.media!.id, newCoverUrl);
        }
      }

      // Update emission status if changed
      final prevEmission = _entry.media?.emissionStatus ?? '';
      if (_emissionStatus != prevEmission && _entry.media != null) {
        await ApiService.updateEmissionStatus(_entry.media!.id, _emissionStatus.isEmpty ? null : _emissionStatus);
      }

      final updated = await ApiService.updateEntry(_entry.id, {
        'status':        _status,
        'rating_label':  _ratingLabel,
        'progress':      _progressCtrl.text.isEmpty ? null : _progressCtrl.text,
        'notes':         _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        'platform':      _platformCtrl.text.isEmpty ? null : _platformCtrl.text,
        'score':         _entry.score,
        'started_at':    _startedAt?.toIso8601String().split('T').first,
        'completed_at':  _completedAt?.toIso8601String().split('T').first,
        'ep_current':    _entry.media?.type != 'MOVIE' ? _epCurrent : null,
        'ep_total':      _entry.media?.type != 'MOVIE' ? _epTotal : null,
        'rewatch_count': _rewatchCount,
        'emission_day':  _emissionDay,
      });
      if (!mounted) return;
      setState(() {
        _entry = UserEntry(
          id: updated.id, userId: updated.userId, mediaId: updated.mediaId,
          status: updated.status, progress: updated.progress, score: updated.score,
          ratingLabel: updated.ratingLabel, notes: updated.notes, platform: updated.platform,
          startedAt: updated.startedAt, completedAt: updated.completedAt,
          epCurrent: updated.epCurrent, epTotal: updated.epTotal,
          rewatchCount: updated.rewatchCount, emissionDay: updated.emissionDay,
          updatedAt: updated.updatedAt,
          // prefer fresh media from server (picks up cover/emission changes)
          media: updated.media ?? _entry.media,
        );
        _editing = false;
        _saving = false;
      });
      _initFields();
      context.read<EntryChangeNotifier>().entryAdded();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: RpgColors.statusDropped));
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: RpgColors.surface,
        title: Text('Eliminar', style: TextStyle(color: RpgColors.textPrimary, fontFamily: 'DMSans', fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text(
          '¿Quitar "${_entry.media?.title}" de tu lista?',
          style: TextStyle(color: RpgColors.textSecondary, fontFamily: 'Crimson'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancelar', style: TextStyle(color: RpgColors.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: RpgColors.statusDropped),
            child: Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiService.deleteEntry(_entry.id);
        if (mounted) context.read<EntryChangeNotifier>().entryAdded();
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: RpgColors.statusDropped));
      }
    }
  }

  Future<void> _share() async {
    try {
      final Uint8List? imageBytes = await _screenshotController.capture(pixelRatio: 2.0);
      if (imageBytes == null) return;
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/nexus_share.png');
      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${_entry.media?.title ?? ''} — Nexus Media Tracker',
      );
    } catch (e) {
      // Fallback: share as text
      final title = _entry.media?.title ?? '';
      final status = statusLabel(_entry.status);
      final rating = RatingConfigCache.labelFor(_entry.ratingLabel);
      await Share.share('$title\n$status · $rating\n— Nexus Media Tracker');
    }
  }

  Future<void> _quickUpdateEpisode(int newCurrent) async {
    try {
      final updated = await ApiService.updateEntry(_entry.id, {
        'ep_current': newCurrent,
      });
      setState(() {
        _entry = UserEntry(
          id: updated.id, userId: updated.userId, mediaId: updated.mediaId,
          status: updated.status, progress: updated.progress, score: updated.score,
          ratingLabel: updated.ratingLabel, notes: updated.notes, platform: updated.platform,
          startedAt: updated.startedAt, completedAt: updated.completedAt,
          epCurrent: updated.epCurrent, epTotal: updated.epTotal,
          rewatchCount: updated.rewatchCount, emissionDay: updated.emissionDay,
          updatedAt: updated.updatedAt, media: _entry.media,
        );
        _epCurrent = updated.epCurrent ?? 0;
      });
      if (mounted && updated.epTotal != null && updated.epCurrent == updated.epTotal && updated.status != 'completed') {
        _suggestComplete();
      }
    } catch (_) {}
  }

  Future<void> _suggestComplete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RpgColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('¿Has terminado?', style: TextStyle(
          fontFamily: 'Cinzel', fontSize: 16, color: RpgColors.textPrimary)),
        content: Text('Llegaste al último episodio. ¿Marcar como completado?',
          style: TextStyle(color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No', style: TextStyle(color: RpgColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sí, completar', style: TextStyle(fontFamily: 'DMSans')),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final today = DateTime.now().toIso8601String().split('T').first;
    try {
      final updated = await ApiService.updateEntry(_entry.id, {
        'status': 'completed',
        'completed_at': today,
      });
      setState(() {
        _entry = UserEntry(
          id: updated.id, userId: updated.userId, mediaId: updated.mediaId,
          status: updated.status, progress: updated.progress, score: updated.score,
          ratingLabel: updated.ratingLabel, notes: updated.notes, platform: updated.platform,
          startedAt: updated.startedAt, completedAt: updated.completedAt,
          epCurrent: updated.epCurrent, epTotal: updated.epTotal,
          rewatchCount: updated.rewatchCount, emissionDay: updated.emissionDay,
          updatedAt: updated.updatedAt, media: _entry.media,
        );
        _status = updated.status;
        _completedAt = updated.completedAt;
      });
    } catch (_) {}
  }

  Future<void> _quickUpdateRewatch(int newCount) async {
    try {
      final updated = await ApiService.updateEntry(_entry.id, {
        'rewatch_count': newCount,
      });
      setState(() {
        _entry = UserEntry(
          id: updated.id, userId: updated.userId, mediaId: updated.mediaId,
          status: updated.status, progress: updated.progress, score: updated.score,
          ratingLabel: updated.ratingLabel, notes: updated.notes, platform: updated.platform,
          startedAt: updated.startedAt, completedAt: updated.completedAt,
          epCurrent: updated.epCurrent, epTotal: updated.epTotal,
          rewatchCount: updated.rewatchCount, emissionDay: updated.emissionDay,
          updatedAt: updated.updatedAt, media: _entry.media,
        );
        _rewatchCount = updated.rewatchCount;
      });
    } catch (_) {}
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _startedAt : _completedAt) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: RpgColors.gold,
            onPrimary: RpgColors.obsidian,
            surface: RpgColors.surface,
            onSurface: RpgColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startedAt = picked;
        else _completedAt = picked;
      });
    }
  }

  Widget _buildSaveFab() {
    return FloatingActionButton.extended(
      onPressed: _saving ? null : _save,
      backgroundColor: RpgColors.gold,
      label: _saving
          ? SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text('Guardar', style: TextStyle(
              fontFamily: 'DMSans', color: RpgColors.obsidian, fontWeight: FontWeight.w700)),
      icon: Icon(Icons.save_outlined, color: RpgColors.obsidian),
    );
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String? _tmdbUrl() {
    final id = _entry.media?.tmdbId;
    if (id == null) return null;
    final type = _entry.media?.type ?? '';
    return type == 'MOVIE'
        ? 'https://www.themoviedb.org/movie/$id'
        : 'https://www.themoviedb.org/tv/$id';
  }

  String? _anilistUrl() {
    final id = _entry.media?.anilistId;
    if (id == null) return null;
    final type = _entry.media?.type ?? '';
    final section = (type == 'ANIME') ? 'anime' : 'manga';
    return 'https://anilist.co/$section/$id';
  }

  List<Widget> _buildDetailActions() {
    if (_editing) {
      return [
        IconButton(
          icon: Icon(Icons.close, color: RpgColors.textMuted),
          onPressed: () { setState(() { _editing = false; _initFields(); }); },
        ),
      ];
    }
    final tmdb = _tmdbUrl();
    final anilist = _anilistUrl();
    return [
      if (tmdb != null)
        IconButton(
          icon: Icon(Icons.movie_outlined, color: RpgColors.textSecondary),
          onPressed: () => _openExternal(tmdb),
          tooltip: 'Ver en TMDB',
        ),
      if (anilist != null)
        IconButton(
          icon: Icon(Icons.open_in_new_rounded, color: RpgColors.textSecondary),
          onPressed: () => _openExternal(anilist),
          tooltip: 'Ver en AniList',
        ),
      IconButton(
        icon: Icon(Icons.share_outlined, color: RpgColors.gold),
        onPressed: _share,
        tooltip: 'Compartir',
      ),
      IconButton(
        icon: Icon(Icons.edit_outlined, color: RpgColors.gold),
        onPressed: () => setState(() => _editing = true),
      ),
      IconButton(
        icon: Icon(Icons.delete_outline, color: RpgColors.statusDropped),
        onPressed: _delete,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final media = _entry.media;
    final isDesktop = context.isDesktop;

    if (isDesktop) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: RpgColors.darkVoid,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: RpgColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            media?.title ?? '',
            style: TextStyle(fontFamily: 'Cinzel', fontSize: 15, color: RpgColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
          actions: _buildDetailActions(),
        ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left panel: cover + tracking
            Container(
              width: 340,
              color: RpgColors.charcoal,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDesktopCoverPanel(media),
                    SizedBox(height: 20),
                    if (_editing) _buildEditForm() else _buildTrackingSection(),
                  ],
                ),
              ),
            ),
            VerticalDivider(thickness: 1, width: 1, color: RpgColors.border),
            // Right panel: media info + history
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildInfoSection(media),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile layout — TabBar splits content into digestible sections
    return Scaffold(
      body: _editing
          ? CustomScrollView(slivers: [
              _buildSliverHeader(media),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildEditForm(),
                ),
              ),
            ])
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                _buildSliverHeader(media),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: RpgColors.accent,
                      unselectedLabelColor: RpgColors.textMuted,
                      indicatorColor: RpgColors.accent,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelStyle: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                      tabs: const [
                        Tab(text: 'PROGRESO'),
                        Tab(text: 'INFO'),
                        Tab(text: 'HISTORIAL'),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: Tracking / progress
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildTrackingSection(),
                  ),
                  // Tab 1: Media info
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildInfoSection(media),
                  ),
                  // Tab 2: History
                  _buildHistoryTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildDesktopCoverPanel(dynamic media) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: media?.coverUrl != null
              ? CachedNetworkImage(
                  imageUrl: media!.coverUrl!,
                  width: double.infinity,
                  height: 440,
                  fit: BoxFit.cover,
                )
              : Container(
                  height: 440,
                  color: RpgColors.surface,
                  child: Center(
                    child: Icon(Icons.image_outlined, color: RpgColors.border, size: 72)),
                ),
        ),
        SizedBox(height: 16),
        if (media?.titleOriginal != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(media!.titleOriginal!,
              style: TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 13)),
          ),
        Text(media?.title ?? '',
          style: TextStyle(
            color: RpgColors.textPrimary, fontFamily: 'Cinzel', fontSize: 17,
            fontWeight: FontWeight.bold, height: 1.25)),
        SizedBox(height: 8),
        Row(children: [
          _TypePill(media?.type),
          SizedBox(width: 8),
          if (media?.year != null)
            Text('${media!.year}', style: TextStyle(
              color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 14)),
        ]),
        SizedBox(height: 6),
        Row(children: [
          EmissionBadge(status: media?.emissionStatus),
          if (media?.externalScore != null) ...[
            SizedBox(width: 8),
            Icon(Icons.star_rounded, color: RpgColors.statusPlan, size: 14),
            Text(' ${media!.externalScore!.toStringAsFixed(1)}',
              style: TextStyle(color: RpgColors.statusPlan, fontFamily: 'Crimson', fontSize: 13)),
          ],
        ]),
      ],
    );
  }

  Widget _buildSliverHeader(dynamic media) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: RpgColors.darkVoid,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: RpgColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (!_editing) ...[
          IconButton(
            icon: Icon(Icons.share_outlined, color: RpgColors.gold),
            onPressed: _share,
            tooltip: 'Compartir',
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: RpgColors.gold),
            onPressed: () => setState(() => _editing = true),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: RpgColors.statusDropped),
            onPressed: _delete,
          ),
        ] else
          IconButton(
            icon: Icon(Icons.close, color: RpgColors.textMuted),
            onPressed: () { setState(() { _editing = false; _initFields(); }); },
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Screenshot(
          controller: _screenshotController,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background blurred cover
              if (media?.coverUrl != null)
                CachedNetworkImage(
                  imageUrl: media!.coverUrl!,
                  fit: BoxFit.cover,
                  color: Colors.black.withOpacity(0.55),
                  colorBlendMode: BlendMode.darken,
                )
              else
                Container(color: RpgColors.charcoal),
              // Bottom gradient
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, RpgColors.obsidian],
                    ),
                  ),
                ),
              ),
              // Cover + info
              Positioned(
                bottom: 16, left: 16, right: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Cover thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: media?.coverUrl != null
                          ? CachedNetworkImage(
                              imageUrl: media!.coverUrl!,
                              width: 100, height: 145, fit: BoxFit.cover,
                            )
                          : Container(
                              width: 100, height: 145,
                              color: RpgColors.charcoal,
                              child: Icon(Icons.image_outlined, color: RpgColors.border, size: 36),
                            ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (media?.titleOriginal != null)
                            Text(media!.titleOriginal!, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 12)),
                          Text(media?.title ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: RpgColors.textPrimary, fontFamily: 'Cinzel', fontSize: 17,
                              fontWeight: FontWeight.bold, height: 1.2,
                              shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                            )),
                          SizedBox(height: 6),
                          Row(children: [
                            _TypePill(media?.type),
                            SizedBox(width: 6),
                            if (media?.year != null)
                              Text('${media!.year}', style: TextStyle(
                                color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 13)),
                          ]),
                          SizedBox(height: 6),
                          Row(children: [
                            EmissionBadge(status: media?.emissionStatus),
                            if (media?.externalScore != null) ...[
                              SizedBox(width: 8),
                              Icon(Icons.star_rounded, color: RpgColors.statusPlan, size: 14),
                              Text(' ${media!.externalScore!.toStringAsFixed(1)}',
                                style: TextStyle(color: RpgColors.statusPlan, fontFamily: 'Crimson', fontSize: 13)),
                            ],
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingSection() {
    final ratingColor = RatingConfigCache.colorFor(_ratingLabel);
    final ratingText  = RatingConfigCache.labelFor(_ratingLabel);
    final df = DateFormat('dd/MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('Mi seguimiento'),
        SizedBox(height: 10),
        Row(children: [
          Expanded(child: _InfoTile(
            icon: Icons.circle_outlined,
            label: 'Mi estado',
            value: statusLabel(_status),
            valueColor: statusColor(_status),
          )),
          SizedBox(width: 10),
          Expanded(child: _InfoTile(
            icon: Icons.bookmark_outlined,
            label: 'Progreso',
            value: _entry.progress ?? '—',
            valueColor: RpgColors.gold,
          )),
        ]),
        SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ratingColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ratingColor.withOpacity(0.4)),
          ),
          child: Row(children: [
            Icon(Icons.star_outline, size: 14, color: RpgColors.textMuted),
            SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('VALORACIÓN', style: TextStyle(
                fontSize: 9, color: RpgColors.textMuted, letterSpacing: 0.8, fontWeight: FontWeight.w500)),
              SizedBox(height: 2),
              Text(ratingText, style: TextStyle(
                color: ratingColor, fontFamily: 'Crimson', fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
        if (_entry.startedAt != null || _entry.completedAt != null) ...[
          SizedBox(height: 10),
          Row(children: [
            if (_entry.startedAt != null)
              Expanded(child: _InfoTile(
                icon: Icons.play_circle_outline,
                label: 'Fecha inicio',
                value: _formatDateDt(_entry.startedAt, df),
                valueColor: RpgColors.statusWatching,
              )),
            if (_entry.startedAt != null && _entry.completedAt != null)
              SizedBox(width: 10),
            if (_entry.completedAt != null)
              Expanded(child: _InfoTile(
                icon: Icons.check_circle_outline,
                label: 'Fecha fin',
                value: _formatDateDt(_entry.completedAt, df),
                valueColor: RpgColors.statusComplete,
              )),
          ]),
        ],
        if (_entry.media?.type != 'MOVIE' && (_entry.epCurrent != null || _entry.epTotal != null)) ...[
          SizedBox(height: 10),
          _EpisodeProgressBar(
            epCurrent: _entry.epCurrent,
            epTotal: _entry.epTotal,
            onIncrement: (_entry.epTotal == null || (_entry.epCurrent ?? 0) < _entry.epTotal!)
                ? () => _quickUpdateEpisode((_entry.epCurrent ?? 0) + 1)
                : null,
            onDecrement: (_entry.epCurrent ?? 0) > 0
                ? () => _quickUpdateEpisode((_entry.epCurrent ?? 0) - 1)
                : null,
          ),
        ],
        SizedBox(height: 10),
        _RewatchTile(
          count: _entry.rewatchCount,
          onIncrement: () => _quickUpdateRewatch(_entry.rewatchCount + 1),
          onDecrement: _entry.rewatchCount > 0 ? () => _quickUpdateRewatch(_entry.rewatchCount - 1) : null,
        ),
        if (_entry.platform != null) ...[
          SizedBox(height: 10),
          _InfoTile(icon: Icons.devices_outlined, label: 'Visto en', value: _entry.platform!),
        ],
        if (_entry.notes != null && _entry.notes!.isNotEmpty) ...[
          SizedBox(height: 12),
          _SectionHeader('Mis notas'),
          SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _notesExpanded = !_notesExpanded),
            child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RpgColors.charcoal,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _entry.notes!,
                  maxLines: _notesExpanded ? null : 5,
                  overflow: _notesExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: TextStyle(
                    color: RpgColors.textSecondary, fontFamily: 'Crimson',
                    fontSize: 14, height: 1.6, fontStyle: FontStyle.italic),
                ),
                if (_entry.notes!.length > 150 || _entry.notes!.contains('\n')) ...[
                  SizedBox(height: 6),
                  Text(
                    _notesExpanded ? 'ver menos ↑' : 'ver más ↓',
                    style: TextStyle(color: RpgColors.gold, fontSize: 12, fontFamily: 'Crimson'),
                  ),
                ],
              ],
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildInfoSection(dynamic media) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (media != null) ...[
          _SectionHeader('Información'),
          SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (media.country != null)   _MetaChip(Icons.flag_outlined, media.country!),
            if (media.duration != null)  _MetaChip(Icons.timer_outlined, media.duration!),
            if (media.network != null)   _MetaChip(Icons.broadcast_on_home_outlined, media.network!),
          ]),
          if (media.genres != null && media.genres!.isNotEmpty) ...[
            SizedBox(height: 10),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: (media.genres as List<String>).map((g) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: RpgColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(g, style: TextStyle(
                  fontSize: 12, color: RpgColors.textSecondary, fontFamily: 'DMSans')),
              )).toList(),
            ),
          ],
          if (media.synopsis != null && media.synopsis!.isNotEmpty) ...[
            SizedBox(height: 16),
            _SectionHeader('Sinopsis'),
            SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _synopsisExpanded = !_synopsisExpanded),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.synopsis!,
                    maxLines: _synopsisExpanded ? null : 6,
                    overflow: _synopsisExpanded ? null : TextOverflow.ellipsis,
                    style: TextStyle(
                      color: RpgColors.textSecondary, fontFamily: 'Crimson',
                      fontSize: 14, height: 1.6),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _synopsisExpanded ? 'Ver menos ↑' : 'Ver más ↓',
                    style: TextStyle(color: RpgColors.gold, fontFamily: 'Crimson', fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
          if (media.castText != null && media.castText!.isNotEmpty) ...[
            SizedBox(height: 16),
            _SectionHeader('Reparto / Staff'),
            SizedBox(height: 8),
            Text(media.castText!, style: TextStyle(
              color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 13, height: 1.5)),
          ],
          SizedBox(height: 16),
        ],
        _HistorySection(entryId: _entry.id),
        SizedBox(height: 80),
      ],
    );
  }

  String _formatDate(String? raw, DateFormat df) {
    if (raw == null) return '—';
    try { return df.format(DateTime.parse(raw)); } catch (_) { return raw; }
  }

  String _formatDateDt(DateTime? dt, DateFormat df) {
    if (dt == null) return '—';
    return df.format(dt);
  }

  Widget _buildEditForm() {
    final ratings = RatingConfigCache.configs;
    final df = DateFormat('dd/MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('Mi estado'),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _status,
          dropdownColor: RpgColors.surface,
          decoration: const InputDecoration(isDense: true),
          style: TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
          items: _statuses.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) { if (v != null) setState(() => _status = v); },
        ),
        SizedBox(height: 14),
        if (_entry.media?.type != 'MOVIE') ...[
          _SectionHeader('Estado de emisión'),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _emissionStatus,
            dropdownColor: RpgColors.surface,
            decoration: const InputDecoration(isDense: true),
            style: TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
            items: _emissionStatuses.entries.map((e) => DropdownMenuItem(
              value: e.key,
              child: Row(children: [
                if (e.key.isNotEmpty) Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: emissionColor(e.key), shape: BoxShape.circle),
                ),
                Text(e.value),
              ]),
            )).toList(),
            onChanged: (v) { if (v != null) setState(() => _emissionStatus = v); },
          ),
          SizedBox(height: 10),
          _SectionHeader('Día de emisión (opcional)'),
          SizedBox(height: 8),
          _EmissionDayPickerDetail(
            value: _emissionDay,
            onChanged: (v) => setState(() => _emissionDay = v),
          ),
          SizedBox(height: 14),
        ],
        _SectionHeader('Valoración'),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _ratingLabel,
          dropdownColor: RpgColors.surface,
          decoration: const InputDecoration(isDense: true),
          style: TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
          items: ratings.map((r) {
            final color = RatingConfigCache.colorFor(r['key']);
            return DropdownMenuItem(
              value: r['key'] as String,
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                SizedBox(width: 8),
                Text(r['label'] as String),
              ]),
            );
          }).toList(),
          onChanged: (v) { if (v != null) setState(() => _ratingLabel = v); },
        ),
        SizedBox(height: 14),
        // Episode stepper (not for movies)
        if (_entry.media?.type != 'MOVIE') ...[
          _EpisodeStepper(
            label: (_entry.media?.type == 'MANGA' || _entry.media?.type == 'MANHWA' ||
                    _entry.media?.type == 'MANHUA' || _entry.media?.type == 'WEBTOON' ||
                    _entry.media?.type == 'NOVEL')
                ? 'CAPÍTULO'
                : 'EPISODIO',
            current: _epCurrent,
            total: _epTotal,
            onChanged: (v) => setState(() => _epCurrent = v),
            onTotalChanged: (v) => setState(() => _epTotal = v),
          ),
          SizedBox(height: 12),
        ],

        // Rewatch counter
        _RewatchStepper(
          count: _rewatchCount,
          label: (_entry.media?.type == 'MANGA' || _entry.media?.type == 'MANHWA' ||
                  _entry.media?.type == 'MANHUA' || _entry.media?.type == 'WEBTOON' ||
                  _entry.media?.type == 'NOVEL')
              ? 'RELECTURAS'
              : 'VUELTO A VER',
          onChanged: (v) => setState(() => _rewatchCount = v),
        ),
        SizedBox(height: 12),

        TextField(
          controller: _progressCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Notas de progreso (T2 E5, Cap 23…)',
            prefixIcon: Icon(Icons.bookmark_outline, color: RpgColors.gold, size: 18),
          ),
          style: TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
        ),
        SizedBox(height: 12),
        TextField(
          controller: _platformCtrl,
          focusNode: _platformFocus,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Plataforma (Netflix, Crunchyroll…)',
            prefixIcon: Icon(Icons.devices_outlined, color: RpgColors.gold, size: 18),
          ),
          style: TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson'),
        ),
        if (_platformFocus.hasFocus && _platforms.isNotEmpty) ...[
          SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _platforms.map((p) => GestureDetector(
                onTap: () {
                  _platformCtrl.text = p;
                  _platformFocus.unfocus();
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: RpgColors.charcoal,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: RpgColors.border),
                  ),
                  child: Center(child: Text(p, style: TextStyle(
                    color: RpgColors.textSecondary, fontSize: 12, fontFamily: 'Crimson'))),
                ),
              )).toList(),
            ),
          ),
        ],
        SizedBox(height: 12),
        // Date pickers
        _SectionHeader('Fechas'),
        SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _DatePickerTile(
              label: 'Fecha de inicio',
              value: _formatDateDt(_startedAt, df),
              onTap: () => _pickDate(isStart: true),
              onClear: _startedAt != null ? () => setState(() => _startedAt = null) : null,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _DatePickerTile(
              label: 'Fecha de fin',
              value: _formatDateDt(_completedAt, df),
              onTap: () => _pickDate(isStart: false),
              onClear: _completedAt != null ? () => setState(() => _completedAt = null) : null,
            ),
          ),
        ]),
        SizedBox(height: 12),
        // Cover URL
        TextField(
          controller: _coverUrlCtrl,
          decoration: const InputDecoration(
            labelText: 'URL de portada',
            prefixIcon: Icon(Icons.image_outlined, color: RpgColors.gold, size: 18),
          ),
          style: TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 13),
        ),
        SizedBox(height: 12),
        TextField(
          controller: _notesCtrl,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Mis notas / reseña',
            alignLabelWithHint: true,
          ),
          style: TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 14, height: 1.5),
        ),
        SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('GUARDAR CAMBIOS', style: TextStyle(
                    fontFamily: 'DMSans', letterSpacing: 1, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ),
        SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return FutureBuilder<List<dynamic>>(
      future: ApiService.getEntryHistory(_entry.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: RpgColors.gold, strokeWidth: 2));
        }
        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Sin cambios registrados',
                style: TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 14)),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: history.length,
          separatorBuilder: (_, __) => Divider(color: RpgColors.border, height: 1),
          itemBuilder: (context, i) {
            final h = history[i];
            final date = DateTime.tryParse(h['changed_at'] ?? '');
            final dateStr = date != null
                ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                : '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Icon(Icons.history_outlined, size: 14, color: RpgColors.textMuted),
                SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      (h['field_name'] ?? '').toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: 9, color: RpgColors.textMuted,
                        letterSpacing: 0.8, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${h['old_value'] ?? '—'}  →  ${h['new_value'] ?? '—'}',
                      style: TextStyle(
                        color: RpgColors.textSecondary,
                        fontFamily: 'Crimson', fontSize: 13),
                    ),
                  ]),
                ),
                Text(dateStr, style: TextStyle(
                  color: RpgColors.textMuted, fontSize: 11, fontFamily: 'Crimson')),
              ]),
            );
          },
        );
      },
    );
  }
}

// ---- Helper widgets ----

class _DatePickerTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DatePickerTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: RpgColors.charcoal,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, size: 14, color: RpgColors.gold),
          SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: TextStyle(
                fontSize: 8, color: RpgColors.textMuted, letterSpacing: 0.6, fontWeight: FontWeight.w500)),
              SizedBox(height: 2),
              Text(value, style: TextStyle(
                color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 13)),
            ]),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 14, color: RpgColors.textMuted),
            ),
        ]),
      ),
    );
  }
}

class _EpisodeProgressBar extends StatelessWidget {
  final int? epCurrent;
  final int? epTotal;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const _EpisodeProgressBar({
    this.epCurrent,
    this.epTotal,
    this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final current = epCurrent ?? 0;
    final total = epTotal ?? 0;
    final pct = (total > 0) ? (current / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: RpgColors.charcoal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('EPISODIOS', style: TextStyle(
            fontSize: 9, color: RpgColors.textMuted, letterSpacing: 0.8, fontWeight: FontWeight.w500)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (onDecrement != null)
              GestureDetector(
                onTap: onDecrement,
                child: Container(
                  width: 24, height: 24,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: RpgColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(Icons.remove, size: 12, color: RpgColors.textMuted),
                ),
              ),
            Text(
              total > 0 ? '$current / $total' : 'Ep. $current',
              style: TextStyle(color: RpgColors.gold, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            if (onIncrement != null)
              GestureDetector(
                onTap: onIncrement,
                child: Container(
                  width: 24, height: 24,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: RpgColors.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: RpgColors.gold),
                  ),
                  child: Icon(Icons.add, size: 12, color: RpgColors.gold),
                ),
              ),
          ]),
        ]),
        if (total > 0) ...[
          SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(children: [
              Container(height: 6, color: RpgColors.surface),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(height: 6, color: RpgColors.gold),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _RewatchTile extends StatelessWidget {
  final int count;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  const _RewatchTile({
    required this.count,
    required this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: RpgColors.charcoal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.replay_outlined, size: 16, color: RpgColors.textMuted),
        SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('VUELTO A VER', style: TextStyle(
              fontSize: 9, color: RpgColors.textMuted, letterSpacing: 0.8, fontWeight: FontWeight.w500)),
            Text(
              count == 0 ? 'Sin revisiones' : 'x$count ${count == 1 ? "vez" : "veces"}',
              style: TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 13),
            ),
          ]),
        ),
        if (onDecrement != null)
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: RpgColors.surfaceHigh,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.remove, size: 14, color: RpgColors.textMuted),
            ),
          ),
        SizedBox(width: 6),
        GestureDetector(
          onTap: onIncrement,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: RpgColors.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: RpgColors.gold),
            ),
            child: Icon(Icons.add, size: 14, color: RpgColors.gold),
          ),
        ),
      ]),
    );
  }
}

class _EpisodeStepper extends StatelessWidget {
  final String label;
  final int current;
  final int? total;
  final ValueChanged<int> onChanged;
  final ValueChanged<int?> onTotalChanged;

  const _EpisodeStepper({
    required this.label,
    required this.current,
    required this.total,
    required this.onChanged,
    required this.onTotalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (total != null && total! > 0) ? (current / total!).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RpgColors.charcoal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(
            fontSize: 9, color: RpgColors.textMuted, letterSpacing: 0.8, fontWeight: FontWeight.w500)),
          Row(children: [
            GestureDetector(
              onTap: current > 0 ? () => onChanged(current - 1) : null,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: current > 0 ? RpgColors.surfaceHigh : RpgColors.obsidian,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.remove, size: 14,
                  color: current > 0 ? RpgColors.textPrimary : RpgColors.textMuted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                total != null ? '$current / $total' : '$current',
                style: TextStyle(
                  color: RpgColors.gold, fontFamily: 'DMSans', fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            GestureDetector(
              onTap: (total == null || current < total!) ? () => onChanged(current + 1) : null,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: (total == null || current < total!) ? RpgColors.gold.withOpacity(0.15) : RpgColors.obsidian,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (total == null || current < total!) ? RpgColors.gold : RpgColors.border),
                ),
                child: Icon(Icons.add, size: 14,
                  color: (total == null || current < total!) ? RpgColors.gold : RpgColors.textMuted),
              ),
            ),
          ]),
        ]),
        if (total != null && total! > 0) ...[
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(children: [
              Container(height: 5, color: RpgColors.surface),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(height: 5, color: RpgColors.gold),
              ),
            ]),
          ),
        ] else ...[
          SizedBox(height: 8),
          Row(children: [
            Text('Total: ', style: TextStyle(
              color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 12)),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Desconocido',
                  isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                style: TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 13),
                onChanged: (v) => onTotalChanged(int.tryParse(v)),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _RewatchStepper extends StatelessWidget {
  final int count;
  final String label;
  final ValueChanged<int> onChanged;

  const _RewatchStepper({
    required this.count,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: RpgColors.charcoal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.replay_outlined, size: 16, color: RpgColors.textMuted),
        SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(
              fontSize: 9, color: RpgColors.textMuted, letterSpacing: 0.8, fontWeight: FontWeight.w500)),
            Text(
              count == 0 ? 'Sin revisiones' : 'x$count ${count == 1 ? "vez" : "veces"}',
              style: TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 13),
            ),
          ]),
        ),
        if (count > 0)
          GestureDetector(
            onTap: () => onChanged(count - 1),
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: RpgColors.surfaceHigh,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.remove, size: 14, color: RpgColors.textMuted),
            ),
          ),
        SizedBox(width: 6),
        GestureDetector(
          onTap: () => onChanged(count + 1),
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: RpgColors.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: RpgColors.gold),
            ),
            child: Icon(Icons.add, size: 14, color: RpgColors.gold),
          ),
        ),
      ]),
    );
  }
}

class _EmissionDayPickerDetail extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  const _EmissionDayPickerDetail({required this.value, required this.onChanged});

  static const _days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _full = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final sel = value == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(sel ? null : i),
            child: Tooltip(
              message: _full[i],
              child: Container(
                margin: EdgeInsets.only(right: i < 6 ? 4 : 0),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? RpgColors.gold.withOpacity(0.18) : RpgColors.charcoal,
                  borderRadius: BorderRadius.circular(6),
                  border: sel ? Border.all(color: RpgColors.gold, width: 1.5) : null,
                ),
                child: Center(
                  child: Text(_days[i], style: TextStyle(
                    fontSize: 11,
                    color: sel ? RpgColors.gold : RpgColors.textMuted,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  )),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10, color: RpgColors.textMuted, letterSpacing: 0.8, fontWeight: FontWeight.w500),
  );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoTile({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: RpgColors.charcoal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: TextStyle(
          fontSize: 9, color: RpgColors.textMuted, letterSpacing: 0.8, fontWeight: FontWeight.w500)),
        SizedBox(height: 4),
        Row(children: [
          Icon(icon, size: 14, color: valueColor ?? RpgColors.textSecondary),
          SizedBox(width: 5),
          Expanded(child: Text(value, style: TextStyle(
            color: valueColor ?? RpgColors.textPrimary,
            fontFamily: 'Crimson', fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      ]),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: RpgColors.charcoal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: RpgColors.textMuted),
        SizedBox(width: 5),
        Text(text, style: TextStyle(
          color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 13)),
      ]),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String? type;
  const _TypePill(this.type);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: RpgColors.amethyst.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: RpgColors.amethystLight.withOpacity(0.4)),
      ),
      child: Text(typeLabel(type), style: TextStyle(
        color: RpgColors.amethystLight, fontSize: 11, fontFamily: 'Crimson')),
    );
  }
}

// ---- History section ----

class _HistorySection extends StatefulWidget {
  final int entryId;
  const _HistorySection({required this.entryId});

  @override
  State<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<_HistorySection> {
  bool _expanded = false;
  List<dynamic> _history = [];
  bool _loaded = false;

  Future<void> _load() async {
    if (_loaded) return;
    try {
      final h = await ApiService.getEntryHistory(widget.entryId);
      if (mounted) setState(() { _history = h; _loaded = true; });
    } catch (_) {
      if (mounted) setState(() { _loaded = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text('Historial de cambios',
          style: TextStyle(color: RpgColors.textSecondary, fontSize: 13)),
      iconColor: RpgColors.gold,
      collapsedIconColor: RpgColors.textMuted,
      onExpansionChanged: (v) {
        if (v) _load();
        setState(() => _expanded = v);
      },
      children: _history.isEmpty && _loaded
          ? [Padding(
              padding: EdgeInsets.all(12),
              child: Text('Sin cambios registrados',
                  style: TextStyle(color: RpgColors.textMuted, fontSize: 12)))]
          : _history.map((h) {
              final date = DateTime.tryParse(h['changed_at'] ?? '');
              final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : '';
              return ListTile(
                dense: true,
                title: Text(
                  '${h['field_name']}: ${h['old_value'] ?? '—'} → ${h['new_value'] ?? '—'}',
                  style: TextStyle(
                      color: RpgColors.textSecondary,
                      fontSize: 12,
                      fontFamily: 'Crimson'),
                ),
                trailing: Text(dateStr,
                    style: TextStyle(color: RpgColors.textMuted, fontSize: 11)),
              );
            }).toList(),
    );
  }
}

// ---- Tab bar delegate for NestedScrollView ----

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: RpgColors.darkVoid,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => tabBar != old.tabBar;
}
