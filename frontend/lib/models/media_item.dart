class MediaItem {
  final int id;
  final String type;
  final String title;
  final String? titleOriginal;
  final int? year;
  final List<String>? genres;
  final String? synopsis;
  final String? coverUrl;
  final String? duration;
  final String? country;
  final String? network;
  final String? castText;
  final double? externalScore;
  final int? tmdbId;
  final int? anilistId;
  final String? platform;

  const MediaItem({
    required this.id,
    required this.type,
    required this.title,
    this.titleOriginal,
    this.year,
    this.genres,
    this.synopsis,
    this.coverUrl,
    this.duration,
    this.country,
    this.network,
    this.castText,
    this.externalScore,
    this.tmdbId,
    this.anilistId,
    this.platform,
  });

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
    id:            j['id'],
    type:          j['type'],
    title:         j['title'],
    titleOriginal: j['title_original'],
    year:          j['year'],
    genres:        (j['genres'] as List?)?.map((e) => e.toString()).toList(),
    synopsis:      j['synopsis'],
    coverUrl:      j['cover_url'],
    duration:      j['duration'],
    country:       j['country'],
    network:       j['network'],
    castText:      j['cast_text'],
    externalScore: (j['external_score'] as num?)?.toDouble(),
    tmdbId:        j['tmdb_id'],
    anilistId:     j['anilist_id'],
    platform:      j['platform'],
  );
}

class SearchResult {
  final String source;
  final String externalId;
  final String title;
  final String? titleOriginal;
  final int? year;
  final String? coverUrl;
  final List<String>? genres;
  final String? synopsis;
  final double? score;
  final String type;
  final String? duration;
  final String? country;

  const SearchResult({
    required this.source,
    required this.externalId,
    required this.title,
    this.titleOriginal,
    this.year,
    this.coverUrl,
    this.genres,
    this.synopsis,
    this.score,
    required this.type,
    this.duration,
    this.country,
  });

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
    source:        j['source'],
    externalId:    j['external_id'],
    title:         j['title'],
    titleOriginal: j['title_original'],
    year:          j['year'],
    coverUrl:      j['cover_url'],
    genres:        (j['genres'] as List?)?.map((e) => e.toString()).toList(),
    synopsis:      j['synopsis'],
    score:         (j['score'] as num?)?.toDouble(),
    type:          j['type'],
    duration:      j['duration'],
    country:       j['country'],
  );
}
