import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Adaptive graphics tiers. Games read [GraphicsSettings.current] to decide
/// particle budgets, shadow passes, texture tiers and ambient animation.
enum GraphicsQuality {
  low,
  medium,
  high;

  /// Maximum simultaneous particles a scene may spawn.
  int get particleBudget => switch (this) { low => 60, medium => 200, high => 500 };

  /// Whether to render soft shadows and reflections.
  bool get shadows => this != low;

  /// Whether background ambient animation runs (dust, light flicker, drapes).
  bool get ambientAnimation => this == high;

  /// Texture suffix: low uses the half resolution variant when one exists.
  String get textureSuffix => this == low ? '@1x' : '@2x';

  /// Target device pixel ratio cap for render textures.
  double get maxPixelRatio => switch (this) { low => 1.5, medium => 2.0, high => 3.0 };
}

/// Global, listenable graphics settings. Persisted by the host app.
class GraphicsSettings extends ChangeNotifier {
  GraphicsSettings._();
  static final GraphicsSettings instance = GraphicsSettings._();

  GraphicsQuality _quality = GraphicsQuality.high;
  bool _reduceEffects = false;
  bool _auto = true;

  GraphicsQuality get current => _quality;
  bool get reduceEffects => _reduceEffects;
  bool get auto => _auto;

  void setQuality(GraphicsQuality q, {bool manual = true}) {
    if (manual) _auto = false;
    if (_quality == q) return;
    _quality = q;
    notifyListeners();
  }

  void setReduceEffects(bool v) {
    if (_reduceEffects == v) return;
    _reduceEffects = v;
    notifyListeners();
  }

  void setAuto(bool v) {
    _auto = v;
    notifyListeners();
  }

  /// Simple frame-time probe: when auto mode is on and the recent average frame
  /// build+raster time exceeds 20 ms (below 50 FPS) for a sustained window,
  /// step down one tier. Steps back up after a quiet period.
  FrameTimingMonitor? _monitor;
  void startAutoTuning() {
    _monitor ??= FrameTimingMonitor(onTooSlow: () {
      if (!_auto) return;
      if (_quality == GraphicsQuality.high) {
        setQuality(GraphicsQuality.medium, manual: false);
      } else if (_quality == GraphicsQuality.medium) {
        setQuality(GraphicsQuality.low, manual: false);
      }
    }, onFastAgain: () {
      if (!_auto) return;
      if (_quality == GraphicsQuality.low) setQuality(GraphicsQuality.medium, manual: false);
    })
      ..start();
  }

  void stopAutoTuning() {
    _monitor?.stop();
    _monitor = null;
  }
}

class FrameTimingMonitor {
  FrameTimingMonitor({required this.onTooSlow, required this.onFastAgain, this.slowThresholdMs = 20, this.window = 120});
  final VoidCallback onTooSlow;
  final VoidCallback onFastAgain;
  final double slowThresholdMs;
  final int window;
  final List<double> _samples = [];
  int _fastStreak = 0;
  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_running) return;
    _running = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _samples.add(t.totalSpan.inMicroseconds / 1000.0);
    }
    if (_samples.length < window) return;
    final avg = _samples.reduce((a, b) => a + b) / _samples.length;
    _samples.clear();
    if (avg > slowThresholdMs) {
      _fastStreak = 0;
      onTooSlow();
    } else {
      _fastStreak++;
      if (_fastStreak >= 5) {
        _fastStreak = 0;
        onFastAgain();
      }
    }
  }
}
