/// Model representing user notification category preferences in backend
class NotificationPreferencesModel {
  final bool social;
  final bool live;
  final bool pk;
  final bool games;
  final bool events;
  final bool finance;
  final bool moderation;
  final bool support;
  final bool marketing;
  final bool system;

  const NotificationPreferencesModel({
    this.social = true,
    this.live = true,
    this.pk = true,
    this.games = true,
    this.events = true,
    this.finance = true,
    this.moderation = true,
    this.support = true,
    this.marketing = false,
    this.system = true,
  });

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      social: json['social'] as bool? ?? true,
      live: json['live'] as bool? ?? true,
      pk: json['pk'] as bool? ?? true,
      games: json['games'] as bool? ?? true,
      events: json['events'] as bool? ?? true,
      finance: json['finance'] as bool? ?? true,
      moderation: json['moderation'] as bool? ?? true,
      support: json['support'] as bool? ?? true,
      marketing: json['marketing'] as bool? ?? false,
      system: json['system'] as bool? ?? true,
    );
  }

  NotificationPreferencesModel copyWith({
    bool? social,
    bool? live,
    bool? pk,
    bool? games,
    bool? events,
    bool? finance,
    bool? moderation,
    bool? support,
    bool? marketing,
    bool? system,
  }) {
    return NotificationPreferencesModel(
      social: social ?? this.social,
      live: live ?? this.live,
      pk: pk ?? this.pk,
      games: games ?? this.games,
      events: events ?? this.events,
      finance: finance ?? this.finance,
      moderation: moderation ?? this.moderation,
      support: support ?? this.support,
      marketing: marketing ?? this.marketing,
      system: system ?? this.system,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'social': social,
      'live': live,
      'pk': pk,
      'games': games,
      'events': events,
      'finance': finance,
      'moderation': moderation,
      'support': support,
      'marketing': marketing,
      'system': system,
    };
  }
}
