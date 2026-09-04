import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../core/animations/app_animations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class GlassNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onCreatePressed;

  const GlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onCreatePressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final items = const [
      _NavItemData(icon: Icons.home_rounded, label: 'Home'),
      _NavItemData(icon: Icons.explore_rounded, label: 'Discover'),
      _NavItemData(icon: Icons.add, label: ''), // Create Placeholder
      _NavItemData(icon: Icons.chat_bubble_rounded, label: 'Messages'),
      _NavItemData(icon: Icons.person_rounded, label: 'Profile'),
    ];

    return Container(
      height: 84.h,
      margin: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 16.h),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Glass Backdrop Container
          ClipRRect(
            borderRadius: BorderRadius.circular(28.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: 68.h,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.black.withValues(alpha: 0.92)
                      : AppColors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(28.r),
                  border: Border.all(
                    color: isDark
                        ? AppColors.goldBorder.withValues(alpha: 0.55)
                        : AppColors.lightBorder.withValues(alpha: 0.8),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / items.length;
                    final activePillLeft = selectedIndex * itemWidth + (itemWidth - (itemWidth * 0.76)) / 2;

                    return Stack(
                      children: [
                        // Smooth Animated Pill Indicator
                        if (selectedIndex != 2)
                          AnimatedPositioned(
                            duration: AppAnimations.normal,
                            curve: AppAnimations.springCurve,
                            left: activePillLeft,
                            top: 8.h,
                            width: itemWidth * 0.76,
                            height: 52.h,
                            child: Container(
                              decoration: BoxDecoration(
                                color: (isDark ? AppColors.warmGold : AppColors.royalBlue).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: (isDark ? AppColors.warmGold : AppColors.royalBlue).withValues(alpha: 0.35),
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),

                        // Navigation Items Row
                        Row(
                          children: List.generate(items.length, (index) {
                            if (index == 2) {
                              return const Expanded(child: SizedBox());
                            }
                            final isSelected = selectedIndex == index;

                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => onTabSelected(index),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedScale(
                                      duration: AppAnimations.fast,
                                      scale: isSelected ? 1.18 : 1.0,
                                      child: Icon(
                                        items[index].icon,
                                        color: isSelected
                                            ? (isDark ? AppColors.warmGold : AppColors.royalBlue)
                                            : (isDark ? AppColors.mutedText : AppColors.lightMuted),
                                        size: 24.w,
                                      ),
                                    ),
                                    SizedBox(height: 3.h),
                                    AnimatedDefaultTextStyle(
                                      duration: AppAnimations.fast,
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected
                                            ? (isDark ? AppColors.warmGold : AppColors.royalBlue)
                                            : (isDark ? AppColors.mutedText : AppColors.lightMuted),
                                      ),
                                      child: Text(items[index].label),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // CENTER FLOATING CREATE BUTTON
          Positioned(
            top: 0,
            child: MetallicShine(
              bandWidth: 0.5,
              beginX: -0.7,
              duration: const Duration(milliseconds: 2800),
              child: GestureDetector(
                onTap: onCreatePressed,
                child: Container(
                  width: 58.w,
                  height: 58.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isDark ? AppColors.metallicGoldGradient : AppColors.metallicBlueGradient,
                    border: Border.all(
                      color: isDark
                          ? AppColors.goldHighlight.withValues(alpha: 0.6)
                          : AppColors.white.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? AppColors.warmGold : AppColors.royalBlue).withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 32.w,
                    color: isDark ? AppColors.black : AppColors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
}
