import 'dart:io' show Platform;

import 'package:magic/magic.dart' show MagicPlatform;

import 'social_platform.dart';

/// IO implementation for native platforms (iOS, tvOS, Android, macOS, Windows, Linux).
SocialPlatform getCurrentPlatform() {
  // tvOS first: the Dart VM answers iOS there.
  if (MagicPlatform.isTvOS) return SocialPlatform.tvos;
  if (Platform.isIOS) return SocialPlatform.ios;
  if (Platform.isAndroid) return SocialPlatform.android;
  if (Platform.isMacOS) return SocialPlatform.macos;
  if (Platform.isWindows) return SocialPlatform.windows;
  if (Platform.isLinux) return SocialPlatform.linux;
  return SocialPlatform.web; // Fallback
}
