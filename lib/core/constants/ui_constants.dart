/// Semantic design tokens for consistent UI dimensions across the app.
///
/// Organized by category for easy discovery and maintenance.
library;

/// Spacing values following a consistent scale.
class Spacing {
  Spacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

/// Media content dimensions (photos, videos, thumbnails).
class MediaSize {
  MediaSize._();

  static const double maxWidth = 250.0;
  static const double maxHeight = 300.0;
  static const double defaultWidth = 200.0;
  static const double defaultHeight = 150.0;
  static const double stickerSize = 150.0;
}

/// Avatar size variants.
class AvatarSize {
  AvatarSize._();

  static const double sm = 40.0;
  static const double md = 50.0;
  static const double lg = 60.0;
}

/// Icon size variants.
class IconSize {
  IconSize._();

  static const double sm = 20.0;
  static const double md = 28.0;
  static const double lg = 40.0;
  static const double xl = 64.0;
}

/// Border radius values.
class Radii {
  Radii._();

  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double full = 9999.0;
}

/// Opacity values for consistent transparency.
class Opacities {
  Opacities._();

  static const double subtle = 0.3;
  static const double muted = 0.4;
  static const double medium = 0.5;
  static const double high = 0.7;
}

/// Gesture thresholds for interactions.
class GestureThreshold {
  GestureThreshold._();

  static const double dismissDrag = 100.0;
  static const double swipeAction = 80.0;
}

/// Auth screen specific dimensions.
class AuthLayout {
  AuthLayout._();

  static const double dialogWidth = 450.0;
  static const double dialogHeight = 600.0;
  static const double qrCodeSize = 250.0;
}

/// Layout ratios for responsive design.
class LayoutRatio {
  LayoutRatio._();

  static const double leftPaneWidth = 0.3;
  static const double bottomSheetHeight = 0.7;
}
