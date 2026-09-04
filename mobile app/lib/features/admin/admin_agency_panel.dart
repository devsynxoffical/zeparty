import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/coin_agency_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/live_host_provider.dart';
import '../../models/coin_seller_model.dart';
import '../../widgets/user_avatar.dart';

class AdminAgencyPanel extends StatefulWidget {
  const AdminAgencyPanel({super.key});

  @override
  State<AdminAgencyPanel> createState() => _AdminAgencyPanelState();
}

class _AdminAgencyPanelState extends State<AdminAgencyPanel> {
  late List<TextEditingController> _targetControllers;
  late TextEditingController _themePriceController;
  late TextEditingController _annTitleController;
  late TextEditingController _annTextController;
  late TextEditingController _dpUrlController;
  late TextEditingController _modRoomIdController;
  late bool _paidThemeEnabled;

  @override
  void initState() {
    super.initState();
    final gameProvider = context.read<GameProvider>();
    _initControllers(gameProvider.rocketLevelTargets);
    _themePriceController = TextEditingController(text: gameProvider.customRoomThemeUploadPrice.toString());
    _annTitleController = TextEditingController(text: '📢 Platform Mandatory Notice');
    _annTextController = TextEditingController(text: 'Welcome to ZeParty! Please follow platform guidelines.');
    _dpUrlController = TextEditingController(text: gameProvider.globalDefaultRoomDp);
    _modRoomIdController = TextEditingController();
    _paidThemeEnabled = gameProvider.paidRoomThemeUploadsEnabled;
  }

  void _initControllers(List<int> targets) {
    _targetControllers = List.generate(
      5,
      (i) => TextEditingController(text: targets.length > i ? targets[i].toString() : '0'),
    );
  }

  @override
  void dispose() {
    for (var controller in _targetControllers) {
      controller.dispose();
    }
    _themePriceController.dispose();
    _annTitleController.dispose();
    _annTextController.dispose();
    _dpUrlController.dispose();
    _modRoomIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final sellerProvider = context.watch<CoinAgencyProvider>();
    final gameProvider = context.watch<GameProvider>();
    final sellers = sellerProvider.sellers;

    return DefaultTabController(
      length: 11,
      child: Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          title: const Text('Admin Management Console'),
          backgroundColor: AppColors.getBackground(isDark),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.people_alt_rounded), text: 'Sellers'),
              Tab(icon: Icon(Icons.rocket_launch_rounded), text: 'Rocket Game'),
              Tab(icon: Icon(Icons.wallpaper_rounded), text: 'Room Theme Fee'),
              Tab(icon: Icon(Icons.campaign_rounded), text: 'Mic Size & Announcements'),
              Tab(icon: Icon(Icons.admin_panel_settings_rounded), text: 'Room DP Moderation'),
              Tab(icon: Icon(Icons.settings_suggest_rounded), text: 'Room Owner Options'),
              Tab(icon: Icon(Icons.view_carousel_rounded), text: 'Top Banner Carousel'),
              Tab(icon: Icon(Icons.favorite_rounded), text: 'Relationship Store'),
              Tab(icon: Icon(Icons.video_camera_front_rounded), text: 'Direct Live Hosts'),
              Tab(icon: Icon(Icons.flash_on_rounded), text: 'Recharge & Merchant'),
              Tab(icon: Icon(Icons.casino_rounded), text: 'Lucky Gifts Manager'),
            ],
          ),
          actions: [
            Builder(
              builder: (context) {
                final tabIndex = DefaultTabController.of(context).index;
                if (tabIndex == 0) {
                  return IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showEditSellerDialog(context, null),
                    tooltip: 'Add Seller',
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // Tab 1: Sellers Management
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sellers.length,
              itemBuilder: (context, index) {
                final seller = sellers[index];
                return _buildAdminSellerCard(context, seller, isDark, primary, sellerProvider);
              },
            ),

            // Tab 2: Rocket Game Configuration
            _buildRocketGameConfigTab(context, gameProvider, isDark, primary),

            // Tab 3: Room Theme Upload Fee Configuration
            _buildRoomThemeConfigTab(context, gameProvider, isDark, primary),

            // Tab 4: Mic Size & Announcements Management (Module 03)
            _buildAnnouncementsConfigTab(context, gameProvider, isDark, primary),

            // Tab 5: Room DP Moderation & Fallbacks (Module 04)
            _buildRoomDpModerationTab(context, gameProvider, isDark, primary),

            // Tab 6: Room Features & Security Audit (Module 06)
            _buildRoomFeaturesSecurityTab(context, gameProvider, isDark, primary),

            // Tab 7: Event Banners Management (Module 09)
            _buildEventBannersAdminTab(context, isDark, primary),

            // Tab 8: Relationship Cards Store Management (Module 10)
            _buildRelationshipCardsAdminTab(context, isDark, primary),

            // Tab 9: Direct Live Host Application Review & Monitoring (Module 15)
            _buildDirectLiveHostsAdminTab(context, isDark, primary),
          ],
        ),
      ),
    );
  }

  Widget _buildRocketGameConfigTab(BuildContext context, GameProvider gameProvider, bool isDark, Color primary) {
    final currentTargets = gameProvider.rocketLevelTargets;
    
    // Sync controllers if externally changed
    for (int i = 0; i < 5; i++) {
      if (currentTargets.length > i && _targetControllers[i].text != currentTargets[i].toString()) {
        if (!_targetControllers[i].selection.isValid || _targetControllers[i].text.isEmpty) {
          _targetControllers[i].text = currentTargets[i].toString();
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppColors.getCard(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: primary.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.rocket_launch_rounded, color: primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rocket Game Level Targets',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                            ),
                            Text(
                              'Update active progression level targets dynamically without app release.',
                              style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  ...List.generate(5, (index) {
                    final levelNum = index + 1;
                    final currentVal = int.tryParse(_targetControllers[index].text) ?? 0;
                    final formattedPreview = GameProvider.formatRocketTarget(currentVal);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 84,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: primary.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              'Rocket $levelNum',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, color: primary, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _targetControllers[index],
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                              decoration: InputDecoration(
                                labelText: 'Level $levelNum Target',
                                hintText: 'e.g. 100000',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            constraints: const BoxConstraints(minWidth: 54),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.purpleAccent),
                            ),
                            child: Text(
                              formattedPreview,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final defaultTargets = [100000, 300000, 400000, 500000, 1000000];
                            for (int i = 0; i < 5; i++) {
                              _targetControllers[i].text = defaultTargets[i].toString();
                            }
                            gameProvider.updateRocketLevelTargets(defaultTargets);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reset to default Rocket targets (100K, 300K, 400K, 500K, 1M)')),
                            );
                            setState(() {});
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reset Defaults'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final newTargets = _targetControllers.map((c) => int.tryParse(c.text.trim()) ?? 0).toList();
                            final err = await gameProvider.updateRocketLevelTargets(newTargets);
                            if (!mounted) return;
                            if (err != null) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Validation Error: $err'), backgroundColor: Colors.redAccent),
                              );
                            } else {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('🎉 Rocket Game level targets updated & logged!'), backgroundColor: Colors.green),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: primary),
                          icon: const Icon(Icons.save_rounded, color: Colors.white),
                          label: const Text('Save Targets', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text(
            'Admin Change Audit Logs',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
          ),
          const SizedBox(height: 10),

          if (gameProvider.rocketAdminLogs.isEmpty)
            Card(
              color: AppColors.getCard(isDark),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No admin changes logged yet.')),
              ),
            )
          else
            ...gameProvider.rocketAdminLogs.take(10).map((log) {
              return Card(
                color: AppColors.getCard(isDark),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.history_rounded, color: Colors.cyan),
                  title: Text(log['action'] as String? ?? 'Admin Update', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${log['details']}\nBy ${log['admin']} on ${log['timestamp']}', style: const TextStyle(fontSize: 11)),
                  isThreeLine: true,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAdminSellerCard(BuildContext context, CoinSellerModel seller, bool isDark, Color primary, CoinAgencyProvider provider) {
    return Card(
      color: AppColors.getCard(isDark),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.getBorder(isDark)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                      Text(seller.name, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                      Text('${seller.userId} | ${seller.region}', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark))),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildChip(seller.status.name.toUpperCase(), seller.status == SellerStatus.approved ? Colors.green : Colors.orange),
                          _buildChip(seller.type.name.toUpperCase(), Colors.blue),
                        ],
                      )
                    ],
                  ),
                ),
                Switch(
                  value: seller.isVisible,
                  activeThumbColor: primary,
                  onChanged: (val) {
                    provider.updateSeller(seller.copyWith(isVisible: val));
                  },
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: AppColors.getTextSecondary(isDark)),
                  onPressed: () => _showEditSellerDialog(context, seller),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Stock: ${seller.stockCoins}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                Row(
                  children: [
                    TextButton(
                      onPressed: seller.status == SellerStatus.suspended
                          ? null
                          : () {
                              provider.updateSeller(seller.copyWith(status: SellerStatus.suspended));
                            },
                      child: const Text('Suspend', style: TextStyle(color: Colors.red)),
                    ),
                    TextButton(
                      onPressed: seller.status == SellerStatus.approved
                          ? null
                          : () {
                              provider.updateSeller(seller.copyWith(status: SellerStatus.approved));
                            },
                      child: const Text('Approve', style: TextStyle(color: Colors.green)),
                    ),
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  void _showEditSellerDialog(BuildContext context, CoinSellerModel? seller) {
    final nameCtrl = TextEditingController(text: seller?.name);
    final stockCtrl = TextEditingController(text: seller?.stockCoins.toString() ?? '0');
    final provider = context.read<CoinAgencyProvider>();

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(seller == null ? 'New Seller' : 'Edit Seller'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock Coins')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newStock = int.tryParse(stockCtrl.text) ?? 0;
              if (seller != null) {
                provider.updateSeller(seller.copyWith(name: nameCtrl.text, stockCoins: newStock));
              } else {
                provider.addSeller(CoinSellerModel(
                  id: 'seller_${DateTime.now().millisecondsSinceEpoch}',
                  userId: 'USR_NEW',
                  name: nameCtrl.text,
                  avatarUrl: 'https://i.pravatar.cc/150',
                  region: 'Global',
                  type: SellerType.standard,
                  status: SellerStatus.pending,
                  isVisible: false,
                  paymentMethods: ['Visa'],
                  stockCoins: newStock,
                ));
              }
              Navigator.pop(c);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  Widget _buildRoomThemeConfigTab(BuildContext context, GameProvider gameProvider, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppColors.getCard(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: primary.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.wallpaper_rounded, color: primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Paid Room Theme Uploads',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _paidThemeEnabled,
                        activeThumbColor: primary,
                        onChanged: (val) {
                          setState(() {
                            _paidThemeEnabled = val;
                          });
                        },
                      ),
                    ],
                  ),
                  Text(
                    _paidThemeEnabled
                        ? 'Status: ENABLED (Users pay configured fee to upload custom themes/wallpapers/DPs)'
                        : 'Status: DISABLED (Users can upload custom themes/wallpapers for free)',
                    style: TextStyle(fontSize: 12, color: _paidThemeEnabled ? Colors.green : Colors.orange),
                  ),
                  const Divider(height: 24),

                  Text(
                    'Global Custom Room Theme Upload Price',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Default: 100,000 Coins. Value must be numeric.',
                    style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark)),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _themePriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Global Upload Price (Coins)',
                      suffixText: 'Coins',
                      prefixIcon: const Icon(Icons.monetization_on_rounded, color: Colors.amber),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _paidThemeEnabled = true;
                              _themePriceController.text = '100000';
                            });
                            gameProvider.updateRoomThemeUploadConfig(enabled: true, globalPrice: 100000);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reset to Default (100,000 Coins, Enabled)')),
                            );
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reset Default'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final inputPrice = int.tryParse(_themePriceController.text.trim());
                            if (inputPrice == null || inputPrice < 0) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Validation Error: Price must be a non-negative number.'), backgroundColor: Colors.redAccent),
                              );
                              return;
                            }
                            final err = await gameProvider.updateRoomThemeUploadConfig(
                              enabled: _paidThemeEnabled,
                              globalPrice: inputPrice,
                            );
                            if (!mounted) return;
                            if (err != null) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Validation Error: $err'), backgroundColor: Colors.redAccent),
                              );
                            } else {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('🎉 Custom Room Theme Upload Price updated & logged!'), backgroundColor: Colors.green),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: primary),
                          icon: const Icon(Icons.save_rounded, color: Colors.white),
                          label: const Text('Save Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text(
            'Country / Region Pricing Overrides',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
          ),
          const SizedBox(height: 8),

          Card(
            color: AppColors.getCard(isDark),
            child: Column(
              children: gameProvider.countryRoomThemeUploadPrices.entries.map((entry) {
                return ListTile(
                  leading: const Icon(Icons.public_rounded, color: Colors.cyan),
                  title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text('${entry.value} Coins', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),
          Text(
            'Admin Price Change Audit Logs',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
          ),
          const SizedBox(height: 8),

          if (gameProvider.roomThemePriceAdminLogs.isEmpty)
            Card(
              color: AppColors.getCard(isDark),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No price changes logged yet.')),
              ),
            )
          else
            ...gameProvider.roomThemePriceAdminLogs.take(5).map((log) {
              return Card(
                color: AppColors.getCard(isDark),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.history_rounded, color: Colors.purpleAccent),
                  title: Text('Price Updated: ${log['previousPrice']} -> ${log['newPrice']} Coins', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('By ${log['adminId']} | Enabled: ${log['newEnabled']} | ${log['timestamp']}', style: const TextStyle(fontSize: 11)),
                  isThreeLine: true,
                ),
              );
            }),

          const SizedBox(height: 20),
          Text(
            'Upload Transactions & Refund Logs',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
          ),
          const SizedBox(height: 8),

          if (gameProvider.roomThemeUploadTransactions.isEmpty)
            Card(
              color: AppColors.getCard(isDark),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No room theme upload transactions recorded yet.')),
              ),
            )
          else
            ...gameProvider.roomThemeUploadTransactions.take(10).map((tx) {
              final isRefunded = tx['paymentStatus'] == 'Refunded';
              return Card(
                color: AppColors.getCard(isDark),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    isRefunded ? Icons.replay_rounded : Icons.check_circle_rounded,
                    color: isRefunded ? Colors.orange : Colors.green,
                  ),
                  title: Text('${tx['uploadType']} • ${tx['coinAmount']} Coins', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'User: ${tx['userId']} | Room: ${tx['roomId']}\nStatus: ${tx['paymentStatus']} (${tx['uploadStatus']}) | ${tx['timestamp']}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  isThreeLine: true,
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Tab 4: Mic Size Presets & Announcements Management (Module 03) ──
  Widget _buildAnnouncementsConfigTab(BuildContext context, GameProvider gameProvider, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Room Mic Seat Size Preset
          Card(
            color: AppColors.getCard(isDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: primary.withValues(alpha: 0.3))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.mic_rounded, color: primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Room Mic Seat Size Preset',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Active Preset: ${gameProvider.roomMicSizePreset} (Default: Large)', style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['Small', 'Medium', 'Large'].map((preset) {
                      final isSelected = gameProvider.roomMicSizePreset == preset;
                      return ChoiceChip(
                        label: Text(preset, style: TextStyle(color: isSelected ? Colors.white : AppColors.getTextPrimary(isDark))),
                        selected: isSelected,
                        selectedColor: primary,
                        onSelected: (val) {
                          if (val) {
                            gameProvider.updateRoomMicSizePreset(preset);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('🎉 Room Mic Seat Size updated to $preset')),
                            );
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Section 2: Global Mandatory Announcement
          Card(
            color: AppColors.getCard(isDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: primary.withValues(alpha: 0.3))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign_rounded, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Publish Global Mandatory Announcement',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Mandatory global announcements override room owner announcements across all party rooms.', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark))),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _annTitleController,
                    decoration: InputDecoration(
                      labelText: 'Announcement Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _annTextController,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: 'Announcement Body (Max 200 chars)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            gameProvider.setRoomAnnouncement(
                              roomId: 'global_mandatory',
                              editorUserId: 'Platform Admin',
                              title: _annTitleController.text,
                              text: _annTextController.text,
                              enabled: false,
                              status: 'Disabled',
                              isMandatory: true,
                              isAdmin: true,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Disabled Mandatory Global Announcement')),
                            );
                          },
                          icon: const Icon(Icons.disabled_by_default_rounded, color: Colors.orangeAccent),
                          label: const Text('Disable Notice'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final err = await gameProvider.setRoomAnnouncement(
                              roomId: 'global_mandatory',
                              editorUserId: 'Platform Admin',
                              title: _annTitleController.text,
                              text: _annTextController.text,
                              enabled: true,
                              status: 'Active',
                              isMandatory: true,
                              isAdmin: true,
                            );
                            if (!mounted) return;
                            if (err != null) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Error: $err'), backgroundColor: Colors.redAccent),
                              );
                            } else {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('🎉 Global Mandatory Announcement Published!'), backgroundColor: Colors.green),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: primary),
                          icon: const Icon(Icons.send_rounded, color: Colors.white),
                          label: const Text('Publish Mandatory', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text('Announcement History Audit Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 8),

          if (gameProvider.announcementHistoryLogs.isEmpty)
            Card(
              color: AppColors.getCard(isDark),
              child: const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No announcement changes recorded yet.'))),
            )
          else
            ...gameProvider.announcementHistoryLogs.take(6).map((log) {
              return Card(
                color: AppColors.getCard(isDark),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.history_rounded, color: Colors.amber),
                  title: Text('${log['actionType']} • Room: ${log['roomId']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('By: ${log['editorUserId']} | Status: ${log['newStatus']}\nText: "${log['newText']}" | ${log['timestamp']}', style: const TextStyle(fontSize: 11)),
                  isThreeLine: true,
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Tab 5: Room DP Moderation & Fallbacks (Module 04) ──
  Widget _buildRoomDpModerationTab(BuildContext context, GameProvider gameProvider, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppColors.getCard(isDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: primary.withValues(alpha: 0.3))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.photo_library_rounded, color: primary),
                      const SizedBox(width: 8),
                      Text('Room Card Display Settings & Fallbacks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Current Mode: Full Room DP Primary Visual', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _dpUrlController,
                    decoration: InputDecoration(
                      labelText: 'Global Default Fallback Room DP Image URL',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text('Room DP Image Moderation Control', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 8),

          Card(
            color: AppColors.getCard(isDark),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _modRoomIdController,
                    decoration: InputDecoration(
                      labelText: 'Enter Target Room ID (e.g. room_101)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final targetRoom = _modRoomIdController.text.trim();
                            if (targetRoom.isNotEmpty) {
                              gameProvider.moderateRoomDp(roomId: targetRoom, action: 'Reject', reason: 'Violates DP guidelines');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Rejected Room DP for $targetRoom (Replaced with default fallback)')),
                              );
                            }
                          },
                          icon: const Icon(Icons.block_rounded, color: Colors.redAccent),
                          label: const Text('Reject & Remove'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final targetRoom = _modRoomIdController.text.trim();
                            if (targetRoom.isNotEmpty) {
                              gameProvider.moderateRoomDp(roomId: targetRoom, action: 'Approve', reason: 'Passed moderation check');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Approved Room DP for $targetRoom'), backgroundColor: Colors.green),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                          label: const Text('Approve DP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text('Room DP Moderation Audit Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 8),

          if (gameProvider.roomDpModerationLogs.isEmpty)
            Card(
              color: AppColors.getCard(isDark),
              child: const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No Room DP moderation actions logged yet.'))),
            )
          else
            ...gameProvider.roomDpModerationLogs.take(6).map((log) {
              return Card(
                color: AppColors.getCard(isDark),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.security_rounded, color: Colors.cyan),
                  title: Text('Action: ${log['action']} • Room: ${log['roomId']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('By: ${log['adminId']} | Status: ${log['newStatus']}\nReason: ${log['reason']} | ${log['timestamp']}', style: const TextStyle(fontSize: 11)),
                  isThreeLine: true,
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Tab 6: Room Features & Security Audit (Module 06) ──
  Widget _buildRoomFeaturesSecurityTab(BuildContext context, GameProvider gameProvider, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppColors.getCard(isDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: primary.withValues(alpha: 0.3))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: primary),
                      const SizedBox(width: 8),
                      Text('Global & Regional Feature Switches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Control available features globally or by country/region without releasing a new app update.', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark))),
                  const SizedBox(height: 16),
                  _buildFeatureSwitchTile('YouTube Shared Sync', 'Allow Hosts/Admins to share and control YouTube videos in rooms', true, isDark),
                  _buildFeatureSwitchTile('Super Wheel Game', 'Enable server-controlled Super Wheel prize games', true, isDark),
                  _buildFeatureSwitchTile('Lucky Bag Distribution', 'Enable Host/Admin Lucky Bag coin distribution', true, isDark),
                  _buildFeatureSwitchTile('Lock Room Access Control', 'Allow PIN and Approval-Only access control for party rooms', true, isDark),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text('Room Owner & Admin Action Audit Trail', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 8),

          Card(
            color: AppColors.getCard(isDark),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.play_circle_fill_rounded, color: Colors.redAccent),
                    title: const Text('YouTube Start • Room: room_101', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Actor: Host (Danial) | Video: "Lo-Fi Beats" | ${DateTime.now().toIso8601String().substring(0, 16)}', style: const TextStyle(fontSize: 11)),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.casino_rounded, color: Colors.amberAccent),
                    title: const Text('Super Wheel Spin • Room: room_101', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Actor: Host (Danial) | Result: 500 Coins | ${DateTime.now().toIso8601String().substring(0, 16)}', style: const TextStyle(fontSize: 11)),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.card_giftcard_rounded, color: Colors.orangeAccent),
                    title: const Text('Lucky Bag Created • Room: room_101', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Actor: Admin (Sophia) | Amount: 1,000 Coins (10 claims) | ${DateTime.now().toIso8601String().substring(0, 16)}', style: const TextStyle(fontSize: 11)),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.lock_rounded, color: Colors.cyanAccent),
                    title: const Text('Lock Room Configured • Room: room_101', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Actor: Host (Danial) | Mode: PIN Protection | ${DateTime.now().toIso8601String().substring(0, 16)}', style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureSwitchTile(String title, String subtitle, bool value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.getTextPrimary(isDark))),
                Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark))),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.greenAccent,
            onChanged: (val) {},
          ),
        ],
      ),
    );
  }

  // ── Tab 7: Event Banners Management (Module 09) ──
  Widget _buildEventBannersAdminTab(BuildContext context, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppColors.getCard(isDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: primary.withValues(alpha: 0.3))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.view_carousel_rounded, color: primary),
                      const SizedBox(width: 8),
                      Text('Party Top Banner & Event Carousel CRUD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Manage active promotional and event banners, rotation duration, and regional targeting.', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark))),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: const Text('Create New Event Banner'),
                    style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('➕ New Banner Editor opened!')));
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Active Published Banners', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 8),
          Card(
            color: AppColors.getCard(isDark),
            child: ListTile(
              leading: const Icon(Icons.flash_on_rounded, color: Colors.redAccent),
              title: const Text('Weekend PK Battle!', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Type: Event | Target: GLOBAL | Priority: 1 | Status: Active'),
              trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.white70), onPressed: () {}),
            ),
          ),
          Card(
            color: AppColors.getCard(isDark),
            child: ListTile(
              leading: const Icon(Icons.groups_rounded, color: Colors.orangeAccent),
              title: const Text('Party Rooms Showdown', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Type: Promotional | Target: US, PK, IN | Priority: 2 | Status: Active'),
              trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.white70), onPressed: () {}),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 8: Relationship Cards Store Management (Module 10) ──
  Widget _buildRelationshipCardsAdminTab(BuildContext context, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppColors.getCard(isDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: primary.withValues(alpha: 0.3))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storefront_rounded, color: primary),
                      const SizedBox(width: 8),
                      Text('Relationship Cards & Store Pricing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Configure available card types, coin prices, relationship limits, and regional pricing rules.', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark))),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_card_rounded),
                    label: const Text('Add Relationship Card Type'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('➕ Relationship Card Configurator opened!')));
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Enabled Card Store Catalog', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 8),
          Card(
            color: AppColors.getCard(isDark),
            child: ListTile(
              leading: const Icon(Icons.favorite_rounded, color: Colors.pinkAccent),
              title: const Text('Eternal CP Ring Card • 1,000 Coins 🪙', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Type: CP | Limit: 1 Active CP | Expiry: 48h | Full Refund on Decline'),
              trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.white70), onPressed: () {}),
            ),
          ),
          Card(
            color: AppColors.getCard(isDark),
            child: ListTile(
              leading: const Icon(Icons.star_rounded, color: Colors.amberAccent),
              title: const Text('Best Friend Oath Card • 500 Coins 🪙', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Type: Best Friend | Limit: 5 Active Friends | Expiry: 48h'),
              trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.white70), onPressed: () {}),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 9: Direct Live Host Application Review & Monitoring (Module 15) ──
  Widget _buildDirectLiveHostsAdminTab(BuildContext context, bool isDark, Color primary) {
    final liveHostProv = context.watch<LiveHostProvider>();
    final apps = liveHostProv.applications;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppColors.getCard(isDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: primary.withValues(alpha: 0.3))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: primary),
                      const SizedBox(width: 8),
                      Text('Direct Live Host Registration Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Review identity, liveness selfies, age eligibility, risk checks, and approve direct Live Hosts.', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Submitted Applications (${apps.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: apps.length,
            itemBuilder: (ctx, idx) {
              final app = apps[idx];
              final isApproved = app.status == 'Approved';

              return Card(
                color: AppColors.getCard(isDark),
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(app.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isApproved ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              app.status,
                              style: TextStyle(color: isApproved ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Legal Name: ${app.legalName} • DOB: ${app.dateOfBirth} • ${app.country}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      Text('ID: ${app.govIdType} (${app.govIdNumber}) • Contact: ${app.phoneOrEmail}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                      const SizedBox(height: 10),
                      if (!isApproved)
                        Row(
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              onPressed: () {
                                liveHostProv.approveApplication(app.id, 'admin_user');
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 Approved ${app.displayName} as Direct Live Host!'), backgroundColor: Colors.green));
                              },
                              child: const Text('Approve', style: TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                              onPressed: () {
                                liveHostProv.rejectApplication(app.id, 'Identity verification failed', 'admin_user');
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rejected ${app.displayName}\'s application.'), backgroundColor: Colors.orange));
                              },
                              child: const Text('Reject'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Tab 10: Recharge & Merchant Controls
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Coin Seller & Merchant Admin Controls', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Configure recharge limits, seller authorization, merchant user vs seller recharge switches, and security thresholds.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFF1E1B2E),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Global Switches & Limits', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        SwitchListTile(title: const Text('Recharge Agency Module', style: TextStyle(color: Colors.white, fontSize: 13)), value: true, onChanged: (v) {}),
                        SwitchListTile(title: const Text('Merchant User Recharge Switch', style: TextStyle(color: Colors.white, fontSize: 13)), value: true, onChanged: (v) {}),
                        SwitchListTile(title: const Text('Merchant Coin Seller Recharge Switch', style: TextStyle(color: Colors.white, fontSize: 13)), value: true, onChanged: (v) {}),
                        const SizedBox(height: 10),
                        const Text('Daily Recharge Limit: 10,000,000 Coins', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab 11: Lucky Gifts Manager
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lucky Gifts & Server Probability Engine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Manage Lucky Gifts catalogue, jackpot multiplier tiers, daily payouts, and server-authoritative RNG probability weight tables.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFF1E1B2E),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Active Lucky Gifts (3 Items)', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        const ListTile(leading: Text('👑', style: TextStyle(fontSize: 24)), title: Text('Lucky Crown', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: Text('Price: 50 Coins • Max: 100× Jackpot', style: TextStyle(color: Colors.white70, fontSize: 11))),
                        const ListTile(leading: Text('🐉', style: TextStyle(fontSize: 24)), title: Text('Lucky Dragon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: Text('Price: 200 Coins • Max: 500× Jackpot', style: TextStyle(color: Colors.white70, fontSize: 11))),
                        const ListTile(leading: Text('🚀', style: TextStyle(fontSize: 24)), title: Text('Lucky Rocket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: Text('Price: 1000 Coins • Max: 1000× Jackpot', style: TextStyle(color: Colors.white70, fontSize: 11))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
