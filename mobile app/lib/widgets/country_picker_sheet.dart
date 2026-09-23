import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class CountryInfo {
  final String code;
  final String name;
  final String flag;
  final String dialCode;

  const CountryInfo({
    required this.code,
    required this.name,
    required this.flag,
    required this.dialCode,
  });
}

class CountryPickerSheet extends StatefulWidget {
  final bool isDark;
  final String? initialCode;
  final ValueChanged<CountryInfo> onSelected;

  const CountryPickerSheet({
    super.key,
    required this.isDark,
    this.initialCode,
    required this.onSelected,
  });

  static const List<CountryInfo> allCountries = [
    CountryInfo(code: 'PK', name: 'Pakistan', flag: '🇵🇰', dialCode: '+92'),
    CountryInfo(code: 'US', name: 'United States', flag: '🇺🇸', dialCode: '+1'),
    CountryInfo(code: 'GB', name: 'United Kingdom', flag: '🇬🇧', dialCode: '+44'),
    CountryInfo(code: 'SA', name: 'Saudi Arabia', flag: '🇸🇦', dialCode: '+966'),
    CountryInfo(code: 'AE', name: 'United Arab Emirates', flag: '🇦🇪', dialCode: '+971'),
    CountryInfo(code: 'IN', name: 'India', flag: '🇮🇳', dialCode: '+91'),
    CountryInfo(code: 'BD', name: 'Bangladesh', flag: '🇧🇩', dialCode: '+880'),
    CountryInfo(code: 'CA', name: 'Canada', flag: '🇨🇦', dialCode: '+1'),
    CountryInfo(code: 'AU', name: 'Australia', flag: '🇦🇺', dialCode: '+61'),
    CountryInfo(code: 'DE', name: 'Germany', flag: '🇩🇪', dialCode: '+49'),
    CountryInfo(code: 'FR', name: 'France', flag: '🇫🇷', dialCode: '+33'),
    CountryInfo(code: 'TR', name: 'Turkey', flag: '🇹🇷', dialCode: '+90'),
    CountryInfo(code: 'EG', name: 'Egypt', flag: '🇪🇬', dialCode: '+20'),
    CountryInfo(code: 'ID', name: 'Indonesia', flag: '🇮🇩', dialCode: '+62'),
    CountryInfo(code: 'MY', name: 'Malaysia', flag: '🇲🇾', dialCode: '+60'),
    CountryInfo(code: 'PH', name: 'Philippines', flag: '🇵🇭', dialCode: '+63'),
    CountryInfo(code: 'BR', name: 'Brazil', flag: '🇧🇷', dialCode: '+55'),
    CountryInfo(code: 'CN', name: 'China', flag: '🇨🇳', dialCode: '+86'),
    CountryInfo(code: 'JP', name: 'Japan', flag: '🇯🇵', dialCode: '+81'),
    CountryInfo(code: 'KR', name: 'South Korea', flag: '🇰🇷', dialCode: '+82'),
    CountryInfo(code: 'RU', name: 'Russia', flag: '🇷🇺', dialCode: '+7'),
    CountryInfo(code: 'IT', name: 'Italy', flag: '🇮🇹', dialCode: '+39'),
    CountryInfo(code: 'ES', name: 'Spain', flag: '🇪🇸', dialCode: '+34'),
    CountryInfo(code: 'NL', name: 'Netherlands', flag: '🇳🇱', dialCode: '+31'),
    CountryInfo(code: 'SE', name: 'Sweden', flag: '🇸🇪', dialCode: '+46'),
    CountryInfo(code: 'CH', name: 'Switzerland', flag: '🇨🇭', dialCode: '+41'),
    CountryInfo(code: 'QA', name: 'Qatar', flag: '🇶🇦', dialCode: '+974'),
    CountryInfo(code: 'KW', name: 'Kuwait', flag: '🇰🇼', dialCode: '+965'),
    CountryInfo(code: 'OM', name: 'Oman', flag: '🇴🇲', dialCode: '+968'),
    CountryInfo(code: 'BH', name: 'Bahrain', flag: '🇧🇭', dialCode: '+973'),
    CountryInfo(code: 'IQ', name: 'Iraq', flag: '🇮🇶', dialCode: '+964'),
    CountryInfo(code: 'JO', name: 'Jordan', flag: '🇯🇴', dialCode: '+962'),
    CountryInfo(code: 'LB', name: 'Lebanon', flag: '🇱🇧', dialCode: '+961'),
    CountryInfo(code: 'AF', name: 'Afghanistan', flag: '🇦🇫', dialCode: '+93'),
    CountryInfo(code: 'ZA', name: 'South Africa', flag: '🇿🇦', dialCode: '+27'),
    CountryInfo(code: 'NG', name: 'Nigeria', flag: '🇳🇬', dialCode: '+234'),
    CountryInfo(code: 'KE', name: 'Kenya', flag: '🇰🇪', dialCode: '+254'),
    CountryInfo(code: 'GH', name: 'Ghana', flag: '🇬🇭', dialCode: '+233'),
    CountryInfo(code: 'MX', name: 'Mexico', flag: '🇲🇽', dialCode: '+52'),
    CountryInfo(code: 'AR', name: 'Argentina', flag: '🇦🇷', dialCode: '+54'),
    CountryInfo(code: 'CL', name: 'Chile', flag: '🇨🇱', dialCode: '+56'),
    CountryInfo(code: 'CO', name: 'Colombia', flag: '🇨🇴', dialCode: '+57'),
    CountryInfo(code: 'SG', name: 'Singapore', flag: '🇸🇬', dialCode: '+65'),
    CountryInfo(code: 'TH', name: 'Thailand', flag: '🇹🇭', dialCode: '+66'),
    CountryInfo(code: 'VN', name: 'Vietnam', flag: '🇻🇳', dialCode: '+84'),
    CountryInfo(code: 'NZ', name: 'New Zealand', flag: '🇳🇿', dialCode: '+64'),
    CountryInfo(code: 'NO', name: 'Norway', flag: '🇳🇴', dialCode: '+47'),
    CountryInfo(code: 'DK', name: 'Denmark', flag: '🇩🇰', dialCode: '+45'),
    CountryInfo(code: 'FI', name: 'Finland', flag: '🇫🇮', dialCode: '+358'),
    CountryInfo(code: 'PL', name: 'Poland', flag: '🇵🇱', dialCode: '+48'),
    CountryInfo(code: 'GR', name: 'Greece', flag: '🇬🇷', dialCode: '+30'),
    CountryInfo(code: 'PT', name: 'Portugal', flag: '🇵🇹', dialCode: '+351'),
    CountryInfo(code: 'IE', name: 'Ireland', flag: '🇮🇪', dialCode: '+353'),
    CountryInfo(code: 'BE', name: 'Belgium', flag: '🇧🇪', dialCode: '+32'),
    CountryInfo(code: 'AT', name: 'Austria', flag: '🇦🇹', dialCode: '+43'),
  ];

  static Future<CountryInfo?> show(BuildContext context, {String? initialCode}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<CountryInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => CountryPickerSheet(
        isDark: isDark,
        initialCode: initialCode,
        onSelected: (country) => Navigator.pop(ctx, country),
      ),
    );
  }

  @override
  State<CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<CountryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.toLowerCase();
    final filtered = CountryPickerSheet.allCountries.where((c) {
      if (query.isEmpty) return true;
      return c.name.toLowerCase().contains(query) ||
          c.dialCode.contains(query) ||
          c.code.toLowerCase().contains(query);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select Country / Region',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(widget.isDark),
            ),
          ),
          const SizedBox(height: 14),

          // Search Field
          TextField(
            controller: _searchController,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Search by country name, ISO, or dial code...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppColors.getTextSecondary(widget.isDark),
              ),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.getBackground(widget.isDark),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Country list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No countries found matching "$_searchQuery"',
                      style: TextStyle(
                        color: AppColors.getTextSecondary(widget.isDark),
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isSelected = widget.initialCode != null &&
                          (widget.initialCode!.toUpperCase() == item.code ||
                              widget.initialCode!.toLowerCase() == item.name.toLowerCase());

                      return ListTile(
                        leading: Text(item.flag, style: const TextStyle(fontSize: 24)),
                        title: Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.getTextPrimary(widget.isDark),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.dialCode,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextSecondary(widget.isDark),
                                fontSize: 13,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
                            ],
                          ],
                        ),
                        onTap: () => widget.onSelected(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
