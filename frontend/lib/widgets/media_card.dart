import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_entry.dart';
import '../theme/rpg_theme.dart';
import 'ornamental_border.dart';

class MediaCard extends StatelessWidget {
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

  bool get _trackingEpisodes =>
      entry.epCurrent != null || entry.epTotal != null;

  @override
  Widget build(BuildContext context) {
    final media = entry.media;
    if (media == null) return const SizedBox.shrink();

    final isNewToday = entry.isNewEpisodeToday && entry.status == 'watching';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: RpgColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isNewToday
                ? RpgColors.gold.withOpacity(0.8)
                : ratingColor(entry.ratingLabel).withOpacity(0.4),
            width: isNewToday ? 1.5 : 1,
          ),
          boxShadow: [
            if (isNewToday)
              BoxShadow(
                color: RpgColors.gold.withOpacity(0.18),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            BoxShadow(
              color: RpgColors.obsidian.withOpacity(0.5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    media.coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: media.coverUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: RpgColors.charcoal,
                            child: const Icon(Icons.image, color: RpgColors.border),
                          ),
                          errorWidget: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                    // Gradient overlay
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, RpgColors.surface.withOpacity(0.9)],
                          ),
                        ),
                      ),
                    ),
                    // Status badge top-right
                    Positioned(
                      top: 6, right: 6,
                      child: StatusBadge(status: entry.status),
                    ),
                    // "NUEVO HOY" badge top-left
                    if (isNewToday)
                      Positioned(
                        top: 6, left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: RpgColors.gold,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('NUEVO', style: TextStyle(
                            fontFamily: 'Cinzel', fontSize: 7,
                            color: RpgColors.obsidian, fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          )),
                        ),
                      )
                    else if (media.emissionStatus == 'AIRING' && entry.status == 'watching')
                      Positioned(
                        top: 6, left: 6,
                        child: EmissionBadge(status: 'AIRING'),
                      ),
                    // Rating color bar at bottom
                    if (entry.ratingLabel != null && entry.ratingLabel != 'sin_valorar')
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          height: 3,
                          color: ratingColor(entry.ratingLabel),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Crimson',
                        fontSize: 13,
                        color: RpgColors.textPrimary,
                        fontWeight: FontWeight.w600,
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
                                style: const TextStyle(
                                  fontSize: 10, color: RpgColors.textMuted,
                                  fontFamily: 'Crimson',
                                ),
                              ),
                              if (_trackingEpisodes)
                                Text(
                                  entry.epTotal != null
                                      ? '${entry.epCurrent ?? 0}/${entry.epTotal}'
                                      : '${entry.epCurrent ?? 0}',
                                  style: const TextStyle(
                                    fontSize: 10, color: RpgColors.gold,
                                    fontFamily: 'Crimson',
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // +1 episode button
                        if (onEpisodePlus != null && _trackingEpisodes)
                          GestureDetector(
                            onTap: onEpisodePlus,
                            child: Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: RpgColors.gold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: RpgColors.gold.withOpacity(0.6)),
                              ),
                              child: const Icon(Icons.add, size: 13, color: RpgColors.gold),
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
      ),
    );
  }

  Widget _placeholder() => Container(
    color: RpgColors.charcoal,
    child: const Center(
      child: Icon(Icons.auto_stories, color: RpgColors.border, size: 32),
    ),
  );
}

class MediaListTile extends StatelessWidget {
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

  bool get _trackingEpisodes =>
      entry.epCurrent != null || entry.epTotal != null;

  @override
  Widget build(BuildContext context) {
    final media = entry.media;
    if (media == null) return const SizedBox.shrink();

    final isNewToday = entry.isNewEpisodeToday && entry.status == 'watching';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isNewToday ? RpgColors.gold.withOpacity(0.04) : RpgColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(
              color: isNewToday ? RpgColors.gold : ratingColor(entry.ratingLabel),
              width: isNewToday ? 3 : 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // Cover thumbnail
            if (media.coverUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: media.coverUrl!,
                  width: 42, height: 58,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(width: 42, height: 58, color: RpgColors.charcoal),
                  errorWidget: (_, __, ___) => Container(
                    width: 42, height: 58, color: RpgColors.charcoal,
                    child: const Icon(Icons.broken_image, color: RpgColors.border, size: 18),
                  ),
                ),
              )
            else
              Container(
                width: 42, height: 58,
                decoration: BoxDecoration(
                  color: RpgColors.charcoal,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.auto_stories, color: RpgColors.border, size: 18),
              ),
            const SizedBox(width: 12),
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
                          style: const TextStyle(
                            fontFamily: 'Crimson', fontSize: 15,
                            color: RpgColors.textPrimary, fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isNewToday) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: RpgColors.gold,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('NUEVO', style: TextStyle(
                            fontFamily: 'Cinzel', fontSize: 7,
                            color: RpgColors.obsidian, fontWeight: FontWeight.bold,
                          )),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(typeLabel(media.type),
                        style: const TextStyle(fontSize: 11, color: RpgColors.textMuted, fontFamily: 'Crimson')),
                      if (media.year != null) ...[
                        const Text(' · ', style: TextStyle(color: RpgColors.textMuted, fontSize: 11)),
                        Text('${media.year}',
                          style: const TextStyle(fontSize: 11, color: RpgColors.textMuted, fontFamily: 'Crimson')),
                      ],
                      if (media.country != null) ...[
                        const Text(' · ', style: TextStyle(color: RpgColors.textMuted, fontSize: 11)),
                        Text(media.country!,
                          style: const TextStyle(fontSize: 11, color: RpgColors.textMuted, fontFamily: 'Crimson')),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      StatusBadge(status: entry.status),
                      const SizedBox(width: 6),
                      RatingBadge(label: entry.ratingLabel),
                      const Spacer(),
                      if (_trackingEpisodes)
                        Text(
                          entry.epTotal != null
                              ? '${entry.epCurrent ?? 0} / ${entry.epTotal}'
                              : 'Cap. ${entry.epCurrent ?? 0}',
                          style: const TextStyle(
                              fontSize: 11, color: RpgColors.gold, fontFamily: 'Crimson'),
                        )
                      else if (entry.progress != null)
                        Text(entry.progress!,
                          style: const TextStyle(fontSize: 11, color: RpgColors.gold, fontFamily: 'Crimson')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right action: +1 or chevron
            if (onEpisodePlus != null && _trackingEpisodes)
              GestureDetector(
                onTap: onEpisodePlus,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: RpgColors.gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: RpgColors.gold.withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.add, size: 16, color: RpgColors.gold),
                ),
              )
            else
              const Icon(Icons.chevron_right, color: RpgColors.border, size: 18),
          ],
        ),
      ),
    );
  }
}
