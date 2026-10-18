import 'package:flutter/material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import 'pdl_app_bar.dart';
import 'pdl_pinned_toolbar.dart';
import 'pdl_refresh.dart';

/// C8 — La coquille d'écran.
///
/// Elle assemble C1 à C4 et **garantit l'ordre de superposition** :
///
/// ```
/// contenu  <  barre d'outils  <  barre d'action  <  app bar / onglets  <  feuille
/// ```
///
/// Cet ordre n'est pas une préférence esthétique, c'est la correction de deux
/// défauts observés : une barre d'outils passant *sous* le contenu qu'elle
/// filtre, et une feuille passant *sous* la barre d'onglets. Il est obtenu par
/// construction et non par des `elevation` à ajuster :
///
/// * la barre d'outils est un sliver épinglé du **même** défileur que le
///   contenu, elle lui passe donc devant sans qu'on ait à le demander ;
/// * la barre d'action et les onglets forment ensemble le
///   `bottomNavigationBar` du [Scaffold], dans cet ordre ;
/// * les feuilles sont des routes du navigateur **racine** ([PdlSheet.show]),
///   donc au-dessus de la coquille entière.
///
/// [constrainWidth] applique la colonne bornée à 600 px : sur une tablette, une
/// liste de cartes étirée sur 1 024 px n'est plus une liste, c'est un tableau.
class PdlScreenScaffold extends StatelessWidget {
  const PdlScreenScaffold({
    super.key,
    this.appBar,
    this.toolbar,
    this.slivers,
    this.body,
    this.actionBar,
    this.bottomTabs,
    this.floating,
    this.constrainWidth = true,
    this.backgroundColor,
    this.scrollController,
    this.onRefresh,
  }) : assert(
         slivers == null || body == null,
         'Un écran a un corps de slivers ou un corps de boîte, pas les deux.',
       ),
       assert(
         onRefresh == null || slivers != null,
         'Tirer pour rafraîchir suit le défileur de l\'écran : il demande un '
         'corps de slivers.',
       ),
       assert(
         toolbar == null || slivers != null,
         'La barre d\'outils épinglée est un sliver : elle demande un corps de '
         'slivers.',
       );

  /// Barre supérieure. En [PdlAppBarVariant.overlay] elle n'occupe pas de
  /// place : elle est empilée au-dessus du contenu, comme sur un hero
  /// cartographique.
  final PdlAppBar? appBar;

  /// Contenu de la barre d'outils épinglée — chips, recherche, segmenté.
  final Widget? toolbar;

  final List<Widget>? slivers;
  final Widget? body;

  /// Barre d'action basse ([PdlActionBar]).
  final Widget? actionBar;

  /// Barre d'onglets ([PdlBottomTabs]), ou le rail des grands écrans.
  final Widget? bottomTabs;

  /// Posé au-dessus de tout le corps, sous les barres : une feuille à crans,
  /// un bouton flottant de carte.
  final Widget? floating;

  final bool constrainWidth;
  final Color? backgroundColor;
  final ScrollController? scrollController;

  /// Tirer pour rafraîchir ([PdlRefresh]), sur le défileur des [slivers].
  ///
  /// Posé **autour du défileur** et non de l'écran : l'indicateur descend alors
  /// sous l'app bar, pas par-dessus.
  final Future<void> Function()? onRefresh;

  bool get _overlayBar => appBar?.variant == PdlAppBarVariant.overlay;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bool keyboardUp = keyboard > 0;

    // Clavier ouvert, le [Scaffold] laisse son `bottomNavigationBar` dessous :
    // le bouton « Enregistrer » d'un formulaire disparaissait pendant la
    // saisie de la description. La barre d'action remonte donc au-dessus du
    // clavier — sans l'inset système, que le clavier recouvre — et les
    // onglets, eux, restent dessous.
    final Widget? bottomBar;
    if (keyboardUp && actionBar != null) {
      bottomBar = Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: MediaQuery.removeViewPadding(
          context: context,
          removeBottom: true,
          child: actionBar!,
        ),
      );
    } else if (actionBar == null && bottomTabs == null) {
      bottomBar = null;
    } else {
      bottomBar = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[?actionBar, ?bottomTabs],
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? c.bg,
      // Le contenu passe **sous** les barres basses : sans cela, leur flou n'a
      // rien à flouter et leur transparence ne veut rien dire. Sauf clavier
      // ouvert : le corps doit alors s'arrêter au-dessus de la barre remontée,
      // sinon le champ en cours de saisie se cache sous le clavier.
      extendBody: !keyboardUp,
      extendBodyBehindAppBar: _overlayBar,
      appBar: _overlayBar ? null : appBar,
      bottomNavigationBar: bottomBar,
      body: Builder(
        builder: (BuildContext context) {
          // `extendBody: true` fait porter au `MediaQuery` du corps la hauteur
          // des barres basses : c'est de là que vient la marge de fin, jamais
          // d'une constante.
          final double bottomInset = MediaQuery.paddingOf(context).bottom;

          Widget content;
          if (slivers != null) {
            content = CustomScrollView(
              controller: scrollController,
              slivers: <Widget>[
                if (toolbar != null) PdlPinnedToolbar(child: toolbar!),
                ...slivers!,
                SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
              ],
            );
            if (onRefresh != null) {
              content = PdlRefresh(onRefresh: onRefresh!, child: content);
            }
          } else {
            content = Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: body ?? const SizedBox.shrink(),
            );
          }

          if (constrainWidth) {
            content = Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: PdlSpacing.contentMaxWidth,
                ),
                child: content,
              ),
            );
          }

          if (floating == null && !_overlayBar) return content;

          return Stack(
            children: <Widget>[
              Positioned.fill(child: content),
              if (floating != null) Positioned.fill(child: floating!),
              if (_overlayBar)
                Positioned(
                  top: MediaQuery.viewPaddingOf(context).top,
                  left: 0,
                  right: 0,
                  child: appBar!,
                ),
            ],
          );
        },
      ),
    );
  }
}
