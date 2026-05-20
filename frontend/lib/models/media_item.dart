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
  final String? emissionStatus;
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
    this.emissionStatus,
    this.tmdbId,
    this.anilistId,
    this.platform,
  });

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
    id:             j['id'],
    type:           j['type'],
    title:          j['title'],
    titleOriginal:  j['title_original'],
    year:           j['year'],
    genres:         (j['genres'] as List?)?.map((e) => e.toString()).toList(),
    synopsis:       j['synopsis'],
    coverUrl:       j['cover_url'],
    duration:       j['duration'],
    country:        j['country'],
    network:        j['network'],
    castText:       j['cast_text'],
    externalScore:  (j['external_score'] as num?)?.toDouble(),
    emissionStatus: j['emission_status'],
    tmdbId:         j['tmdb_id'],
    anilistId:      j['anilist_id'],
    platform:       j['platform'],
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
  final String? emissionStatus;
  final String? network;
  final String? castText;
  final int? episodes;

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
    this.emissionStatus,
    this.network,
    this.castText,
    this.episodes,
  });

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
    source:         j['source'],
    externalId:     j['external_id'],
    title:          j['title'],
    titleOriginal:  j['title_original'],
    year:           j['year'],
    coverUrl:       j['cover_url'],
    genres:         (j['genres'] as List?)?.map((e) => e.toString()).toList(),
    synopsis:       j['synopsis'],
    score:          (j['score'] as num?)?.toDouble(),
    type:           j['type'],
    duration:       j['duration'],
    country:        j['country'],
    emissionStatus: j['emission_status'],
    network:        j['network'],
    castText:       j['cast_text'],
    episodes:       j['episodes'] as int?,
  );
}

class RatingConfig {
  final int id;
  final int userId;
  final String key;
  final String label;
  final String color;
  final int sortOrder;

  const RatingConfig({
    required this.id,
    required this.userId,
    required this.key,
    required this.label,
    required this.color,
    required this.sortOrder,
  });

  factory RatingConfig.fromJson(Map<String, dynamic> j) => RatingConfig(
    id:        j['id'],
    userId:    j['user_id'],
    key:       j['key'],
    label:     j['label'],
    color:     j['color'],
    sortOrder: j['sort_order'],
  );

  Map<String, dynamic> toMap() => {
    'key': key,
    'label': label,
    'color': color,
    'sort_order': sortOrder,
  };
}
