import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../keys.dart';
import '../../domain/track_surfaces.dart';

/// L'interrupteur **unique** Pente | Revêtement | Météo d'une carte de
/// parcours (ledger `MOB-105`) : il colore la carte encastrée, son plein écran
/// et le profil — le pendant mobile des `ColorModeControls` du site. La carte
/// encastrée ne se manipule pas : il se pose sous elle ; en plein écran, le
/// même interrupteur, sur le même état, se pose sur la carte, en bas
/// ([routeMapBottomLayer], [overMap]).
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

  /// Vrai quand il est posé sur une carte (le plein écran) : une ombre et un
  /// filet le détachent de la tuile.
  final bool overMap;

  /// La largeur d'un segment : `PdlSegmented` exige une largeur bornée, et
  /// trois segments étirés sur toute une tablette se liraient mal.
  static const double _segmentWidth = 120;

  @override
  Widget build(BuildContext context) {
    if (modes.length < 2) return const SizedBox.shrink();
    final Widget segmented = PdlSegmented<RouteColorBy>(
      value: modes.contains(value) ? value : modes.first,
      onChanged: onChanged,
      segments: <PdlSegment<RouteColorBy>>[
        for (final RouteColorBy mode in modes)
          PdlSegment<RouteColorBy>(
            key: keys.routeDetail.colorByMode(mode.name),
            value: mode,
            label: _label(mode),
          ),
      ],
    );
    return Semantics(
      label: semanticLabel ?? 'routes.surfaceDetail.colorBy'.tr(),
      container: true,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _segmentWidth * modes.length),
          child: SizedBox(
            width: double.infinity,
            child: overMap
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: PdlRadii.mdAll,
                      border: Border.all(color: context.pdl.borderSubtle),
                      boxShadow: PdlShadows.sheet,
                    ),
                    child: segmented,
                  )
                : segmented,
          ),
        ),
      ),
    );
  }

  static String _label(RouteColorBy mode) => switch (mode) {
    RouteColorBy.grade => 'routes.surfaceDetail.grade'.tr(),
    RouteColorBy.surface => 'routes.surfaceDetail.surface'.tr(),
    RouteColorBy.wind => 'rides.weather.mapMode'.tr(),
  };
}

/// Ce qui se pose en bas d'une carte de parcours, dans le `foreground` de
/// `PdlMapHero` : l'interrupteur de mode en plein écran ([modeSwitch], ledger
/// `MOB-105`), et sous lui la légende du vent ([legend]). Dans la coquille et
/// non dans les `overlays` de la carte, qui n'apparaissent qu'une fois la vue
/// native prête : ni l'un ni l'autre n'en a besoin. À gauche : le coin droit
/// reste au crédit ⓘ des tuiles. `null` quand il n'y a rien à poser.
///
/// [passTouches] : sur une vignette qui s'ouvre au toucher, la légende ne
/// garde pas le doigt pour elle.
Widget? routeMapBottomLayer({
  required bool fullscreen,
  Widget? modeSwitch,
  Widget? legend,
  bool passTouches = false,
}) {
  if (modeSwitch == null && legend == null) return null;
  return Positioned(
    left: PdlSpacing.sectionTightV,
    right: PdlMetrics.tapTarget + PdlSpacing.sectionTightV,
    bottom: PdlSpacing.sectionTightV,
    child: SafeArea(
      top: false,
      left: fullscreen,
      right: false,
      bottom: fullscreen,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ?modeSwitch,
          if (modeSwitch != null && legend != null)
            const SizedBox(height: PdlSpacing.chipGap),
          if (legend != null)
            IgnorePointer(ignoring: passTouches, child: legend),
        ],
      ),
    ),
  );
}
