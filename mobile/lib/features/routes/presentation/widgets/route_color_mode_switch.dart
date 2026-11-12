import 'package:easy_localization/easy_localization.dart';

import '../../../../core/material.dart';

import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../keys.dart';
import '../../domain/track_surfaces.dart';

/// Un mode d'un [MapColorModeSwitch] : sa valeur, son libellé déjà traduit, et
/// la clé de son segment (celle qu'un test touche).
class MapColorModeOption<T> {
  const MapColorModeOption({
    required this.value,
    required this.label,
    this.key,
  });

  final T value;
  final String label;
  final Key? key;
}

/// L'interrupteur segmenté qui choisit ce que colore une carte — le dessin
/// commun de [RouteColorModeSwitch] (Pente | Revêtement | Météo) et de celui
/// de la carte d'ensemble d'un voyage (Étapes | Météo) : sous la carte
/// encastrée, ou dans la carte du bas du plein écran ([overMap],
/// [routeMapBottomLayer]).
///
/// Avec moins de deux [options], il n'y a rien à choisir : rien ne se rend.
class MapColorModeSwitch<T> extends StatelessWidget {
  const MapColorModeSwitch({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.overMap = false,
  });

  final List<MapColorModeOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Ce que l'interrupteur colore, pour les lecteurs d'écran, déjà traduit.
  final String semanticLabel;

  /// Vrai quand il est posé sur la carte, dans la carte du bas
  /// ([routeMapBottomLayer]) : il en prend **toute la largeur**, et c'est
  /// elle qui porte la surface, le filet et l'ombre — une seule surface pour
  /// l'interrupteur et la légende (ledger `docs/LEDGER_*.md MOB-129`). Faux
  /// sous la carte encastrée : à gauche, borné à [_segmentWidth] par segment.
  final bool overMap;

  /// La largeur d'un segment sous la carte : trois segments étirés sur toute
  /// une tablette se liraient mal. Dans la carte du bas, la largeur est celle
  /// de la carte, que le hero borne déjà à ses marges.
  static const double _segmentWidth = 120;

  @override
  Widget build(BuildContext context) {
    if (options.length < 2) return const SizedBox.shrink();
    final bool known = options.any(
      (MapColorModeOption<T> o) => o.value == value,
    );
    final Widget segmented = PdlSegmented<T>(
      value: known ? value : options.first.value,
      onChanged: onChanged,
      segments: <PdlSegment<T>>[
        for (final MapColorModeOption<T> option in options)
          PdlSegment<T>(
            key: option.key,
            value: option.value,
            label: option.label,
          ),
      ],
    );
    return Semantics(
      label: semanticLabel,
      container: true,
      child: overMap
          ? segmented
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: _segmentWidth * options.length,
                ),
                child: SizedBox(width: double.infinity, child: segmented),
              ),
            ),
    );
  }
}

/// L'interrupteur **unique** Pente | Revêtement | Météo d'une carte de
/// parcours (ledger `MOB-105`) : il colore la carte encastrée, son plein écran
/// et le profil — le pendant mobile des `ColorModeControls` du site. La carte
/// encastrée ne se manipule pas : il se pose sous elle ; en plein écran, le
/// même interrupteur, sur le même état, se pose dans la carte du bas, au-dessus
/// de la légende ([routeMapBottomLayer], [overMap]).
///
/// [modes] vient de `routeColorModes`, [value] de `resolveRouteColorBy`. Avec
/// un seul mode proposé — la pente —, il n'y a rien à choisir : rien ne se
/// rend.
class RouteColorModeSwitch extends StatelessWidget {
  const RouteColorModeSwitch({
    super.key,
    required this.modes,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.overMap = false,
  });

  final List<RouteColorBy> modes;
  final RouteColorBy value;
  final ValueChanged<RouteColorBy> onChanged;

  /// Ce que l'interrupteur colore, pour les lecteurs d'écran, déjà traduit.
  /// `null` : « le profil et le tracé ».
  final String? semanticLabel;

  /// Vrai dans la carte du bas du plein écran : voir
  /// [MapColorModeSwitch.overMap].
  final bool overMap;

  @override
  Widget build(BuildContext context) => MapColorModeSwitch<RouteColorBy>(
    options: <MapColorModeOption<RouteColorBy>>[
      for (final RouteColorBy mode in modes)
        MapColorModeOption<RouteColorBy>(
          key: keys.routeDetail.colorByMode(mode.name),
          value: mode,
          label: _label(mode),
        ),
    ],
    value: value,
    onChanged: onChanged,
    semanticLabel: semanticLabel ?? 'routes.surfaceDetail.colorBy'.tr(),
    overMap: overMap,
  );

  static String _label(RouteColorBy mode) => switch (mode) {
    RouteColorBy.grade => 'routes.surfaceDetail.grade'.tr(),
    RouteColorBy.surface => 'routes.surfaceDetail.surface'.tr(),
    RouteColorBy.wind => 'rides.weather.mapMode'.tr(),
  };
}

/// La carte du bas d'une carte de parcours, à passer à
/// `PdlMapHero.bottomLayer` (ledger `docs/LEDGER_*.md MOB-129`) : **une seule
/// surface** ([PdlMapFloatingCard]) qui porte l'interrupteur de mode du plein
/// écran ([modeSwitch], ledger `MOB-105`, construit avec `overMap: true`) sur
/// toute sa largeur, puis dessous la légende du vent ([legend],
/// `RideWindMapLegend`, qui n'a pas de surface à elle). `null` quand il n'y a
/// rien à poser.
///
/// Le hero la pose à ses marges, au-dessus de la zone sûre en plein écran, et
/// la **mesure** : l'échelle, le crédit ⓘ et la colonne de boutons montent
/// au-dessus d'elle — c'est ce qui les empêche de se recouvrir. Elle ne pose
/// donc ni position ni zone sûre, et ne réserve rien à droite.
///
/// Avec l'interrupteur, la carte prend toute la largeur ; la légende seule (la
/// vignette, l'onglet Météo) se contente de la sienne, à gauche, pour laisser
/// voir le plus de carte possible.
///
/// [passTouches] : sur une vignette qui s'ouvre au toucher, la carte du bas ne
/// garde pas le doigt pour elle — il traverse jusqu'à la couche du hero qui
/// ouvre le plein écran.
Widget? routeMapBottomLayer({
  Widget? modeSwitch,
  Widget? legend,
  bool passTouches = false,
}) {
  if (modeSwitch == null && legend == null) return null;
  final Widget card = PdlMapFloatingCard(
    padding: const EdgeInsets.all(PdlSpacing.chipGap),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: modeSwitch == null
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.stretch,
      children: <Widget>[
        ?modeSwitch,
        if (modeSwitch != null && legend != null)
          const SizedBox(height: PdlSpacing.chipGap),
        ?legend,
      ],
    ),
  );
  return IgnorePointer(
    ignoring: passTouches,
    child: modeSwitch == null
        ? Align(alignment: AlignmentDirectional.centerStart, child: card)
        : card,
  );
}
