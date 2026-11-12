import 'package:easy_localization/easy_localization.dart';

import '../../../../../api/generated/export.dart';

/// Le résumé d'un modèle : « 3 groupes · prochaine #42 » (ledger `MOB-78`).
///
/// [long] écrit « prochaine sortie #42 » et, pour un modèle qui ne numérote
/// pas, « sans numéro » — la carte de la liste ; la forme courte, celle des
/// lignes du tableau de bord et de la feuille de l'éditeur de sortie, n'ajoute
/// rien à un modèle sans numéro.
///
/// Un modèle sans groupe ne dit pas « Aucun groupe » : un compteur à zéro ne
/// s'affiche pas (règle R4, KIT §9). Le résumé peut alors être vide.
String rideTemplateSummary(RideTemplateDto template, {bool long = false}) {
  final int? next = template.nextNumber;
  final String key = long
      ? 'rides.templates.nextLong'
      : 'rides.templates.nextShort';
  return <String>[
    if (template.groupCount > 0) 'rides.groupCount'.plural(template.groupCount),
    if (next != null)
      key.tr(namedArgs: <String, String>{'number': '$next'})
    else if (long)
      'rides.templates.unnumbered'.tr(),
  ].join(' · ');
}
