import 'package:flutter/material.dart';

class SVIPPrivilegeItem {
  final String id;
  final String name;
  final IconData icon;
  final String description;
  final int requiredLevel;
  final String category;

  const SVIPPrivilegeItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.requiredLevel,
    this.category = 'General',
  });
}

class SVIPPackage {
  final String id;
  final String name;
  final int points;
  final int priceCoins;
  final int bonusPoints;

  const SVIPPackage({
    required this.id,
    required this.name,
    required this.points,
    required this.priceCoins,
    this.bonusPoints = 0,
  });
}

class SVIPLevel {
  final int level;
  final String name;
  final int requiredPoints;
  final List<String> privilegeIds;
  final String badgeText;
  final List<Color> gradientColors;

  const SVIPLevel({
    required this.level,
    required this.name,
    required this.requiredPoints,
    required this.privilegeIds,
    required this.badgeText,
    required this.gradientColors,
  });
}

class SVIPAuditRecord {
  final String id;
  final String type; // 'recharge', 'manual_grant', 'upgrade', 'renewal', 'revoke'
  final int points;
  final int level;
  final DateTime timestamp;
  final String note;
  final String? operatorId;

  const SVIPAuditRecord({
    required this.id,
    required this.type,
    required this.points,
    required this.level,
    required this.timestamp,
    required this.note,
    this.operatorId,
  });
}
