import 'package:flutter/widgets.dart';

class _RideDetailKey extends ValueKey<String> {
  const _RideDetailKey(String value) : super('rideDetail_$value');
}

class RideDetailKeys {
  /// Le bandeau « Sortie annulée » sous l'identité.
  final cancelledBanner = const _RideDetailKey('cancelledBanner');

  /// Le badge « Terminée » d'une sortie passée.
  final finishedBadge = const _RideDetailKey('finishedBadge');

  /// Le bloc de départ sous l'identité (ledger `MOB-113`).
  final departureBlock = const _RideDetailKey('departureBlock');

  /// La pastille de la carte des groupes, qui nomme le groupe sélectionné.
  final groupsMapPill = const _RideDetailKey('groupsMapPill');

  /// L'interrupteur Pente | Revêtement | Météo sous la carte d'une sortie
  /// solo à un seul parcours (ledger `MOB-105`) : il colore son tracé, son
  /// plein écran et son profil.
  final mapColorBy = const _RideDetailKey('mapColorBy');

  /// La puce « Météo » sous la carte d'une sortie solo dont le groupe roule
  /// un autre parcours que la sortie (ledger `MOB-94`) : deux couches, aux
  /// couleurs de leur couche, et le vent sur celle du groupe seulement.
  final windMapChip = const _RideDetailKey('windMapChip');

  /// Pente | Revêtement **au-dessus du profil** quand la carte garde une
  /// couleur par couche — plusieurs groupes, ou une sortie solo à deux
  /// parcours (ledger `MOB-105`) : il ne colore que le profil.
  final profileColorBy = const _RideDetailKey('profileColorBy');

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

  /// Les lieux de départ et d'arrivée du bloc de départ, en liens
  /// d'itinéraire (`ridePlaceLinks`, ledger `MOB-132`).
  final startPlaceLink = const _RideDetailKey('startPlaceLink');
  final endPlaceLink = const _RideDetailKey('endPlaceLink');

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

  /// Le crédit des prévisions (CC BY 4.0) : celui de la carte météo compacte,
  /// et le lien de la feuille « Source des prévisions météo ».
  final weatherAttribution = const _RideDetailKey('weatherAttribution');

  /// La section Météo d'un écran de détail (`WeatherSection`, ledger
  /// `MOB-132`) — son titre « Météo ».
  final weatherSection = const _RideDetailKey('weatherSection');

  /// La carte « Exposition au vent » de la section Météo.
  final weatherExposure = const _RideDetailKey('weatherExposure');

  /// « Météo le long du parcours » : le bloc replié (`PdlDisclosure`, à
  /// toucher pour déplier) ou, déplié d'office, son sous-titre.
  final weatherAlongRoute = const _RideDetailKey('weatherAlongRoute');

  /// « Prévision du mar. 10 nov. · 08:30 », au bas de la section Météo.
  final weatherForecastOf = const _RideDetailKey('weatherForecastOf');

  /// Le bouton ⓘ du bas de la section Météo : la source des prévisions.
  final weatherSourceButton = const _RideDetailKey('weatherSourceButton');

  /// La feuille qu'il ouvre.
  final weatherSourceSheet = const _RideDetailKey('weatherSourceSheet');

  /// « Prévisions pas encore disponibles le long du parcours » : étape sans
  /// prévision (`UNAVAILABLE`, `NOT_YET_AVAILABLE`, statut inconnu) ou sans point.
  final weatherLegUnavailable = const _RideDetailKey('weatherLegUnavailable');

  /// La ligne de résumé météo d'une carte (sortie, voyage, étape, groupe).
  final weatherSummary = const _RideDetailKey('weatherSummary');

  /// L'alerte « Pluie 60 % vers 11:00 » de la ligne de résumé météo.
  final weatherSummaryRainAlert = const _RideDetailKey(
    'weatherSummaryRainAlert',
  );

  /// La marque « Prévision ancienne » (`STALE`) de la ligne de résumé météo.
  final weatherSummaryStale = const _RideDetailKey('weatherSummaryStale');

  /// Un point de passage de la frise de l'écran « Météo du parcours ».
  ValueKey<String> weatherCheckpoint(int index) =>
      _RideDetailKey('weatherCheckpoint_$index');

  /// La ligne météo, non cliquable, de la carte d'un groupe.
  ValueKey<String> groupWeatherLine(String groupId) =>
      _RideDetailKey('groupWeatherLine_$groupId');

  /// La ligne de départ d'un groupe à heure propre, sous son nom (ledger
  /// `BRAND-8`).
  ValueKey<String> groupDeparture(String groupId) =>
      _RideDetailKey('groupDeparture_$groupId');

  ValueKey<String> group(String groupId) => _RideDetailKey('group_$groupId');

  ValueKey<String> groupLeader(String groupId) =>
      _RideDetailKey('groupLeader_$groupId');

  ValueKey<String> groupJoinButton(String groupId) =>
      _RideDetailKey('groupJoin_$groupId');

  ValueKey<String> groupLeaveButton(String groupId) =>
      _RideDetailKey('groupLeave_$groupId');

  /// Le bouton « GPS » de la carte d'un groupe, qui ouvre la feuille GPS.
  ValueKey<String> groupGps(String groupId) =>
      _RideDetailKey('groupGps_$groupId');

  /// Le « Complet » désactivé d'un groupe plein.
  ValueKey<String> groupFullButton(String groupId) =>
      _RideDetailKey('groupFull_$groupId');
}

class _RideGroupKey extends ValueKey<String> {
  const _RideGroupKey(String value) : super('rideGroup_$value');
}

/// La page d'un groupe de sortie (ledgers `MOB-67`, `MOB-132`) : une page qui
/// défile, sans onglets ni barre d'action.
class RideGroupPageKeys {
  final page = const _RideGroupKey('page');

  /// Le retour de l'app bar, vers la sortie.
  final backButton = const _RideGroupKey('backButton');

  /// Les sections de la page, dans leur ordre (maquettes
  /// `groupe-mobile-cible`, `groupe-inscrit-mobile-cible`) : bloc de départ,
  /// tuiles de chiffres, « Parcours », « Personnes inscrites », « Météo ».
  final departureBlock = const _RideGroupKey('departureBlock');
  final statTiles = const _RideGroupKey('statTiles');
  final routeSection = const _RideGroupKey('routeSection');
  final participantsSection = const _RideGroupKey('participantsSection');
  final weatherSection = const _RideGroupKey('weatherSection');

  /// L'attente de la section Météo, tant que la prévision se charge.
  final weatherLoading = const _RideGroupKey('weatherLoading');

  /// Le contrôle d'inscription du bloc de départ (`RideRegistrationControl`) :
  /// « Rejoindre », le badge « J'y vais », « Complet » désactivé, « Changer
  /// pour A ». Partagé avec la barre d'action d'une sortie solo
  /// (`RideGroupActionBar`) pour « Rejoindre », « Quitter » et « Complet ».
  final joinButton = const _RideGroupKey('joinButton');
  final goingBadge = const _RideGroupKey('goingBadge');
  final switchButton = const _RideGroupKey('switchButton');

  /// « Quitter le groupe », au pied de « Personnes inscrites » sur la page
  /// d'un groupe ; « Quitter » de la barre d'action d'une sortie solo.
  final leaveButton = const _RideGroupKey('leaveButton');

  /// « Complet » : bouton désactivé sur la page d'un groupe, badge dans la
  /// barre d'action d'une sortie solo.
  final fullBadge = const _RideGroupKey('fullBadge');

  /// « Votre inscription est dans le groupe X. » — barre d'action d'une
  /// sortie solo seulement (retirée au lot 7 du ledger `MOB-132`).
  final registeredElsewhere = const _RideGroupKey('registeredElsewhere');

  /// Le lien vers le groupe où l'on est inscrit, même barre.
  final viewMyGroup = const _RideGroupKey('viewMyGroup');

  /// Les places : « 3/16 personnes » de la barre d'action d'une sortie
  /// solo ; la barre de places et « 13 places restantes » de la page d'un
  /// groupe.
  final participantsCount = const _RideGroupKey('participantsCount');

  /// Le capitaine désigné — absent quand `leader` est nul.
  final leader = const _RideGroupKey('leader');

  /// La grappe d'avatars de « Personnes inscrites », sans le capitaine.
  final participantsAvatars = const _RideGroupKey('participantsAvatars');

  /// L'interrupteur Pente | Revêtement | Météo sous la carte du groupe
  /// (ledger `MOB-105`), partagé par la carte, son plein écran et le profil.
  final mapColorBy = const _RideGroupKey('mapColorBy');

  /// La légende du vent posée sur la carte du groupe en mode « Météo ».
  final windMapLegend = const _RideGroupKey('windMapLegend');

  /// Le crédit des prévisions dans cette légende.
  final windMapCredit = const _RideGroupKey('windMapCredit');

  /// Le titre « Météo au départ de … » de la section Météo (ledger `BRAND-8`).
  final departureWeatherTitle = const _RideGroupKey('departureWeatherTitle');

  /// La goutte de l'alerte pluie sur la carte, encastrée ou plein écran
  /// (ledgers `MOB-92`, `MOB-107`).
  final weatherMapRainDrop = const _RideGroupKey('weatherMapRainDrop');

  /// La feuille du détail d'une pastille ou de la goutte.
  final weatherMapSheet = const _RideGroupKey('weatherMapSheet');

  /// La pastille météo d'un point de passage, par son `index`.
  ValueKey<String> weatherMapPastille(int index) =>
      _RideGroupKey('weatherMapPastille_$index');

  /// « Voir toutes les personnes inscrites », qui ouvre `ParticipantsSheet`.
  final viewAllParticipants = const _RideGroupKey('viewAllParticipants');

  /// Le bouton « GPS » du parcours du groupe (page d'un groupe, sortie solo).
  final gps = const _RideGroupKey('gps');

  /// Le groupe supprimé ou inconnu : un état vide et le retour à la sortie.
  final notFound = const _RideGroupKey('notFound');
  final backToRide = const _RideGroupKey('backToRide');

  /// La pastille d'un groupe dans le sélecteur de la page.
  ValueKey<String> groupChip(String groupId) =>
      _RideGroupKey('groupChip_$groupId');
}

class _RideRouteKey extends ValueKey<String> {
  const _RideRouteKey(String value) : super('rideRoute_$value');
}

/// La section « Parcours » d'une sortie (`RideRouteSection`, ledger
/// `MOB-132`) : la page d'un groupe aujourd'hui, la sortie solo et sans
/// groupe ensuite.
class RideRouteSectionKeys {
  /// Le bouton ⓘ de « Profil » et sa feuille (la source des altitudes).
  final profileSource = const _RideRouteKey('profileSource');
  final profileSourceSheet = const _RideRouteKey('profileSourceSheet');

  /// Le bouton ⓘ de la légende du revêtement (OpenStreetMap).
  final surfaceSource = const _RideRouteKey('surfaceSource');

  /// « Détails », qui pousse la fiche du parcours.
  final details = const _RideRouteKey('details');

  /// « Points du parcours », replié.
  final waypoints = const _RideRouteKey('waypoints');
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
