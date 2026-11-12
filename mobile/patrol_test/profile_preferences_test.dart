import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart' show Brightness;
import 'package:pedalons/core/units/unit_system.dart';
import 'package:pedalons/core/utils/formatters.dart';

import 'api/ads_seed.dart';
import 'api/profile_seed.dart';
import 'common.dart';

/// Web counterpart: `flow-account.e2e.ts` › profile settings.
///
/// The profile's settings apply at once, with no « save » but the display name's (« Mon compte »),
/// and live on the server (`PATCH /api/users/me/preferences`) so that another device finds them: units (the example
/// figures follow), theme (the app redraws), language (the app speaks it), and « Être contacté par
/// les membres », which the ad relay obeys — off, a buyer's message is refused
/// `AD_CONTACT_OPTED_OUT`.
void main() {
  testApp(
    'Display name, units, theme, language and the contactable switch apply at once and reach the '
    'server; switched off, the relay refuses a buyer',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final seller = await backend.newUser('Settings seller');
      final buyer = await backend.newUser('Settings buyer');
      final team = await backend.newTeam(seller, 'Equipe reglages');
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, buyer);
      final ad = await backend.newAd(seller, teamSlug, 'Velo reglages');
      final newName = unique('Nom change');

      await openAppSignedIn($, seller);
      await modules.navigation.goToProfile();
      await modules.profile.waitUntilShown();

      await modules.profile.openAccount();
      await modules.profileSettings.renameTo(newName);
      await modules.profile.backToOverview();

      await modules.profile.openPrivacy();
      final contactableAtFirst = modules.profileSettings.contactableIsOn;
      await modules.profileSettings.toggleContactable();
      await modules.profile.backToOverview();

      await modules.profile.openPreferences();
      await modules.profileSettings.chooseUnits(UnitSystem.imperial);
      await modules.profileSettings.waitUntilUnitsExampleSays(
        AppFormatters.withUnit('', UnitSymbols.mile),
      );
      await modules.profileSettings.chooseTheme(ThemePreference.dark);
      await modules.profileSettings.waitUntilAppIs(Brightness.dark);
      await modules.profileSettings.chooseLanguage('en');
      await modules.profileSettings.waitUntilLanguageRowSays('English');

      final saved = await eventually(
        () => backend.profile(seller),
        until: (me) =>
            me['displayName'] == newName &&
            me['unitSystem'] == 'IMPERIAL' &&
            me['theme'] == 'DARK' &&
            me['language'] == 'en' &&
            me['contactableByMembers'] == false,
        description: 'the settings on the server',
        timeout: const Duration(seconds: 15),
      );
      expect(saved['displayName'], newName);
      expect(contactableAtFirst, isTrue);
      await modules.profile.backToOverview();
      await modules.profile.openPrivacy();
      expect(modules.profileSettings.contactableIsOn, isFalse);
      expect(
        await backend.contactSellerError(buyer, teamSlug, ad['slug'] as String),
        'AD_CONTACT_OPTED_OUT',
      );

      // Back to French: the language is a choice both ways.
      await modules.profile.backToOverview();
      await modules.profile.openPreferences();
      await modules.profileSettings.chooseLanguage('fr');
      await modules.profileSettings.waitUntilLanguageRowSays('Français');
      await eventually(
        () => backend.profile(seller),
        until: (me) => me['language'] == 'fr',
        description: 'French on the server',
        timeout: const Duration(seconds: 15),
      );
    },
  );
}
