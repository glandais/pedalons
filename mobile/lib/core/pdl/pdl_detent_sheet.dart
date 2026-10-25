import 'package:flutter/material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import 'pdl_sheet.dart';

/// C7 — La feuille à crans, posée sur une carte.
///
/// Trois crans, et chacun répond à une question : `.18` « qu'est-ce que je
/// regarde ? » (la poignée et une ligne de résumé), `.5` « et dans le
/// détail ? », `.92` « montre-moi la liste ». `snap: true` : elle ne s'arrête
/// pas entre deux.
///
/// Elle **remplace** le `DraggableScrollableSheet` bridé à `maxChildSize: 0.7`
/// de `route_detail_page.dart` — 0,7 laisse un tiers de carte qu'on ne regarde
/// plus et coupe la liste au milieu.
///
/// Deux points de construction, tous deux liés au fait qu'une feuille à crans
/// se reconstruit **à chaque pixel de glissement** :
///
/// * **Le [ValueListenableBuilder] n'englobe que l'en-tête.** L'en-tête change
///   de composition selon le cran ([headerBuilder] reçoit la fraction
///   courante) ; si le builder englobait la feuille entière, les 40 lignes de
///   la liste se reconstruiraient à 60 fois par seconde pendant le geste.
/// * **Le pied est un [Positioned] du [Stack] interne, pas le dernier enfant
///   d'une colonne** : il doit rester collé au bas de la feuille pendant que
///   le corps défile sous lui.
class PdlDetentSheet extends StatefulWidget {
  const PdlDetentSheet({
    super.key,
    required this.bodyBuilder,
    this.headerBuilder,
    this.footer,
    this.controller,
    this.detents = const <double>[0.18, 0.5, 0.92],
    this.initialDetentIndex = 1,
    this.onDetentChanged,
  }) : assert(detents.length >= 2, 'Une feuille à crans en a au moins deux.');

  /// Le corps reçoit le [ScrollController] de la feuille — sans lui, tirer sur
  /// la liste ne fait pas monter la feuille — et la hauteur mesurée de
  /// [footer], à ajouter en fin de liste : le pied est un [Positioned] qui
  /// flotte **par-dessus** le corps, donc sans cette réserve le dernier
  /// élément défile sous lui, invisible à fond de feuille.
  final Widget Function(
    BuildContext context,
    ScrollController controller,
    double footerInset,
  )
  bodyBuilder;

  /// En-tête, reconstruit à chaque changement de fraction — et lui seul.
  final Widget Function(BuildContext context, double extent)? headerBuilder;

  /// Pied fixe, collé au bas de la feuille.
  final Widget? footer;

  final DraggableScrollableController? controller;

  /// Les crans, en fraction de la hauteur disponible.
  final List<double> detents;

  final int initialDetentIndex;

  /// Notifié à chaque franchissement de cran, jamais en continu.
  final ValueChanged<double>? onDetentChanged;

  @override
  State<PdlDetentSheet> createState() => _PdlDetentSheetState();
}

class _PdlDetentSheetState extends State<PdlDetentSheet> {
  late final ValueNotifier<double> _extent = ValueNotifier<double>(
    widget.detents[widget.initialDetentIndex],
  );
  double _lastSnapped = -1;

  /// Hauteur du pied, relevée après pose — variable avec l'échelle de police
  /// et son contenu, donc jamais une constante devinée.
  double _footerHeight = 0;

  /// Le contrôleur du glissement. [DraggableScrollableSheet] ne se laisse
  /// entraîner que par **son** scrollable, or la poignée et l'en-tête n'en font
  /// pas partie : sans lui, tirer sur la poignée — le geste que la poignée
  /// annonce — ne fait rien, et il faut viser la liste, laquelle défile au lieu
  /// de bouger la feuille dès qu'elle n'est plus en haut. C'est ce qui rendait
  /// la feuille « capricieuse ».
  late final DraggableScrollableController _controller =
      widget.controller ?? DraggableScrollableController();

  /// La hauteur disponible, relevée par le `LayoutBuilder` de [build] : les
  /// crans sont des fractions, les gestes des pixels.
  double _available = 0;

  @override
  void dispose() {
    // Un contrôleur fourni par l'appelant lui appartient.
    if (widget.controller == null) _controller.dispose();
    _extent.dispose();
    super.dispose();
  }

  double get _min => widget.detents.first;
  double get _max => widget.detents.last;

  /// Le cran le plus proche de [size], la vélocité départageant les ex æquo.
  ///
  /// [velocity] est en pixels par seconde, positive vers le bas. Un geste franc
  /// (au-delà de 400 px/s, le seuil de `DraggableScrollableSheet` lui-même)
  /// emmène au cran suivant dans son sens, même s'il n'a pas parcouru la moitié
  /// de la distance : c'est ce qui fait qu'un petit coup sec suffit.
  double _snapTarget(double size, double velocity) {
    final List<double> detents = widget.detents;
    if (velocity.abs() > 400) {
      final bool up = velocity < 0;
      for (int i = 0; i < detents.length; i++) {
        final int j = up ? i : detents.length - 1 - i;
        if (up ? detents[j] > size + 0.01 : detents[j] < size - 0.01) {
          return detents[j];
        }
      }
    }
    return detents.reduce(
      (double a, double b) => (a - size).abs() < (b - size).abs() ? a : b,
    );
  }

  void _onHandleDrag(DragUpdateDetails details) {
    if (_available <= 0 || !_controller.isAttached) return;
    // Vers le haut = la feuille grandit, d'où le signe.
    final double next = (_controller.size - details.delta.dy / _available)
        .clamp(_min, _max);
    _controller.jumpTo(next);
  }

  void _onHandleDragEnd(DragEndDetails details) {
    if (!_controller.isAttached) return;
    _animateTo(
      _snapTarget(_controller.size, details.velocity.pixelsPerSecond.dy),
    );
  }

  /// Ramène la feuille d'un cran, en réponse à un tap sur la carte au-dessus.
  void _collapseOneStep() {
    if (!_controller.isAttached) return;
    final List<double> detents = widget.detents;
    final double size = _controller.size;
    for (int i = detents.length - 1; i >= 0; i--) {
      if (detents[i] < size - 0.01) return _animateTo(detents[i]);
    }
  }

  void _animateTo(double size) => _controller.animateTo(
    size,
    duration: PdlMotion.stateChange,
    curve: PdlMotion.stateChangeCurve,
  );

  bool _onNotification(DraggableScrollableNotification notification) {
    _extent.value = notification.extent;

    // Le rappel de cran ne suit pas le doigt : il ne parle qu'une fois posé.
    final double nearest = widget.detents.reduce(
      (double a, double b) =>
          (a - notification.extent).abs() < (b - notification.extent).abs()
          ? a
          : b,
    );
    if ((nearest - notification.extent).abs() < 0.01 &&
        nearest != _lastSnapped) {
      _lastSnapped = nearest;
      widget.onDetentChanged?.call(nearest);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final List<double> detents = widget.detents;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _available = constraints.maxHeight;
        return Stack(
          children: <Widget>[
            // Au-dessus de la feuille : un tap la ramène d'un cran. La zone
            // est **exactement** la partie non couverte, et n'est active
            // qu'au-delà du cran d'ouverture. En deçà, la carte qui vit dessous
            // garde ses taps — sur la fiche parcours, c'est ce tap qui pose le
            // réticule, et le lui prendre à tous les crans serait une perte
            // sèche. Au-delà, il ne reste plus assez de carte pour viser quoi
            // que ce soit : refermer est la seule intention plausible.
            ValueListenableBuilder<double>(
              valueListenable: _extent,
              builder: (BuildContext context, double extent, _) {
                final bool active =
                    extent > widget.detents[widget.initialDetentIndex] + 0.01;
                return Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: (1 - extent) * _available,
                  child: IgnorePointer(
                    ignoring: !active,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _collapseOneStep,
                    ),
                  ),
                );
              },
            ),
            _sheet(c, detents),
          ],
        );
      },
    );
  }

  Widget _sheet(PdlColors c, List<double> detents) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: _onNotification,
      child: DraggableScrollableSheet(
        controller: _controller,
        initialChildSize: detents[widget.initialDetentIndex],
        minChildSize: detents.first,
        maxChildSize: detents.last,
        snap: true,
        snapSizes: detents.sublist(1, detents.length - 1),
        builder: (BuildContext context, ScrollController scrollController) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: PdlRadii.sheetTop,
              border: Border(top: BorderSide(color: c.borderSubtle)),
              boxShadow: PdlShadows.sheet,
            ),
            child: ClipRRect(
              borderRadius: PdlRadii.sheetTop,
              child: Stack(
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Poignée **et** en-tête entraînent la feuille : ils
                      // sont hors du scrollable, donc `DraggableScrollableSheet`
                      // ne les voit pas, et c'est ce `GestureDetector` qui
                      // rattache le geste au contrôleur.
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: _onHandleDrag,
                        onVerticalDragEnd: _onHandleDragEnd,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const PdlSheetHandle(),
                            if (widget.headerBuilder != null)
                              ValueListenableBuilder<double>(
                                valueListenable: _extent,
                                builder: (
                                  BuildContext context,
                                  double extent,
                                  _,
                                ) => widget.headerBuilder!(context, extent),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: widget.bodyBuilder(
                          context,
                          scrollController,
                          _footerHeight,
                        ),
                      ),
                    ],
                  ),
                  if (widget.footer != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _MeasureSize(
                        onChange: (double height) {
                          if (height != _footerHeight) {
                            setState(() => _footerHeight = height);
                          }
                        },
                        child: widget.footer!,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Signale la hauteur rendue de [child], relevée après chaque pose.
///
/// [Positioned] ne contraint pas la hauteur d'un pied qui se dimensionne à
/// son contenu ([PdlDetentSheet] ne la connaît donc pas d'avance ; il n'y a
/// pas de raccourci `RenderObject` plus court que mesurer après coup.
class _MeasureSize extends StatefulWidget {
  const _MeasureSize({required this.onChange, required this.child});

  final ValueChanged<double> onChange;
  final Widget child;

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  double? _reported;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final double? height =
          (context.findRenderObject() as RenderBox?)?.size.height;
      if (height != null && height != _reported) {
        _reported = height;
        widget.onChange(height);
      }
    });
    return widget.child;
  }
}
