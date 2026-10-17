import 'package:easy_localization/easy_localization.dart';

import '../../../../../api/generated/export.dart';

/// Le résumé d'un modèle : « 3 groupes · prochaine #42 » (ledger `MOB-78`).
///
/// [long] écrit « prochaine sortie #42 » et, pour un modèle qui ne numérote
/// pas, « sans numéro » — la carte de la liste ; la forme courte, celle des
/// lignes du tableau de bord et de la feuille de l'éditeur de sortie, n'ajoute
/// rien à un modèle sans numéro.
String rideTemplateSummary(RideTemplateDto template, {bool long = false}) {
  final String groups = 'rides.groupCount'.plural(template.groupCount);
  final int? next = template.nextNumber;
  if (next == null) {
    return long ? '$groups · ${'rides.templates.unnumbered'.tr()}' : groups;
  }
  final String key = long
      ? 'rides.templates.nextLong'
      : 'rides.templates.nextShort';
  return '$groups · ${key.tr(namedArgs: <String, String>{'number': '$next'})}';
}
