import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_entry.dart';
import '../theme/rpg_theme.dart';
import 'ornamental_border.dart';
import 'shared/shared.dart';

class MediaCard extends StatefulWidget {
  final UserEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onEpisodePlus;
  final VoidCallback? onLongPress;

  const MediaCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onEpisodePlus,
    this.onLongPress,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _hovered = false;

  bool get _trackingEpisodes =>
      widget.entry.epCurrent != null || widget.entry.epTotal != null;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final media = entry.media;
    if (media == null) return const SizedBox.shrink();

    final isNewToday = entry.isNewEpisodeToday && entry.status == 'watching';
    final hasRating = entry.ratingLabel != null && entry.ratingLabel != 'sin_valorar';

    // Border only for special states (new today, or rating color on hover)
    final borderColor = isNewToday
        ? RpgColors.gold.withOpacity(0.9)
        : (_hovered ? ratingColor(entry.ratingLabel).withOpacity(0.6) : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap?.call();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          widget.onLongPress?.call();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: _hovered
              ? (Matrix4.identity()..translate(0.0, -3.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: RpgColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              if (isNewToday)
                BoxShadow(
                  color: RpgColors.gold.withOpacity(0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              if (_hovered)
                BoxShadow(
                  color: RpgColors.accent.withOpacity(0.18),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              BoxShadow(
                color: RpgColors.obsidian.withOpacity(0.6),
                blurRadius: _hovered ? 14 : 4,
                offset: Offset(0, _hovered ? 8 : 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover image
                  Expanded(
                    flex: 5,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          media.coverUrl != null
                            ? CachedNetworkImage(
                                imageUrl: media.coverUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: RpgColors.charcoal,
                                  child: Icon(Icons.image, color: RpgColors.border),
                                ),
                                errorWidget: (_, __, ___) => _placeholder(),
                              )
                            : _placeholder(),
                          // Bottom gradient fade into card
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, RpgColors.surface.withOpacity(0.95)],
                                ),
                              ),
                            ),
                          ),
                          // Status badge
                          Positioned(
                            top: 6, right: 6,
                            child: StatusBadge(status: entry.status),
                          ),
                          // "NUEVO" badge
                          if (isNewToday)
                            Positioned(
                              top: 6, left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: RpgColors.gold,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text('NUEVO', style: TextStyle(
                                  fontSize: 7, fontFamily: 'DMSans',
                                  color: Colors.white, fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                )),
                              ),
                            )
                          else if (media.emissionStatus == 'AIRING' && entry.status == 'watching')
                            Positioned(
                              top: 6, left: 6,
                              child: EmissionBadge(status: 'AIRING'),
                            ),
                          // Rating bar at base of cover
                          if (hasRating)
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              child: Container(
                                height: 2.5,
                                color: ratingColor(entry.ratingLabel),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Info section
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 5, 6, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            media.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 12,
                              color: RpgColors.textPrimary,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      typeLabel(media.type),
                                      style: TextStyle(
                                        fontSize: 10, color: RpgColors.textMuted,
                                        fontFamily: 'DMSans',
                                      ),
                                    ),
                                    if (_trackingEpisodes)
                                      Text(
                                        entry.epTotal != null
                                            ? '${entry.epCurrent ?? 0}/${entry.epTotal}'
                                            : 'Ep. ${entry.epCurrent ?? 0}',
                                        style: TextStyle(
                                          fontSize: 10, color: RpgColors.gold,
                                          fontFamily: 'DMSans', fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (widget.onEpisodePlus != null && _trackingEpisodes)
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    widget.onEpisodePlus?.call();
                                  },
                                  child: Container(
                                    width: 22, height: 22,
                                    decoration: BoxDecoration(
                                      color: RpgColors.accent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: RpgColors.accent.withOpacity(0.5)),
                                    ),
                                    child: Icon(Icons.add, size: 13, color: RpgColors.accent),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Top edge highlight — subtle gloss
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 1.5,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                    gradient: LinearGradient(
                      colors: [Color(0x00FFFFFF), Color(0x18FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: RpgColors.charcoal,
    child: Center(
      child: Icon(Icons.auto_stories, color: RpgColors.border, size: 32),
    ),
  );
}

class MediaListTile extends StatefulWidget {
  final UserEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onEpisodePlus;
  final VoidCallback? onLongPress;

  const MediaListTile({
    super.key,
    required this.entry,
    this.onTap,
    this.onEpisodePlus,
    this.onLongPress,
  });

  @override
  State<MediaListTile> createState() => _MediaListTileState();
}

class _MediaListTileState extends State<MediaListTile> {
  bool _hovered = false;

  bool get _trackingEpisodes =>
      widget.entry.epCurrent != null || widget.entry.epTotal != null;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final media = entry.media;
    if (media == null) return const SizedBox.shrink();

    final isNewToday = entry.isNewEpisodeToday && entry.status == 'watching';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () { HapticFeedback.lightImpact(); widget.onTap?.call(); },
        onLongPress: () { HapticFeedback.mediumImpact(); widget.onLongPress?.call(); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? RpgColors.surfaceHigh : RpgColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(
                color: isNewToday
                    ? RpgColors.gold
                    : ratingColor(entry.ratingLabel).withOpacity(0.8),
                width: 3,
              ),
            ),
            boxShadow: _hovered ? [
              BoxShadow(
                color: RpgColors.accent.withOpacity(0.10),
                blurRadius: 16, spreadRadius: 1,
              ),
            ] : null,
          ),
          child: Row(
            children: [
              // Cover thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: media.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: media.coverUrl!,
                      width: 44, height: 60,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(width: 44, height: 60, color: RpgColors.charcoal),
                      errorWidget: (_, __, ___) => Container(
                        width: 44, height: 60, color: RpgColors.charcoal,
                        child: Icon(Icons.broken_image, color: RpgColors.border, size: 18),
                      ),
                    )
                  : Container(
                      width: 44, height: 60,
                      color: RpgColors.charcoal,
                      child: Icon(Icons.auto_stories, color: RpgColors.border, size: 18),
                    ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            media.title,
                            style: TextStyle(
                              fontFamily: 'DMSans', fontSize: 14,
                              color: RpgColors.textPrimary, fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isNewToday) ...[
                          SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: RpgColors.gold,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('NUEVO', style: TextStyle(
                              fontSize: 7, fontFamily: 'DMSans',
                              color: Colors.white, fontWeight: FontWeight.w700,
                            )),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 3),
                    Row(
                      children: [
                        Text(typeLabel(media.type),
                          style: TextStyle(fontSize: 11, color: RpgColors.textMuted, fontFamily: 'DMSans')),
                        if (media.year != null) ...[
                          Text(' · ', style: TextStyle(color: RpgColors.textMuted, fontSize: 11)),
                          Text('${media.year}',
                            style: TextStyle(fontSize: 11, color: RpgColors.textMuted, fontFamily: 'DMSans')),
                        ],
                        if (media.country != null) ...[
                          Text(' · ', style: TextStyle(color: RpgColors.textMuted, fontSize: 11)),
                          Text(media.country!,
                            style: TextStyle(fontSize: 11, color: RpgColors.textMuted, fontFamily: 'DMSans')),
                        ],
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        StatusBadge(status: entry.status),
                        SizedBox(width: 6),
                        RatingBadge(label: entry.ratingLabel),
                        const Spacer(),
                        if (_trackingEpisodes)
                          Text(
                            entry.epTotal != null
                                ? '${entry.epCurrent ?? 0} / ${entry.epTotal}'
                                : 'Cap. ${entry.epCurrent ?? 0}',
                            style: TextStyle(
                              fontSize: 11, color: RpgColors.gold,
                              fontFamily: 'DMSans', fontWeight: FontWeight.w500),
                          )
                        else if (entry.progress != null)
                          Text(entry.progress!,
                            style: TextStyle(
                              fontSize: 11, color: RpgColors.gold,
                              fontFamily: 'DMSans', fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              if (widget.onEpisodePlus != null && _trackingEpisodes)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onEpisodePlus?.call();
                  },
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: RpgColors.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: RpgColors.accent.withOpacity(0.4)),
                    ),
                    child: Icon(Icons.add, size: 16, color: RpgColors.accent),
                  ),
                )
              else
                Icon(Icons.chevron_right, color: RpgColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
