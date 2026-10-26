import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/coin_agency_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/coin_seller_model.dart';
import '../../widgets/user_avatar.dart';

class AgencyRechargeScreen extends StatefulWidget {
  const AgencyRechargeScreen({super.key});

  @override
  State<AgencyRechargeScreen> createState() => _AgencyRechargeScreenState();
}

class _AgencyRechargeScreenState extends State<AgencyRechargeScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final fallback = auth.currentUser.region.isNotEmpty ? auth.currentUser.region : 'Pakistan';
      final agencyProv = context.read<CoinAgencyProvider>();
      await agencyProv.initSelectedCountry(fallback);
      agencyProv.fetchSellers();
    });
  }

  void _showCountrySelectionModal(BuildContext context, CoinAgencyProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final countries = [
      {'name': 'Pakistan', 'flag': '🇵🇰'},
      {'name': 'United States', 'flag': '🇺🇸'},
      {'name': 'United Kingdom', 'flag': '🇬🇧'},
      {'name': 'UAE', 'flag': '🇦🇪'},
      {'name': 'Saudi Arabia', 'flag': '🇸🇦'},
      {'name': 'Canada', 'flag': '🇨🇦'},
      {'name': 'Australia', 'flag': '🇦🇺'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getSurface(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Country',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              const SizedBox(height: 12),
              ...countries.map((c) {
                final isSelected = CoinAgencyProvider.isCountryMatch(c['name'], provider.currentUserCountry);
                return ListTile(
                  leading: Text(c['flag']!, style: const TextStyle(fontSize: 22)),
                  title: Text(
                    c['name']!,
                    style: TextStyle(
                      color: AppColors.getTextPrimary(isDark),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    provider.setUserCountry(c['name']);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<CoinAgencyProvider>();
    final userCountry = provider.countryDisplayName;
    final sellers = provider.getSellersForCountry(provider.currentUserCountry ?? auth.currentUser.region);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Authorized Sellers'),
        backgroundColor: AppColors.getBackground(isDark),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchSellers(),
        child: Column(
          children: [
            // Search & Country Info Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search sellers by name or ID...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                provider.setSearchQuery('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.getSurface(isDark),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: provider.setSearchQuery,
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _showCountrySelectionModal(context, provider),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 14, color: Colors.amberAccent),
                          const SizedBox(width: 6),
                          Text(
                            'Showing Authorized Sellers for $userCountry',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, size: 16, color: Colors.amberAccent),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Sellers List / Loading / Error / Empty States
            Expanded(
              child: Builder(
                builder: (context) {
                  if (provider.isLoading && sellers.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.hasError && sellers.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.redAccent),
                            const SizedBox(height: 12),
                            Text(
                              'Failed to connect to Authorized Sellers Directory',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.getTextPrimary(isDark),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              provider.errorMessage ?? 'Please check your connection.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.getTextSecondary(isDark),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => provider.fetchSellers(),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (sellers.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.storefront_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'No authorized coin sellers available in your country',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.getTextSecondary(isDark),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return NotificationListener<ScrollNotification>(
                    onNotification: (scrollInfo) {
                      if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                        provider.loadMoreSellers();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: sellers.length + (provider.isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == sellers.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final seller = sellers[index];
                        return _buildSellerCard(seller, isDark, primary);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerCard(CoinSellerModel seller, bool isDark, Color primary) {
    final displayName = seller.effectiveName;
    final displayPublicId = seller.effectivePublicId;
    final displayAvatar = seller.effectiveAvatar;
    final countryFlag = seller.countryFlag;

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
              UserAvatar(imageUrl: displayAvatar, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (countryFlag.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(countryFlag, style: const TextStyle(fontSize: 14)),
                        ],
                        if (seller.type == SellerType.official || seller.type == SellerType.verified) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified, color: seller.type == SellerType.official ? Colors.blue : Colors.green, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: $displayPublicId • ${seller.region.isNotEmpty ? seller.region : (seller.countryName.isNotEmpty ? seller.countryName : 'Verified')}',
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
                    SnackBar(content: Text('Contacting $displayName for purchase...')),
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
                  seller.paymentMethods.isNotEmpty
                      ? seller.paymentMethods.join(' • ')
                      : 'Direct Transfer • Bank Transfer',
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
