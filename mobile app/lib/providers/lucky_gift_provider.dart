import 'dart:math';
import 'package:flutter/material.dart';
import '../models/lucky_gift_model.dart';
import 'wallet_provider.dart';

class LuckyGiftProvider extends ChangeNotifier {
  final List<LuckyGiftModel> _luckyGifts = [];
  final List<LuckyGiftResultModel> _luckyHistory = [];
  final List<Map<String, dynamic>> _roomMarqueeAnnouncements = [];

  List<LuckyGiftModel> get luckyGifts => List.unmodifiable(_luckyGifts);
  List<LuckyGiftResultModel> get luckyHistory => List.unmodifiable(_luckyHistory);
  List<Map<String, dynamic>> get roomMarqueeAnnouncements => List.unmodifiable(_roomMarqueeAnnouncements);

  LuckyGiftProvider() {
    _initMockLuckyGifts();
  }

  void _initMockLuckyGifts() {
    _luckyGifts.addAll([
      const LuckyGiftModel(
        id: 'lg_1',
        name: 'Lucky Crown',
        icon: '👑',
        animationUrl: 'assets/animations/lucky_crown.json',
        coinPrice: 50,
        badge: '100× JACKPOT',
        maxMultiplier: 100,
        rewardTable: [
          LuckyMultiplierTier(multiplier: 2, probability: 0.50, label: '2× Multiplier'),
          LuckyMultiplierTier(multiplier: 5, probability: 0.30, label: '5× Multiplier'),
          LuckyMultiplierTier(multiplier: 10, probability: 0.15, label: '10× Super Win'),
          LuckyMultiplierTier(multiplier: 50, probability: 0.04, label: '50× Mega Win'),
          LuckyMultiplierTier(multiplier: 100, probability: 0.01, label: '100× Grand Jackpot!'),
        ],
      ),
      const LuckyGiftModel(
        id: 'lg_2',
        name: 'Lucky Dragon',
        icon: '🐉',
        animationUrl: 'assets/animations/lucky_dragon.json',
        coinPrice: 200,
        badge: '500× JACKPOT',
        maxMultiplier: 500,
        rewardTable: [
          LuckyMultiplierTier(multiplier: 2, probability: 0.50, label: '2× Multiplier'),
          LuckyMultiplierTier(multiplier: 10, probability: 0.30, label: '10× Multiplier'),
          LuckyMultiplierTier(multiplier: 50, probability: 0.15, label: '50× Super Win'),
          LuckyMultiplierTier(multiplier: 200, probability: 0.04, label: '200× Mega Win'),
          LuckyMultiplierTier(multiplier: 500, probability: 0.01, label: '500× Grand Jackpot!'),
        ],
      ),
      const LuckyGiftModel(
        id: 'lg_3',
        name: 'Lucky Rocket',
        icon: '🚀',
        animationUrl: 'assets/animations/lucky_rocket.json',
        coinPrice: 1000,
        badge: '1000× JACKPOT',
        maxMultiplier: 1000,
        rewardTable: [
          LuckyMultiplierTier(multiplier: 5, probability: 0.50, label: '5× Multiplier'),
          LuckyMultiplierTier(multiplier: 20, probability: 0.30, label: '20× Multiplier'),
          LuckyMultiplierTier(multiplier: 100, probability: 0.15, label: '100× Super Win'),
          LuckyMultiplierTier(multiplier: 500, probability: 0.04, label: '500× Mega Win'),
          LuckyMultiplierTier(multiplier: 1000, probability: 0.01, label: '1000× Grand Jackpot!'),
        ],
      ),
    ]);
  }

  // Server-Authoritative Lucky Gift Send & Spin Logic
  Future<LuckyGiftResultModel?> sendLuckyGift({
    required LuckyGiftModel gift,
    required String senderId,
    required String senderName,
    required String recipientId,
    required String recipientName,
    required int quantity,
    required WalletProvider wallet,
  }) async {
    final totalCost = gift.coinPrice * quantity;

    // Check balance
    if (wallet.coins < totalCost) return null;

    // Atomic Wallet Deduction
    final ok = wallet.spendCoins(totalCost);
    if (!ok) return null;

    // Server-Authoritative Lucky Multiplier Calculation
    final rng = Random();
    final randVal = rng.nextDouble();
    int wonMultiplier = gift.rewardTable.first.multiplier;
    double cumulative = 0.0;

    for (final tier in gift.rewardTable) {
      cumulative += tier.probability;
      if (randVal <= cumulative) {
        wonMultiplier = tier.multiplier;
        break;
      }
    }

    final coinsWon = totalCost * wonMultiplier;

    // Reward Credit back to Sender Wallet
    wallet.spendCoins(-coinsWon);

    final result = LuckyGiftResultModel(
      transactionId: 'tx_lucky_${DateTime.now().millisecondsSinceEpoch}',
      giftId: gift.id,
      giftName: gift.name,
      senderId: senderId,
      senderName: senderName,
      recipientId: recipientId,
      recipientName: recipientName,
      quantity: quantity,
      totalCostCoins: totalCost,
      multiplierWon: wonMultiplier,
      coinsWon: coinsWon,
      timestamp: DateTime.now(),
    );

    _luckyHistory.insert(0, result);

    // Create Room Activity Banner / Marquee Announcement if win >= 10x
    if (wonMultiplier >= 10) {
      _roomMarqueeAnnouncements.insert(0, {
        'id': 'marq_${DateTime.now().millisecondsSinceEpoch}',
        'text': '$senderName sent ${gift.name} ×$quantity to $recipientName and won $wonMultiplier× ($coinsWon Coins)!',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    notifyListeners();
    return result;
  }
}
