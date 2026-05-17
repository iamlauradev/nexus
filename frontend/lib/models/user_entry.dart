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
  final String? startedAt;
  final String? completedAt;
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
    required this.updatedAt,
    this.media,
  });

  factory UserEntry.fromJson(Map<String, dynamic> j) => UserEntry(
    id:          j['id'],
    userId:      j['user_id'],
    mediaId:     j['media_id'],
    status:      j['status'],
    progress:    j['progress'],
    score:       (j['score'] as num?)?.toDouble(),
    ratingLabel: j['rating_label'],
    notes:       j['notes'],
    platform:    j['platform'],
    startedAt:   j['started_at'],
    completedAt: j['completed_at'],
    updatedAt:   DateTime.parse(j['updated_at']),
    media:       j['media'] != null ? MediaItem.fromJson(j['media']) : null,
  );
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
