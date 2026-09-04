import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../widgets/design/premium_card.dart';
import '../../../../widgets/design/gold_button.dart';
import '../../../../providers/auth_provider.dart';
import '../../models/p2p_order.dart';
import '../../providers/escrow_provider.dart';
import '../../../../providers/wallet_provider.dart';

class OrderDetailsScreen extends StatefulWidget {
  final P2POrder order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final TextEditingController _chatController = TextEditingController();
  final List<String> _chatMessages = ['System: Escrow created. Coins are locked securely.'];

  void _sendMessage() {
    if (_chatController.text.trim().isNotEmpty) {
      setState(() {
        _chatMessages.add('You: ${_chatController.text.trim()}');
        _chatController.clear();
      });
    }
  }

  void _markAsPaid() {
    context.read<EscrowProvider>().updateOrderStatus(widget.order.id, 'paid', paidAt: DateTime.now());
    setState(() {});
  }

  void _releaseCoins() {
    context.read<EscrowProvider>().updateOrderStatus(widget.order.id, 'released', completedAt: DateTime.now());
    context.read<WalletProvider>().releaseLockedCoins(widget.order.coins);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.getPrimary(isDark);
    final user = context.watch<AuthProvider>().currentUser;
    
    // We get the fresh order from provider if it updated
    final order = context.watch<EscrowProvider>().orders.firstWhere((o) => o.id == widget.order.id, orElse: () => widget.order);
    
    final isBuyer = user.id == order.buyerId;
    final isSeller = user.id == order.sellerId;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Header
                  PremiumCard(
                    padding: const EdgeInsets.all(20),
                    radius: 16,
                    gradient: AppColors.getBannerGradient(isDark),
                    child: Row(
                      children: [
                        Icon(
                          order.status == 'released' ? Icons.check_circle_rounded :
                          order.status == 'paid' ? Icons.access_time_filled_rounded :
                          Icons.lock_rounded,
                          color: primaryColor,
                          size: 40,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.status.toUpperCase(),
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                order.status == 'released' ? 'Trade Completed' :
                                order.status == 'paid' ? 'Waiting for seller to release coins' :
                                'Waiting for buyer payment',
                                style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Order Info
                  Text('Trade Information', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  PremiumCard(
                    padding: const EdgeInsets.all(16),
                    radius: 16,
                    child: Column(
                      children: [
                        _buildInfoRow('Fiat Amount', '${AppFormatters.formatCurrency(order.fiatAmount)} ${order.fiatCurrency}', isDark, primaryColor, boldVal: true),
                        const Divider(height: 24),
                        _buildInfoRow('Coin Amount', '${order.coins} 🪙', isDark, primaryColor, boldVal: true),
                        const Divider(height: 24),
                        _buildInfoRow('Payment Method', order.paymentMethod, isDark, primaryColor),
                        const Divider(height: 24),
                        _buildInfoRow(isBuyer ? 'Seller' : 'Buyer', isBuyer ? order.sellerName : order.buyerName, isDark, primaryColor),
                        const Divider(height: 24),
                        _buildInfoRow('Order ID', order.id, isDark, primaryColor),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Actions based on status
                  if (order.status == 'pending' && isBuyer)
                    SizedBox(
                      width: double.infinity,
                      child: GoldButton(
                        text: 'I have transferred the payment',
                        onPressed: _markAsPaid,
                      ),
                    ),
                  if (order.status == 'paid' && isSeller)
                    SizedBox(
                      width: double.infinity,
                      child: GoldButton(
                        text: 'Payment Received (Release Coins)',
                        onPressed: _releaseCoins,
                      ),
                    ),
                  if (order.status == 'pending' && isSeller)
                    Center(child: Text('Waiting for buyer to pay...', style: TextStyle(color: AppColors.getTextSecondary(isDark)))),
                  if (order.status == 'paid' && isBuyer)
                    Center(child: Text('Waiting for seller to release coins...', style: TextStyle(color: AppColors.getTextSecondary(isDark)))),
                  
                  const SizedBox(height: 30),
                  Text('Chat', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  // Mock Chat Messages
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.getCard(isDark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.getBorder(isDark)),
                    ),
                    child: ListView.builder(
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, index) {
                        final msg = _chatMessages[index];
                        final isSys = msg.startsWith('System:');
                        final isMe = msg.startsWith('You:');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            msg,
                            style: TextStyle(
                              color: isSys ? primaryColor : isMe ? AppColors.getTextPrimary(isDark) : AppColors.getTextSecondary(isDark),
                              fontStyle: isSys ? FontStyle.italic : FontStyle.normal,
                              fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Chat Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.getCard(isDark),
              border: Border(top: BorderSide(color: AppColors.getBorder(isDark))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: AppColors.getTextSecondary(isDark)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send_rounded, color: primaryColor),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, Color primaryColor, {bool boldVal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.getTextSecondary(isDark))),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value, 
            textAlign: TextAlign.right,
            style: TextStyle(color: boldVal ? primaryColor : AppColors.getTextPrimary(isDark), fontWeight: boldVal ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ],
    );
  }
}
