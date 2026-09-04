import 'package:flutter/material.dart';

class NoblePrivilege {
  final String id;
  final String name;
  final IconData icon;
  final String description;
  final String category; // 'display', 'mic', 'functional'

  const NoblePrivilege({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.category = 'functional',
  });
}

class NobleRank {
  final String id;
  final String name;
  final int requiredSentCoins;
  final int firstMonthCost;
  final int returnPercentage;
  final int durationDays;
  final List<Color> colors;
  final String badgeAsset;
  final List<NoblePrivilege> privileges;

  const NobleRank({
    required this.id,
    required this.name,
    required this.requiredSentCoins,
    required this.firstMonthCost,
    required this.returnPercentage,
    required this.durationDays,
    required this.colors,
    required this.badgeAsset,
    required this.privileges,
  });

  int get returnedCoins => (firstMonthCost * (returnPercentage / 100)).round();
}

class NobleAuditRecord {
  final String id;
  final String rankId;
  final String type; // 'auto_sent_coins', 'purchase', 'manual_grant', 'upgrade', 'renewal', 'revoke'
  final DateTime timestamp;
  final String note;
  final String? operatorId;

  const NobleAuditRecord({
    required this.id,
    required this.rankId,
    required this.type,
    required this.timestamp,
    required this.note,
    this.operatorId,
  });
}
