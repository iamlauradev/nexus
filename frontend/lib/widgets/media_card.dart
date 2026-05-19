import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_entry.dart';
import '../theme/rpg_theme.dart';
import 'ornamental_border.dart';

class MediaCard extends StatelessWidget {
  final UserEntry entry;
  final VoidCallback? onTap;

  const MediaCard({super.key, required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final media = entry.media;
    if (media == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: RpgColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: ratingColor(entry.ratingLabel).withOpacity(0.4),
            width: 1,
          ),
          boxShadow: [
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
                    // Emission badge top-left for AIRING content being watched
                    if (entry.media?.emissionStatus == 'AIRING' && entry.status == 'watching')
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
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
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
                      children: [
                        Text(
                          typeLabel(media.type),
                          style: const TextStyle(
                            fontSize: 10, color: RpgColors.textMuted,
                            fontFamily: 'Crimson',
                          ),
                        ),
                        if (entry.progress != null) ...[
                          const Spacer(),
                          Text(
                            entry.progress!,
                            style: const TextStyle(
                              fontSize: 10, color: RpgColors.gold,
                              fontFamily: 'Crimson',
                            ),
                          ),
                        ],
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

  const MediaListTile({super.key, required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final media = entry.media;
    if (media == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: RpgColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(
              color: ratingColor(entry.ratingLabel),
              width: 3,
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
                  placeholder: (_, __) => Container(
                    width: 42, height: 58,
                    color: RpgColors.charcoal,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 42, height: 58,
                    color: RpgColors.charcoal,
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
                  Text(
                    media.title,
                    style: const TextStyle(
                      fontFamily: 'Crimson',
                      fontSize: 15,
                      color: RpgColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        typeLabel(media.type),
                        style: const TextStyle(fontSize: 11, color: RpgColors.textMuted, fontFamily: 'Crimson'),
                      ),
                      if (media.year != null) ...[
                        const Text(' · ', style: TextStyle(color: RpgColors.textMuted, fontSize: 11)),
                        Text('${media.year}', style: const TextStyle(fontSize: 11, color: RpgColors.textMuted, fontFamily: 'Crimson')),
                      ],
                      if (media.country != null) ...[
                        const Text(' · ', style: TextStyle(color: RpgColors.textMuted, fontSize: 11)),
                        Text(media.country!, style: const TextStyle(fontSize: 11, color: RpgColors.textMuted, fontFamily: 'Crimson')),
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
                      if (entry.progress != null)
                        Text(
                          entry.progress!,
                          style: const TextStyle(fontSize: 11, color: RpgColors.gold, fontFamily: 'Crimson'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: RpgColors.border, size: 18),
          ],
        ),
      ),
    );
  }
}
