import 'package:flutter/widgets.dart';

import '../../api/generated/export.dart';

class _ProfilePageKey extends ValueKey<String> {
  const _ProfilePageKey(String value) : super('profilePage_$value');
}

class ProfilePageKeys {
  final logoutButton = const _ProfilePageKey('logoutButton');

  /// Le bouton qui confirme une action destructive (`confirmDestructive`).
  final confirmDestructiveButton = const _ProfilePageKey(
    'confirmDestructiveButton',
  );

  /// Le texte de la feuille de confirmation destructive — la conséquence,
  /// équipes supprimées avec le compte comprises.
  final confirmDestructiveMessage = const _ProfilePageKey(
    'confirmDestructiveMessage',
  );

  /// « Supprimer mon compte », dans la zone de danger.
  final deleteAccountButton = const _ProfilePageKey('deleteAccountButton');

  /// Le bandeau qui refuse la suppression en nommant les équipes qui la
  /// bloquent (seul administrateur d'une équipe qui a d'autres membres).
  final deletionBlockedBanner = const _ProfilePageKey('deletionBlockedBanner');

  /// Vue d'ensemble : la ligne « Mes sorties » et son compteur de sorties à
  /// venir.
  final participationsUpcomingRow = const _ProfilePageKey(
    'participationsUpcomingRow',
  );
  final participationsUpcomingCount = const _ProfilePageKey(
    'participationsUpcomingCount',
  );

  /// Vue d'ensemble : la carte d'identité (vers « Mon compte ») et un
  /// raccourci par sous-page.
  final identityCard = const _ProfilePageKey('identityCard');
  final teamsRow = const _ProfilePageKey('teamsRow');
  final preferencesRow = const _ProfilePageKey('preferencesRow');
  final notificationsRow = const _ProfilePageKey('notificationsRow');
  final devicesRow = const _ProfilePageKey('devicesRow');
  final securityRow = const _ProfilePageKey('securityRow');
  final privacyRow = const _ProfilePageKey('privacyRow');
  final accountRow = const _ProfilePageKey('accountRow');
  final helpRow = const _ProfilePageKey('helpRow');

  /// La flèche de retour d'une sous-page du profil, vers la vue d'ensemble
  /// (ou « Confidentialité », sous « Utilisateurs bloqués »).
  final backButton = const _ProfilePageKey('backButton');

  /// « Mes sorties » : les segments « À venir » et « Historique ».
  final participationsUpcomingTab = const _ProfilePageKey(
    'participationsUpcomingTab',
  );
  final participationsHistoryTab = const _ProfilePageKey(
    'participationsHistoryTab',
  );

  /// Une publication de la liste « Mes participations », par son slug.
  Key participationCard(String slug) =>
      _ProfilePageKey('participationCard_$slug');

  /// Confidentialité : l'interrupteur « Être contacté par les membres ».
  final contactableSwitch = const _ProfilePageKey('contactableSwitch');

  /// « Mes données » : le bouton de demande et la ligne d'état de l'export.
  final dataExportButton = const _ProfilePageKey('dataExportButton');
  final dataExportStatus = const _ProfilePageKey('dataExportStatus');

  /// Identité : le champ « Nom affiché » et son « Enregistrer ».
  final displayNameField = const _ProfilePageKey('displayNameField');
  final displayNameSave = const _ProfilePageKey('displayNameSave');

  /// La ligne « Fuseau horaire », la recherche de sa feuille, et un fuseau de
  /// la liste, par son nom IANA.
  final timezoneRow = const _ProfilePageKey('timezoneRow');
  final timezoneSearch = const _ProfilePageKey('timezoneSearch');
  Key timezoneOption(String name) => _ProfilePageKey('timezoneOption_$name');

  /// La ligne « Langue », et une langue de sa feuille, par son code.
  final languageRow = const _ProfilePageKey('languageRow');
  Key languageOption(String code) => _ProfilePageKey('languageOption_$code');

  /// Un appareil appairé, par l'id de son appairage, et sa croix « Délier »
  /// (docs/LEDGER_*.md API-64) ; la ligne affichée quand il n'y en a aucun.
  Key pairedDevice(String id) => _ProfilePageKey('pairedDevice_$id');
  Key unpairDevice(String id) => _ProfilePageKey('unpairDevice_$id');
  final noPairedDevice = const _ProfilePageKey('noPairedDevice');

  /// Un service GPS connecté : l'interrupteur « Envoi automatique » et la
  /// ligne qui le porte, dont le sous-titre dit l'état (docs/LEDGER_*.md
  /// MOB-71).
  Key gpsAutoSyncSwitch(GpsServiceType service) =>
      _ProfilePageKey('gpsAutoSyncSwitch_${service.json}');
  Key gpsAutoSyncRow(GpsServiceType service) =>
      _ProfilePageKey('gpsAutoSyncRow_${service.json}');
  Key gpsReconnect(GpsServiceType service) =>
      _ProfilePageKey('gpsReconnect_${service.json}');

  /// « Déconnecter tous les appareils ».
  final logoutAllButton = const _ProfilePageKey('logoutAllButton');

  /// Un segment du sélecteur de thème, par sa valeur.
  Key themeSegment(ThemePreference theme) =>
      _ProfilePageKey('themeSegment_${theme.name}');

  /// Un segment du sélecteur d'unités, par sa valeur, et l'exemple chiffré.
  Key unitSegment(UnitSystem unit) =>
      _ProfilePageKey('unitSegment_${unit.name}');
  final unitsExample = const _ProfilePageKey('unitsExample');

  /// « Aide et à propos » : les lignes « Applications » et « Signaler un
  /// problème ».
  final appsRow = const _ProfilePageKey('appsRow');
  final reportProblemRow = const _ProfilePageKey('reportProblemRow');
}
