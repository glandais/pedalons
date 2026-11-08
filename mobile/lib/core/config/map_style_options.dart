import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/generated/models/map_style_dto.dart';
import '../../api/generated/models/map_terrain_dto.dart';
import '../pdl/pdl.dart';
import '../theme/pdl_colors.dart';
import 'config_provider.dart';

/// Les fonds servis, prêts pour le sélecteur de `PdlMapHero`.
///
/// Un seul endroit pour les cinq cartes de l'app : la conversion était recopiée
/// à l'identique dans chacune, et l'ajout des sections l'aurait été aussi.
/// `core/pdl` ne traduit rien — l'intitulé de section est localisé ici.
///
/// Un fond qui a une variante sombre gagne une seconde ligne, pour le rendu que
/// le thème ne choisirait pas.
List<PdlMapStyleOption> servedMapStyleOptions(
  WidgetRef ref,
  Brightness brightness,
) => mapStyleOptions(
  ref.watch(appConfigProvider).value?.mapStyles ?? const <MapStyleDto>[],
  brightness,
);

/// Les lignes du sélecteur, pour un thème donné.
List<PdlMapStyleOption> mapStyleOptions(
  List<MapStyleDto> styles,
  Brightness brightness,
) {
  final Brightness opposite = brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  final String oppositeKey = opposite == Brightness.dark
      ? 'map.stylePinned.dark'
      : 'map.stylePinned.light';
  return <PdlMapStyleOption>[
    for (final MapStyleDto style in styles) ...<PdlMapStyleOption>[
      PdlMapStyleOption(
        id: style.id,
        label: style.label,
        groupLabel: mapStyleGroupLabel(style.group),
      ),
      if (style.darkVariant?.isNotEmpty ?? false)
        PdlMapStyleOption(
          id: pinnedMapStyleId(style.id, opposite),
          label: oppositeKey.tr(
            namedArgs: <String, String>{'label': style.label},
          ),
          groupLabel: mapStyleGroupLabel(style.group),
        ),
    ],
  ];
}

/// Le crédit à passer à `PdlMap`, pour le fond résolu.
///
/// L'essentiel vient du document de style et `PdlMapAttribution` le lit tout
/// seul ; ce qui se décide ici, c'est le complément servi
/// (`MapStyleDto.attribution`, non nul pour le seul fond dont le fournisseur ne
/// déclare rien) et l'intitulé localisé, que `core/pdl` ne saurait pas traduire.
PdlMapCredit servedMapCredit(ResolvedMapStyle? style) => PdlMapCredit(
  toggleLabel: 'map.attribution'.tr(),
  extra: style?.style.attribution,
);

/// L'ombrage du relief à passer à `PdlMap`, ou `null` — pas de source servie,
/// ou interrupteur éteint.
///
/// Les deux teintes viennent de `context.pdl`, jamais d'un littéral : `core/pdl`
/// ne peut pas les choisir (il ne connaît pas la source), mais elles restent des
/// couleurs de la charte.
PdlHillshade? servedHillshade(BuildContext context, WidgetRef ref) {
  final MapTerrainDto? terrain = ref.watch(mapTerrainProvider);
  if (terrain == null || !ref.watch(hillshadeEnabledProvider)) return null;
  final PdlColors c = context.pdl;
  return PdlHillshade(
    url: terrain.url,
    shadowColor: c.mapHillshadeShadow,
    highlightColor: c.mapHillshadeHighlight,
  );
}

/// L'état à donner au sélecteur : `null` quand aucune source n'est servie, ce
/// qui **retire** la ligne au lieu d'offrir un interrupteur sans effet.
bool? servedHillshadeEnabled(WidgetRef ref) =>
    ref.watch(mapTerrainProvider) == null
    ? null
    : ref.watch(hillshadeEnabledProvider);

/// L'intitulé d'une section du sélecteur.
///
/// Le contrat laisse `group` libre : un groupe que cette version ne connaît pas
/// est rendu **tel quel**, en section à lui. Le traduire par sa clé afficherait
/// `map.styleGroup.xxx` à l'écran, et l'ignorer rangerait silencieusement le
/// fond sous la section précédente — les deux mentent sur ce que le serveur a
/// classé.
String mapStyleGroupLabel(String group) => switch (group) {
  'vector' => 'map.styleGroup.vector'.tr(),
  'satellite' => 'map.styleGroup.satellite'.tr(),
  'raster' => 'map.styleGroup.raster'.tr(),
  _ => group,
};
