class WalletDateGate {
  static const String restrictionNotice =
      'IMPORTANT NOTE: Withdrawals, transfers, and exchanges are available only on the 1st and 15th of each month.';

  static const String blockedMessage =
      'Available only on the 1st and 15th of each month.';

  static bool isDateAllowed([DateTime? date]) {
    final now = date ?? DateTime.now();
    return now.day == 1 || now.day == 15;
  }

  static String? validateDateForTransaction([DateTime? date]) {
    if (!isDateAllowed(date)) {
      return blockedMessage;
    }
    return null;
  }
}
