import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/app_colors.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final currentMode = themeProvider.themeMode;

    return Column(
      children: [
        _buildOptionCard(
          context,
          title: 'Light Mode',
          subtitle: 'Clean & bright appearance with high contrast',
          icon: Icons.light_mode_rounded,
          mode: ThemeMode.light,
          isSelected: currentMode == ThemeMode.light,
          accentColor: AppColors.warmGold,
          onTap: () => themeProvider.setThemeMode(ThemeMode.light),
        ),
        const SizedBox(height: 12),
        _buildOptionCard(
          context,
          title: 'Dark Mode',
          subtitle: 'Sleek dark aesthetics, comfortable for night streaming',
          icon: Icons.dark_mode_rounded,
          mode: ThemeMode.dark,
          isSelected: currentMode == ThemeMode.dark,
          accentColor: AppColors.metallicGold,
          onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
        ),
        const SizedBox(height: 12),
        _buildOptionCard(
          context,
          title: 'System Default',
          subtitle: 'Automatically match device system theme settings',
          icon: Icons.settings_system_daydream_rounded,
          mode: ThemeMode.system,
          isSelected: currentMode == ThemeMode.system,
          accentColor: AppColors.lightGold,
          onTap: () => themeProvider.setThemeMode(ThemeMode.system),
        ),
      ],
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeMode mode,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final cardColor = isSelected
        ? accentColor.withValues(alpha: 0.12)
        : Theme.of(context).cardColor;

    final borderColor = isSelected ? accentColor : Theme.of(context).dividerColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? accentColor : Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.black : Theme.of(context).iconTheme.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? accentColor : null,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? accentColor : Theme.of(context).dividerColor,
                  width: 2,
                ),
                color: isSelected ? accentColor : AppColors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: AppColors.black, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
