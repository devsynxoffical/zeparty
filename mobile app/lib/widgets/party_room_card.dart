import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/live_room_model.dart';
import '../core/services/room_lock_manager.dart';
import '../core/services/room_config_manager.dart';
import '../providers/game_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Module 04: Redesigned PartyRoomCard with Full Room DP as Primary Visual
/// Removes circular center host avatar overlay completely.
/// Places metadata cleanly below the image area with approved small corner badges.
class PartyRoomCard extends StatelessWidget {
  final LiveRoomModel room;
  final VoidCallback? onTap;

  const PartyRoomCard({super.key, required this.room, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final gameProvider = Provider.of<GameProvider>(context);
    final cardColor = AppColors.getCard(isDark);
    final borderColor = AppColors.getBorder(isDark);

    final effectiveRoom = RoomConfigManager.instance.applyOverrides(room);
    final totalSeats = (effectiveRoom.viewerCount % 3 == 0) ? 4 : 8;
    final occupiedSeats = (effectiveRoom.viewerCount % totalSeats) + 1;
    final customCover = RoomConfigManager.instance.getCustomCover(effectiveRoom.id);
    final effectiveDp = (customCover != null && customCover.isNotEmpty)
        ? customCover
        : gameProvider.getEffectiveRoomDp(
            effectiveRoom.id,
            effectiveRoom.coverUrl,
            effectiveRoom.host.region,
            hostAvatarUrl: effectiveRoom.host.avatarUrl,
          );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.3) : AppColors.primaryBlue.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Primary Visual: Full Clear Room DP (Square / Rounded-Square) ──
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                    child: Builder(
                      builder: (context) {
                        if (effectiveDp.startsWith('http')) {
                          return Image.network(
                            effectiveDp,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Image.network(
                              effectiveRoom.host.avatarUrl.isNotEmpty
                                  ? effectiveRoom.host.avatarUrl
                                  : gameProvider.globalDefaultRoomDp,
                              fit: BoxFit.cover,
                            ),
                          );
                        } else if (effectiveDp.startsWith('assets')) {
                          return Image.asset(effectiveDp, fit: BoxFit.cover);
                        } else {
                          final f = File(effectiveDp);
                          if (f.existsSync()) {
                            return Image.file(f, fit: BoxFit.cover);
                          }
                          return Image.network(
                            effectiveRoom.host.avatarUrl.isNotEmpty
                                ? effectiveRoom.host.avatarUrl
                                : gameProvider.globalDefaultRoomDp,
                            fit: BoxFit.cover,
                          );
                        }
                      },
                    ),
                  ),

                  Positioned(
                    top: 8.h,
                    left: 8.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.orangeAccent, width: 1),
                      ),
                      child: Text(
                        'PARTY',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // Room Lock Badge (Outside listing)
                  if (RoomLockManager.instance.isRoomLocked(room.id) || room.isPrivate || room.roomMode == 'Lock mode')
                    Positioned(
                      top: 32.h,
                      left: 8.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(color: Colors.cyanAccent, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded, size: 9.sp, color: Colors.cyanAccent),
                            SizedBox(width: 2.w),
                            Text(
                              'Locked',
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 8.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  Positioned(
                    top: 8.h,
                    right: 8.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chair_alt, size: 11.w, color: Colors.amberAccent),
                          SizedBox(width: 3.w),
                          Text(
                            '$occupiedSeats/$totalSeats',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Separate Metadata Area Below Room DP Image ──
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    effectiveRoom.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.getTextPrimary(isDark),
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Text('🇵🇰 ', style: TextStyle(fontSize: 10.sp)),
                      Expanded(
                        child: Text(
                          room.host.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.getTextSecondary(isDark),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
