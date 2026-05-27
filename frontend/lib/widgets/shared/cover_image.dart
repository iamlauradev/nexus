/// Consistent cover image widget with fixed 2:3 aspect ratio.
/// Prevents layout shifts from different source APIs (TMDB vs AniList vs MangaDex).
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/rpg_theme.dart';

class CoverImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const CoverImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(8);
    return ClipRRect(
      borderRadius: br,
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (_, __) => _Placeholder(width: width, height: height),
              errorWidget: (_, __, ___) => _Placeholder(width: width, height: height),
            )
          : _Placeholder(width: width, height: height),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double? width;
  final double? height;
  const _Placeholder({this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: RpgColors.charcoal,
      child: Center(
        child: Icon(Icons.auto_stories, color: RpgColors.border, size: 32),
      ),
    );
  }
}

/// AspectRatio 2:3 wrapper for grid covers.
class CoverCard extends StatelessWidget {
  final String? url;
  final BorderRadius? borderRadius;

  const CoverCard({super.key, this.url, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: CoverImage(
        url: url,
        borderRadius: borderRadius,
      ),
    );
  }
}
