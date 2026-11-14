import 'package:dowel/dowel.dart';

import 'commands/social_doctor_command.dart';
import 'commands/social_install_command.dart';

/// Contributes social:* commands to the dowel dispatcher.
///
/// `plugin:install` registers it in the host's `.dowel/plugins.json`.
///
/// Ships `social:install` (config, native files and the starter bridge) and
/// `social:doctor` (checks them and prints the backend env to set).
class MagicSocialAuthDowelProvider extends DowelServiceProvider {
  @override
  String get providerName => 'magic_social_auth';

  @override
  List<DowelCommand> commands() => <DowelCommand>[
    SocialInstallCommand(),
    SocialDoctorCommand(),
  ];
}
