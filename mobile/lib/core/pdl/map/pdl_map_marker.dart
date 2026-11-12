import 'dart:math' as math;

import '../../material.dart';

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
    this.rank,
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

  /// Qui cède la place quand la carte manque de place ([layoutMarkerBoxes]) :
  /// `null` reste toujours affiché, un rang bas passe avant un rang haut.
  final int? rank;

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
      other.rank == rank &&
      other.semanticLabel == semanticLabel;

  @override
  int get hashCode =>
      Object.hash(id, lon, lat, size, alignment, rank, semanticLabel);
}

/// L'écart laissé entre deux marqueurs que [spreadMarkerBoxes] écarte.
const double pdlMarkerGap = 4;

/// La boîte **visuelle** de [marker] quand son point tombe en [at] à l'écran,
/// accrochée selon son [PdlMapMarker.alignment] — comme la pose `WidgetLayer`.
Rect pdlMarkerBox(PdlMapMarker marker, Offset at) => Rect.fromLTWH(
  at.dx - marker.size.width / 2 * (marker.alignment.x + 1),
  at.dy - marker.size.height / 2 * (marker.alignment.y + 1),
  marker.size.width,
  marker.size.height,
);

/// De combien déplacer chaque boîte, en pixels d'écran, pour qu'aucune n'en
/// recouvre une autre (ledger `MOB-104`, `MOB-109`, le pendant de `WEB-128` et
/// `WEB-131`).
///
/// Chaque boîte recouverte glisse **à l'horizontale**, à sa hauteur, du
/// minimum qui la dégage, dans l'ordre de la liste : la première d'un
/// recouvrement reste sur son point, la suivante passe du côté où elle est
/// déjà, à droite à égalité (le départ d'une boucle à gauche de son arrivée).
/// Pas de rangée commune : sur un long parcours nord-sud dézoomé, chaque
/// pastille touche la suivante, et une rangée les emporterait toutes hors de
/// l'écran, loin de leur point ; elles se répartissent ainsi de part et
/// d'autre du tracé.
///
/// Bord à bord ne compte pas, [gap] ne sert qu'à l'écart posé. Une boîte seule
/// ne bouge pas, et aucune autre ne vient se poser sur elle. Une goutte posée
/// **sous** son point ne touche pas la pastille posée au-dessus : elles restent
/// où elles sont.
List<Offset> spreadMarkerBoxes(List<Rect> boxes, {double gap = pdlMarkerGap}) {
  final List<Rect> placed = <Rect>[];
  final List<int> pending = <int>[];
  for (int i = 0; i < boxes.length; i++) {
    bool alone = true;
    for (int j = 0; j < boxes.length && alone; j++) {
      alone = j == i || !boxes[i].overlaps(boxes[j]);
    }
    if (alone) {
      placed.add(boxes[i]);
    } else {
      pending.add(i);
    }
  }

  /// Le déplacement minimal de [box] vers la droite, ou vers la gauche.
  double clear(Rect box, {required bool right}) {
    double dx = 0;
    while (true) {
      final Rect moved = box.shift(Offset(dx, 0));
      final int hit = placed.indexWhere(moved.overlaps);
      if (hit < 0) return dx;
      dx = right
          ? placed[hit].right + gap - box.left
          : placed[hit].left - gap - box.right;
    }
  }

  final List<Offset> shifts = List<Offset>.filled(boxes.length, Offset.zero);
  for (final int i in pending) {
    final double toRight = clear(boxes[i], right: true);
    final double toLeft = clear(boxes[i], right: false);
    final double dx = toLeft.abs() < toRight.abs() ? toLeft : toRight;
    shifts[i] = Offset(dx, 0);
    placed.add(boxes[i].shift(shifts[i]));
  }
  return shifts;
}

/// L'écart minimal gardé autour d'un marqueur qui peut céder sa place.
const double pdlMarkerClearance = 16;

/// Ce que devient chaque boîte à ce zoom (ledger `MOB-117`, le pendant de
/// `WEB-142`) : `null` si elle est masquée, sinon son déplacement.
///
/// Une boîte de rang `null` reste toujours, écartée des autres de sa sorte par
/// [spreadMarkerBoxes]. Les autres sont essayées par rang, puis dans l'ordre
/// de la liste : chacune n'est gardée que si rien de déjà posé ne se trouve à
/// moins de [clearance], et elle ne bouge jamais.
List<Offset?> layoutMarkerBoxes(
  List<Rect> boxes,
  List<int?> ranks, {
  double clearance = pdlMarkerClearance,
}) {
  final List<int> required = <int>[
    for (int i = 0; i < boxes.length; i++)
      if (ranks[i] == null) i,
  ];
  final List<Offset> spread = spreadMarkerBoxes(<Rect>[
    for (final int i in required) boxes[i],
  ]);
  final List<Offset?> result = List<Offset?>.filled(boxes.length, null);
  final List<Rect> placed = <Rect>[];
  for (int k = 0; k < required.length; k++) {
    result[required[k]] = spread[k];
    placed.add(boxes[required[k]].shift(spread[k]));
  }
  // `sort` n'étant pas stable, l'indice départage les rangs égaux.
  final List<int> candidates =
      <int>[
        for (int i = 0; i < boxes.length; i++)
          if (ranks[i] != null) i,
      ]..sort((int a, int b) {
        final int byRank = ranks[a]!.compareTo(ranks[b]!);
        return byRank != 0 ? byRank : a.compareTo(b);
      });
  for (final int i in candidates) {
    final Rect room = boxes[i].inflate(clearance);
    if (placed.any(room.overlaps)) continue;
    result[i] = Offset.zero;
    placed.add(boxes[i]);
  }
  return result;
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
