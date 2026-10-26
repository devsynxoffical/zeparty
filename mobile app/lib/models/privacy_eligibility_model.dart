class FeatureEligibility {
  final bool eligible;
  final String reason;
  final bool isEnabled;

  const FeatureEligibility({
    required this.eligible,
    required this.reason,
    this.isEnabled = false,
  });

  factory FeatureEligibility.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      final isEligible = json['eligible'] == true ||
          json['isEligible'] == true ||
          json['isLocked'] == false;
      final reason = (json['reason'] ?? json['eligibilityReason'] ?? '').toString();
      final isEnabled = json['isEnabled'] == true || json['enabled'] == true;
      return FeatureEligibility(
        eligible: isEligible,
        reason: reason.isNotEmpty ? reason : (isEligible ? 'Eligible' : 'Requires SVIP or Noble status upgrade'),
        isEnabled: isEnabled,
      );
    }
    return const FeatureEligibility(eligible: false, reason: 'Eligibility info not available');
  }

  FeatureEligibility copyWith({
    bool? eligible,
    String? reason,
    bool? isEnabled,
  }) {
    return FeatureEligibility(
      eligible: eligible ?? this.eligible,
      reason: reason ?? this.reason,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

class PrivacyEligibilityModel {
  final FeatureEligibility antiFollow;
  final FeatureEligibility failedToFind;
  final Map<String, FeatureEligibility> features;

  const PrivacyEligibilityModel({
    required this.antiFollow,
    required this.failedToFind,
    this.features = const {},
  });

  FeatureEligibility? getFeature(String key) => features[key.toUpperCase()];

  factory PrivacyEligibilityModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;

    FeatureEligibility? af;
    FeatureEligibility? ftf;
    final featureMap = <String, FeatureEligibility>{};

    if (data.containsKey('antiFollow')) {
      af = FeatureEligibility.fromJson(data['antiFollow']);
      featureMap['ANTI_FOLLOW'] = af;
    }
    if (data.containsKey('failedToFind')) {
      ftf = FeatureEligibility.fromJson(data['failedToFind']);
      featureMap['FAILED_TO_FIND'] = ftf;
    }

    if (data['items'] is List) {
      for (final it in (data['items'] as List)) {
        if (it is Map<String, dynamic>) {
          final k = it['key']?.toString().toUpperCase();
          if (k != null && k.isNotEmpty) {
            final feat = FeatureEligibility.fromJson(it);
            featureMap[k] = feat;
            if (k == 'ANTI_FOLLOW' && af == null) af = feat;
            if (k == 'FAILED_TO_FIND' && ftf == null) ftf = feat;
          }
        }
      }
    }

    return PrivacyEligibilityModel(
      antiFollow: af ?? const FeatureEligibility(eligible: false, reason: 'Requires higher tier'),
      failedToFind: ftf ?? const FeatureEligibility(eligible: false, reason: 'Requires higher tier'),
      features: featureMap,
    );
  }

  PrivacyEligibilityModel copyWith({
    FeatureEligibility? antiFollow,
    FeatureEligibility? failedToFind,
    Map<String, FeatureEligibility>? features,
  }) {
    return PrivacyEligibilityModel(
      antiFollow: antiFollow ?? this.antiFollow,
      failedToFind: failedToFind ?? this.failedToFind,
      features: features ?? this.features,
    );
  }
}
