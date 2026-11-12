import 'package:flutter/rendering.dart';

import '../material.dart';
import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import 'pdl_blur_surface.dart';

/// C3 — La barre d'outils épinglée.
///
/// Un `SliverPersistentHeader(pinned: true)`, à placer **juste sous** la
/// `SliverAppBar`. C'est elle qui reste, quand l'app bar, elle, se rétracte
/// (arbitrage §1.0.4) : ce qui filtre et trie une liste doit rester joignable
/// au 40ᵉ élément, ce qui la titre n'a pas à occuper 56 px en permanence.
///
/// **Sa hauteur est mesurée, jamais figée.** C'est le défaut F-DE-3 sous une
/// autre forme : un `SliverPersistentHeader` demande ses extents *avant* de
/// construire son enfant, et la tentation est d'y écrire une constante. À 130 %
/// d'agrandissement typographique, la rangée de chips ou le champ de recherche
/// qu'elle contient dépasse cette constante et se fait rogner. La barre laisse
/// donc son contenu se mesurer librement — [OverflowBox] à hauteur non bornée —
/// puis adopte la hauteur relevée. Le premier cadre emploie
/// [estimatedExtent] ; l'écart, s'il y en a un, est corrigé au cadre suivant.
class PdlPinnedToolbar extends StatefulWidget {
  const PdlPinnedToolbar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      vertical: PdlMetrics.toolbarPadding,
    ),
    this.estimatedExtent =
        PdlMetrics.tapTarget + 2 * PdlMetrics.toolbarPadding + 1,
    this.showBorder = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Hauteur du **premier** cadre, avant que le contenu ne se soit mesuré.
  /// Par défaut la barre d'outils courante : une cible de 44 px, ses 10 px de
  /// gouttière et la bordure basse.
  final double estimatedExtent;

  final bool showBorder;

  @override
  State<PdlPinnedToolbar> createState() => _PdlPinnedToolbarState();
}

class _PdlPinnedToolbarState extends State<PdlPinnedToolbar> {
  double? _extent;

  void _onHeight(double height) {
    if (_extent != null && (_extent! - height).abs() < 0.5) return;
    // La mesure tombe pendant la phase de layout : re-bâtir tout de suite
    // lèverait « setState() called during build ». On attend la fin du cadre.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _extent = height);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _PdlToolbarDelegate(
        extent: _extent ?? widget.estimatedExtent,
        padding: widget.padding,
        showBorder: widget.showBorder,
        onHeight: _onHeight,
        child: widget.child,
      ),
    );
  }
}

class _PdlToolbarDelegate extends SliverPersistentHeaderDelegate {
  const _PdlToolbarDelegate({
    required this.extent,
    required this.padding,
    required this.showBorder,
    required this.onHeight,
    required this.child,
  });

  final double extent;
  final EdgeInsetsGeometry padding;
  final bool showBorder;
  final ValueChanged<double> onHeight;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final PdlColors c = context.pdl;

    return PdlBlurSurface(
      color: c.overlaySolid,
      sigma: PdlMotion.blurToolbar,
      border: showBorder
          ? Border(bottom: BorderSide(color: c.borderSubtle))
          : null,
      child: SizedBox.expand(
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: 0,
            maxHeight: double.infinity,
            child: _MeasuredHeight(
              onHeight: onHeight,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PdlToolbarDelegate old) =>
      old.extent != extent ||
      old.padding != padding ||
      old.showBorder != showBorder ||
      old.child != child;
}

/// Relaie la hauteur naturelle de son enfant après chaque layout.
class _MeasuredHeight extends SingleChildRenderObjectWidget {
  const _MeasuredHeight({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasuredHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasuredHeight renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderMeasuredHeight extends RenderProxyBox {
  _RenderMeasuredHeight(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (_reported != size.height) {
      _reported = size.height;
      onHeight(size.height);
    }
  }
}
