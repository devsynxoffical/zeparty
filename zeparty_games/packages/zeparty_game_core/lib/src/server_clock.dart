/// Server-synchronised wall clock.
///
/// Turn deadlines and chess clocks are absolute server timestamps. Comparing
/// them with the device clock made two phones show different remaining time
/// whenever their clocks disagreed (a 2 minute skew between two test devices
/// produced a 2 minute clock difference in the same chess game). The socket
/// client feeds every server message's `t` stamp in here; the UI reads
/// [nowMs] instead of `DateTime.now()`.
class ServerClock {
  ServerClock._();
  static final ServerClock instance = ServerClock._();

  /// server time minus device time, in milliseconds. 0 until the first sample.
  int offsetMs = 0;
  bool _hasSample = false;

  bool get synced => _hasSample;

  /// Current time on the server's clock, in milliseconds since epoch.
  int get nowMs => DateTime.now().millisecondsSinceEpoch + offsetMs;

  /// Record a server timestamp that was just received. One-way latency is
  /// unknown, so the estimate is biased by up to the network delay; the
  /// smoothing below keeps a few hundred ms of jitter from moving the clocks.
  void observe(int serverMs) {
    final sample = serverMs - DateTime.now().millisecondsSinceEpoch;
    if (!_hasSample) {
      offsetMs = sample;
      _hasSample = true;
      return;
    }
    final delta = sample - offsetMs;
    // Large jumps (device clock changed, long suspend) are taken at once;
    // small ones are averaged in.
    offsetMs = delta.abs() > 2000 ? sample : offsetMs + delta ~/ 4;
  }

  /// Test hook.
  void reset() {
    offsetMs = 0;
    _hasSample = false;
  }
}
