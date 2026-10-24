import 'package:flutter/widgets.dart';

class _RideDetailKey extends ValueKey<String> {
  const _RideDetailKey(String value) : super('rideDetail_$value');
}

class RideDetailKeys {
  /// Le bandeau « Sortie annulée » sous l'identité.
  final cancelledBanner = const _RideDetailKey('cancelledBanner');

  /// Le badge « Terminée » d'une sortie passée.
  final finishedBadge = const _RideDetailKey('finishedBadge');

  /// La pastille de la carte des groupes, qui nomme le groupe sélectionné.
  final groupsMapPill = const _RideDetailKey('groupsMapPill');

  final loadError = const _RideDetailKey('loadError');

  /// « Réessayer » de l'état d'erreur.
  final loadErrorRetryButton = const _RideDetailKey('loadErrorRetryButton');

  /// Le `⋯` de l'app bar : signaler la sortie.
  final moreButton = const _RideDetailKey('moreButton');

  /// « Voir la liste » du bloc méta : les participants de toute la sortie.
  final participantsButton = const _RideDetailKey('participantsButton');

  final title = const _RideDetailKey('title');

  /// Le bandeau d'échec d'inscription de la section Groupes, quel qu'en soit
  /// le motif.
  final registrationFailure = const _RideDetailKey('registrationFailure');

  /// Le bouton du bandeau d'exclusivité : quitter l'autre groupe, puis entrer.
  final switchGroupButton = const _RideDetailKey('switchGroupButton');

  /// La carte météo compacte du détail — et la cible du défilement « météo »
  /// (lien `#meteo`, ou `?tab=weather` d'une page de groupe quittée pour le
  /// détail, ledger `MOB-69`).
  final weatherCard = const _RideDetailKey('weatherCard');

  /// La section du groupe d'une sortie solo, à la place des cartes de groupe
  /// (ledger `MOB-69`). Sa présence dit que le détail **est** la page du
  /// groupe : l'inscription passe par la barre d'action (`keys.rideGroup.*`).
  final soloGroupSection = const _RideDetailKey('soloGroupSection');

  /// L'en-tête « Groupe X » de cette section, avec la couleur du tracé.
  final soloGroupHeader = const _RideDetailKey('soloGroupHeader');

  /// Les visages inscrits de cette section, qui ouvrent la feuille des
  /// participants du groupe.
  final soloGroupParticipants = const _RideDetailKey('soloGroupParticipants');

  /// « Voir la météo du parcours » de la carte météo d'une étape de voyage
  /// (`WeatherForecastCard`) — la carte d'une sortie n'en a plus (ledger
  /// `MOB-67`).
  final weatherOpenButton = const _RideDetailKey('weatherOpenButton');

  /// « Météo indisponible » (statut `UNAVAILABLE`, ou échec de l'appel).
  final weatherUnavailable = const _RideDetailKey('weatherUnavailable');

  /// « Réessayer » de la météo indisponible.
  final weatherRetryButton = const _RideDetailKey('weatherRetryButton');

  /// « Prévision disponible à partir du… ».
  final weatherNotYetAvailable = const _RideDetailKey('weatherNotYetAvailable');

  /// Le mot aux organisateurs : il manque un lieu ou un parcours.
  final weatherNoLocation = const _RideDetailKey('weatherNoLocation');

  /// L'état neutre de l'écran météo d'une étape quand il n'y a rien à montrer
  /// (`OUT_OF_RANGE`, `NO_LOCATION` pour un membre, statut inconnu).
  final weatherEmpty = const _RideDetailKey('weatherEmpty');

  /// Le crédit des prévisions (CC BY 4.0) de la carte météo compacte.
  final weatherAttribution = const _RideDetailKey('weatherAttribution');

  /// « Prévisions pas encore disponibles le long du parcours » : étape sans
  /// prévision (`UNAVAILABLE`, `NOT_YET_AVAILABLE`, statut inconnu) ou sans point.
  final weatherLegUnavailable = const _RideDetailKey('weatherLegUnavailable');

  /// La ligne de résumé météo d'une carte de sortie.
  final weatherSummary = const _RideDetailKey('weatherSummary');

  /// La marque « Prévision ancienne » (`STALE`) de la ligne de résumé météo.
  final weatherSummaryStale = const _RideDetailKey('weatherSummaryStale');

  /// Un point de passage de la frise de l'écran « Météo du parcours ».
  ValueKey<String> weatherCheckpoint(int index) =>
      _RideDetailKey('weatherCheckpoint_$index');

  /// La ligne météo, non cliquable, de la carte d'un groupe.
  ValueKey<String> groupWeatherLine(String groupId) =>
      _RideDetailKey('groupWeatherLine_$groupId');

  ValueKey<String> group(String groupId) => _RideDetailKey('group_$groupId');

  ValueKey<String> groupLeader(String groupId) =>
      _RideDetailKey('groupLeader_$groupId');

  ValueKey<String> groupJoinButton(String groupId) =>
      _RideDetailKey('groupJoin_$groupId');

  ValueKey<String> groupLeaveButton(String groupId) =>
      _RideDetailKey('groupLeave_$groupId');

  /// « Télécharger le GPX » de la carte d'un groupe.
  ValueKey<String> groupExportGpx(String groupId) =>
      _RideDetailKey('groupExportGpx_$groupId');

  /// « Télécharger le FIT » de la carte d'un groupe.
  ValueKey<String> groupExportFit(String groupId) =>
      _RideDetailKey('groupExportFit_$groupId');

  /// « Envoyer vers un appareil » de la carte d'un groupe.
  ValueKey<String> groupSendToDevice(String groupId) =>
      _RideDetailKey('groupSendToDevice_$groupId');

  /// Le « Complet » désactivé d'un groupe plein.
  ValueKey<String> groupFullButton(String groupId) =>
      _RideDetailKey('groupFull_$groupId');
}

class _RideGroupKey extends ValueKey<String> {
  const _RideGroupKey(String value) : super('rideGroup_$value');
}

/// La page d'un groupe de sortie (ledger `MOB-67`).
class RideGroupPageKeys {
  final page = const _RideGroupKey('page');

  /// Le retour de l'app bar, vers la sortie.
  final backButton = const _RideGroupKey('backButton');

  /// Les trois onglets : Aperçu · Météo · Participants.
  final tabOverview = const _RideGroupKey('tabOverview');
  final tabWeather = const _RideGroupKey('tabWeather');
  final tabParticipants = const _RideGroupKey('tabParticipants');

  /// « Rejoindre » et « Quitter » de la barre d'action.
  final joinButton = const _RideGroupKey('joinButton');
  final leaveButton = const _RideGroupKey('leaveButton');

  /// Le badge « Complet » qui remplace le bouton d'un groupe plein.
  final fullBadge = const _RideGroupKey('fullBadge');

  /// « Vous êtes inscrit dans le groupe X. »
  final registeredElsewhere = const _RideGroupKey('registeredElsewhere');

  /// Le lien vers le groupe où l'on est inscrit.
  final viewMyGroup = const _RideGroupKey('viewMyGroup');

  /// Le compteur de places de la barre d'action.
  final participantsCount = const _RideGroupKey('participantsCount');

  /// Le meneur désigné — absent quand `leader` est nul.
  final leader = const _RideGroupKey('leader');

  /// La carte résumé « Météo au départ du groupe » de l'aperçu.
  final weatherSummaryCard = const _RideGroupKey('weatherSummaryCard');

  /// La puce « Météo » sous la carte de l'aperçu : le vent sur le tracé
  /// (ledger `MOB-91`).
  final windMapChip = const _RideGroupKey('windMapChip');

  /// La légende du vent posée sur la carte du groupe en mode « Météo ».
  final windMapLegend = const _RideGroupKey('windMapLegend');

  /// Le crédit des prévisions dans cette légende.
  final windMapCredit = const _RideGroupKey('windMapCredit');

  /// La carte encastrée en tête de l'onglet Météo, toujours en mode
  /// « Météo » (ledger `MOB-93`).
  final weatherTabMap = const _RideGroupKey('weatherTabMap');

  /// La goutte de l'alerte pluie sur la carte plein écran (ledger `MOB-92`).
  final weatherMapRainDrop = const _RideGroupKey('weatherMapRainDrop');

  /// La feuille du détail d'une pastille ou de la goutte.
  final weatherMapSheet = const _RideGroupKey('weatherMapSheet');

  /// La pastille météo d'un point de passage, par son `index`.
  ValueKey<String> weatherMapPastille(int index) =>
      _RideGroupKey('weatherMapPastille_$index');

  /// « Voir toutes les personnes inscrites » de l'aperçu.
  final viewAllParticipants = const _RideGroupKey('viewAllParticipants');

  final exportGpx = const _RideGroupKey('exportGpx');
  final exportFit = const _RideGroupKey('exportFit');
  final sendToDevice = const _RideGroupKey('sendToDevice');

  /// L'état neutre de l'onglet Météo quand il n'y a rien à montrer
  /// (`OUT_OF_RANGE`, `NO_LOCATION` pour un membre, statut inconnu).
  final weatherEmpty = const _RideGroupKey('weatherEmpty');

  /// Le groupe supprimé ou inconnu : un état vide et le retour à la sortie.
  final notFound = const _RideGroupKey('notFound');
  final backToRide = const _RideGroupKey('backToRide');

  /// La pastille d'un groupe dans le sélecteur de la page.
  ValueKey<String> groupChip(String groupId) =>
      _RideGroupKey('groupChip_$groupId');
}

class _RideEditorKey extends ValueKey<String> {
  const _RideEditorKey(String value) : super('rideEditor_$value');
}

/// Les six clés d'une carte de groupe, que l'éditeur de sortie et celui de
/// modèle (ledger `MOB-78`) fournissent chacun avec leur préfixe : les deux
/// peuvent coexister dans la pile (éditeur de sortie, feuille, liste, modèle).
abstract interface class GroupEditorKeys {
  ValueKey<String> group(int index);
  ValueKey<String> groupName(int index);
  ValueKey<String> groupSpeed(int index);
  ValueKey<String> groupMax(int index);
  ValueKey<String> groupTime(int index);
  ValueKey<String> groupRemove(int index);
}

/// L'éditeur de sortie, création et modification (ledger `MOB-80`).
class RideEditorKeys implements GroupEditorKeys {
  final forbidden = const _RideEditorKey('forbidden');
  final loadError = const _RideEditorKey('loadError');
  final saveButton = const _RideEditorKey('saveButton');
  final errorBanner = const _RideEditorKey('errorBanner');
  final templateButton = const _RideEditorKey('templateButton');
  final nameField = const _RideEditorKey('nameField');
  final slugRow = const _RideEditorKey('slugRow');
  final slugField = const _RideEditorKey('slugField');
  final slugSave = const _RideEditorKey('slugSave');
  final markdownField = const _RideEditorKey('markdownField');
  final markdownPreview = const _RideEditorKey('markdownPreview');
  final markdownMode = const _RideEditorKey('markdownMode');
  final logoButton = const _RideEditorKey('logoButton');
  final imageAddButton = const _RideEditorKey('imageAddButton');
  final attachmentAddButton = const _RideEditorKey('attachmentAddButton');
  final dateRow = const _RideEditorKey('dateRow');
  final timeRow = const _RideEditorKey('timeRow');
  final startPlaceRow = const _RideEditorKey('startPlaceRow');
  final endPlaceRow = const _RideEditorKey('endPlaceRow');
  final tagsRow = const _RideEditorKey('tagsRow');
  final visibility = const _RideEditorKey('visibility');
  final status = const _RideEditorKey('status');
  final publishAtRow = const _RideEditorKey('publishAtRow');
  final routeRow = const _RideEditorKey('routeRow');
  final addGroupButton = const _RideEditorKey('addGroupButton');
  final pickerSearch = const _RideEditorKey('pickerSearch');

  /// « Gérer les modèles », en pied de la feuille « Choisir un modèle »
  /// (ledger `MOB-78`).
  final manageTemplatesButton = const _RideEditorKey('manageTemplatesButton');

  @override
  ValueKey<String> group(int index) => _RideEditorKey('group_$index');
  @override
  ValueKey<String> groupName(int index) => _RideEditorKey('groupName_$index');
  @override
  ValueKey<String> groupSpeed(int index) => _RideEditorKey('groupSpeed_$index');
  @override
  ValueKey<String> groupMax(int index) => _RideEditorKey('groupMax_$index');
  @override
  ValueKey<String> groupTime(int index) => _RideEditorKey('groupTime_$index');
  ValueKey<String> groupLeader(int index) =>
      _RideEditorKey('groupLeader_$index');
  ValueKey<String> groupRoute(int index) => _RideEditorKey('groupRoute_$index');
  @override
  ValueKey<String> groupRemove(int index) =>
      _RideEditorKey('groupRemove_$index');
  ValueKey<String> pickerOption(String id) => _RideEditorKey('option_$id');
}

class _RideTemplateKey extends ValueKey<String> {
  const _RideTemplateKey(String value) : super('rideTemplates_$value');
}

/// La liste des modèles de sortie, son menu et ses états (ledger `MOB-78`).
class RideTemplateKeys {
  final forbidden = const _RideTemplateKey('forbidden');
  final loadError = const _RideTemplateKey('loadError');
  final newButton = const _RideTemplateKey('newButton');
  final searchField = const _RideTemplateKey('searchField');
  final count = const _RideTemplateKey('count');
  final empty = const _RideTemplateKey('empty');
  final emptyNewButton = const _RideTemplateKey('emptyNewButton');
  final noResults = const _RideTemplateKey('noResults');
  final menuCreateRide = const _RideTemplateKey('menuCreateRide');
  final menuEdit = const _RideTemplateKey('menuEdit');
  final menuDelete = const _RideTemplateKey('menuDelete');

  /// La carte d'un modèle, par son slug.
  ValueKey<String> card(String slug) => _RideTemplateKey('card_$slug');

  /// Le `⋯` de la carte d'un modèle, par son slug.
  ValueKey<String> moreButton(String slug) => _RideTemplateKey('more_$slug');
}

class _RideTemplateEditorKey extends ValueKey<String> {
  const _RideTemplateEditorKey(String value)
    : super('rideTemplateEditor_$value');
}

/// L'éditeur de modèle de sortie, création et modification (ledger `MOB-78`).
class RideTemplateEditorKeys implements GroupEditorKeys {
  final saveButton = const _RideTemplateEditorKey('saveButton');
  final errorBanner = const _RideTemplateEditorKey('errorBanner');
  final nameField = const _RideTemplateEditorKey('nameField');
  final nextNumberField = const _RideTemplateEditorKey('nextNumberField');
  final markdownField = const _RideTemplateEditorKey('markdownField');
  final tagsRow = const _RideTemplateEditorKey('tagsRow');
  final visibility = const _RideTemplateEditorKey('visibility');
  final status = const _RideTemplateEditorKey('status');
  final addGroupButton = const _RideTemplateEditorKey('addGroupButton');

  @override
  ValueKey<String> group(int index) => _RideTemplateEditorKey('group_$index');
  @override
  ValueKey<String> groupName(int index) =>
      _RideTemplateEditorKey('groupName_$index');
  @override
  ValueKey<String> groupSpeed(int index) =>
      _RideTemplateEditorKey('groupSpeed_$index');
  @override
  ValueKey<String> groupMax(int index) =>
      _RideTemplateEditorKey('groupMax_$index');
  @override
  ValueKey<String> groupTime(int index) =>
      _RideTemplateEditorKey('groupTime_$index');
  @override
  ValueKey<String> groupRemove(int index) =>
      _RideTemplateEditorKey('groupRemove_$index');
}

class _RideManageKey extends ValueKey<String> {
  const _RideManageKey(String value) : super('rideManage_$value');
}

/// Les gestes d'organisateur du détail d'une sortie (ledger `MOB-80`).
class RideManageKeys {
  final editButton = const _RideManageKey('editButton');
  final publish = const _RideManageKey('publish');
  final unpublish = const _RideManageKey('unpublish');
  final cancel = const _RideManageKey('cancel');
  final reinstate = const _RideManageKey('reinstate');
  final delete = const _RideManageKey('delete');
  final restore = const _RideManageKey('restore');
  final report = const _RideManageKey('report');
  final deletedBanner = const _RideManageKey('deletedBanner');
}
