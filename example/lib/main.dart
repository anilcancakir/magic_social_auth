import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_social_auth/magic_social_auth.dart';

const Color _ink = Color(0xFF111827);
const Color _accent = Color(0xFF4F46E5);
const TextStyle _text = TextStyle(color: _ink, fontSize: 16);

/// The backend's API base URL, read from `--dart-define=API_BASE_URL=...`.
///
/// Empty by default: the example then shows what resolves offline and runs no
/// flow, because a flow needs a `magic-starter-laravel` backend to answer it.
const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

const List<String> _providers = <String>[
  'google',
  'apple',
  'github',
  'microsoft',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Magic.init(
    configs: [
      {
        'app': {
          'providers': [
            (app) => NetworkServiceProvider(app),
            (app) => SocialAuthServiceProvider(app),
          ],
        },
        'network': {
          'drivers': {
            'api': {'base_url': _apiBaseUrl},
          },
        },
        // What `social:install` writes to lib/config/social_auth.dart. The
        // callbacks are placeholders: replace them with your own, equal to the
        // backend's MAGIC_STARTER_SOCIAL_IOS_REDIRECT and
        // MAGIC_STARTER_SOCIAL_ANDROID_REDIRECT.
        'social_auth': {
          'providers': {
            'google': {
              'enabled': true,
              'ios_client_id': '',
              'server_client_id': '',
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
      },
    ],
  );

  runApp(const ExampleApp());
}

/// One row per provider: the driver it resolves to and a sign-in button.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'magic_social_auth example',
      color: _accent,
      textStyle: _text,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        );
      },
      home: const ProvidersPage(),
    );
  }
}

class ProvidersPage extends StatefulWidget {
  const ProvidersPage({super.key});

  @override
  State<ProvidersPage> createState() => _ProvidersPageState();
}

class _ProvidersPageState extends State<ProvidersPage> {
  final Map<String, String> _outcome = <String, String>{};

  String? _running;

  void _signIn(String provider) {
    if (_apiBaseUrl.isEmpty) {
      setState(() {
        _outcome[provider] =
            'No backend. Run with --dart-define=API_BASE_URL=<your API base>.';
      });
      return;
    }

    setState(() => _running = provider);

    // No await before signIn(): a web popup must open in the tap's own run.
    SocialAuth.driver(provider).signIn().then(
      (SocialAuthResult result) => _finish(provider, _describe(result)),
      onError: (Object error) => _finish(provider, _describeError(error)),
    );
  }

  void _finish(String provider, String outcome) {
    if (!mounted) return;

    setState(() {
      _running = null;
      _outcome[provider] = outcome;
    });
  }

  String _describe(SocialAuthResult result) {
    if (result.isTwoFactor) return 'The account needs its 2FA code.';

    // The package never logs the app in; a real app calls Auth.login here.
    return 'The backend signed in user ${result.user?['id']}.';
  }

  String _describeError(Object error) {
    if (error is SocialAuthCancelledException) return 'Cancelled.';
    if (error is SocialAuthException) {
      return '${error.code ?? 'error'}: ${error.message}';
    }

    return '$error';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final String provider in _providers) ...[
              _row(provider),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String provider) {
    if (!SocialAuth.supports(provider)) {
      return Text('$provider: not supported on this platform', style: _text);
    }

    final String driver = '${SocialAuth.driver(provider).runtimeType}';
    final String? outcome = _outcome[provider];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$provider runs as $driver', style: _text),
        const SizedBox(height: 8),
        Row(
          children: [
            _Button(
              label: _running == provider ? 'Running...' : 'Sign in',
              onTap: _running == null ? () => _signIn(provider) : null,
            ),
          ],
        ),
        if (outcome != null) ...[
          const SizedBox(height: 8),
          Text(outcome, style: _text),
        ],
      ],
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: onTap == null ? const Color(0xFF9CA3AF) : _accent,
        child: Text(label, style: const TextStyle(color: Color(0xFFFFFFFF))),
      ),
    );
  }
}
