enum TransactionDirection { credit, debit }

class CategorizedTransactionModel {
  final String transactionId;
  final String category; // 'All', 'Host Salary', 'Agent Salary', 'Transfer', 'Exchange', 'Withdrawal', 'Gift/Reward', 'Refund/Reversal'
  final double amount;
  final String currency; // 'Diamonds', 'Coins', 'USD'
  final TransactionDirection direction;
  final String senderName;
  final String senderId;
  final String receiverName;
  final String receiverId;
  final String? roomId;
  final String? giftName;
  final double balanceBefore;
  final double balanceAfter;
  final String status; // 'Completed', 'Pending', 'Failed', 'Rejected', 'Reversed', 'Refunded'
  final DateTime timestamp;
  final String reason;
  
  // Extended Receipt Fields for Module 21
  final double fee;
  final double? exchangeRate;
  final String timezone;
  final String? failureReason;
  final String? reversalReason;
  
  // Salary Receipt Fields
  final String? settlementType; // 'Host', 'Agent', 'Member'
  final String? targetCycle; // e.g. '2026-08 Cycle 1 (1st-15th)'
  final String? earningSource; // e.g. 'Live Streaming Gifts & PK Battles'
  final String? settlementRef;
  
  // Exchange Receipt Fields
  final double? inputAmount;
  final double? outputAmount;
  final String? inputCurrency;
  final String? outputCurrency;
  final String? configVersion;

  const CategorizedTransactionModel({
    required this.transactionId,
    required this.category,
    required this.amount,
    this.currency = 'Diamonds',
    required this.direction,
    required this.senderName,
    required this.senderId,
    required this.receiverName,
    required this.receiverId,
    this.roomId,
    this.giftName,
    required this.balanceBefore,
    required this.balanceAfter,
    this.status = 'Completed',
    required this.timestamp,
    this.reason = 'Standard Transaction',
    this.fee = 0.0,
    this.exchangeRate,
    this.timezone = 'UTC+0',
    this.failureReason,
    this.reversalReason,
    this.settlementType,
    this.targetCycle,
    this.earningSource,
    this.settlementRef,
    this.inputAmount,
    this.outputAmount,
    this.inputCurrency,
    this.outputCurrency,
    this.configVersion,
  });

  String get signedAmountString {
    final sign = direction == TransactionDirection.credit ? '+' : '-';
    return '$sign${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)} $currency';
  }

  String get formattedDate {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
  }

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }
}

