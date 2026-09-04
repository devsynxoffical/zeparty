import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/svip_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/svip_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/user_avatar.dart';
import '../wallet/wallet_screen.dart';
import '../rewards/rewards_screen.dart';
import 'vip_honor_screen.dart';

class SVIPCenterScreen extends StatefulWidget {
  const SVIPCenterScreen({super.key});

  @override
  State<SVIPCenterScreen> createState() => _SVIPCenterScreenState();
}

class _SVIPCenterScreenState extends State<SVIPCenterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SVIPProvider>().fetchSVIPData();
    });
  }

  void _handlePurchasePoints(SVIPPackage package) async {
    final wallet = context.read<WalletProvider>();
    if (wallet.coins < package.priceCoins) {
      _showInsufficientCoinsDialog();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.orangeAccent)),
    );

    final success = await context.read<SVIPProvider>().purchasePoints(package, wallet);
    if (mounted) Navigator.pop(context);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully acquired ${package.name}!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showInsufficientCoinsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        title: Text('Insufficient Coins', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
        content: Text('You do not have enough coins to purchase this SVIP points package.', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (c) => const WalletScreen()));
            },
            child: Text('Recharge', style: TextStyle(color: AppColors.getPrimary(isDark))),
          ),
        ],
      ),
    );
  }

  void _showRecordSheet(SVIPProvider svip, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SVIP Points & Upgrade History',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              const SizedBox(height: 14),
              if (svip.auditHistory.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No points records yet. Recharge to earn points.',
                      style: TextStyle(color: AppColors.getTextSecondary(isDark)),
                    ),
                  ),
                )
              else
                ...svip.auditHistory.take(5).map((rec) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rec.note, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.getTextPrimary(isDark))),
                            Text('${rec.timestamp.month}/${rec.timestamp.day} - Type: ${rec.type}', style: TextStyle(fontSize: 10, color: AppColors.getTextSecondary(isDark))),
                          ],
                        ),
                        Text('+${AppFormatters.formatNumber(rec.points)} pts', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final svip = context.watch<SVIPProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final primaryText = AppColors.getTextPrimary(isDark);
    
    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('SVIP', style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: svip.isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.getPrimary(isDark)))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // ─── Header Area ───
                  _buildSVIPHeader(svip, user, isDark),
                  
                  const SizedBox(height: 10),
                  
                  // ─── Level Selector Tabs (SVIP1 - SVIP16) ───
                  _buildLevelTabs(svip, isDark),
                  
                  const SizedBox(height: 16),
                  
                  // ─── Action Shortcuts: Record, Get VIP Points, Upgrade, Honor, Mission (Benefit Removed) ───
                  _buildActionShortcuts(svip, isDark),
                  
                  const SizedBox(height: 18),
                  
                  // ─── Privileges Grid (Dynamic Count) ───
                  _buildPrivilegesSection(svip, isDark),
                  
                  const SizedBox(height: 20),
                  
                  // ─── SVIP Store ───
                  _buildSVIPStore(svip, isDark),
                  
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildSVIPHeader(SVIPProvider svip, user, bool isDark) {
    final nextLevel = svip.nextSVIPLevelData;
    
    double progress = 1.0;
    if (nextLevel != null && nextLevel.requiredPoints > 0) {
      progress = (svip.currentPoints / nextLevel.requiredPoints).clamp(0.0, 1.0);
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 88, left: 20, right: 20, bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: svip.selectedSVIPLevelData.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        UserAvatar(imageUrl: user.avatarUrl, radius: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            user.name,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'SVIP ${svip.currentLevel}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nextLevel != null
                          ? '${AppFormatters.formatNumber(svip.currentPoints)} / ${AppFormatters.formatNumber(nextLevel.requiredPoints)} pts'
                          : '${AppFormatters.formatNumber(svip.currentPoints)} pts (Max Tier)',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    if (nextLevel != null)
                      Text(
                        '${AppFormatters.formatNumber(nextLevel.requiredPoints - svip.currentPoints)} points to unlock SVIP ${nextLevel.level}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 10),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Expiry: ${svip.expiryDate.year}.${svip.expiryDate.month.toString().padLeft(2, '0')}.${svip.expiryDate.day.toString().padLeft(2, '0')}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Luxury Crown / SVIP Badge Emblem
              Container(
                width: 100,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('👑', style: TextStyle(fontSize: 34)),
                    const SizedBox(height: 4),
                    Text(
                      'SVIP ${svip.selectedViewLevel}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelTabs(SVIPProvider svip, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: svip.levels.map((lvl) {
          final isSelected = lvl.level == svip.selectedViewLevel;
          return GestureDetector(
            onTap: () => svip.setSelectedViewLevel(lvl.level),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.getPrimary(isDark) : AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.getPrimary(isDark) : AppColors.getBorder(isDark),
                ),
              ),
              child: Text(
                lvl.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.getTextPrimary(isDark),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionShortcuts(SVIPProvider svip, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildShortcutButton(
            'Record',
            Icons.receipt_long_rounded,
            isDark,
            onTap: () => _showRecordSheet(svip, isDark),
          ),
          _buildShortcutButton(
            'Get VIP Points',
            Icons.monetization_on_rounded,
            isDark,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const WalletScreen()));
            },
          ),
          _buildShortcutButton(
            'Upgrade',
            Icons.arrow_circle_up_rounded,
            isDark,
            onTap: () => svip.upgradeLevel(),
          ),
          _buildShortcutButton(
            'Honor 🏆',
            Icons.workspace_premium_rounded,
            isDark,
            isHighlight: true,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const VIPHonorScreen()));
            },
          ),
          _buildShortcutButton(
            'Mission ⚡',
            Icons.star_rounded,
            isDark,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const RewardsScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutButton(String label, IconData icon, bool isDark, {VoidCallback? onTap, bool isHighlight = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isHighlight ? Colors.orangeAccent.withValues(alpha: 0.2) : AppColors.getCard(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isHighlight ? Colors.orangeAccent : AppColors.getBorder(isDark),
                width: isHighlight ? 1.5 : 1,
              ),
            ),
            child: Icon(icon, color: isHighlight ? Colors.orangeAccent : AppColors.getPrimary(isDark), size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isHighlight ? Colors.orangeAccent : AppColors.getTextSecondary(isDark),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivilegesSection(SVIPProvider svip, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Dynamic Privilege Counter (e.g. Privileges X / 37)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withValues(alpha: 0.15),
                  Colors.orangeAccent.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.diamond_rounded, color: Colors.orangeAccent, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Privileges ${svip.unlockedPrivilegesCount} / ${svip.totalPrivilegesCount}',
                  style: TextStyle(
                    color: AppColors.getTextPrimary(isDark),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3-Column Privilege Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: SVIPProvider.privilegeCatalog.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, index) {
              final priv = SVIPProvider.privilegeCatalog[index];
              final isUnlocked = svip.isPrivilegeUnlocked(priv.id);

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.getCard(isDark),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isUnlocked ? Colors.orangeAccent.withValues(alpha: 0.5) : AppColors.getBorder(isDark),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          priv.icon,
                          color: isUnlocked ? Colors.orangeAccent : Colors.grey.shade600,
                          size: 26,
                        ),
                        if (!isUnlocked)
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Icon(Icons.lock_rounded, size: 12, color: Colors.grey.shade400),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      priv.name,
                      style: TextStyle(
                        color: isUnlocked ? AppColors.getTextPrimary(isDark) : AppColors.getTextSecondary(isDark),
                        fontSize: 10.5,
                        fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SVIP ${priv.requiredLevel}',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: isUnlocked ? Colors.greenAccent : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSVIPStore(SVIPProvider svip, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SVIP Points Store',
            style: TextStyle(
              color: AppColors.getTextPrimary(isDark),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.getCard(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.getBorder(isDark)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: svip.storePackages.map((pkg) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pkg.name,
                            style: TextStyle(
                              color: AppColors.getTextPrimary(isDark),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (pkg.bonusPoints > 0)
                            Text(
                              '+${AppFormatters.formatNumber(pkg.bonusPoints)} Bonus Points',
                              style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.getPrimary(isDark),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () => _handlePurchasePoints(pkg),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🪙', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              AppFormatters.formatNumber(pkg.priceCoins),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
