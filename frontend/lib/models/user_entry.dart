import 'media_item.dart';

class UserEntry {
  final int id;
  final int userId;
  final int mediaId;
  final String status;
  final String? progress;
  final double? score;
  final String? ratingLabel;
  final String? notes;
  final String? platform;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? epCurrent;
  final int? epTotal;
  final int rewatchCount;
  final int? emissionDay;  // 0=lunes … 6=domingo, null=no configurado
  final DateTime updatedAt;
  final MediaItem? media;

  const UserEntry({
    required this.id,
    required this.userId,
    required this.mediaId,
    required this.status,
    this.progress,
    this.score,
    this.ratingLabel,
    this.notes,
    this.platform,
    this.startedAt,
    this.completedAt,
    this.epCurrent,
    this.epTotal,
    this.rewatchCount = 0,
    this.emissionDay,
    required this.updatedAt,
    this.media,
  });

  factory UserEntry.fromJson(Map<String, dynamic> j) => UserEntry(
    id:           j['id'],
    userId:       j['user_id'],
    mediaId:      j['media_id'],
    status:       j['status'],
    progress:     j['progress'],
    score:        (j['score'] as num?)?.toDouble(),
    ratingLabel:  j['rating_label'],
    notes:        j['notes'],
    platform:     j['platform'],
    startedAt:    j['started_at'] != null ? DateTime.tryParse(j['started_at']) : null,
    completedAt:  j['completed_at'] != null ? DateTime.tryParse(j['completed_at']) : null,
    epCurrent:    j['ep_current'] as int?,
    epTotal:      j['ep_total'] as int?,
    rewatchCount: (j['rewatch_count'] as int?) ?? 0,
    emissionDay:  j['emission_day'] as int?,
    updatedAt:    DateTime.parse(j['updated_at']),
    media:        j['media'] != null ? MediaItem.fromJson(j['media']) : null,
  );

  bool get isNewEpisodeToday {
    if (emissionDay == null) return false;
    // DateTime.weekday: 1=lunes…7=domingo → convertir a 0-6
    return emissionDay == DateTime.now().weekday - 1;
  }

  // Helper to get ISO string for API calls
  String? get startedAtStr => startedAt?.toIso8601String().split('T').first;
  String? get completedAtStr => completedAt?.toIso8601String().split('T').first;
}

class AppUser {
  final int id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final bool isAdmin;

  const AppUser({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.isAdmin,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id:          j['id'],
    username:    j['username'],
    displayName: j['display_name'],
    avatarUrl:   j['avatar_url'],
    isAdmin:     j['is_admin'] ?? false,
  );

  String get name => displayName ?? username;
}
