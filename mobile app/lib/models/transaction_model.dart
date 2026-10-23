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
  final String? senderName;
  final String? receiverName;

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
    this.senderName,
    this.receiverName,
  });

  String get displayTransactionId => (referenceId != null && referenceId!.isNotEmpty) ? referenceId! : id;

  factory TransactionModel.fromLedgerJson(Map<String, dynamic> json) {
    final rawType = json['category']?.toString() ?? json['type']?.toString() ?? 'TRANSACTION';
    final asset = json['asset']?.toString() ?? 'COINS';

    // Amount & direction handling (CREDIT = positive, DEBIT = negative)
    final entryType = json['entryType']?.toString().toUpperCase();
    final direction = json['direction']?.toString().toUpperCase();
    double rawAmount = double.tryParse(json['amount']?.toString() ?? json['amountCoins']?.toString() ?? '') ?? 0.0;
    if (entryType == 'DEBIT' || direction == 'DEBIT' || direction == 'EXPENSE' || direction == 'EXPENSES') {
      if (rawAmount > 0) rawAmount = -rawAmount;
    } else if (entryType == 'CREDIT' || direction == 'CREDIT' || direction == 'INCOME') {
      if (rawAmount < 0) rawAmount = -rawAmount;
    }

    final desc = json['description']?.toString() ?? json['title']?.toString() ?? '$asset $rawType';
    final date = json['createdAt'] != null
        ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
        : (json['date'] != null ? (DateTime.tryParse(json['date'].toString()) ?? DateTime.now()) : DateTime.now());
    final balAfter = int.tryParse(json['balanceAfter']?.toString() ?? '');

    final counterparty = json['counterparty'] is Map<String, dynamic> ? json['counterparty'] as Map<String, dynamic> : null;
    final targetUser = counterparty?['displayName']?.toString() ??
        counterparty?['name']?.toString() ??
        counterparty?['username']?.toString() ??
        counterparty?['publicId']?.toString() ??
        json['targetUserId']?.toString();

    final sName = json['senderName']?.toString() ?? json['sellerName']?.toString() ?? counterparty?['senderName']?.toString();
    final rName = json['receiverName']?.toString() ?? json['recipientName']?.toString() ?? counterparty?['receiverName']?.toString();

    final ref = json['referenceId']?.toString() ?? json['transactionId']?.toString();
    final realId = json['id']?.toString() ?? ref ?? '';

    String currencyFormatted = 'Coins';
    if (asset.toUpperCase() == 'DIAMONDS') {
      currencyFormatted = 'Diamonds';
    } else if (asset.toUpperCase() == 'USD' || asset.toUpperCase() == 'RCOINS') {
      currencyFormatted = asset;
    }

    return TransactionModel(
      id: realId,
      title: desc,
      type: rawType,
      amount: rawAmount,
      currency: currencyFormatted,
      status: json['status']?.toString() ?? 'Completed',
      date: date,
      targetUserId: targetUser,
      referenceId: ref,
      balanceAfter: balAfter,
      senderName: sName,
      receiverName: rName,
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
