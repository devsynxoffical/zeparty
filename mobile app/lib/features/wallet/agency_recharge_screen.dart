import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/coin_agency_provider.dart';
import '../../models/coin_seller_model.dart';
import '../../widgets/user_avatar.dart';

class AgencyRechargeScreen extends StatefulWidget {
  const AgencyRechargeScreen({super.key});

  @override
  State<AgencyRechargeScreen> createState() => _AgencyRechargeScreenState();
}

class _AgencyRechargeScreenState extends State<AgencyRechargeScreen> {
  final _searchController = TextEditingController();
  final List<String> _regions = ['All', 'Global', 'Middle East', 'Asia', 'Europe', 'Americas'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final provider = context.watch<CoinAgencyProvider>();
    final sellers = provider.filteredSellers;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Authorized Sellers'),
        backgroundColor: AppColors.getBackground(isDark),
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search sellers by name or ID...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.getSurface(isDark),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: provider.setSearchQuery,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _regions.length,
                    itemBuilder: (context, index) {
                      final region = _regions[index];
                      final isSelected = provider.selectedRegion == region;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(region),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) provider.setRegionFilter(region);
                          },
                          selectedColor: primary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: isSelected ? primary : AppColors.getTextSecondary(isDark),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Sellers List
          Expanded(
            child: sellers.isEmpty
                ? Center(
                    child: Text(
                      'No approved sellers found.',
                      style: TextStyle(color: AppColors.getTextSecondary(isDark)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sellers.length,
                    itemBuilder: (context, index) {
                      final seller = sellers[index];
                      return _buildSellerCard(seller, isDark, primary);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerCard(CoinSellerModel seller, bool isDark, Color primary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorder(isDark)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(imageUrl: seller.avatarUrl, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            seller.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (seller.type == SellerType.official || seller.type == SellerType.verified) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified, color: seller.type == SellerType.official ? Colors.blue : Colors.green, size: 16),
                        ]
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${seller.userId} • ${seller.region}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Contacting ${seller.name} for purchase...')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  minimumSize: const Size(70, 36),
                ),
                child: const Text('BUY'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.payment, size: 16, color: AppColors.getTextSecondary(isDark)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  seller.paymentMethods.join(' • '),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Stock: ${(seller.stockCoins / 1000).toStringAsFixed(1)}K',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
