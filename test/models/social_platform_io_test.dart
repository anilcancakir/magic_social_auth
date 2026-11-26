import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_social_auth/src/models/social_platform.dart';

void main() {
  group('current on tvOS', () {
    test('answers tvos where the Dart VM would read ios or macos', () {
      MagicPlatform.debugTvOSOverride = true;
      addTearDown(() => MagicPlatform.debugTvOSOverride = null);

      expect(SocialPlatformExtension.current, SocialPlatform.tvos);
    });

    test('leaves the host answer alone when not on tvOS', () {
      MagicPlatform.debugTvOSOverride = false;
      addTearDown(() => MagicPlatform.debugTvOSOverride = null);

      expect(SocialPlatformExtension.current, isNot(SocialPlatform.tvos));
    });
  });

  test('tvos is neither mobile nor desktop', () {
    expect(SocialPlatform.tvos.isMobile, isFalse);
    expect(SocialPlatform.tvos.isDesktop, isFalse);
  });
}
