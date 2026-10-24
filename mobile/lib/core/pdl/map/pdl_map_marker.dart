import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/pdl_tokens.dart';

/// Un marqueur Flutter posé sur la carte : une position, un widget, et un
/// toucher qui rend son [id] (`PdlMap.onMarkerTapped`).
///
/// Générique : `core/pdl` ne sait pas ce qu'il montre — une pastille météo,
/// une goutte de pluie. L'écran construit le [child] avec ses jetons et ses
/// textes traduits, et fournit le [semanticLabel] que le lecteur d'écran
/// annonce.
///
/// **Égalité de valeur** sur ce qui identifie, place et annonce le marqueur —
/// [id], [lon], [lat], [size], [alignment], [semanticLabel] —, pas sur
/// [child] : l'égalité d'un `Widget` est son identité, et un écran qui
/// reconstruit ses marqueurs à chaque `build` les verrait tous changer. Le
/// libellé décrit ce que montre le widget : un contenu qui change change
/// aussi son libellé.
@immutable
class PdlMapMarker {
  const PdlMapMarker({
    required this.id,
    required this.lon,
    required this.lat,
    required this.size,
    required this.semanticLabel,
    required this.child,
    this.alignment = Alignment.center,
  });

  /// Identité stable, rendue au toucher.
  final String id;
  final double lon;
  final double lat;

  /// La taille **visuelle** du [child]. La cible tactile, elle, ne descend
  /// jamais sous `PdlMetrics.tapTarget` : voir [PdlMapMarkerTarget].
  final Size size;

  /// Le point d'accroche du marqueur sur sa position : `center` le centre
  /// sur le point, `bottomCenter` le pose au-dessus, `topCenter` en dessous.
  final Alignment alignment;

  /// Ce que le lecteur d'écran annonce : le marqueur est un bouton.
  final String semanticLabel;

  final Widget child;

  /// La boîte posée sur la carte : la taille visuelle, élargie à la cible
  /// tactile.
  Size get targetSize => Size(
    math.max(size.width, PdlMetrics.tapTarget),
    math.max(size.height, PdlMetrics.tapTarget),
  );

  @override
  bool operator ==(Object other) =>
      other is PdlMapMarker &&
      other.id == id &&
      other.lon == lon &&
      other.lat == lat &&
      other.size == size &&
      other.alignment == alignment &&
      other.semanticLabel == semanticLabel;

  @override
  int get hashCode => Object.hash(id, lon, lat, size, alignment, semanticLabel);
}

/// Le cap de la carte sous un [PdlMapMarker] : degrés, sens horaire, 0 =
/// nord en haut. [PdlMap] le pose autour de chaque marqueur, que MapLibre
/// garde droit à l'écran quand la carte tourne : un dessin qui montre une
/// direction **absolue** (une flèche de vent) retranche ce cap pour rester
/// juste. Hors d'une carte, 0.
class PdlMapBearing extends InheritedWidget {
  const PdlMapBearing({super.key, required this.bearing, required super.child});

  final double bearing;

  /// Le cap de la carte qui entoure [context], 0 hors d'une carte. Le widget
  /// qui le lit se reconstruit quand la carte tourne.
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PdlMapBearing>()?.bearing ?? 0;

  @override
  bool updateShouldNotify(PdlMapBearing oldWidget) =>
      oldWidget.bearing != bearing;
}

/// La cible d'un [PdlMapMarker] : au moins 44 × 44, le visuel accroché dans
/// la boîte selon [PdlMapMarker.alignment] — une pastille posée au-dessus de
/// son point garde son bas sur le point —, un bouton pour le lecteur d'écran.
///
/// Sans [onTap], le marqueur n'est qu'une image : ni bouton, ni toucher.
class PdlMapMarkerTarget extends StatelessWidget {
  const PdlMapMarkerTarget({super.key, required this.marker, this.onTap});

  final PdlMapMarker marker;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Size box = marker.targetSize;
    return Semantics(
      container: true,
      button: onTap != null,
      label: marker.semanticLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox.fromSize(
            size: box,
            child: Align(
              alignment: marker.alignment,
              child: SizedBox.fromSize(size: marker.size, child: marker.child),
            ),
          ),
        ),
      ),
    );
  }
}
