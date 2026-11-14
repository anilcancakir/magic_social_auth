# Flows

Every provider ends at the same place: `magic-starter-laravel` answers a Sanctum token, or a two-factor challenge when the account confirmed 2FA, and this package hands the answer to the caller as a `SocialAuthResult` without ever logging the app in.

- [Native Token Flow](#native-token-flow)
- [Browser Flow](#browser-flow)
- [Completing a Sign-In](#completing-a-sign-in)
- [Connecting a Provider](#connecting-a-provider)
- [Confirming an Identity](#confirming-an-identity)
- [Account Deletion](#account-deletion)
- [Signing Out](#signing-out)
- [Errors](#errors)
- [Guarantees](#guarantees)
- [Gotchas](#gotchas)
- [Related Documentation](#related-documentation)

<a name="native-token-flow"></a>
## Native Token Flow

There are two ways to reach the backend, and a driver picks one per provider and platform (see [Drivers](./drivers.md#platform-support-matrix)).

Google (iOS, Android) and Apple (iOS) already hold an ID token after their native sheet, so the app skips the browser and posts it to `POST auth/social/{provider}/token` with an `intent` of `signin`, `connect` or `confirm`.

- A provider access token is never sent: the backend accepts an ID token checked against its configured audiences.
- Apple: the sheet gets the lowercase sha256 hex of a fresh nonce; the backend gets the raw nonce and the authorisation code. One nonce per sheet.
- Google: no nonce at all.
- The token is single use; a replayed one is refused.

<a name="browser-flow"></a>
## Browser Flow

GitHub and Microsoft everywhere, Apple on Android and the web, Google on the web. Three steps, hosted by the backend:

1. **Redirect.** The app mints a PKCE pair and opens `GET <base_url>/auth/social/{provider}/redirect?platform=<ios|android|web>&challenge=<challenge>` in the system browser. A connect adds `ticket=<link ticket>`; a confirm adds `intent=confirm`.
2. **Callback.** The provider sends the browser to the backend's fixed callback, which sends it on to the app: `myapp://auth/social?code=...` on iOS, `https://auth.example.com/auth/social?code=...` on Android, the app's `auth.html` on the web. A refusal arrives as `?error=<code>`. No token is ever placed in a URL.
3. **Exchange.** The app posts `{code, code_verifier}` to `POST auth/social/exchange`. The code is single use, bound to the PKCE challenge, and worthless without the verifier.

On iOS the browser is a web authentication session; on Android an Auth Tab with `httpsHost` and `httpsPath` from `callback.android`; on the web a popup.

<a name="completing-a-sign-in"></a>
## Completing a Sign-In

Without `magic_starter`, the app finishes the sign-in itself:

```dart
import 'package:magic/magic.dart';
import 'package:magic_social_auth/magic_social_auth.dart';

Future<void> signInWith(String provider) async {
  try {
    final SocialAuthResult result = await SocialAuth.driver(provider).signIn();

    if (result.isTwoFactor) {
      // The account confirmed 2FA: finish at auth/two-factor-challenge with
      // result.twoFactorToken and the user's code.
      return;
    }

    await Auth.login(
      {'token': result.token},
      SocialAuth.manager.createUser(result.user!),
    );

    if (result.deletionCancelled) {
      // Signing in cancelled a scheduled account deletion: tell the user.
    }
  } on SocialAuthCancelledException catch (error) {
    // The user backed out, or another flow took the browser.
    if (!error.superseded) {
      // Offer a retry.
    }
  } on SocialAuthException catch (error) {
    // Switch on error.code, never on error.message.
  }
}
```

On the web, call this straight from the tap handler: the provider popup has to open in the same synchronous run as the tap, so nothing may be `await`ed first. `SocialAuthButtons` calls `onPressed` synchronously for this reason.

With Apple, check for `AppleSignInResult` to pick up `givenName` and `familyName`; they exist on the first authorisation only.

`magic_starter` apps do not write any of this: the bridge `social:install` publishes feeds the result into the starter's login and registration completion, which handles 2FA, `Auth.login` and `deletion_cancelled`.

<a name="connecting-a-provider"></a>
## Connecting a Provider

A signed-in user links another provider to the account. A linked identity is a new way into the account, so the caller steps up first:

| Account | Proof sent with the connect |
|:--------|:----------------------------|
| Has a password | `{'password': ...}` |
| No password, 2FA confirmed | `{'code': <TOTP>}`, or a `confirmation_token` |
| No password | `{'confirmation_token': ...}` from [confirming](#confirming-an-identity) a provider already linked |
| Guest (`is_guest`, no password) | none (`null`) |

```dart
import 'package:magic_social_auth/magic_social_auth.dart';

// Mobile: one call.
Future<void> connectOnMobile(String password) {
  return SocialAuth.driver('github').connect({'password': password});
}

// Web: the link ticket is a network call, so open the popup from a second tap.
Future<Future<SocialAuthResult> Function()> prepareOnWeb(String password) {
  return SocialAuth.driver('github').beginConnect({'password': password});
}

// ...in the next tap handler (an explicit "Continue to GitHub" button):
Future<SocialAuthResult> continueOnWeb(
  Future<SocialAuthResult> Function() open,
) {
  return open();
}
```

The backend answers 422 `step_up_required` with `accepts` naming the proofs this account can send when no live proof came along. Every connect mints a new PKCE pair, a new link ticket and a new proof; nothing is cached across attempts. A link ticket is single use and expires after the backend's `link_ticket_ttl` (300 seconds by default).

This package has no disconnect. Unlinking a provider (`DELETE user/social-accounts/{provider}`) and setting a first password (`POST user/password/set`) are backend calls that `magic_starter`'s own screens make, see [connected accounts](https://anilcancakir.com/magic/docs/starter/basics/connected-accounts) and [set password](https://anilcancakir.com/magic/docs/starter/basics/set-password). The backend refuses to remove the last sign-in method of a password-less account (`last_login_method`).

<a name="confirming-an-identity"></a>
## Confirming an Identity

A password-less account that is not a guest has no password to type for a sensitive action (deleting the account, removing a session, changing 2FA, linking a provider, setting a password). It re-authenticates with a provider it already linked:

```dart
import 'package:magic_social_auth/magic_social_auth.dart';

Future<String> confirmWithGoogle() async {
  final SocialAuthResult result = await SocialAuth.driver('google').confirm();

  // Send it as {'confirmation_token': proof} to the gated call.
  return result.confirmationToken!;
}
```

`confirm()` needs the caller's bearer token. The proof is single use and short lived (the backend's `confirmation_ttl`, 600 seconds by default). On iOS the browser session is ephemeral, so the provider asks for the account again instead of waving a remembered one through. A confirm for an identity that is not linked to the caller is refused with 403 `invalid_identity`.

<a name="account-deletion"></a>
## Account Deletion

Deleting an account is scheduled, not immediate. `DELETE user` answers `202` with `data.deletion_scheduled_at`, revokes every token of the user at once, and the account is purged after a grace period (30 days by default). Signing in again, by any method, within the grace period cancels the deletion: the sign-in answer carries `deletion_cancelled: true`, which this package exposes as `SocialAuthResult.deletionCancelled`. The user resource carries `deletion_scheduled_at` so a client holding a token can tell a deletion is pending.

<a name="signing-out"></a>
## Signing Out

The Google SDK keeps its own session, so the next sign-in skips the account picker unless it is signed out. `GoogleDriver.signOut()` does it. `SocialAuth.signOut()` signs out every driver the manager has cached in this process, then clears the cache.

A session restored at boot has created no driver, so sign Google out by name on every transition to signed-out:

```dart
import 'package:magic_social_auth/magic_social_auth.dart';

Future<void> signGoogleOut() async {
  // supports() is false when Google is disabled; driver() would throw
  // ProviderNotConfiguredException instead.
  if (SocialAuth.supports('google')) {
    await SocialAuth.driver('google').signOut();
  }
}
```

The bridge `social:install` publishes does this for `magic_starter` apps, listening to `Auth.stateNotifier`. An app without `magic_starter` has to do it on its own sign-out (see [Installation](../getting-started/installation.md#without-magic_starter)).

<a name="errors"></a>
## Errors

| Exception | Meaning |
|:----------|:--------|
| `SocialAuthCancelledException` | The user closed the sheet, or another flow took the browser (`superseded` is `true`; the newer flow reports the outcome, so stay quiet). On Android an Auth Tab whose App Link verification failed also reports this, so the message invites a retry. |
| `SocialAuthException` | A backend refusal. `code` is the backend's machine code (or the `error` a browser callback carried), `statusCode` the HTTP status, `message` a translated sentence. A failure of the SDK or the browser carries the code `sdk_error`. |
| `UnsupportedPlatformException` | The browser flow does not run on this platform. |
| `ProviderNotConfiguredException` | The provider has `enabled: false` in `social_auth.providers`. |

Switch on `code`, never on `message`. The codes the backend sends:

| Code | Meaning |
|:-----|:--------|
| `social_email_taken` | An account with this email exists. The owner signs in and connects the provider from their profile. |
| `social_account_taken` | The provider account is linked to another user, or the caller already holds another account of that provider. |
| `last_login_method` | The last sign-in method of a password-less account cannot be removed. |
| `provider_not_supported` | Unknown provider, or not on the backend allowlist. |
| `platform_not_configured` | No redirect target for the platform, or the provider is not configured. |
| `flow_expired` | The state, code or ticket is unknown, expired or already used. |
| `invalid_identity` | The provider's answer or ID token could not be verified. |
| `provider_email_missing` | The provider returned no email for a new account. |
| `password_already_set` | The account already has a password. |
| `password_not_set` | The account has no password to change; set one instead. |
| `step_up_required` | A sensitive action needs a `code` or `confirmation_token`. |
| `provider_unavailable` | The provider's key set could not be fetched (503); retry later. |
| `owns_shared_teams`, `team_has_active_subscription`, `subscription_active` | Account deletion refused. |

<a name="guarantees"></a>
## Guarantees

- Every browser flow mints a new PKCE pair (verifier of 64 characters from `A-Z a-z 0-9 - _`, challenge `base64url(sha256(verifier))`, 43 characters). Nothing is persisted.
- One browser flow at a time on mobile: a second start while one is open throws `SocialAuthCancelledException(superseded: true)`. On the web a new click supersedes a pending popup, and only the newest flow spends its code.
- A request that fails because of a missing redirect key names the key (`social_auth.callback.ios`) in its message.

<a name="gotchas"></a>
## Gotchas

| Mistake | Fix |
|:--------|:----|
| Reading a refusal from `SocialAuthException.message` | The backend translates it. Switch on `code`. |
| Calling `Auth.login` with `result.token` when `result.isTwoFactor` is `true` | `token` and `user` are `null` on a challenged sign-in. Finish the 2FA challenge with `twoFactorToken` first. |
| Treating every `SocialAuthCancelledException` as the user backing out | A failed Android App Link verification and a misconfigured Google client report the same cancel. Offer a retry, and stay quiet only when `superseded` is `true`. |
| Relying on `SocialAuth.signOut()` to sign Google out after the app restarted | It only reaches drivers cached in this process. Sign Google out by name, behind `SocialAuth.supports('google')`, on every transition to signed-out. |
| Looking for a disconnect method on a driver | There is none. Unlinking is the backend's `DELETE user/social-accounts/{provider}`, which `magic_starter`'s screens call. |
| Starting a second mobile flow while one is open | It throws `SocialAuthCancelledException(superseded: true)`. Pass `SocialAuthButtons.loadingProvider` while a flow runs: it disables the other buttons. |

<a name="related-documentation"></a>
## Related Documentation

- [Drivers](./drivers.md): the driver contract and the platform matrix.
- [Configuration](../getting-started/configuration.md): the callback keys the browser flow returns to and the `SocialAuthButtons` parameters.
- [Installation](../getting-started/installation.md): `social:install`, `social:doctor` and the backend values.
- [Architecture overview](../architecture/overview.md): how the flow client fits with the drivers.
- [Connected accounts in magic_starter](https://anilcancakir.com/magic/docs/starter/basics/connected-accounts): the screens that link and unlink providers.
