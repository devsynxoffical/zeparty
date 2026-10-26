import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import '../theme/zp_colors.dart';
import '../theme/zp_theme.dart';

/// Audio mix and graphics quality. Values live in [GraphicsSettings] and
/// [AudioSettings]; the host app persists them.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(ZpRadius.lg))),
        builder: (_) => const SettingsSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final g = GraphicsSettings.instance;
    final a = AudioSettings.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([g, a]),
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(ZpSpace.xl, ZpSpace.md, ZpSpace.xl, ZpSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ZpColors.divider, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: ZpSpace.lg),
              Text('Settings', style: t.headlineSmall),
              const SizedBox(height: ZpSpace.lg),
              Text('GRAPHICS', style: t.labelSmall?.copyWith(letterSpacing: 2, color: ZpColors.gold)),
              const SizedBox(height: ZpSpace.sm),
              SegmentedButton<GraphicsQuality>(
                segments: const [
                  ButtonSegment(value: GraphicsQuality.low, label: Text('Low')),
                  ButtonSegment(value: GraphicsQuality.medium, label: Text('Medium')),
                  ButtonSegment(value: GraphicsQuality.high, label: Text('High')),
                ],
                selected: {g.current},
                onSelectionChanged: (v) => g.setQuality(v.first),
                style: SegmentedButton.styleFrom(selectedBackgroundColor: ZpColors.gold, selectedForegroundColor: ZpColors.obsidian, foregroundColor: ZpColors.textSecondary),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Adapt automatically'),
                subtitle: const Text('Lower quality when frame rate drops'),
                value: g.auto,
                activeThumbColor: ZpColors.gold,
                onChanged: g.setAuto,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reduce visual effects'),
                subtitle: const Text('Fewer particles and shorter animations'),
                value: g.reduceEffects,
                activeThumbColor: ZpColors.gold,
                onChanged: g.setReduceEffects,
              ),
              const SizedBox(height: ZpSpace.md),
              Text('AUDIO', style: t.labelSmall?.copyWith(letterSpacing: 2, color: ZpColors.gold)),
              _Slider(label: 'Sound effects', value: a.sfxVolume, onChanged: a.setSfxVolume),
              _Slider(label: 'Music', value: a.musicVolume, onChanged: a.setMusicVolume),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Duck music while people talk'),
                subtitle: const Text('Keeps voice chat clear'),
                value: a.duckForVoice,
                activeThumbColor: ZpColors.gold,
                onChanged: a.setDuckForVoice,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Haptics'),
                value: a.haptics,
                activeThumbColor: ZpColors.gold,
                onChanged: a.setHaptics,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({required this.label, required this.value, required this.onChanged});
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(width: 110, child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
        Expanded(child: Slider(value: value, onChanged: onChanged, activeColor: ZpColors.gold, inactiveColor: ZpColors.gold.withValues(alpha: 0.2))),
        SizedBox(width: 36, child: Text('${(value * 100).round()}', textAlign: TextAlign.end, style: Theme.of(context).textTheme.labelMedium)),
      ]);
}

/// Audio preferences shared by every game. Mixing: effective music volume is
/// musicVolume * (voiceActive && duckForVoice ? 0.25 : 1).
class AudioSettings extends ChangeNotifier {
  AudioSettings._();
  static final AudioSettings instance = AudioSettings._();
  double _sfx = 0.9;
  double _music = 0.5;
  bool _duck = true;
  bool _haptics = true;
  bool _voiceActive = false;

  double get sfxVolume => _sfx;
  double get musicVolume => _music;
  bool get duckForVoice => _duck;
  bool get haptics => _haptics;
  bool get voiceActive => _voiceActive;
  double get effectiveMusicVolume => _music * (_voiceActive && _duck ? 0.25 : 1);

  void setSfxVolume(double v) {
    _sfx = v;
    notifyListeners();
  }

  void setMusicVolume(double v) {
    _music = v;
    notifyListeners();
  }

  void setDuckForVoice(bool v) {
    _duck = v;
    notifyListeners();
  }

  void setHaptics(bool v) {
    _haptics = v;
    notifyListeners();
  }

  /// Called by the host bridge listener when the voice room has active speech.
  void setVoiceActive(bool v) {
    if (_voiceActive == v) return;
    _voiceActive = v;
    notifyListeners();
  }
}
