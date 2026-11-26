<p align="center">
  <img src="https://raw.githubusercontent.com/anilcancakir/magic_social_auth/master/.github/logo.png" width="120" alt="Magic Social Auth logo" />
</p>

<h1 align="center">Magic Social Auth</h1>

<p align="center">
  <strong>Let users sign in with Google, Apple, GitHub and Microsoft.</strong><br/>
  Social sign-in for Magic apps: native Google and Apple sheets, a PKCE browser flow for the rest, and <code>social:install</code> writes the native edits while <code>social:doctor</code> checks them. Your <code>magic-starter-laravel</code> backend decides the outcome; the app owns the session.
</p>

<p align="center">
  <a href="https://pub.dev/packages/magic_social_auth"><img src="https://img.shields.io/pub/v/magic_social_auth.svg" alt="pub package"></a>
  <a href="https://github.com/anilcancakir/magic_social_auth/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/anilcancakir/magic_social_auth/ci.yml?branch=master&label=CI" alt="CI"></a>
  <a href="https://codecov.io/gh/anilcancakir/magic_social_auth"><img src="https://codecov.io/gh/anilcancakir/magic_social_auth/graph/badge.svg" alt="codecov"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://pub.dev/packages/magic_social_auth/score"><img src="https://img.shields.io/pub/points/magic_social_auth" alt="pub points"></a>
</p>

<p align="center">
  <a href="https://anilcancakir.com/magic/docs/social_auth">Documentation</a> ·
  <a href="https://pub.dev/packages/magic_social_auth">pub.dev</a> ·
  <a href="https://github.com/anilcancakir/magic_social_auth/issues">Issues</a>
</p>

## At a glance

| Fact | Value |
|---|---|
| Package | [`magic_social_auth`](https://pub.dev/packages/magic_social_auth) |
| Install | `flutter pub add magic_social_auth`, then `dart run magic:dowel plugin:install magic_social_auth` and `dart run magic:dowel social:install` |
| Import | `package:magic_social_auth/magic_social_auth.dart` |
| Entry points | `SocialAuth` (facade), `SocialAuthManager`, `SocialDriver` with `GoogleDriver`, `AppleDriver` and `RedirectDriver`, `SocialAuthResult`, `SocialAuthButtons`, `SocialAuthServiceProvider`; `social:install` and `social:doctor` (CLI) |
| Platforms | iOS, Android and web. tvOS, macOS, Windows and Linux are not supported. |
| Requires | Dart >=3.13, Flutter >=3.47, `magic` ^1.0.0, and a `magic-starter-laravel` backend with the `social-login` feature on |
| Dependencies | `magic`, `google_sign_in`, `sign_in_with_apple`, `flutter_web_auth_2`, `crypto`; dowel runs the CLI |
| License | MIT |

## Install

```bash
flutter pub add magic_social_auth
dart run magic:dowel plugin:install magic_social_auth
dart run magic:dowel social:install \
  --providers=google,apple,github,microsoft \
  --google-ios-client-id=123-abc.apps.googleusercontent.com \
  --google-server-client-id=123-def.apps.googleusercontent.com \
  --ios-scheme=myapp \
  --android-callback=https://auth.example.com/auth/social
dart run magic:dowel social:doctor
```

`plugin:install` registers the dowel commands and adds `SocialAuthServiceProvider` to `lib/config/app.dart`. `social:install` stages that registration as well, writes `lib/config/social_auth.dart` and adds it to `Magic.init`'s `configFactories`, then makes the native edits for the providers you enable: the Google keys and URL scheme in `Info.plist`, the Sign in with Apple entitlement, the Android callback activity and `web/auth.html`. When the app lists `magic_starter` it also publishes the bridge that feeds the starter's screens. Every flag is optional, `--dry-run` previews, and a file that changed since the last install is reported as a conflict until you pass `--force`.

`social:doctor` checks the result and prints the `MAGIC_STARTER_SOCIAL_*` lines the backend `.env` needs, plus the callback URL each provider console has to list. It exits 1 while a check fails. It cannot prove that an Android App Link verifies or that a provider console lists the callback; those stay a device check.

## Sign in

```dart
import 'package:magic/magic.dart';
import 'package:magic_social_auth/magic_social_auth.dart';

Future<void> signInWith(String provider) async {
  try {
    final SocialAuthResult result = await SocialAuth.driver(provider).signIn();

    if (result.isTwoFactor) {
      // Finish at auth/two-factor-challenge with result.twoFactorToken.
      return;
    }

    await Auth.login(
      {'token': result.token},
      SocialAuth.manager.createUser(result.user!),
    );
  } on SocialAuthCancelledException catch (error) {
    if (!error.superseded) {
      // The user backed out; offer a retry.
    }
  } on SocialAuthException catch (error) {
    // Switch on error.code, never on error.message.
    Log.error('Social sign-in refused: ${error.code}');
  }
}
```

The package never logs the app in. A driver answers a `SocialAuthResult` and the caller decides what a session, a 2FA challenge or a cancelled deletion means. With `magic_starter` you write none of this: the published bridge hands the result to the starter's login and registration.

| Field | Set by |
|-------|--------|
| `token`, `user` | A completed sign-in: the Sanctum token and the user resource. Both are `null` on a challenged sign-in. |
| `isTwoFactor`, `twoFactorToken` | A sign-in on an account with confirmed 2FA. |
| `deletionCancelled` | A sign-in that cancelled a scheduled account deletion. |
| `connectedProvider` | A connect. |
| `confirmationToken` | A confirm. |

Apple answers an `AppleSignInResult`, which adds `givenName` and `familyName`: Apple shares the name on the first authorisation only, so pass it on to a profile update or it is lost.

Failure modes:

| Situation | What happens |
|-----------|--------------|
| The user closes the sheet or popup | `SocialAuthCancelledException`. `superseded` is `true` when another flow took the browser; stay quiet then. On Android a failed App Link verification and a misconfigured Google client report the same cancel. |
| The backend refuses | `SocialAuthException` with the backend's `code` (`social_email_taken`, `flow_expired`, `step_up_required`, ...) and `statusCode`. |
| The SDK or the browser fails | `SocialAuthException` coded `sdk_error`; the detail goes to `Log.error`. |
| Google has no `server_client_id` | `sdk_error`, and the logged message names the key. |
| A flow needs `social_auth.callback.ios` or `.android` and it is empty | `SocialAuthException` that names the key. |
| `enabled: false` for the provider | `SocialAuth.driver(name)` throws `ProviderNotConfiguredException`. |
| A name that is neither built in nor registered | `ArgumentError`. `SocialAuth.supports(name)` answers `false` for both this and the previous row. |
| tvOS, macOS, Windows or Linux | `SocialAuth.supports(name)` is `false`; a browser-flow driver called anyway throws `UnsupportedPlatformException`. |
| A second browser flow on mobile while one is open | `SocialAuthCancelledException(superseded: true)`. |

## Providers and platforms

| Provider | iOS | Android | Web |
|---|---|---|---|
| Google | native SDK | native SDK | browser flow |
| Apple | native sheet | browser flow | browser flow |
| GitHub | browser flow | browser flow | browser flow |
| Microsoft | browser flow | browser flow | browser flow |

The native flows post the SDK's ID token to `auth/social/{provider}/token`. The browser flow is hosted by the backend: the app mints a PKCE pair, opens `<network.drivers.api.base_url>/auth/social/{provider}/redirect`, receives a one-time code on the callback and trades it with the verifier at `auth/social/exchange`. iOS returns through a custom scheme (an https callback needs iOS 17.4), Android through an https App Link on a dedicated host, the web through a popup and `web/auth.html`.

`social:install` writes the config:

```dart
Map<String, dynamic> get socialAuthConfig => {
  'social_auth': {
    'providers': {
      'google': {
        'enabled': true,
        'ios_client_id': '123-abc.apps.googleusercontent.com',
        'server_client_id': '123-def.apps.googleusercontent.com',
      },
      'apple': {'enabled': true},
      'github': {'enabled': true},
      'microsoft': {'enabled': true},
    },
    'callback': {
      'ios': 'myapp://auth/social',
      'android': 'https://auth.example.com/auth/social',
    },
  },
};
```

`callback.ios` and `callback.android` must equal the backend's `MAGIC_STARTER_SOCIAL_IOS_REDIRECT` and `MAGIC_STARTER_SOCIAL_ANDROID_REDIRECT`: the backend takes the redirect target only from its own config. Client secrets and the Apple key live in the backend, never in the app. The backend's base URL is `network.drivers.api.base_url`.

## Connect and confirm

A signed-in user links another provider with `connect`, or re-authenticates with a linked one for a step-up proof with `confirm`.

```dart
import 'package:magic_social_auth/magic_social_auth.dart';

Future<void> link(String password) async {
  // Mobile: one call.
  await SocialAuth.driver('github').connect({'password': password});
}

Future<String?> stepUp() async {
  final SocialAuthResult result = await SocialAuth.driver('google').confirm();

  // Send it as {'confirmation_token': proof} to the gated call.
  return result.confirmationToken;
}
```

| Member | Meaning |
|--------|---------|
| `connect(proof)` | Links the provider. `proof` is `{'password': ...}`, `{'code': ...}` or `{'confirmation_token': ...}`; `null` for a guest. Mint it per call. |
| `beginConnect(proof)` | The web variant: does the network half and returns an opener to call from a second tap, because a popup opened after an `await` is blocked. |
| `confirm()` | Answers `confirmationToken`, a single-use proof for a password-less account's sensitive actions. Needs the caller's bearer token. |

There is no disconnect: unlinking is the backend's `DELETE user/social-accounts/{provider}`, which `magic_starter`'s screens call. The backend answers `step_up_required` when a connect carries no live proof and `last_login_method` when an unlink would remove a password-less account's last way in.

## Buttons

`SocialAuthButtons` renders one button per enabled provider that runs on this platform, in config `order`, with Apple first on iOS.

```dart
import 'package:flutter/widgets.dart';
import 'package:magic_social_auth/magic_social_auth.dart';

Widget buildButtons(void Function(String provider) onPressed) {
  return SocialAuthButtons(
    // No await before signIn(): a web popup must open in the tap's own run.
    onPressed: onPressed,
    mode: SocialAuthMode.signIn,
  );
}
```

`onPressed` runs synchronously from the tap. The widget is built from Wind widgets, so it needs a `WindTheme` above it (`MagicApplication` provides one). Labels come from `trans('auth.sign_in_with')` and `trans('auth.sign_up_with')` unless you pass `labelBuilder`. `loadingProvider` shows a spinner on the tapped button and disables the others.

## Custom providers

```dart
import 'package:magic_social_auth/magic_social_auth.dart';

void registerGitLab() {
  SocialAuth.manager.extend(
    'gitlab',
    (config) => RedirectDriver('gitlab', config),
  );
}
```

Register before the first `SocialAuth.driver('gitlab')`. The backend must host a flow for the provider; the app only carries the PKCE pair. `social_auth.providers.gitlab.enabled: false` still disables it.

## Sign out

`SocialAuth.signOut()` signs out the drivers cached in this process, which is how Google's SDK session ends and the account picker returns. A session restored at boot has cached none, so an app without `magic_starter` signs Google out by name on its own sign-out:

```dart
import 'dart:async';

import 'package:magic/magic.dart';
import 'package:magic_social_auth/magic_social_auth.dart';

void signGoogleOutOnSignOut() {
  Auth.stateNotifier.addListener(() {
    if (!Auth.check() && SocialAuth.supports('google')) {
      unawaited(SocialAuth.driver('google').signOut());
    }
  });
}
```

`SocialAuth.supports('google')` is `false` when Google is disabled, so the lookup never throws. The starter bridge does the same for starter apps.

## For AI coding agents

Rules for an agent writing code against this package. Each one is a mistake that fails silently in a review, on a device or at the backend.

| Do | Because |
|----|---------|
| Import only `package:magic_social_auth/magic_social_auth.dart` | Everything under `src/` is private; `cli.dart` carries the dowel provider only. |
| Register `SocialAuthServiceProvider` through `social:install` | It is not auto-registered, and without it `SocialAuth` cannot resolve the manager. |
| Run `dart run magic:dowel social:doctor` after any native or config change | A wrong native edit is silent: a sheet that closes at once, a button that does nothing, a review rejection. |
| Call `SocialAuth.driver(name).signIn()` straight from the tap handler | On the web a popup opened after an `await` is blocked. |
| Run `Auth.login` yourself, or let the starter bridge do it | The package never creates a session. |
| Check `isTwoFactor` before reading `token` | `token` and `user` are `null` on a challenged sign-in. |
| Switch on `SocialAuthException.code`, never on `message` | The backend translates the message. |
| Keep `callback.ios` and `callback.android` equal to the backend's redirect env | A mismatch lands the browser where the app is not listening. |
| Give Android a dedicated callback host | Another App Link filter on the same host may open the wrong activity. |
| Build the `proof` map per call and call `beginConnect` again per attempt | Every connect mints a new PKCE pair, link ticket and proof; none is reusable. |
| Never send a nonce for Google, or the raw nonce to Apple, from a custom driver | Google takes none; Apple gets the sha256 hex and the backend gets the raw value. |
| Sign Google out by name on every transition to signed-out when there is no starter bridge | `SocialAuth.signOut()` reaches only cached drivers. |
| Leave client secrets and the Apple key out of the app | They belong to the backend's environment. |
| In a test, fake the platform through the `@visibleForTesting` seams, not a method channel | The SDK and browser calls only exist behind a platform channel. |

## Dependencies

`magic` for the container, `Config`, `Http` and `Auth`; `google_sign_in` and `sign_in_with_apple` for the native sheets; `flutter_web_auth_2` for the browser flow; `crypto` for the PKCE challenge and the Apple nonce hash; dowel to run `social:install` and `social:doctor` through `dart run magic:dowel`. The commands live in `package:magic_social_auth/cli.dart`, which imports no UI toolkit so the command line runs as a plain Dart process.

## Links

- [Documentation](https://anilcancakir.com/magic/docs/social_auth/getting-started/installation): installation, configuration, drivers, flows and the architecture
- [API reference](https://pub.dev/documentation/magic_social_auth/latest/)
- [llms.txt](llms.txt) and the [agent skill](skills/magic-social-auth/SKILL.md) for AI coding agents: `npx skills add anilcancakir/magic_social_auth`
- [Changelog](CHANGELOG.md)
- [Report an issue](https://github.com/anilcancakir/magic_social_auth/issues)
- [Security policy](SECURITY.md)

## License

MIT, see [LICENSE](LICENSE). Built by [Anılcan Çakır](https://anilcancakir.com).
