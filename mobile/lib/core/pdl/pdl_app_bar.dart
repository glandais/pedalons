import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';
import 'pdl_blur_surface.dart';

/// Les deux rendus de la barre supérieure.
enum PdlAppBarVariant {
  /// Fond `surface`, texte `text`, bordure basse — le cas courant.
  solid,

  /// Posée **sur** une tuile ou une photo : fond transparent, texte blanc,
  /// boutons voilés et floutés, barre système en clair.
  overlay,
}

/// C1 — La barre supérieure.
///
/// 56 px, padding `0 8 0 16`, actions de 44 × 44, bordure basse.
///
/// **Aucun emplacement de notification.** Ce n'est pas un oubli : aucun
/// endpoint ne l'alimenterait, et le brief §5 interdit une icône-action sans
/// effet. La cloche des maquettes est retirée partout (§1.0.4).
///
/// En [PdlAppBarVariant.overlay] la barre ne réserve pas sa place : elle se
/// pose en `Positioned` au-dessus du média, ses boutons prennent le voile
/// `scrim` à 55 % et un flou σ 6, et la barre système passe en
/// [SystemUiOverlayStyle.light] — sans quoi l'heure noire de l'appareil
/// disparaît sur une tuile sombre.
///
/// Les couleurs du mode `overlay` ne dépendent **pas** de la luminosité de
/// l'app : le voile `scrim` est identique dans les deux modes, le texte posé
/// dessus l'est donc aussi (`onPrimary`, blanc pur dans les deux modes).
class PdlAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PdlAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.onBack,
    this.backSemanticLabel,
    this.backKey,
    this.leading,
    this.actions = const <Widget>[],
    this.variant = PdlAppBarVariant.solid,
    this.centerTitle = false,
    this.showBorder = true,
  });

  /// Titre 17/700, une ligne, ellipsis. Ignoré si [titleWidget] est fourni.
  final String? title;

  /// Titre libre — le logotype de l'accueil, une pile titre + sous-titre.
  final Widget? titleWidget;

  /// Flèche de retour. `null` ⇒ pas de flèche (écran racine).
  final VoidCallback? onBack;

  /// Libellé d'accessibilité de la flèche : « Retour au voyage » vaut mieux
  /// que « Retour ». `core/pdl` ne traduit rien, l'écran fournit la chaîne.
  final String? backSemanticLabel;

  /// Clé de la flèche de retour, pour qu'un test la trouve sans dépendre de
  /// sa position ni de son libellé (qui suit la langue de l'app).
  final Key? backKey;

  /// Remplace entièrement la zone de tête (et donc [onBack]).
  final Widget? leading;

  /// Actions de droite. Chacune doit mesurer 44 × 44 — [PdlAppBarAction] s'en
  /// charge.
  final List<Widget> actions;

  final PdlAppBarVariant variant;
  final bool centerTitle;

  /// Bordure basse. Sans objet en `overlay`, qui n'en porte jamais.
  final bool showBorder;

  bool get _isOverlay => variant == PdlAppBarVariant.overlay;

  @override
  Size get preferredSize => const Size.fromHeight(PdlMetrics.appBar);

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;

    final Widget bar = SizedBox(
      height: PdlMetrics.appBar,
      child: buildRow(context),
    );

    if (_isOverlay) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: bar,
      );
    }

    // La barre système prend le style de la dernière région qui en déclare
    // un : sans celle-ci, un écran poussé au-dessus d'une barre `overlay`
    // gardait ses icônes blanches, sur le fond clair de `surface` (Android).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: _surface(c, bar),
    );
  }

  Widget _surface(PdlColors c, Widget bar) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: showBorder
            ? Border(bottom: BorderSide(color: c.borderSubtle))
            : null,
      ),
      // `preferredSize` ne compte que les 56 px de la rangée : c'est le
      // [Scaffold] qui ajoute l'encoche par-dessus. Sans ce `SafeArea`, la
      // rangée se cale en haut de l'emplacement ainsi agrandi et le titre passe
      // sous l'heure de l'appareil. Le fond, lui, reste *hors* du `SafeArea`
      // pour continuer de couvrir la barre système.
      //
      // En `overlay` l'appelant place la barre lui-même (`Positioned` +
      // `SafeArea`, ou `PdlScreenScaffold`), d'où le retour anticipé plus haut.
      child: SafeArea(bottom: false, left: false, right: false, child: bar),
    );
  }

  /// La rangée nue, sans fond ni hauteur : partagée avec [PdlSliverAppBar].
  @visibleForTesting
  Widget buildRow(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final Color foreground = _isOverlay ? c.onPrimary : c.text;

    final Widget? head =
        leading ??
        (onBack == null
            ? null
            : PdlAppBarAction(
                key: backKey,
                icon: PdlIcons.back,
                onPressed: onBack,
                semanticLabel: backSemanticLabel,
                variant: variant,
              ));

    Widget? titleChild = titleWidget;
    if (titleChild == null && title != null) {
      titleChild = Text(
        title!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: centerTitle ? TextAlign.center : TextAlign.start,
        style: t.barTitle.copyWith(color: foreground),
      );
    }

    return Padding(
      // `0 8 0 16` : 16 à gauche quand le titre commence la barre, 8 à droite
      // parce que les actions portent déjà leur propre gouttière de 44 px.
      padding: EdgeInsets.only(left: head == null ? PdlSpacing.section : 4),
      child: Row(
        children: <Widget>[
          ?head,
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: head == null ? 0 : 4),
              child: titleChild ?? const SizedBox.shrink(),
            ),
          ),
          ...actions,
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Une action de barre supérieure : 44 × 44, ronde, icône 20.
///
/// En `overlay` elle porte le voile `scrim` à 55 % et un flou σ 6 — c'est le
/// seul moyen de garder une icône blanche lisible sur une tuile claire.
class PdlAppBarAction extends StatelessWidget {
  const PdlAppBarAction({
    super.key,
    required this.icon,
    this.onPressed,
    this.semanticLabel,
    this.variant = PdlAppBarVariant.solid,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final PdlAppBarVariant variant;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final bool isOverlay = variant == PdlAppBarVariant.overlay;
    final Color foreground = isOverlay ? c.onPrimary : c.text;

    Widget content = SizedBox(
      width: PdlMetrics.tapTarget,
      height: PdlMetrics.tapTarget,
      child: Icon(icon, size: 20, color: foreground),
    );

    if (isOverlay) {
      content = PdlBlurSurface(
        // 55 % du voile de carte, et non un gris inventé : c'est
        // `rgba(36,36,36,.55)` de `pedalons.css`, dérivé du jeton `scrim`.
        color: c.scrim.withValues(alpha: 0.55),
        sigma: PdlMotion.blurOverlayButton,
        borderRadius: PdlRadii.pillAll,
        child: content,
      );
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        onTap: onPressed,
        radius: PdlMetrics.tapTarget / 2,
        containedInkWell: isOverlay,
        customBorder: const CircleBorder(),
        child: content,
      ),
    );
  }
}

/// La même barre, en sliver rétractable.
///
/// Arbitrage §1.0.4 : la maquette la voulait collante, le brief la veut
/// rétractable — c'est le brief qui l'emporte, parce que rendre 56 px au
/// défilement ramène une carte entière à l'écran. C'est la **barre d'outils**
/// ([PdlPinnedToolbar]) qui reste épinglée, pas celle-ci.
class PdlSliverAppBar extends StatelessWidget {
  const PdlSliverAppBar({
    super.key,
    required this.appBar,
    this.floating = true,
    this.snap = true,
    this.pinned = false,
  });

  final PdlAppBar appBar;
  final bool floating;
  final bool snap;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;

    return SliverAppBar(
      primary: false,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      toolbarHeight: PdlMetrics.appBar,
      backgroundColor: c.surface,
      surfaceTintColor: c.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      floating: floating,
      snap: floating && snap,
      pinned: pinned,
      title: SizedBox(
        height: PdlMetrics.appBar,
        child: appBar.buildRow(context),
      ),
      bottom: appBar.showBorder
          ? PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: c.borderSubtle),
            )
          : null,
    );
  }
}
