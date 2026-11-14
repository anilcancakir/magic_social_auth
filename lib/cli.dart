/// Flutter-free dowel-CLI surface for magic_social_auth.
///
/// Exposes ONLY the dowel-CLI surface ([MagicSocialAuthDowelProvider]).
/// Does NOT export any Flutter runtime symbols (no `dart:ui` imports), so this
/// barrel is safe for consumption from pure-Dart dowel dispatchers.
///
/// `plugin:install` registers the provider in the consumer's `bin/dispatcher.dart`; wiring it by hand looks like:
///
/// ```dart
/// import 'package:dowel/dowel.dart';
/// import 'package:magic_social_auth/cli.dart' show MagicSocialAuthDowelProvider;
///
/// Future<void> main(List<String> args) async {
///   final registry = DowelRegistry()
///     ..registerProvider(MagicSocialAuthDowelProvider());
///   exit(await DowelApplication(registry: registry).dispatch(args));
/// }
/// ```
///
/// Runtime consumers (lib/main.dart of a Magic-based app) continue to import
/// `package:magic_social_auth/magic_social_auth.dart` for the full surface.
library;

export 'src/cli/social_auth_dowel_provider.dart';
