import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/user_asset_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/backpack_provider.dart';
import '../../../../widgets/user_avatar.dart';

class OutfitScreen extends StatefulWidget {
  const OutfitScreen({super.key});

  @override
  State<OutfitScreen> createState() => _OutfitScreenState();
}

class _OutfitScreenState extends State<OutfitScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<BackpackProvider>().fetchBackpack(currentUser: auth.currentUser);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleEquip(UserAssetModel userAsset) async {
    final backpack = context.read<BackpackProvider>();
    final auth = context.read<AuthProvider>();

    if (userAsset.isEquipped) {
      final success = await backpack.unequipAsset(
        userAsset.id,
        onAvatarFrameChanged: (frame) => auth.updateAvatarFrame(frame),
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unequipped ${userAsset.asset?.name ?? 'item'}'), duration: const Duration(seconds: 1)),
        );
      }
    } else {
      final success = await backpack.equipAsset(
        userAsset.id,
        onAvatarFrameChanged: (frame) => auth.updateAvatarFrame(frame),
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Equipped ${userAsset.asset?.name ?? 'item'}! ✨'), duration: const Duration(seconds: 1)),
        );
      }
    }
  }

  void _showFrameZoomPreviewDialog(BuildContext context, UserAssetModel item, bool isDark) {
    String displayName = item.asset?.name ?? 'Asset';
    displayName = displayName.replaceAll(RegExp(r'\s+Frame$', caseSensitive: false), '').trim();
    final imageUrl = item.asset?.imageUrl ?? '';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'FramePreview',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final backpack = context.watch<BackpackProvider>();
            final auth = context.watch<AuthProvider>();
            final currentAsset = backpack.userAssets.firstWhere(
              (a) => a.id == item.id,
              orElse: () => item,
            );
            final isEquipped = currentAsset.isEquipped;

            return Center(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.88,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF171524).withValues(alpha: 0.92)
                          : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: isEquipped
                            ? AppColors.metallicGold.withValues(alpha: 0.6)
                            : (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1)),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isEquipped ? AppColors.metallicGold : Colors.black).withValues(alpha: 0.3),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Pinch or double-tap to zoom details',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.black.withValues(alpha: 0.05),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Interactive Zoom Artwork
                        Container(
                          height: 220,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.35)
                                : Colors.grey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: InteractiveViewer(
                              minScale: 0.8,
                              maxScale: 4.5,
                              clipBehavior: Clip.none,
                              child: Center(
                                child: imageUrl.startsWith('assets/')
                                    ? Image.asset(
                                        imageUrl,
                                        width: 170,
                                        height: 170,
                                        fit: BoxFit.contain,
                                      )
                                    : Image.network(
                                        imageUrl,
                                        width: 170,
                                        height: 170,
                                        fit: BoxFit.contain,
                                      ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Live Avatar Preview
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                imageUrl: auth.currentUser.avatarUrl,
                                radius: 18,
                                frameAsset: imageUrl,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Live Avatar Preview',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      isEquipped ? 'Currently equipped on your profile' : 'Ready to equip',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isEquipped
                                            ? AppColors.metallicGold
                                            : (isDark ? Colors.white60 : Colors.black54),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Glass Action Button
                        SizedBox(
                          width: double.infinity,
                          child: _buildGlassButton(
                            isEquipped: isEquipped,
                            isDark: isDark,
                            fontSize: 13.5,
                            verticalPadding: 9,
                            onPressed: () => _toggleEquip(currentAsset),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGlassButton({
    required bool isEquipped,
    required bool isDark,
    required VoidCallback? onPressed,
    double fontSize = 10.5,
    double verticalPadding = 4,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isEquipped
                  ? [
                      Colors.white.withValues(alpha: isDark ? 0.12 : 0.20),
                      Colors.white.withValues(alpha: isDark ? 0.04 : 0.08),
                    ]
                  : [
                      AppColors.metallicGold.withValues(alpha: isDark ? 0.28 : 0.38),
                      AppColors.getPrimary(isDark).withValues(alpha: isDark ? 0.20 : 0.30),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isEquipped
                  ? (isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.15))
                  : AppColors.metallicGold.withValues(alpha: isDark ? 0.65 : 0.80),
              width: 1.0,
            ),
            boxShadow: isEquipped
                ? null
                : [
                    BoxShadow(
                      color: AppColors.metallicGold.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              isEquipped ? 'Unequip' : 'Equip',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
                color: isEquipped
                    ? (isDark ? Colors.white70 : Colors.black87)
                    : (isDark ? AppColors.metallicGold : AppColors.gold),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final backpack = context.watch<BackpackProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text('My Backpack & Outfits', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<BackpackProvider>().fetchBackpack(refresh: true, currentUser: auth.currentUser),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primary,
          unselectedLabelColor: AppColors.getTextSecondary(isDark),
          indicatorColor: primary,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Bubbles'),
            Tab(text: 'Frames'),
            Tab(text: 'Cars'),
            Tab(text: 'Effects'),
          ],
        ),
      ),
      body: backpack.isLoading && backpack.userAssets.isEmpty
          ? Center(child: CircularProgressIndicator(color: primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAssetCategoryGrid('BUBBLE', isDark),
                _buildAssetCategoryGrid('FRAME', isDark),
                _buildAssetCategoryGrid('VEHICLE', isDark),
                _buildAssetCategoryGrid('EFFECT', isDark),
              ],
            ),
    );
  }

  Widget _buildAssetPreview(UserAssetModel item, bool isDark) {
    final imageUrl = item.asset?.imageUrl ?? '';

    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: 58,
        height: 58,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => const Icon(Icons.style_rounded, size: 36, color: AppColors.gold),
      );
    } else if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        width: 58,
        height: 58,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => const Icon(Icons.style_rounded, size: 36, color: AppColors.gold),
      );
    }

    return const Icon(Icons.style_rounded, size: 36, color: AppColors.gold);
  }

  Widget _buildAssetCategoryGrid(String typeKeyword, bool isDark) {
    final backpack = context.watch<BackpackProvider>();
    final items = backpack.userAssets.where((ua) {
      final type = (ua.asset?.assetType ?? '').toUpperCase();
      final cat = (ua.asset?.categoryId ?? '').toUpperCase();

      if (typeKeyword == 'VEHICLE' || typeKeyword == 'CAR') {
        return type.contains('CAR') || type.contains('MOUNT') || type.contains('VEHICLE') || cat.contains('CAR');
      }
      if (typeKeyword == 'FRAME') {
        return type.contains('FRAME') || cat.contains('FRAME');
      }
      if (typeKeyword == 'BUBBLE') {
        return type.contains('BUBBLE') || cat.contains('BUBBLE');
      }
      if (typeKeyword == 'EFFECT' || typeKeyword == 'BACKGROUND' || typeKeyword == 'CARD') {
        return type.contains(typeKeyword) || cat.contains(typeKeyword) || type.contains('THEME') || cat.contains('THEME') || cat.contains('BACKGROUND') || cat.contains('CARD');
      }

      return type.contains(typeKeyword) || cat.contains(typeKeyword);
    }).toList();

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checkroom_rounded, size: 64, color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No items owned in this category', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
            const SizedBox(height: 8),
            Text('Visit the Store to unlock new styles', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.7))),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (context, idx) {
        final item = items[idx];
        final isEquipped = item.isEquipped;
        final isExpired = item.isExpired;

        // Clean name (e.g. "King Supreme Frame" -> "King Supreme")
        String displayName = item.asset?.name ?? 'Asset';
        displayName = displayName.replaceAll(RegExp(r'\s+Frame$', caseSensitive: false), '').trim();

        Color cardBorderColor = AppColors.getBorder(isDark);
        if (isEquipped) cardBorderColor = AppColors.metallicGold;
        if (isExpired) cardBorderColor = Colors.red.withValues(alpha: 0.3);

        return GestureDetector(
          onTap: () => _showFrameZoomPreviewDialog(context, item, isDark),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getCard(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorderColor, width: isEquipped ? 1.8 : 1),
              boxShadow: isEquipped
                  ? [
                      BoxShadow(
                        color: AppColors.metallicGold.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Status: Only show if EQUIPPED (no 364 days text)
                if (isEquipped)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.metallicGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'EQUIPPED',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: AppColors.metallicGold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 14),

                // Frame Graphic Artwork Preview (Frame only, no DP)
                Expanded(
                  child: Center(
                    child: _buildAssetPreview(item, isDark),
                  ),
                ),

                const SizedBox(height: 4),

                // Clean Title without "Frame"
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.getTextPrimary(isDark),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 6),

                // Glass Equip / Unequip Button
                SizedBox(
                  width: double.infinity,
                  child: _buildGlassButton(
                    isEquipped: isEquipped,
                    isDark: isDark,
                    onPressed: isExpired ? null : () => _toggleEquip(item),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
