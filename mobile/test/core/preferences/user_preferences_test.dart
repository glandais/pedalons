import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/models/theme_preference.dart';
import 'package:pedalons/api/generated/models/unit_system.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> mirrorWith(Map<String, Object> values) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('miroir local', () {
    test(
      'un démarrage à froid restitue le mode avant tout appel réseau',
      () async {
        final SharedPreferences prefs = await mirrorWith(<String, Object>{
          'prefs.theme': 'DARK',
          'prefs.unitSystem': 'IMPERIAL',
          'prefs.language': 'en',
        });
        final UserPreferences p = readMirror(prefs);
        expect(p.theme, ThemePreference.dark);
        expect(p.themeMode, ThemeMode.dark);
        expect(p.unitSystem, UnitSystem.imperial);
        expect(p.language, 'en');
      },
    );

    test('un miroir vide donne les défauts, pas une erreur', () async {
      final SharedPreferences prefs = await mirrorWith(<String, Object>{});
      final UserPreferences p = readMirror(prefs);
      expect(p.theme, ThemePreference.system);
      expect(p.themeMode, ThemeMode.system);
      expect(p.unitSystem, UnitSystem.metric);
      expect(p.language, isNull);
    });

    test('une valeur inconnue du miroir retombe sur « système »', () async {
      final SharedPreferences prefs = await mirrorWith(<String, Object>{
        'prefs.theme': 'SEPIA',
      });
      final UserPreferences p = readMirror(prefs);
      expect(p.theme, ThemePreference.$unknown);
      expect(p.themeMode, ThemeMode.system);
    });

    test('contactableByMembers n\'est jamais miroité', () async {
      final SharedPreferences prefs = await mirrorWith(<String, Object>{
        'prefs.theme': 'LIGHT',
      });
      expect(prefs.getKeys(), isNot(contains('prefs.contactableByMembers')));
      // Il reprend donc son défaut à chaque démarrage, jusqu'à ce que
      // `GET /api/users/me` donne la valeur réelle.
      expect(readMirror(prefs).contactableByMembers, isTrue);
    });
  });

  group('UserPreferences', () {
    test('themeMode couvre les quatre valeurs de ThemePreference', () {
      const UserPreferences base = UserPreferences();
      expect(
        base.copyWith(theme: ThemePreference.light).themeMode,
        ThemeMode.light,
      );
      expect(
        base.copyWith(theme: ThemePreference.dark).themeMode,
        ThemeMode.dark,
      );
      expect(
        base.copyWith(theme: ThemePreference.system).themeMode,
        ThemeMode.system,
      );
      expect(
        base.copyWith(theme: ThemePreference.$unknown).themeMode,
        ThemeMode.system,
      );
    });

    test('copyWith distingue « langue non fournie » de « langue effacée »', () {
      const UserPreferences p = UserPreferences(language: 'fr');
      // Paramètre omis : la langue est conservée.
      expect(p.copyWith(theme: ThemePreference.dark).language, 'fr');
      // Paramètre explicitement nul : la langue est effacée, et l'app
      // retombe alors sur celle de l'appareil.
      expect(p.copyWith(language: null).language, isNull);
    });
  });
}
