import '../../../api/generated/export.dart';
import 'ride_weather_display.dart';

/// Une sortie « solo » — exactement un groupe — n'a qu'une page : la sienne
/// est aussi celle de son groupe (ledger `MOB-69`). Ces trois prédicats sont
/// la seule écriture de la règle côté mobile ; le web a les siens (`WEB-79`).

/// Le groupe unique d'une sortie solo, `null` à zéro ou plusieurs groupes.
RideGroupDto? soloGroupOf(RideDto ride) =>
    ride.groups.length == 1 ? ride.groups.single : null;

/// Vrai quand la page d'un groupe de [ride] cède la place au détail de la
/// sortie : sortie solo (la page du groupe **est** le détail) ou sans groupe
/// (un groupe disparu y mène mieux qu'un « Ce groupe n'existe plus »).
bool leavesGroupPage(RideDto ride) => ride.groups.length <= 1;

/// Le leg météo que le détail de [ride] déroule en entier : le leg unique
/// sans `groupId` d'une sortie sans groupe, ou celui du groupe d'une sortie
/// solo — correspondance stricte, jamais le leg d'un autre groupe. `null` à
/// plusieurs groupes : chacun a sa page et sa ligne sur sa carte.
WeatherLegDto? rideOwnLeg(RideWeatherDto dto, RideDto ride) {
  final RideGroupDto? solo = soloGroupOf(ride);
  if (solo != null) return weatherLegOfGroup(dto.legs, solo.id);
  if (ride.groups.isEmpty &&
      dto.legs.length == 1 &&
      dto.legs.single.groupId == null) {
    return dto.legs.single;
  }
  return null;
}
