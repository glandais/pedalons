import 'package:flutter/widgets.dart';

import '../../../api/generated/export.dart';
import '../../../core/theme/pdl_icons.dart';

/// Le type d'un point de parcours. Une valeur que cette app ne connaît pas (un
/// contrat plus récent que l'app) se rend comme une information — la règle du
/// site (`waypointTypeOf`).
WaypointType waypointTypeOf(String raw) {
  final WaypointType type = WaypointType.fromJson(raw);
  return type == WaypointType.$unknown ? WaypointType.info : type;
}

/// L'ordre d'empilement des pictogrammes, du bas vers le haut : un danger
/// passe par-dessus tout, une information par-dessus rien. C'est aussi la clé
/// de la passe de collision des étiquettes. Table du site (`WAYPOINT_PRIORITY`).
const Map<WaypointType, int> kWaypointPriority = <WaypointType, int>{
  WaypointType.info: 0,
  WaypointType.toilets: 1,
  WaypointType.bikeShop: 2,
  WaypointType.viewpoint: 3,
  WaypointType.cafe: 4,
  WaypointType.water: 5,
  WaypointType.supply: 6,
  WaypointType.summit: 7,
  WaypointType.split: 8,
  WaypointType.realStart: 9,
  WaypointType.regroup: 10,
  WaypointType.danger: 11,
};

/// Les rangs des points le long du parcours, les points hors tracé (sans
/// distance) à la fin ; stable.
List<int> sortedWaypointIndices(List<WaypointDto> list) =>
    List<int>.generate(list.length, (int i) => i)..sort((int a, int b) {
      final double da = list[a].distance ?? double.infinity;
      final double db = list[b].distance ?? double.infinity;
      if (da != db) return da < db ? -1 : 1;
      return a.compareTo(b);
    });

/// Les points triés le long du parcours (le client retrie : l'ordre du serveur
/// n'est pas un contrat).
List<WaypointDto> sortWaypoints(Iterable<WaypointDto> waypoints) {
  final List<WaypointDto> list = waypoints.toList();
  return <WaypointDto>[
    for (final int i in sortedWaypointIndices(list)) list[i],
  ];
}

/// La clé d'un point : son identifiant, ou son rang dans la liste d'origine.
/// Calculée **avant tout tri**, pour que la carte, le profil et la liste
/// partagent la même.
String waypointKey(WaypointDto w, int index) => w.id ?? 'i$index';

/// Vrai si le point a une position. **Jamais de filtre sur la valeur** : un
/// point sur l'équateur ou sur le méridien de Greenwich est un point (ledger
/// `WEB-108`).
bool waypointHasPosition(WaypointDto w) => w.geometry.coordinates.length >= 2;

extension WaypointTypeDisplay on WaypointType {
  /// L'équivalent Material du pictogramme du site (`PdlIcons.waypoint*`).
  IconData get glyph => switch (this) {
    WaypointType.regroup => PdlIcons.waypointRegroup,
    WaypointType.supply => PdlIcons.waypointSupply,
    WaypointType.water => PdlIcons.waypointWater,
    WaypointType.cafe => PdlIcons.waypointCafe,
    WaypointType.toilets => PdlIcons.waypointToilets,
    WaypointType.danger => PdlIcons.waypointDanger,
    WaypointType.summit => PdlIcons.waypointSummit,
    WaypointType.viewpoint => PdlIcons.waypointViewpoint,
    WaypointType.bikeShop => PdlIcons.waypointBikeShop,
    WaypointType.realStart => PdlIcons.waypointRealStart,
    WaypointType.split => PdlIcons.waypointSplit,
    WaypointType.info || WaypointType.$unknown => PdlIcons.waypointInfo,
  };

  /// La clé de traduction du libellé du type.
  String get labelKey =>
      'routes.waypoints.type.${waypointTypeOf(json ?? '').json}';

  int get priority => kWaypointPriority[waypointTypeOf(json ?? '')]!;
}
