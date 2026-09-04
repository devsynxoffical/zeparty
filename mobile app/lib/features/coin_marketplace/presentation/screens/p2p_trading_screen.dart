import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../providers/p2p_provider.dart';
import '../../providers/escrow_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/wallet_provider.dart';
import '../../models/p2p_offer.dart';
import '../../models/p2p_order.dart';
import '../../../../widgets/design/premium_card.dart';
import '../../../../widgets/design/gold_button.dart';
import '../../../../widgets/user_avatar.dart';
import 'order_details_screen.dart';

class P2PTradingScreen extends StatefulWidget {
  const P2PTradingScreen({super.key});

  @override
  State<P2PTradingScreen> createState() => _P2PTradingScreenState();
}

class _P2PTradingScreenState extends State<P2PTradingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.getPrimary(isDark);
    final p2p = context.watch<P2PProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('P2P Trading'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: AppColors.getTextSecondary(isDark),
          tabs: const [
            Tab(text: 'Buy Coins'),
            Tab(text: 'Sell Coins'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOfferList(p2p.sellOffers, isDark, primaryColor, isBuying: true),
          _buildOfferList(p2p.buyOffers, isDark, primaryColor, isBuying: false),
        ],
      ),
    );
  }

  Widget _buildOfferList(List<P2POffer> offers, bool isDark, Color primaryColor, {required bool isBuying}) {
    if (offers.isEmpty) {
      return Center(
        child: Text(
          'No offers available right now.',
          style: TextStyle(color: AppColors.getTextSecondary(isDark)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: offers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final offer = offers[index];
        return PremiumCard(
          padding: const EdgeInsets.all(16),
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(imageUrl: offer.sellerAvatar, radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.sellerName,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.getTextPrimary(isDark)),
                        ),
                        Row(
                          children: [
                            Text(
                              '${offer.availableCoins} Coins available',
                              style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark)),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.verified, size: 12, color: AppColors.success),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Price',
                        style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
                      ),
                      Text(
                        '${AppFormatters.formatCurrency(offer.fiatPricePerCoin)} / 🪙',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Limits: ${AppFormatters.formatCurrency(offer.minLimit.toDouble())} - ${AppFormatters.formatCurrency(offer.maxLimit.toDouble())}',
                          style: TextStyle(fontSize: 12, color: AppColors.getTextPrimary(isDark)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: offer.acceptedPaymentMethods.map((method) {
                            return Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                method,
                                style: TextStyle(fontSize: 10, color: primaryColor, fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  GoldButton(
                    text: isBuying ? 'Buy' : 'Sell',
                    expand: false,
                    height: 36,
                    radius: 8,
                    onPressed: () {
                      _showTradeDialog(context, offer, isBuying, isDark, primaryColor);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTradeDialog(BuildContext context, P2POffer offer, bool isBuying, bool isDark, Color primaryColor) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isBuying ? 'Buy Coins' : 'Sell Coins', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to place an order to ${isBuying ? 'buy' : 'sell'} coins. The other party will be notified.', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13)),
            const SizedBox(height: 20),
            Text('Merchant: ${offer.sellerName}', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold)),
            Text('Price: ${AppFormatters.formatCurrency(offer.fiatPricePerCoin)} / Coin', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Note: Real-time trading forms and escrows will be active upon confirmation.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('Cancel', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
          ),
          GoldButton(
            text: 'Confirm',
            expand: false,
            height: 40,
            onPressed: () {
              Navigator.pop(c);
              
              // Create mock order
              final user = context.read<AuthProvider>().currentUser;
              final order = P2POrder(
                id: const Uuid().v4(),
                offerId: offer.id,
                buyerId: isBuying ? user.id : offer.sellerId,
                buyerName: isBuying ? user.name : offer.sellerName,
                buyerAvatar: isBuying ? user.avatarUrl : offer.sellerAvatar,
                sellerId: isBuying ? offer.sellerId : user.id,
                sellerName: isBuying ? offer.sellerName : user.name,
                sellerAvatar: isBuying ? offer.sellerAvatar : user.avatarUrl,
                coins: offer.minLimit, // just a mock amount
                fiatAmount: offer.minLimit * offer.fiatPricePerCoin,
                fiatCurrency: offer.fiatCurrency,
                paymentMethod: offer.acceptedPaymentMethods.first,
                status: 'pending',
                createdAt: DateTime.now(),
              );

              // If I am selling my coins, lock them
              if (!isBuying) {
                final wallet = context.read<WalletProvider>();
                if (!wallet.lockCoins(offer.minLimit)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not enough coins to sell.')));
                  return;
                }
              }

              context.read<EscrowProvider>().createOrder(order);

              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order placed successfully!')));
              Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)));
            },
          ),
        ],
      ),
    );
  }
}
