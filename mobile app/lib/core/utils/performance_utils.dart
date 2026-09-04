import 'dart:math';

/// Utility class for performance optimizations, image cache sizing,
/// and financial transaction idempotency validation.
class PerformanceUtils {
  PerformanceUtils._();

  /// Calculate optimal memory cache width for CircleAvatar or thumbnail widgets.
  /// Reduces RAM usage by avoiding decoding full 4K or 1080p images in memory.
  static int getMemCacheWidth(double displayRadiusOrWidth, [double pixelRatio = 2.0]) {
    return (displayRadiusOrWidth * pixelRatio).clamp(50, 600).toInt();
  }

  /// Calculate optimal memory cache height.
  static int getMemCacheHeight(double displayHeight, [double pixelRatio = 2.0]) {
    return (displayHeight * pixelRatio).clamp(50, 800).toInt();
  }

  /// Generate a unique transaction idempotency key to prevent double spending.
  static String generateIdempotencyKey(String prefix) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomPart = Random().nextInt(999999).toString().padLeft(6, '0');
    return '${prefix}_${timestamp}_$randomPart';
  }
}
