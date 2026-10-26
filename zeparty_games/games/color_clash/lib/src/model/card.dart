import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

/// The four Color Clash colours plus the colourless slot of Prism / Prism Surge / Echo.
enum CcColor {
  ruby,
  sapphire,
  emerald,
  gold,
  wild;

  static CcColor parse(String s) => CcColor.values.firstWhere((c) => c.name == s, orElse: () => CcColor.wild);

  bool get isWild => this == CcColor.wild;

  /// Display colour for faces, glows and the colour picker.
  Color get color => switch (this) {
        CcColor.ruby => const Color(0xFFE7345B),
        CcColor.sapphire => const Color(0xFF3B7BFF),
        CcColor.emerald => const Color(0xFF22C58A),
        CcColor.gold => ZpColors.goldLight,
        CcColor.wild => const Color(0xFFB08CFF),
      };

  Color get deep => switch (this) {
        CcColor.ruby => const Color(0xFF7A1230),
        CcColor.sapphire => const Color(0xFF14307A),
        CcColor.emerald => const Color(0xFF0B5A3C),
        CcColor.gold => const Color(0xFF7A5A0F),
        CcColor.wild => const Color(0xFF2E1A5C),
      };

  String get label => switch (this) {
        CcColor.ruby => 'Ruby',
        CcColor.sapphire => 'Sapphire',
        CcColor.emerald => 'Emerald',
        CcColor.gold => 'Gold',
        CcColor.wild => 'Prism',
      };

  static const List<CcColor> playable = [CcColor.ruby, CcColor.sapphire, CcColor.emerald, CcColor.gold];
}

enum CcKind {
  number,
  skip,
  flip,
  surge,
  prism,
  prismSurge,
  echo;

  static CcKind parse(String s) => switch (s) {
        'number' => CcKind.number,
        'skip' => CcKind.skip,
        'flip' => CcKind.flip,
        'surge' => CcKind.surge,
        'prism' => CcKind.prism,
        'prism_surge' => CcKind.prismSurge,
        'echo' => CcKind.echo,
        _ => CcKind.number,
      };

  String get wire => switch (this) { CcKind.prismSurge => 'prism_surge', _ => name };

  bool get isWild => this == CcKind.prism || this == CcKind.prismSurge;

  String get label => switch (this) {
        CcKind.number => '',
        CcKind.skip => 'Skip',
        CcKind.flip => 'Flip',
        CcKind.surge => 'Surge +2',
        CcKind.prism => 'Prism',
        CcKind.prismSurge => 'Prism Surge +4',
        CcKind.echo => 'Echo',
      };
}

/// One card as the server describes it.
class CcCard {
  const CcCard({required this.id, required this.color, required this.kind, this.value});
  final String id;
  final CcColor color;
  final CcKind kind;
  final int? value;

  factory CcCard.fromJson(Map<String, dynamic> j) => CcCard(
        id: j['id'] as String,
        color: CcColor.parse(j['color'] as String),
        kind: CcKind.parse(j['kind'] as String),
        value: j['value'] as int?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'color': color.name, 'kind': kind.wire, if (value != null) 'value': value};

  bool get isNumber => kind == CcKind.number;

  /// Points this card is worth to the round winner if left in a hand.
  int get points => switch (kind) {
        CcKind.number => value ?? 0,
        CcKind.prism || CcKind.prismSurge => 50,
        _ => 20,
      };

  /// Short glyph shown on the face (number or symbol fallback text).
  String get glyph => switch (kind) {
        CcKind.number => '${value ?? 0}',
        CcKind.surge => '+2',
        CcKind.prismSurge => '+4',
        _ => '',
      };

  @override
  bool operator ==(Object other) => other is CcCard && other.id == id;
  @override
  int get hashCode => id.hashCode;
  @override
  String toString() => 'CcCard($id ${color.name} ${kind.name}${value == null ? '' : ' $value'})';
}

/// Client mirror of the server legality rule (hint rendering only; the server decides).
/// Mirrors `cardPlayable` in backend/src/games/color_clash/engine.ts and is checked
/// against tests/fixtures/color_clash_views.json.
bool cardPlayable({required CcCard? top, required CcColor currentColor, required int? echoNumber, required int pendingDraw, required List<CcCard> hand, required CcCard card}) {
  if (top == null) return false;
  final holdsColor = hand.any((c) => c.color == currentColor);
  if (pendingDraw > 0) {
    if (card.kind != top.kind) return false;
    if (card.kind == CcKind.prismSurge) return !holdsColor;
    return card.kind == CcKind.surge;
  }
  if (echoNumber != null) return card.isNumber && card.value == echoNumber;
  switch (card.kind) {
    case CcKind.prism:
    case CcKind.echo:
      return true;
    case CcKind.prismSurge:
      return !holdsColor;
    case CcKind.number:
      return card.color == currentColor || (top.isNumber && top.value == card.value);
    default:
      return card.color == currentColor || top.kind == card.kind;
  }
}
