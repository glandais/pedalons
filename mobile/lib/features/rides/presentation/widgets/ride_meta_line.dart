import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../domain/group_title.dart';

/// La première ligne compacte d'une sortie : « 09:30 · Vélo Club des Monts ·
/// Groupe B » (règle R11, KIT §9 ; « Les 7 prochains jours », agenda).
///
/// L'heure ne se tronque jamais ; le groupe (passé par [groupLabel]) non plus,
/// tant qu'il tient dans la ligne après l'heure : c'est l'**équipe** qui cède
/// (décision du 2026-11-12). Seul un nom de groupe plus long que toute la
/// place restante s'abrège à son tour, plutôt que de déborder.
///
/// Une mise en page à soi plutôt qu'un `Row` : un `Row` ne sait pas donner la
/// place d'abord au dernier enfant, et un `LayoutBuilder` ne répondrait pas
/// aux mesures intrinsèques de la carte d'agenda (`IntrinsicHeight`).
class RideMetaLine extends StatelessWidget {
  const RideMetaLine({
    super.key,
    this.time,
    required this.teamName,
    this.groupName,
    required this.style,
    this.timeStyle,
  });

  final String? time;
  final String teamName;

  /// Le nom brut du groupe rejoint ; `null` ou vide, la ligne n'en parle pas.
  final String? groupName;
  final TextStyle style;

  /// Le style de l'heure, [style] par défaut.
  final TextStyle? timeStyle;

  @override
  Widget build(BuildContext context) {
    final String? group = groupName == null || groupName!.trim().isEmpty
        ? null
        : groupLabel(groupName!);
    return _MetaLine(
      children: <Widget>[
        // L'heure et son séparateur, entiers.
        if (time != null)
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: time, style: timeStyle ?? style),
                const TextSpan(text: ' · '),
              ],
            ),
            maxLines: 1,
            softWrap: false,
            style: style,
          )
        else
          const SizedBox.shrink(),
        // L'équipe, dans ce qui reste une fois le groupe servi.
        Text(
          teamName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          // La largeur de ce qui est écrit, pas celle offerte : abrégée,
          // l'équipe garderait sinon un blanc avant « · Groupe B ».
          textWidthBasis: TextWidthBasis.longestLine,
          style: style,
        ),
        // Le groupe et son séparateur, servis avant l'équipe.
        if (group != null)
          Text(
            ' · $group',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: style,
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}

/// Trois enfants dans l'ordre de lecture — tête, milieu, queue : la tête
/// prend sa largeur, la queue ce qui reste, le milieu le reste du reste.
class _MetaLine extends MultiChildRenderObjectWidget {
  const _MetaLine({required super.children}) : assert(children.length == 3);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMetaLine();
}

class _MetaLineParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMetaLine extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MetaLineParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MetaLineParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MetaLineParentData) {
      child.parentData = _MetaLineParentData();
    }
  }

  List<RenderBox> get _kids => getChildrenAsList();

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => _kids.fold<double>(
    0,
    (double sum, RenderBox c) => sum + c.getMaxIntrinsicWidth(height),
  );

  @override
  double computeMinIntrinsicHeight(double width) => _kids.fold<double>(
    0,
    (double h, RenderBox c) => math.max(h, c.getMinIntrinsicHeight(width)),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _kids.fold<double>(
    0,
    (double h, RenderBox c) => math.max(h, c.getMaxIntrinsicHeight(width)),
  );

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final (double width, double height, _) = _measure(
      constraints,
      (RenderBox c, BoxConstraints cc) => c.getDryLayout(cc),
    );
    return constraints.constrain(Size(width, height));
  }

  (double, double, List<Size>) _measure(
    BoxConstraints constraints,
    Size Function(RenderBox, BoxConstraints) layout,
  ) {
    final List<RenderBox> kids = _kids;
    final double max = constraints.maxWidth;
    final Size head = layout(kids[0], BoxConstraints(maxWidth: max));
    final double afterHead = math.max(0, max - head.width);
    final Size tail = layout(kids[2], BoxConstraints(maxWidth: afterHead));
    final Size middle = layout(
      kids[1],
      BoxConstraints(maxWidth: math.max(0, afterHead - tail.width)),
    );
    final double height = math.max(
      head.height,
      math.max(middle.height, tail.height),
    );
    return (
      head.width + middle.width + tail.width,
      height,
      <Size>[head, tail, middle],
    );
  }

  @override
  void performLayout() {
    final (double width, double height, List<Size> sizes) = _measure(
      constraints,
      (RenderBox c, BoxConstraints cc) {
        c.layout(cc, parentUsesSize: true);
        return c.size;
      },
    );
    size = constraints.constrain(Size(width, height));
    final List<RenderBox> kids = _kids;
    final Size head = sizes[0];
    final Size tail = sizes[1];
    final Size middle = sizes[2];
    (kids[0].parentData! as _MetaLineParentData).offset = Offset(
      0,
      (height - head.height) / 2,
    );
    (kids[1].parentData! as _MetaLineParentData).offset = Offset(
      head.width,
      (height - middle.height) / 2,
    );
    (kids[2].parentData! as _MetaLineParentData).offset = Offset(
      head.width + middle.width,
      (height - tail.height) / 2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
