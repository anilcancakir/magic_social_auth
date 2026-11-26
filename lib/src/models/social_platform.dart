// Conditional imports to avoid dart:io on web
import 'social_platform_stub.dart'
    if (dart.library.io) 'social_platform_io.dart'
    if (dart.library.html) 'social_platform_web.dart';

/// Platforms social authentication tells apart.
///
/// [tvos] is named so a flow can refuse it: no sign-in SDK has a tvOS half,
/// and the Dart VM answers iOS there.
enum SocialPlatform { ios, android, web, macos, windows, linux, tvos }

/// Extension methods for [SocialPlatform].
extension SocialPlatformExtension on SocialPlatform {
  /// Get the current platform.
  static SocialPlatform get current => getCurrentPlatform();

  /// Check if this platform is mobile.
  bool get isMobile =>
      this == SocialPlatform.ios || this == SocialPlatform.android;

  /// Check if this platform is desktop.
  bool get isDesktop =>
      this == SocialPlatform.macos ||
      this == SocialPlatform.windows ||
      this == SocialPlatform.linux;
}
