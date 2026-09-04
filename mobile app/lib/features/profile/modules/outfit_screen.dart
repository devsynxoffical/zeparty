import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/dummy_data.dart';
import '../../../../models/outfit_model.dart';

class OutfitScreen extends StatefulWidget {
  const OutfitScreen({super.key});

  @override
  State<OutfitScreen> createState() => _OutfitScreenState();
}

class _OutfitScreenState extends State<OutfitScreen> with SingleTickerProviderStateMixin {
  late List<OutfitModel> _outfits;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _outfits = List.from(DummyData.userOutfits);
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _equipItem(int globalIndex, OutfitCategory category) {
    setState(() {
      // Unequip current active in same category
      for (int i = 0; i < _outfits.length; i++) {
        if (_outfits[i].category == category && _outfits[i].status == OutfitStatus.active) {
          _outfits[i] = _outfits[i].copyWith(status: OutfitStatus.available);
        }
      }
      // Equip new item
      _outfits[globalIndex] = _outfits[globalIndex].copyWith(
        status: OutfitStatus.active,
        daysRemaining: _outfits[globalIndex].daysRemaining > 0 ? _outfits[globalIndex].daysRemaining : 30,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Equipped ${_outfits[globalIndex].name}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text('Outfit Gallery', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primary,
          unselectedLabelColor: AppColors.getTextSecondary(isDark),
          indicatorColor: primary,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Outfits & Bubbles'),
            Tab(text: 'Frames'),
            Tab(text: 'Cars'),
            Tab(text: 'Effects'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryGrid(OutfitCategory.bubble, isDark),
          _buildCategoryGrid(OutfitCategory.frame, isDark),
          _buildCategoryGrid(OutfitCategory.car, isDark),
          _buildCategoryGrid(OutfitCategory.effect, isDark),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(OutfitCategory category, bool isDark) {
    // Find all items matching category
    final items = <MapEntry<int, OutfitModel>>[];
    for (int i = 0; i < _outfits.length; i++) {
      if (_outfits[i].category == category) {
        items.add(MapEntry(i, _outfits[i]));
      }
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checkroom_rounded, size: 64, color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No items in this category', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.76,
      ),
      itemCount: items.length,
      itemBuilder: (context, idx) {
        final globalIndex = items[idx].key;
        final item = items[idx].value;
        final isActive = item.status == OutfitStatus.active;
        final isExpired = item.status == OutfitStatus.expired;

        Color cardBorderColor = AppColors.getBorder(isDark);
        if (isActive) cardBorderColor = AppColors.metallicGold;
        if (isExpired) cardBorderColor = Colors.red.withValues(alpha: 0.3);

        return Container(
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorderColor, width: isActive ? 1.8 : 1),
            boxShadow: isActive ? [
              BoxShadow(
                color: AppColors.metallicGold.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive 
                      ? AppColors.metallicGold.withValues(alpha: 0.2) 
                      : isExpired 
                          ? Colors.red.withValues(alpha: 0.1) 
                          : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive 
                      ? 'ACTIVE' 
                      : isExpired 
                          ? 'EXPIRED' 
                          : 'AVAILABLE',
                  style: TextStyle(
                    fontSize: 9, 
                    fontWeight: FontWeight.bold,
                    color: isActive 
                        ? AppColors.metallicGold 
                        : isExpired 
                            ? Colors.red 
                            : Colors.white54,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Image Asset
              Container(
                width: 70,
                height: 70,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.metallicGold.withValues(alpha: 0.1) : Colors.white10,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    item.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  item.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: isActive ? Colors.white : AppColors.getTextPrimary(isDark),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isActive 
                    ? '${item.daysRemaining} days left' 
                    : isExpired 
                        ? 'Expired' 
                        : 'Permanent',
                style: TextStyle(color: Colors.white30, fontSize: 10),
              ),
              const SizedBox(height: 12),
              if (!isExpired)
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: isActive ? null : () => _equipItem(globalIndex, category),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive ? Colors.grey.withValues(alpha: 0.2) : AppColors.metallicGold,
                      foregroundColor: isActive ? Colors.white30 : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(isActive ? 'Equipped' : 'Equip', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                )
              else
                SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Redirecting to Store to renew...')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Renew', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
