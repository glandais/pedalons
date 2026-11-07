import 'package:flutter/widgets.dart';

class _HomeKey extends ValueKey<String> {
  const _HomeKey(String value) : super('home_$value');
}

class HomeKeys {
  /// La carte « Ma prochaine sortie », portant le slug de la sortie qu'elle
  /// nomme.
  ValueKey<String> nextRideCard(String rideSlug) =>
      _HomeKey('nextRide_$rideSlug');

  /// « Se désinscrire » sur la carte « Ma prochaine sortie ».
  final nextRideLeaveButton = const _HomeKey('nextRideLeave');

  /// « Ma prochaine sortie » : la pastille « Aujourd'hui » / « Demain » posée
  /// sur l'image, la ligne de départ et le fait « groupe » de la carte.
  final nextRideDayPill = const _HomeKey('nextRideDayPill');
  final nextRideStart = const _HomeKey('nextRideStart');
  final nextRideGroup = const _HomeKey('nextRideGroup');

  /// La carte compacte qui remplace le bloc quand rien n'est à venir.
  final noNextRideCard = const _HomeKey('noNextRide');

  /// « Envoyer vers le compteur » sur la carte « Ma prochaine sortie ».
  final nextRideSendToDevice = const _HomeKey('nextRideSendToDevice');

  /// Le bloc « Cette semaine ».
  final weekSection = const _HomeKey('weekSection');

  /// Une ligne de « Cette semaine », par le slug de la sortie ou de l'étape.
  ValueKey<String> weekEvent(String entitySlug) =>
      _HomeKey('weekEvent_$entitySlug');

  /// La carte qui remplace l'agenda quand la semaine est vide.
  final weekEmpty = const _HomeKey('weekEmpty');

  /// Le bloc « Mes équipes ».
  final teamsSection = const _HomeKey('teamsSection');

  /// Une équipe de « Mes équipes », par son slug.
  ValueKey<String> teamRow(String teamSlug) => _HomeKey('teamRow_$teamSlug');

  /// « Trouver une équipe », quand l'utilisateur n'est membre d'aucune.
  final findTeamButton = const _HomeKey('findTeam');
}
