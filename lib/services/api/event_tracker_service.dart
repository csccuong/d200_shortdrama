import 'dart:async';
import 'package:dio/dio.dart';
import 'package:dxx_shortdrama/core/network/api_endpoints.dart';

/// Batched user behavior event tracker (v4.5 — doc 02 §3.2).
///
/// Queues events in memory and flushes up to 50 events per batch every 10s
/// (or immediately once 15+ events accumulate) to `POST /v1/events/track`.
class DramaEventTracker {
  final Dio _dio;
  final List<Map<String, dynamic>> _queue = [];
  Timer? _flushTimer;

  DramaEventTracker(this._dio) {
    _flushTimer = Timer.periodic(const Duration(seconds: 10), (_) => flush());
  }

  void track(
    String event, {
    String dramaId = '',
    int episodeNumber = 0,
    int positionSec = 0,
    int watchedSec = 0,
    String sourceScreen = '',
    Map<String, dynamic>? props,
  }) {
    _queue.add({
      'event': event,
      if (dramaId.isNotEmpty) 'drama_id': dramaId,
      if (episodeNumber > 0) 'episode_number': episodeNumber,
      if (positionSec > 0) 'position_sec': positionSec,
      if (watchedSec > 0) 'watched_sec': watchedSec,
      if (sourceScreen.isNotEmpty) 'source_screen': sourceScreen,
      if (props != null && props.isNotEmpty) 'props': props,
    });
    if (_queue.length >= 15) {
      unawaited(flush());
    }
  }

  Future<void> flush() async {
    if (_queue.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_queue.take(50));
    _queue.removeRange(0, batch.length);
    try {
      await _dio.post(
        ApiEndpoints.eventsTrack,
        data: {'events': batch},
      );
    } catch (_) {
      // Do not block UI flow on transient network errors.
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
    unawaited(flush());
  }
}
