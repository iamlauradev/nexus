import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_entry.dart';
import '../services/api_service.dart';

// ---------------------------------------------------------------------------
// Entry list state + notifier
// ---------------------------------------------------------------------------

class EntryListParams {
  final String? status;
  final String? mediaType;
  final String? rating;
  final String? q;
  final int limit;
  final int offset;

  const EntryListParams({
    this.status,
    this.mediaType,
    this.rating,
    this.q,
    this.limit = 50,
    this.offset = 0,
  });

  @override
  bool operator ==(Object other) =>
      other is EntryListParams &&
      status == other.status &&
      mediaType == other.mediaType &&
      rating == other.rating &&
      q == other.q &&
      limit == other.limit &&
      offset == other.offset;

  @override
  int get hashCode =>
      Object.hash(status, mediaType, rating, q, limit, offset);
}

// Family provider: each unique params combination gets its own cached state
final entryListProvider = FutureProvider.family<List<UserEntry>, EntryListParams>(
  (ref, params) => ApiService.getEntries(
    status: params.status,
    mediaType: params.mediaType,
    rating: params.rating,
    q: params.q,
    limit: params.limit,
    offset: params.offset,
  ),
);

// Simple notifier to signal that entries changed (triggers re-fetches)
class EntryChangeNotifierRv extends Notifier<int> {
  @override
  int build() => 0;

  void notifyChanged() => state = state + 1;
}

final entryChangeRvProvider =
    NotifierProvider<EntryChangeNotifierRv, int>(EntryChangeNotifierRv.new);

// Stats provider
final statsProvider = FutureProvider<Map<String, dynamic>>(
  (_) => ApiService.getStats(),
);
