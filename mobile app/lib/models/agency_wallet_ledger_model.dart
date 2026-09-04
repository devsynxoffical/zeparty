class AgencyWalletLedgerModel {
  final String transactionId;
  final String cycleId;
  final String agencyId;
  final String hostId;
  final int diamonds;
  final double usdAmount;
  final double commissionUsd;
  final String type; // 'Settlement', 'Transfer', 'Withdrawal', 'Adjustment', 'Deduction'
  final String status; // 'Pending', 'Approved', 'Completed', 'Rejected', 'Failed', 'Refunded'
  final String recipientChannel;
  final DateTime timestamp;

  const AgencyWalletLedgerModel({
    required this.transactionId,
    required this.cycleId,
    required this.agencyId,
    required this.hostId,
    required this.diamonds,
    required this.usdAmount,
    required this.commissionUsd,
    required this.type,
    this.status = 'Completed',
    this.recipientChannel = 'Wallet Transfer',
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'transactionId': transactionId,
        'cycleId': cycleId,
        'agencyId': agencyId,
        'hostId': hostId,
        'diamonds': diamonds,
        'usdAmount': usdAmount,
        'commissionUsd': commissionUsd,
        'type': type,
        'status': status,
        'recipientChannel': recipientChannel,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AgencyWalletLedgerModel.fromJson(Map<String, dynamic> json) => AgencyWalletLedgerModel(
        transactionId: json['transactionId'] ?? '',
        cycleId: json['cycleId'] ?? '',
        agencyId: json['agencyId'] ?? '',
        hostId: json['hostId'] ?? '',
        diamonds: json['diamonds'] ?? 0,
        usdAmount: (json['usdAmount'] ?? 0).toDouble(),
        commissionUsd: (json['commissionUsd'] ?? 0).toDouble(),
        type: json['type'] ?? 'Settlement',
        status: json['status'] ?? 'Completed',
        recipientChannel: json['recipientChannel'] ?? 'Wallet Transfer',
        timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      );
}
