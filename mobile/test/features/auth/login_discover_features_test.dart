import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/config/app_config.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/link_launcher.dart';
import 'package:pedalons/features/auth/presentation/pages/login_page.dart';
import 'package:pedalons/features/auth/services/passkey_service.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';

/// Un appareil sans clé d'accès : la page n'a besoin de rien d'autre.
class _NoPasskey implements PasskeyService {
  @override
  Future<bool> isSupported() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// « Découvrir les fonctionnalités » ouvre la page de présentation **du
/// site**, sur le domaine de l'installation : l'app n'a pas d'écran pour elle.
void main() {
  setUpAll(loadTestTranslations);

  tearDown(() => debugLinkOpener = null);

  testWidgets('le lien ouvre /fonctionnalites du domaine courant', (
    WidgetTester tester,
  ) async {
    final List<Uri> opened = <Uri>[];
    debugLinkOpener = (Uri url) async {
      opened.add(url);
      return true;
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [passkeyServiceProvider.overrideWithValue(_NoPasskey())],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pump();

    final Finder link = find.byKey(keys.login.discoverFeaturesButton);
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pump();

    expect(opened, hasLength(1));
    expect(opened.single.host, AppConfig.deepLinkHost);
    expect(PathVariants.features().values, contains(opened.single.path));
  });
}
