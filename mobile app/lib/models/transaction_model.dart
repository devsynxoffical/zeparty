class TransactionModel {
  final String id;
  final String title;
  final String type; // Recharge, Withdrawal, Gift Sent, Gift Received, Seller Distribution
  final double amount;
  final String currency; // Coins, Diamonds, RCoins, USD
  final String status; // Completed, Pending, Approved, Rejected
  final DateTime date;
  final String? proofUrl;
  final String? targetUserId;

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
  });
}
