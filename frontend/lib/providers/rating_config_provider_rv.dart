import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';
import '../theme/rpg_theme.dart';

final ratingConfigProvider = FutureProvider<List<RatingConfig>>(
  (ref) async {
    final configs = await ApiService.getRatingConfigs();
    RatingConfigCache.update(configs.map((c) => {
      'key': c.key,
      'label': c.label,
      'color': c.color,
      'sort_order': c.sortOrder,
    }).toList());
    return configs;
  },
);
