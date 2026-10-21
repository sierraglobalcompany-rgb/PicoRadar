import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/driving/presentation/driving_map_episode.dart';

void main() {
  setUp(CameraMapEpisodeCache.resetForTesting);

  test(
    'success is revalidated and point updates preserve the pending deadline',
    () {
      final state = CameraMapEpisodeStateMachine();
      final start = DateTime.utc(2026, 9, 9);
      state.begin('episode', start);
      state.markReady('episode');
      final changed = start.add(const Duration(seconds: 10));
      expect(state.revalidate('episode', changed), isTrue);
      expect(
        state.revalidate('episode', changed.add(const Duration(seconds: 2))),
        isFalse,
      );
      expect(
        state.markTimedOut('episode', changed.add(const Duration(seconds: 3))),
        isTrue,
      );
      expect(state.markReady('episode'), isFalse);
      expect(state.revalidate('episode', changed), isFalse);
    },
  );

  test('retry is explicit and old episode completions stay invalid', () {
    final state = CameraMapEpisodeStateMachine();
    final start = DateTime.utc(2026, 9, 9);
    state.begin('old', start);
    state.markFallback('old');
    state.retry('old', start.add(const Duration(seconds: 10)));
    expect(state.state, CameraMapEpisodeViewState.pending);
    expect(
      state.markTimedOut('old', start.add(const Duration(seconds: 12))),
      isFalse,
    );
    state.begin('new', start.add(const Duration(seconds: 11)));
    expect(state.markReady('old'), isFalse);
    expect(state.markFallback('old'), isFalse);
  });

  test(
    'episode cache is bounded and evicts deadlines together with old state',
    () {
      final start = DateTime.utc(2026, 9, 9);
      for (var i = 0; i <= CameraMapEpisodeCache.maximumEntries; i++) {
        CameraMapEpisodeCache.write(
          'episode-$i',
          CameraMapEpisodeViewState.pending,
          pendingSince: start,
        );
      }
      expect(CameraMapEpisodeCache.read('episode-0'), isNull);
      expect(CameraMapEpisodeCache.pendingSince('episode-0'), isNull);
      expect(
        CameraMapEpisodeCache.read('episode-64'),
        CameraMapEpisodeViewState.pending,
      );
      CameraMapEpisodeCache.write(
        'episode-64',
        CameraMapEpisodeViewState.ready,
      );
      expect(CameraMapEpisodeCache.pendingSince('episode-64'), isNull);
      CameraMapEpisodeCache.remove('episode-64');
      expect(CameraMapEpisodeCache.read('episode-64'), isNull);
    },
  );
}
