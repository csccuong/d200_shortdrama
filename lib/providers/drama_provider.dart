import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/injection.dart';
import '../core/network/drama_dio_interceptor.dart';
import '../models/drama_card.dart';
import '../models/episode_detail.dart';
import '../models/play_response.dart';
import '../services/api/drama_api_service.dart';

// ============================================================================
// DRAMA DETAIL STATE
// ============================================================================

class DramaDetailState {
  final DramaCard dramaDetail;
  final List<DramaCard> relatedDramas;
  final EpisodesListResponse episodes;

  const DramaDetailState({
    required this.dramaDetail,
    required this.relatedDramas,
    required this.episodes,
  });
}

// ============================================================================
// DRAMA DETAIL PROVIDER — Family keyed by dramaId
// ============================================================================

final dramaDetailProvider =
    FutureProvider.autoDispose.family<DramaDetailState, String>(
  (ref, dramaId) async {
    final service = inject<DramaApiService>();

    // Fetch drama detail and episodes in parallel (up to 100 episodes per page)
    final detailFuture = service.fetchDramaDetail(dramaId);
    final episodesFuture = service.fetchEpisodes(dramaId, pageSize: 100);
    final detailRes = await detailFuture;
    final episodesResponse = await episodesFuture;

    return DramaDetailState(
      dramaDetail: detailRes.drama,
      relatedDramas: detailRes.relatedDramas,
      episodes: episodesResponse,
    );
  },
);

// ============================================================================
// PLAY EPISODE PROVIDER — Family keyed by (dramaId, episodeNumber)
// Handles both HTTP 200 (play) and HTTP 402 (paywall)
// ============================================================================

final playEpisodeProvider = FutureProvider.autoDispose
    .family<PlayResponse, ({String dramaId, int episodeNumber})>(
  (ref, args) async {
    final service = inject<DramaApiService>();
    try {
      return await service.playEpisode(args.dramaId, args.episodeNumber);
    } on DramaPaywallException {
      // Re-throw so UI layer can catch and show paywall bottom sheet
      rethrow;
    }
  },
);
