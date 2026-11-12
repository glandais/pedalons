import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/generated/models/map_style_dto.dart';
import '../../api/generated/models/map_terrain_dto.dart';
import '../../api/generated/models/unit_system.dart';
import '../pdl/pdl.dart';
import '../preferences/user_preferences_provider.dart';
import '../theme/pdl_colors.dart';
import '../units/unit_system.dart';
import '../utils/formatters.dart';
import 'config_provider.dart';

/// Les fonds servis, prêts pour le sélecteur de `PdlMapHero`.
///
/// Un seul endroit pour les cinq cartes de l'app : la conversion était recopiée
/// à l'identique dans chacune, et l'ajout des sections l'aurait été aussi.
/// `core/pdl` ne traduit rien — l'intitulé de section est localisé ici.
List<PdlMapStyleOption> servedMapStyleOptions(WidgetRef ref) => mapStyleOptions(
  ref.watch(appConfigProvider).value?.mapStyles ?? const <MapStyleDto>[],
);

/// Les lignes du sélecteur : une par fond servi.
List<PdlMapStyleOption> mapStyleOptions(List<MapStyleDto> styles) =>
    <PdlMapStyleOption>[
      for (final MapStyleDto style in styles)
        PdlMapStyleOption(
          id: style.id,
          label: style.label,
          groupLabel: mapStyleGroupLabel(style.group),
        ),
    ];

/// L'interrupteur « Carte claire » de la feuille des couches, ou rien.
///
/// Il n'est offert que là où il change quelque chose : en thème sombre, sur un
/// fond qui a une variante sombre. Une liste, pour s'étaler dans `switches:`.
List<PdlMapHeroSwitch> servedLightMapSwitch(
  WidgetRef ref,
  Brightness brightness,
) {
  final bool hasDarkVariant =
      ref.watch(mapStyleProvider(brightness)).value?.hasDarkVariant ?? false;
  // Le réglage n'est lu que là où il est offert : ailleurs il ne compte pas.
  if (brightness != Brightness.dark || !hasDarkVariant) {
    return const <PdlMapHeroSwitch>[];
  }
  return lightMapSwitch(
    brightness: brightness,
    hasDarkVariant: hasDarkVariant,
    value: ref.watch(mapLightInDarkProvider),
    onChanged: (bool v) => ref.read(mapLightInDarkProvider.notifier).set(v),
  );
}

List<PdlMapHeroSwitch> lightMapSwitch({
  required Brightness brightness,
  required bool hasDarkVariant,
  required bool value,
  required ValueChanged<bool> onChanged,
}) => <PdlMapHeroSwitch>[
  if (brightness == Brightness.dark && hasDarkVariant)
    PdlMapHeroSwitch(
      id: 'lightMap',
      label: 'map.lightMap'.tr(),
      value: value,
      onChanged: onChanged,
    ),
];

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

/// La barre d'échelle à passer à `PdlMap`, dans les unités du lecteur
/// (`UserDto.unitSystem`) : mètres puis kilomètres, ou pieds puis milles.
PdlMapScale servedMapScale(WidgetRef ref) =>
    mapScaleFor(ref.watch(unitSystemProvider));

/// Les paliers 1-2-5 de la barre, pour un système d'unités donné.
///
/// Au-delà de 2 000 ft la barre passe au mille : 1 mi vaut 5 280 ft, et
/// « 5000 ft » ne se lit pas d'un coup d'œil.
PdlMapScale mapScaleFor(UnitSystem units) {
  const List<double> mantissas = <double>[1, 2, 5];
  PdlMapScaleStep step(double meters, num value, String symbol) =>
      PdlMapScaleStep(
        meters,
        AppFormatters.withUnit(AppFormatters.formatNumber(value), symbol),
      );
  final List<PdlMapScaleStep> steps = <PdlMapScaleStep>[];
  if (units.isImperial) {
    for (final double ft in <double>[10, 20, 50, 100, 200, 500, 1000, 2000]) {
      steps.add(step(ft * kMetersPerFoot, ft, UnitSymbols.foot));
    }
    for (double decade = 1; decade <= 1000; decade *= 10) {
      for (final double m in mantissas) {
        final double mi = m * decade;
        steps.add(step(mi * kMetersPerMile, mi, UnitSymbols.mile));
      }
    }
  } else {
    for (double decade = 1; decade <= 1000000; decade *= 10) {
      for (final double m in mantissas) {
        final double meters = m * decade;
        steps.add(
          meters < 1000
              ? step(meters, meters, UnitSymbols.meter)
              : step(meters, meters / 1000, UnitSymbols.kilometer),
        );
      }
    }
  }
  return PdlMapScale(steps);
}

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
