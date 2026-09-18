class TransactionModel {
  final String id;
  final String title;
  final String type; // RECHARGE, GIFT_TRANSFER, ADJUSTMENT, WITHDRAWAL, ESCROW_LOCK, etc.
  final double amount;
  final String currency; // Coins, Diamonds, RCoins, USD
  final String status; // Completed, Pending, Approved, Rejected
  final DateTime date;
  final String? proofUrl;
  final String? targetUserId;
  final int? balanceAfter;
  final String? referenceId;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    required this.date,
    this.proofUrl,
    this.targetUserId,
    this.balanceAfter,
    this.referenceId,
  });

  factory TransactionModel.fromLedgerJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString() ?? 'TRANSACTION';
    final asset = json['asset']?.toString() ?? 'COINS';
    final rawAmount = double.tryParse(json['amount']?.toString() ?? '') ?? 0.0;
    final desc = json['description']?.toString() ?? '$asset $rawType';
    final date = json['createdAt'] != null
        ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
        : DateTime.now();
    final balAfter = int.tryParse(json['balanceAfter']?.toString() ?? '');

    String currencyFormatted = 'Coins';
    if (asset.toUpperCase() == 'DIAMONDS') {
      currencyFormatted = 'Diamonds';
    } else if (asset.toUpperCase() == 'USD' || asset.toUpperCase() == 'RCOINS') {
      currencyFormatted = asset;
    }

    return TransactionModel(
      id: json['id']?.toString() ?? 'tx_${date.millisecondsSinceEpoch}',
      title: desc,
      type: rawType,
      amount: rawAmount,
      currency: currencyFormatted,
      status: 'Completed',
      date: date,
      referenceId: json['referenceId']?.toString(),
      balanceAfter: balAfter,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'amount': amount,
      'currency': currency,
      'status': status,
      'date': date.toIso8601String(),
      'proofUrl': proofUrl,
      'targetUserId': targetUserId,
      'balanceAfter': balanceAfter,
      'referenceId': referenceId,
    };
  }
}
