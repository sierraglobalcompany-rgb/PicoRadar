import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/driving/presentation/driving_map_episode.dart';

void main() {
  test('tile success makes the current map episode ready', () {
    final machine = CameraMapEpisodeStateMachine();

    machine.begin('cam-1:1', DateTime.utc(2026, 9, 1, 12));

    expect(machine.markReady('cam-1:1'), isTrue);
    expect(machine.state, CameraMapEpisodeViewState.ready);
  });

  test('tile error latches fallback for the current episode', () {
    final machine = CameraMapEpisodeStateMachine();

    machine.begin('cam-1:1', DateTime.utc(2026, 9, 1, 12));

    expect(machine.markFallback('cam-1:1'), isTrue);
    expect(machine.state, CameraMapEpisodeViewState.fallback);
    expect(machine.markReady('cam-1:1'), isFalse);
    expect(machine.state, CameraMapEpisodeViewState.fallback);
  });

  test('GPS updates do not clear a failed map episode', () {
    final machine = CameraMapEpisodeStateMachine();
    final now = DateTime.utc(2026, 9, 1, 12);

    machine.begin('cam-1:1', now);
    machine.markFallback('cam-1:1');
    machine.begin('cam-1:1', now.add(const Duration(seconds: 5)));

    expect(machine.state, CameraMapEpisodeViewState.fallback);
  });

  test('new camera episode can retry map after a fallback', () {
    final machine = CameraMapEpisodeStateMachine();
    final now = DateTime.utc(2026, 9, 1, 12);

    machine.begin('cam-1:1', now);
    machine.markFallback('cam-1:1');
    machine.begin('cam-1:2', now.add(const Duration(minutes: 1)));

    expect(machine.state, CameraMapEpisodeViewState.pending);
    expect(machine.markReady('cam-1:2'), isTrue);
    expect(machine.state, CameraMapEpisodeViewState.ready);
  });

  test('old tile ready callback cannot mutate a newer episode', () {
    final machine = CameraMapEpisodeStateMachine();
    final now = DateTime.utc(2026, 9, 1, 12);

    machine.begin('cam-1:1', now);
    machine.begin('cam-2:1', now.add(const Duration(seconds: 1)));

    expect(machine.markReady('cam-1:1'), isFalse);
    expect(machine.state, CameraMapEpisodeViewState.pending);
    expect(machine.markReady('cam-2:1'), isTrue);
    expect(machine.state, CameraMapEpisodeViewState.ready);
  });

  test('old tile error callback cannot mutate a newer episode', () {
    final machine = CameraMapEpisodeStateMachine();
    final now = DateTime.utc(2026, 9, 1, 12);

    machine.begin('cam-1:1', now);
    machine.begin('cam-2:1', now.add(const Duration(seconds: 1)));

    expect(machine.markFallback('cam-1:1'), isFalse);
    expect(machine.state, CameraMapEpisodeViewState.pending);
    expect(machine.markFallback('cam-2:1'), isTrue);
    expect(machine.state, CameraMapEpisodeViewState.fallback);
  });

  test('pending map times out to radar fallback deterministically', () {
    final machine = CameraMapEpisodeStateMachine(
      timeout: const Duration(seconds: 3),
    );
    final now = DateTime.utc(2026, 9, 1, 12);

    machine.begin('cam-1:1', now);

    expect(
      machine.markTimedOut('cam-1:1', now.add(const Duration(seconds: 2))),
      isFalse,
    );
    expect(machine.state, CameraMapEpisodeViewState.pending);
    expect(
      machine.markTimedOut('cam-1:1', now.add(const Duration(seconds: 3))),
      isTrue,
    );
    expect(machine.state, CameraMapEpisodeViewState.fallback);
  });
}
