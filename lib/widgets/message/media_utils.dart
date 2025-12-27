import '../../core/constants/ui_constants.dart';

/// Calculates display dimensions for media content while maintaining aspect ratio.
///
/// Returns (width, height) tuple constrained to max dimensions.
/// Falls back to default dimensions if source size is invalid.
(double, double) calculateMediaDimensions({
  int? width,
  int? height,
  double maxWidth = MediaSize.maxWidth,
  double maxHeight = MediaSize.maxHeight,
  double defaultWidth = MediaSize.defaultWidth,
  double defaultHeight = MediaSize.defaultHeight,
}) {
  if (width == null || height == null || width <= 0 || height <= 0) {
    return (defaultWidth, defaultHeight);
  }

  final aspectRatio = width / height;
  double displayWidth;
  double displayHeight;

  if (aspectRatio > 1) {
    // Landscape
    displayWidth = maxWidth;
    displayHeight = maxWidth / aspectRatio;
    if (displayHeight > maxHeight) {
      displayHeight = maxHeight;
      displayWidth = maxHeight * aspectRatio;
    }
  } else {
    // Portrait or square
    displayHeight = maxHeight;
    displayWidth = maxHeight * aspectRatio;
    if (displayWidth > maxWidth) {
      displayWidth = maxWidth;
      displayHeight = maxWidth / aspectRatio;
    }
  }

  return (displayWidth, displayHeight);
}
