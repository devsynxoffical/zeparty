import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class RoomTypeSelectorSheet extends StatefulWidget {
  final String initialRoomType;
  final int initialCapacity;
  final Function(String roomType, int capacity) onApply;

  const RoomTypeSelectorSheet({
    super.key,
    required this.initialRoomType,
    required this.initialCapacity,
    required this.onApply,
  });

  @override
  State<RoomTypeSelectorSheet> createState() => _RoomTypeSelectorSheetState();
}

class _RoomTypeSelectorSheetState extends State<RoomTypeSelectorSheet> {
  late String _selectedRoomType;
  late int _selectedCapacity;

  final List<int> _capacityOptions = [10, 15, 20, 30];

  @override
  void initState() {
    super.initState();
    _selectedRoomType = widget.initialRoomType;
    _selectedCapacity = widget.initialCapacity;
    if (!_capacityOptions.contains(_selectedCapacity)) {
      _selectedCapacity = 10;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final cardBg = isDark ? const Color(0xFF1E1B2E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Handle Indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white30 : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Center(
              child: Text(
                'Room Type & Seats Layout',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── 1. Room Type Tabs (Video Room / Voice Room) ──
            Text(
              'Room Type',
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeTab('Voice Room', Icons.mic_rounded, primary, isDark),
                  ),
                  Expanded(
                    child: _buildTypeTab('Video Room', Icons.videocam_rounded, primary, isDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 2. Seat Capacity Options (10, 15, 20, 30) ──
            Text(
              'Seat Capacity',
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _capacityOptions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
              ),
              itemBuilder: (context, index) {
                final cap = _capacityOptions[index];
                final isSelected = _selectedCapacity == cap;
                return _buildCapacityCard(cap, isSelected, primary, isDark);
              },
            ),
            const SizedBox(height: 28),

            // ── 3. Bottom Action Buttons (Cancel / Done) ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? Colors.white30 : Colors.grey.shade400,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(_selectedRoomType, _selectedCapacity);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: AppColors.onPrimary(isDark: isDark),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeTab(String typeName, IconData icon, Color primary, bool isDark) {
    final isSelected = _selectedRoomType == typeName;
    return GestureDetector(
      onTap: () => setState(() => _selectedRoomType = typeName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? AppColors.onPrimary(isDark: isDark)
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              typeName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected
                    ? AppColors.onPrimary(isDark: isDark)
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapacityCard(int seats, bool isSelected, Color primary, bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _selectedCapacity = seats),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primary : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Seats Count Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_seat_rounded,
                  size: 16,
                  color: isSelected ? primary : (isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(width: 4),
                Text(
                  '$seats Seats',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isSelected ? primary : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check_circle_rounded, size: 14, color: primary),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // Visual Seat Diagram Representation
            _buildSeatDiagramPreview(seats, isSelected, primary, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatDiagramPreview(int seats, bool isSelected, Color primary, bool isDark) {
    int rows = seats <= 10 ? 2 : (seats <= 15 ? 3 : (seats <= 20 ? 3 : 4));
    int dotsPerRow = (seats / rows).ceil();
    final dotColor = isSelected ? primary : (isDark ? Colors.white38 : Colors.grey.shade400);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rows, (r) {
        int dotsInThisRow = (r == rows - 1) ? (seats - (r * dotsPerRow)) : dotsPerRow;
        if (dotsInThisRow <= 0) dotsInThisRow = dotsPerRow;
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              dotsInThisRow,
              (d) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: (r == 0 && d == 0) ? Colors.amber : dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
