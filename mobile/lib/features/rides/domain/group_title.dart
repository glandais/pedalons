import 'package:easy_localization/easy_localization.dart';

/// Le nom d'un groupe de sortie tel qu'il s'affiche, à partir du gabarit
/// traduit [template] (« Groupe {name} »).
///
/// Le gabarit ne s'applique qu'à un nom de **1 ou 2 caractères** — « B » →
/// « Groupe B », « A1 » → « Groupe A1 » — qui seul ne se lirait pas comme un
/// groupe. Tout autre nom s'affiche tel quel : « Les Rapides », « Groupe 1 »,
/// « Gr. A » (décision du 2026-11-12, KIT §9). La même règle vaut partout où
/// l'app nomme un groupe, lignes compactes comprises.
String groupTitle(String name, String template) {
  final String trimmed = name.trim();
  if (trimmed.isEmpty || trimmed.runes.length > 2) return trimmed;
  return template.replaceAll('{name}', trimmed);
}

/// [groupTitle] avec le gabarit de la langue de l'interface
/// (`rides.groupPage.title`) : ce que les cartes et les lignes appellent.
String groupLabel(String name) =>
    groupTitle(name, 'rides.groupPage.title'.tr());
