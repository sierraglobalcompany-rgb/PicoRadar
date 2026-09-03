enum CameraMapEpisodeViewState { pending, ready, fallback }

const drivingMapTileReadinessTimeout = Duration(seconds: 3);

class CameraMapEpisodeCache {
  static final Map<String, CameraMapEpisodeViewState> _states = {};

  static CameraMapEpisodeViewState? read(String episodeKey) {
    return _states[episodeKey];
  }

  static void write(String episodeKey, CameraMapEpisodeViewState state) {
    _states[episodeKey] = state;
  }

  static void resetForTesting() {
    _states.clear();
  }
}

class CameraMapEpisodeStateMachine {
  CameraMapEpisodeStateMachine({this.timeout = drivingMapTileReadinessTimeout});

  final Duration timeout;
  String? _episodeKey;
  CameraMapEpisodeViewState _state = CameraMapEpisodeViewState.pending;
  DateTime? _startedAt;

  CameraMapEpisodeViewState get state => _state;

  void begin(String episodeKey, DateTime now) {
    if (_episodeKey == episodeKey) {
      return;
    }
    _episodeKey = episodeKey;
    _state = CameraMapEpisodeViewState.pending;
    _startedAt = now;
  }

  bool markReady(String episodeKey) {
    if (_episodeKey != episodeKey ||
        _state != CameraMapEpisodeViewState.pending) {
      return false;
    }
    _state = CameraMapEpisodeViewState.ready;
    return true;
  }

  bool markFallback(String episodeKey) {
    if (_episodeKey != episodeKey ||
        _state == CameraMapEpisodeViewState.fallback) {
      return false;
    }
    _state = CameraMapEpisodeViewState.fallback;
    return true;
  }

  bool markTimedOut(String episodeKey, DateTime now) {
    final startedAt = _startedAt;
    if (_episodeKey != episodeKey ||
        startedAt == null ||
        _state != CameraMapEpisodeViewState.pending ||
        now.difference(startedAt) < timeout) {
      return false;
    }
    _state = CameraMapEpisodeViewState.fallback;
    return true;
  }
}
