enum CameraMapEpisodeViewState { pending, ready, fallback }

const drivingMapTileReadinessTimeout = Duration(seconds: 3);

class CameraMapEpisodeCache {
  static const maximumEntries = 64;
  static final Map<String, CameraMapEpisodeViewState> _states = {};
  static final Map<String, DateTime> _pendingSince = {};

  static CameraMapEpisodeViewState? read(String episodeKey) {
    return _states[episodeKey];
  }

  static DateTime? pendingSince(String episodeKey) => _pendingSince[episodeKey];

  static void write(
    String episodeKey,
    CameraMapEpisodeViewState state, {
    DateTime? pendingSince,
  }) {
    _states.remove(episodeKey);
    _states[episodeKey] = state;
    if (state != CameraMapEpisodeViewState.pending) {
      _pendingSince.remove(episodeKey);
    } else if (pendingSince != null) {
      _pendingSince[episodeKey] = pendingSince;
    }
    while (_states.length > maximumEntries) {
      remove(_states.keys.first);
    }
  }

  static void remove(String episodeKey) {
    _states.remove(episodeKey);
    _pendingSince.remove(episodeKey);
  }

  static void resetForTesting() {
    _states.clear();
    _pendingSince.clear();
  }
}

class CameraMapEpisodeStateMachine {
  CameraMapEpisodeStateMachine({this.timeout = drivingMapTileReadinessTimeout});

  final Duration timeout;
  String? _episodeKey;
  CameraMapEpisodeViewState _state = CameraMapEpisodeViewState.pending;
  DateTime? _startedAt;

  CameraMapEpisodeViewState get state => _state;
  DateTime? get pendingSince => _startedAt;

  /// Repeated incomplete viewports share one deadline until coverage succeeds.
  bool revalidate(String episodeKey, DateTime now) {
    if (_episodeKey != episodeKey ||
        _state != CameraMapEpisodeViewState.ready) {
      return false;
    }
    _state = CameraMapEpisodeViewState.pending;
    _startedAt = now;
    return true;
  }

  void retry(String episodeKey, DateTime now) {
    _episodeKey = null;
    begin(episodeKey, now);
  }

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
