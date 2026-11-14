# magic_social_auth example

A Magic app with one row per provider (Google, Apple, GitHub, Microsoft). Each row shows whether the provider runs on this platform and which driver `SocialAuth.driver(name)` resolves to (`GoogleDriver` or `AppleDriver` for a native sheet, `RedirectDriver` for the browser flow), and a button that calls `signIn()` straight from the tap.

```bash
cd example
flutter create --platforms=web .
flutter run -d chrome
```

`flutter create` adds the platform folder once; it leaves `lib/` and `pubspec.yaml` as they are.

## What works without a backend

Booting the app, registering `SocialAuthServiceProvider`, reading the `social_auth` config and resolving a driver per provider all run offline, so the rows render on their own. On the web every provider is a `RedirectDriver`; on a phone Google and Apple are native. Pressing `Sign in` without a backend only says so: a sign-in is a request to `magic-starter-laravel`, and this example does not pretend otherwise.

## What needs a backend, a device or a console

- **A flow.** Pass your backend's API base URL: `flutter run -d chrome --dart-define=API_BASE_URL=<your API base>`. The backend needs the `social-login` feature on and the provider keys set.
- **The web popup.** Copy `../assets/stubs/install/auth.html.stub` to `web/auth.html` (`social:install` writes it in a real app) and set the backend's `MAGIC_STARTER_SOCIAL_WEB_REDIRECT` to `https://<origin>/auth.html`.
- **Native sheets.** Google and Apple on a phone need the native edits `dart run magic:dowel social:install` makes (client ids, URL scheme, the Sign in with Apple entitlement) and a device. The callbacks in `lib/main.dart` are placeholders; replace them with values equal to the backend's `MAGIC_STARTER_SOCIAL_IOS_REDIRECT` and `MAGIC_STARTER_SOCIAL_ANDROID_REDIRECT`.

A completed sign-in reports the user id the backend answered. The example never calls `Auth.login`: the package leaves the session to the app, so a real app does that where the example comment says. Client secrets and the Apple key belong to the backend's environment, never to this app.
