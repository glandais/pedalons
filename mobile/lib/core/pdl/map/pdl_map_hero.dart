import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../theme/pdl_colors.dart';
import '../../theme/pdl_icons.dart';
import '../../theme/pdl_tokens.dart';
import '../pdl_color_track.dart';
import '../pdl_section_header.dart';
import '../pdl_setting_row.dart';
import '../pdl_switch.dart';
import '../pdl_sheet.dart';
import 'pdl_map_bottom_inset.dart';
import 'pdl_map_buttons.dart';

/// Un fond de carte proposé au sélecteur.
///
/// Le pendant DTO-libre de `MapStyleDto` : l'écran lit `ConfigDto.mapStyles[]`
/// via `mapStyleProvider` et convertit. **Aucune URL de style n'est écrite
/// ici** — changer `mapStyles` côté serveur change le sélecteur sans livrer une
/// version du client.
@immutable
class PdlMapStyleOption {
  const PdlMapStyleOption({
    required this.id,
    required this.label,
    this.groupLabel,
  });

  final String id;

  /// Libellé déjà localisé par l'appelant.
  final String label;

  /// L'intitulé de la section, **déjà localisé**. Le sélecteur pose un titre
  /// chaque fois qu'il change d'une option à la suivante — il ne regroupe pas
  /// lui-même et ne re-trie pas : la liste arrive dans l'ordre servi, et deux
  /// tronçons portant le même intitulé donneraient deux sections, ce qui est la
  /// bonne lecture d'un serveur qui les a séparés. `null` partout = pas de
  /// titres, la liste plate d'avant.
  final String? groupLabel;
}

/// Un tracé que la feuille des couches propose de masquer ou d'afficher.
///
/// Rien d'un DTO : un identifiant (celui du `PdlMapTrack` qu'il commande), un
/// libellé **déjà localisé** et la couleur du trait, que l'appelant tire de
/// `kMultiTrackPalette`.
@immutable
class PdlMapTrackToggle {
  const PdlMapTrackToggle({
    required this.id,
    required this.label,
    required this.color,
    required this.visible,
  });

  final String id;
  final String label;
  final Color color;
  final bool visible;
}

/// Un interrupteur de plus dans la feuille des couches, sous l'ombrage : un
/// mode de la carte que l'écran pilote (le vent sur le tracé d'un groupe).
///
/// Comme l'ombrage, il ne referme pas la feuille. L'écran reste la source de
/// vérité ; [label] arrive déjà traduit.
@immutable
class PdlMapHeroSwitch {
  const PdlMapHeroSwitch({
    required this.id,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  /// Identité stable : elle nomme la clé de la ligne (`pdlMapHeroSwitch_<id>`).
  final String id;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
}

/// Les libellés du hero. `core/pdl` ne traduit rien : l'écran les fournit.
@immutable
class PdlMapHeroLabels {
  const PdlMapHeroLabels({
    required this.enterFullscreen,
    required this.exitFullscreen,
    required this.chooseBackground,
    required this.backgroundSheetTitle,
    this.hillshade,
    this.tracks,
  });

  final String enterFullscreen;
  final String exitFullscreen;
  final String chooseBackground;
  final String backgroundSheetTitle;

  /// L'intitulé de l'interrupteur d'ombrage. `null` = l'app de cet écran n'en
  /// propose pas, la ligne n'est pas rendue.
  final String? hillshade;

  /// L'intitulé de la section des tracés à cocher. `null` = pas de section,
  /// même si des [PdlMapHero.trackToggles] sont fournis.
  final String? tracks;
}

/// La coquille d'une carte occupant une surface, avec ses
/// commandes.
///
/// Elle tient trois promesses du brief §5 :
///
/// 1. une barre système accordée au thème **dès qu'une carte est en fond** —
///    l'heure et la batterie en noir sur une tuile sombre était le défaut de la
///    maquette 13 ;
/// 2. **aucun voile** sur la tuile : celui du haut assombrissait chaque carte,
///    encastrée comme plein écran, pour une barre système qui se lit très bien
///    sans lui, et celui du bas n'avait plus d'appelant ;
/// 3. plein écran (« Agrandir », « Fermer ») et sélecteur de fond, tous à
///    44 px.
///
/// ## Le plein écran est **une page de l'appelant**, pas une copie du hero
///
/// [fullscreenBuilder] construit la page, et l'écran y reconstruit son propre
/// hero (`isFullscreen: true`). Le hero ne se recopie pas lui-même dans la
/// route, et c'est la seule forme qui marche :
///
/// * une `MaterialPageRoute` n'appelle son constructeur **qu'une fois**, donc
///   une copie prise à la poussée y reste figée ;
/// * republier la copie depuis l'écran ne sauve rien, parce qu'une route
///   opaque éteint le `TickerMode` de tout ce qu'elle recouvre et que
///   **Riverpod met alors en pause les `ref.watch` de l'écran** (`Consumer`
///   « will temporarily stop listening to providers when the widget stops
///   being visible »). L'écran masqué ne se reconstruit plus : il n'a plus
///   rien à republier, et ne repart qu'au `pop`.
///
/// La page, elle, est visible : ses providers sont vivants, et choisir un fond
/// y change la carte tout de suite. Elle rend aussi [pill], [floatingCard] et
/// [foreground], que la copie laissait silencieusement au bord de la route.
///
/// ## Les zones de la carte (ledger `docs/LEDGER_*.md MOB-129`)
///
/// L'ordre est fixe, d'une carte à l'autre :
///
/// * **en haut à gauche**, en plein écran seulement : « Fermer »
///   (`PdlIcons.close`, libellé [PdlMapHeroLabels.exitFullscreen]) ;
/// * **en haut au centre** : [pill], qui s'écarte en plein écran de la largeur
///   de « Fermer », des deux côtés pour rester centrée ;
/// * **en bas à droite** : la colonne de boutons — « Agrandir » hors plein
///   écran, Calques (sauf sur une [vignette]), puis [extraButtons] —, posée
///   au-dessus du crédit ⓘ ;
/// * **en bas** : [bottomLayer] et [floatingCard], dont la hauteur est
///   **mesurée**. La place qu'ils prennent — ou [bottomInset], s'il est plus
///   grand — est publiée par [PdlMapBottomInset] autour de [mapBuilder] :
///   l'échelle et le crédit, que la carte rend sous toutes les couches du
///   hero, se posent au-dessus, et la colonne au-dessus du crédit.
class PdlMapHero extends StatefulWidget {
  const PdlMapHero({
    super.key,
    required this.mapBuilder,
    required this.labels,
    this.height,
    this.styles = const <PdlMapStyleOption>[],
    this.selectedStyleId,
    this.onStyleSelected,
    this.hillshadeEnabled,
    this.onHillshadeChanged,
    this.switches = const <PdlMapHeroSwitch>[],
    this.trackToggles = const <PdlMapTrackToggle>[],
    this.onTrackVisibilityChanged,
    this.showFullscreenButton = true,
    this.fullscreenBuilder,
    this.tapOpensFullscreen = false,
    this.extraButtons = const <Widget>[],
    this.pill,
    this.floatingCard,
    this.bottomLayer,
    this.bottomInset = 0,
    this.vignette = false,
    this.foreground,
    this.isFullscreen = false,
  }) : assert(
         !showFullscreenButton || isFullscreen || fullscreenBuilder != null,
         'Un bouton plein écran sans fullscreenBuilder : la page ne pourrait '
         'relire ni son fond ni ses tracés, puisque Riverpod met en pause '
         "l'écran qu'elle recouvre. Passez fullscreenBuilder, ou "
         'showFullscreenButton: false.',
       ),
       assert(bottomInset >= 0, 'bottomInset se compte depuis le bas : ≥ 0.');

  /// Construit la carte elle-même — typiquement un `PdlMap`.
  final WidgetBuilder mapBuilder;

  final PdlMapHeroLabels labels;

  /// Hauteur imposée. `null` = la carte prend la place disponible.
  final double? height;

  /// Les fonds servis, **dans l'ordre servi**. Vide = pas de sélecteur.
  final List<PdlMapStyleOption> styles;
  final String? selectedStyleId;
  final ValueChanged<String>? onStyleSelected;

  /// L'état de l'ombrage du relief. `null` = le déploiement ne sert aucune
  /// source d'élévation (`ConfigDto.terrain`), et l'interrupteur disparaît —
  /// plutôt qu'un réglage sans effet.
  final bool? hillshadeEnabled;
  final ValueChanged<bool>? onHillshadeChanged;

  /// Les interrupteurs de mode, rendus sous l'ombrage. Vide = aucun.
  final List<PdlMapHeroSwitch> switches;

  /// Les tracés à cocher, **dans l'ordre de la carte**. Moins de deux = pas de
  /// section : masquer l'unique tracé d'une carte n'a pas de sens.
  final List<PdlMapTrackToggle> trackToggles;

  /// Une case cochée ou décochée : l'identifiant du tracé et sa visibilité
  /// voulue. L'écran reste la source de vérité et filtre ses `PdlMapTrack`.
  final void Function(String id, bool visible)? onTrackVisibilityChanged;

  /// Hors plein écran : « Agrandir », dans la colonne. En plein écran :
  /// « Fermer », en haut à gauche.
  final bool showFullscreenButton;

  /// Construit le **contenu de la page plein écran**, typiquement l'écran
  /// lui-même en variante plein écran. Il doit relire ses sources : il est le
  /// seul à être encore visible, donc le seul dont les providers vivent.
  ///
  /// Le hero l'enveloppe d'un `Scaffold` et le pousse en route opaque.
  final WidgetBuilder? fullscreenBuilder;

  /// Vrai : un toucher **n'importe où sur la carte encastrée** ouvre le plein
  /// écran, comme son bouton. Pour une vignette qui ne se manipule pas et
  /// n'a rien à toucher (la carte de l'onglet Météo d'un groupe) : une couche
  /// transparente passe au-dessus de la vue native, sous les boutons, et lui
  /// prend le toucher — un tap seulement, le défilement de la page n'est pas
  /// disputé. Elle laisse passer ce que la carte enveloppe d'un
  /// [PdlMapTapPassThrough] : le crédit ⓘ des tuiles, que les licences veulent
  /// accessible d'un toucher. Sans effet en plein écran ou sans
  /// [fullscreenBuilder]. Les lecteurs d'écran ont déjà le bouton : la couche
  /// ne s'y annonce pas.
  final bool tapOpensFullscreen;

  /// La clé de cette couche, pour les tests.
  static const Key tapTargetKey = ValueKey<String>('pdlMapHeroTapTarget');

  /// Boutons ajoutés sous les boutons standards — « autour de moi »,
  /// recentrage. Rendus aussi sur une [vignette] : c'est l'écran qui les pose.
  final List<Widget> extraButtons;

  /// Pilule posée en haut au centre — « Rechercher dans cette zone ».
  final Widget? pill;

  /// Carte flottante posée en bas, à la sélection : à 12 px des bords, au-dessus
  /// de la zone sûre en plein écran. Sa hauteur est mesurée, et la ligne du bas
  /// se pose au-dessus ([PdlMapBottomInset]).
  final Widget? floatingCard;

  /// Le calque du bas de la carte — l'interrupteur de mode, la légende du
  /// vent. Posé comme [floatingCard] (12 px des bords, zone sûre en plein
  /// écran, pleine largeur : son contenu choisit son alignement) et mesuré de
  /// même. Il ne remonte **pas** avec [bottomInset].
  final Widget? bottomLayer;

  /// Ce qui occupe le bas de la carte **hors du hero**, compté depuis son bord
  /// bas : la feuille à crans de la fiche parcours. Combiné aux mesures de
  /// [bottomLayer] et [floatingCard] par le **plus grand**, pas la somme : tous
  /// se comptent depuis le même bord, et ce qui passe sous une feuille est
  /// caché par elle. `0` : rien.
  final double bottomInset;

  /// Vrai pour une vignette encastrée, qui ne se manipule pas : la colonne n'y
  /// garde qu'« Agrandir » (et les [extraButtons]) — fond, ombrage, tracés et
  /// Météo se règlent en plein écran. Sans effet en plein écran.
  final bool vignette;

  /// Contenu libre posé au-dessus de tout (barre superposée, titre) — sauf
  /// « Fermer », qui reste toujours touchable.
  final Widget? foreground;

  /// Vrai dans la page plein écran : « Agrandir » y devient « Fermer ».
  final bool isFullscreen;

  /// Vrai si le contexte est celui de la carte **plein écran**.
  ///
  /// [mapBuilder] est appelé dans les deux, et une carte encastrée dans une
  /// liste ne se pilote pas comme une carte plein écran : la première doit
  /// laisser le doigt au défilement de la page, la seconde est là pour être
  /// manipulée. Sans ce témoin, l'appelant ne peut pas faire la différence.
  static bool isFullscreenOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_PdlMapHeroScope>()
          ?.isFullscreen ??
      false;

  /// Ouvre le plein écran du hero qui encadre [context], comme son bouton —
  /// pour ce que la carte rend elle-même et qui, sur la vignette encastrée,
  /// doit y mener plutôt qu'à sa propre action (une pastille météo, ledger
  /// `MOB-107`). Lu **au moment du toucher** : la page poussée est celle du
  /// hero tel qu'il est alors. Sans effet en plein écran, sans
  /// [fullscreenBuilder] ou hors d'un [PdlMapHero].
  static void openFullscreen(BuildContext context) => context
      .getInheritedWidgetOfExactType<_PdlMapHeroScope>()
      ?.openFullscreen
      ?.call();

  @override
  State<PdlMapHero> createState() => _PdlMapHeroState();
}

class _PdlMapHeroState extends State<PdlMapHero> {
  /// Les hauteurs relevées de [PdlMapHero.bottomLayer] et
  /// [PdlMapHero.floatingCard], zone sûre comprise ; `0` tant qu'elles ne le
  /// sont pas.
  double _bottomLayerHeight = 0;
  double _floatingCardHeight = 0;

  /// La marge entre les bords de la carte et ce que le hero y pose.
  static const double _edge = PdlSpacing.sectionTightV;

  /// Ce qui sépare la colonne du crédit ⓘ qu'elle surplombe, et la pilule de
  /// « Fermer ».
  static const double _gap = PdlSpacing.chipGap;

  @override
  void didUpdateWidget(PdlMapHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Un occupant retiré ne prend plus de place ; revenu, il sera remesuré.
    if (widget.bottomLayer == null) _bottomLayerHeight = 0;
    if (widget.floatingCard == null) _floatingCardHeight = 0;
  }

  /// Vrai quand l'ombrage du relief est proposable : une source servie, un
  /// intitulé et de quoi prévenir l'écran.
  bool get _hasHillshade =>
      widget.hillshadeEnabled != null &&
      widget.onHillshadeChanged != null &&
      widget.labels.hillshade != null;

  /// Vrai quand la feuille porte une section de tracés à cocher.
  bool get _hasTrackToggles =>
      widget.trackToggles.length > 1 &&
      widget.onTrackVisibilityChanged != null &&
      widget.labels.tracks != null;

  /// Vrai quand la feuille des couches a quelque chose à régler.
  bool get _hasLayers =>
      (widget.styles.isNotEmpty && widget.onStyleSelected != null) ||
      _hasHillshade ||
      widget.switches.isNotEmpty ||
      _hasTrackToggles;

  /// La place qu'occupe le bas de la carte, depuis son bord bas : le plus
  /// haut des occupants mesurés (hauteur + marge), ou l'occupant externe.
  double get _bottomInset {
    double occupied(Widget? occupant, double height) =>
        occupant == null || height == 0 ? 0 : height + _edge;
    return math.max(
      widget.bottomInset,
      math.max(
        occupied(widget.bottomLayer, _bottomLayerHeight),
        occupied(widget.floatingCard, _floatingCardHeight),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget stack = _buildStack(context);
    final Widget sized = widget.height == null
        ? stack
        : SizedBox(height: widget.height, child: stack);

    // Sans voile, la barre système se lit sur la tuile elle-même : le fond
    // suit le thème (là où il a une variante nocturne), les icônes aussi.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: sized,
    );
  }

  Widget _buildStack(BuildContext context) {
    final PdlMapHero w = widget;
    final bool fullscreen = w.isFullscreen;
    final bool showClose = w.showFullscreenButton && fullscreen;
    final double inset = _bottomInset;

    final List<Widget> buttons = <Widget>[
      if (w.showFullscreenButton && !fullscreen)
        PdlMapButton(
          icon: PdlIcons.fullscreen,
          semanticLabel: w.labels.enterFullscreen,
          onPressed: () => _toggleFullscreen(context),
        ),
      // Une vignette ne se règle pas : Calques attend le plein écran.
      if (_hasLayers && (fullscreen || !w.vignette))
        PdlMapButton(
          icon: PdlIcons.layers,
          semanticLabel: w.labels.chooseBackground,
          onPressed: () => _openStyleSheet(context),
        ),
      ...w.extraButtons,
    ];

    // La colonne surplombe le crédit ⓘ, qui se pose lui-même au plus haut de
    // la zone sûre et de l'inset (`PdlMapBottomInset.safeArea`). La place du
    // crédit est réservée même quand il n'est pas rendu : il n'apparaît qu'au
    // chargement du style, et la colonne ne doit pas sauter à ce moment-là.
    final double columnBottom =
        math.max(MediaQuery.paddingOf(context).bottom, inset) +
        PdlMapBottomInset.rowPadding +
        PdlMapBottomInset.creditExtent +
        _gap;

    // En plein écran, la pilule laisse la largeur de « Fermer » — des deux
    // côtés, pour rester centrée.
    final double pillSide = showClose
        ? _edge + PdlMetrics.tapTarget + _gap
        : PdlSpacing.sectionTightH;

    // L'hôte est posé même sans couche de toucher : la forme de l'arbre ne
    // dépend pas de [tapOpensFullscreen], et basculer celui-ci ne recrée pas
    // la vue native de la carte.
    return _TapPassThroughHost(
      builder: (_TapPassThroughs regions) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // La carte d'abord, toujours enveloppée de la même façon : un
          // enveloppement conditionnel recréerait la vue native.
          _PdlMapHeroScope(
            isFullscreen: fullscreen,
            openFullscreen: !fullscreen && w.fullscreenBuilder != null
                ? () => _toggleFullscreen(context)
                : null,
            child: PdlMapBottomInset(
              value: inset,
              child: Builder(builder: w.mapBuilder),
            ),
          ),
          if (w.tapOpensFullscreen &&
              !fullscreen &&
              w.fullscreenBuilder != null)
            Positioned.fill(
              child: _PassThroughHitTest(
                regions: regions,
                child: GestureDetector(
                  key: PdlMapHero.tapTargetKey,
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: () => _toggleFullscreen(context),
                ),
              ),
            ),
          if (w.pill != null)
            Positioned(
              left: pillSide,
              right: pillSide,
              top: _edge,
              child: Align(child: w.pill),
            ),
          if (buttons.isNotEmpty)
            Positioned(
              right: _edge,
              bottom: columnBottom,
              child: PdlMapButtonColumn(children: buttons),
            ),
          if (w.floatingCard != null)
            _bottomOccupant(
              fullscreen: fullscreen,
              onHeight: (double h) => _setHeight(h, card: true),
              child: w.floatingCard!,
            ),
          if (w.bottomLayer != null)
            _bottomOccupant(
              fullscreen: fullscreen,
              onHeight: (double h) => _setHeight(h, card: false),
              child: w.bottomLayer!,
            ),
          ?w.foreground,
          // En dernier : la sortie du plein écran reste touchable quoi que
          // l'écran pose au-dessus de la carte.
          if (showClose)
            Positioned(
              left: _edge,
              top: _edge,
              child: SafeArea(
                right: false,
                bottom: false,
                child: PdlMapButton(
                  icon: PdlIcons.close,
                  semanticLabel: w.labels.exitFullscreen,
                  onPressed: () => _toggleFullscreen(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Un occupant du bas : à [_edge] des bords, au-dessus de la zone sûre en
  /// plein écran (la page plein écran la laisse au hero), et mesuré — zone
  /// sûre comprise, puisque l'inset se compte depuis le bord de la carte.
  Widget _bottomOccupant({
    required bool fullscreen,
    required ValueChanged<double> onHeight,
    required Widget child,
  }) => Positioned(
    left: _edge,
    right: _edge,
    bottom: _edge,
    child: _MeasureHeight(
      onHeight: onHeight,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: fullscreen,
        child: child,
      ),
    ),
  );

  void _setHeight(double height, {required bool card}) {
    if (!mounted) return;
    final double current = card ? _floatingCardHeight : _bottomLayerHeight;
    if (current == height) return;
    setState(() {
      if (card) {
        _floatingCardHeight = height;
      } else {
        _bottomLayerHeight = height;
      }
    });
  }

  void _toggleFullscreen(BuildContext context) {
    if (widget.isFullscreen) {
      Navigator.of(context).maybePop();
      return;
    }
    final WidgetBuilder? builder = widget.fullscreenBuilder;
    if (builder == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        // La barre système reste hors de la carte : sans voile, elle se lirait
        // mal sur une tuile. Le bas, lui, reste au hero, qui pose ses
        // occupants au-dessus de la zone sûre.
        builder: (BuildContext context) => Scaffold(
          body: SafeArea(bottom: false, child: Builder(builder: builder)),
        ),
      ),
    );
  }

  Future<void> _openStyleSheet(BuildContext context) async {
    final PdlMapHero w = widget;
    final PdlColors c = context.pdl;
    // Par `PdlSheet` et non par `showModalBottomSheet` : c'est la règle du
    // C5, et elle vaut aussi pour la bibliothèque elle-même.
    final String? picked = await PdlSheet.show<String>(
      context: context,
      builder: (BuildContext sheetContext) => PdlSheet(
        title: w.labels.backgroundSheetTitle,
        children: <Widget>[
          // **Dans l'ordre servi** : le serveur classe ses fonds, le client
          // ne re-trie pas.
          for (final (int i, PdlMapStyleOption style)
              in w.styles.indexed) ...<Widget>[
            if (style.groupLabel != null &&
                (i == 0 || style.groupLabel != w.styles[i - 1].groupLabel))
              Padding(
                padding: const EdgeInsets.only(top: PdlSpacing.sectionTightV),
                child: PdlSectionHeader(title: style.groupLabel!),
              ),
            PdlSettingRow(
              title: style.label,
              onTap: () => Navigator.of(sheetContext).pop(style.id),
              trailing: style.id == w.selectedStyleId
                  ? Icon(PdlIcons.check, size: 20, color: c.primary)
                  : const SizedBox.shrink(),
            ),
          ],
          // Le relief est un réglage **du** fond, pas un choix **de** fond : il
          // vient après la liste et, contrairement à elle, ne referme pas la
          // feuille — on veut pouvoir juger de l'ombrage puis changer de fond.
          if (_hasHillshade)
            _SwitchRow(
              label: w.labels.hillshade!,
              initialValue: w.hillshadeEnabled!,
              onChanged: w.onHillshadeChanged!,
            ),
          for (final PdlMapHeroSwitch option in w.switches)
            _SwitchRow(
              key: ValueKey<String>('pdlMapHeroSwitch_${option.id}'),
              label: option.label,
              initialValue: option.value,
              onChanged: option.onChanged,
            ),
          // Les tracés se cochent comme l'ombrage se bascule : sans refermer
          // la feuille, pour en masquer plusieurs d'affilée.
          if (_hasTrackToggles) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(top: PdlSpacing.sectionTightV),
              child: PdlSectionHeader(title: w.labels.tracks!),
            ),
            for (final PdlMapTrackToggle track in w.trackToggles)
              _TrackToggleRow(
                key: ValueKey<String>('pdlMapTrackToggle_${track.id}'),
                track: track,
                onChanged: (bool visible) =>
                    w.onTrackVisibilityChanged!(track.id, visible),
              ),
          ],
        ],
      ),
    );
    if (picked != null) w.onStyleSelected?.call(picked);
  }
}

/// Relève la hauteur de son enfant et la remonte **après** l'image : la mise
/// en page ne dépend jamais de la valeur qu'elle produit, donc pas de boucle.
/// Rien n'est remonté tant que la hauteur ne change pas.
class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  _RenderMeasureHeight createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureHeight renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final double height = size.height;
    if (height == _reported) return;
    _reported = height;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (attached) onHeight(height);
    });
  }
}

/// Une ligne à interrupteur de la feuille des fonds : « Ombrage du relief »,
/// ou un [PdlMapHeroSwitch].
///
/// Elle tient son propre état parce que la feuille est construite une fois :
/// `PdlSheet` n'est pas reconstruit quand l'écran l'est, si bien qu'un
/// interrupteur piloté seulement par la propriété resterait figé dans sa
/// position d'origine jusqu'à la fermeture. L'écran reste la source de vérité —
/// il reçoit le changement et le persiste ; ce témoin local n'est que l'écho
/// immédiat que la feuille doit à celui qui vient d'appuyer.
class _SwitchRow extends StatefulWidget {
  const _SwitchRow({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  final String label;
  final bool initialValue;
  final ValueChanged<bool> onChanged;

  @override
  State<_SwitchRow> createState() => _SwitchRowState();
}

class _SwitchRowState extends State<_SwitchRow> {
  late bool _value = widget.initialValue;

  void _toggle() {
    setState(() => _value = !_value);
    widget.onChanged(_value);
  }

  @override
  Widget build(BuildContext context) => PdlSettingRow(
    title: widget.label,
    onTap: _toggle,
    trailing: PdlSwitch(
      value: _value,
      // La ligne entière est déjà une cible tactile de 44 px ; l'interrupteur
      // n'en ouvre pas une seconde qui ferait diverger les deux états.
      onChanged: (bool _) => _toggle(),
      semanticLabel: widget.label,
    ),
  );
}

/// Une ligne de la section des tracés : le trait de couleur, le nom, la case.
///
/// État local pour la même raison que [_SwitchRow] : la feuille n'est pas
/// reconstruite quand l'écran l'est.
class _TrackToggleRow extends StatefulWidget {
  const _TrackToggleRow({
    super.key,
    required this.track,
    required this.onChanged,
  });

  final PdlMapTrackToggle track;
  final ValueChanged<bool> onChanged;

  @override
  State<_TrackToggleRow> createState() => _TrackToggleRowState();
}

class _TrackToggleRowState extends State<_TrackToggleRow> {
  late bool _visible = widget.track.visible;

  void _toggle() {
    setState(() => _visible = !_visible);
    widget.onChanged(_visible);
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    return PdlSettingRow(
      title: widget.track.label,
      leading: PdlColorTrack(
        color: widget.track.color,
        shape: PdlColorTrackShape.legend,
      ),
      onTap: _toggle,
      trailing: Semantics(
        label: widget.track.label,
        checked: _visible,
        child: ExcludeSemantics(
          child: Checkbox(
            value: _visible,
            activeColor: c.primary,
            // La ligne entière est la cible : la case n'en ouvre pas une
            // seconde.
            onChanged: (bool? _) => _toggle(),
          ),
        ),
      ),
    );
  }
}

/// Porte [PdlMapHero.isFullscreenOf] et [PdlMapHero.openFullscreen]
/// jusqu'au `mapBuilder`.
class _PdlMapHeroScope extends InheritedWidget {
  const _PdlMapHeroScope({
    required this.isFullscreen,
    required this.openFullscreen,
    required super.child,
  });

  final bool isFullscreen;

  /// Pousse le plein écran ; `null` en plein écran ou sans page à pousser.
  /// Lu sans dépendance, au toucher : pas de notification à son changement.
  final VoidCallback? openFullscreen;

  @override
  bool updateShouldNotify(_PdlMapHeroScope oldWidget) =>
      oldWidget.isFullscreen != isFullscreen;
}

/// Une zone de la carte que la couche [PdlMapHero.tapOpensFullscreen] laisse
/// passer : un toucher qui y tombe va à [child], pas au plein écran.
///
/// La couche est posée au-dessus de tout le `mapBuilder`, donc de ce que la
/// carte rend elle-même ; sans ce passe-droit, le crédit ⓘ des tuiles
/// (`PdlMapAttribution`) ouvrirait le plein écran au lieu de se déplier. La
/// zone suit [child] où qu'il soit et quelle que soit sa taille (crédits
/// dépliés compris). Hors d'un [PdlMapHero], ou sans couche, sans effet.
class PdlMapTapPassThrough extends StatefulWidget {
  const PdlMapTapPassThrough({super.key, required this.child});

  final Widget child;

  @override
  State<PdlMapTapPassThrough> createState() => _PdlMapTapPassThroughState();
}

class _PdlMapTapPassThroughState extends State<PdlMapTapPassThrough> {
  _TapPassThroughs? _regions;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final _TapPassThroughs? regions = context
        .dependOnInheritedWidgetOfExactType<_TapPassThroughScope>()
        ?.regions;
    if (identical(regions, _regions)) return;
    _regions?.zones.remove(this);
    _regions = regions?..zones.add(this);
  }

  @override
  void dispose() {
    _regions?.zones.remove(this);
    super.dispose();
  }

  /// Vrai si [global] tombe sur ce qui est rendu ici.
  bool _contains(Offset global) {
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    return box.size.contains(box.globalToLocal(global));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Les zones [PdlMapTapPassThrough] d'un hero.
class _TapPassThroughs {
  final Set<_PdlMapTapPassThroughState> zones = <_PdlMapTapPassThroughState>{};

  bool contains(Offset global) =>
      zones.any((_PdlMapTapPassThroughState z) => z._contains(global));
}

/// Garde les zones d'un hero d'un build à l'autre.
class _TapPassThroughHost extends StatefulWidget {
  const _TapPassThroughHost({required this.builder});

  final Widget Function(_TapPassThroughs regions) builder;

  @override
  State<_TapPassThroughHost> createState() => _TapPassThroughHostState();
}

class _TapPassThroughHostState extends State<_TapPassThroughHost> {
  final _TapPassThroughs _regions = _TapPassThroughs();

  @override
  Widget build(BuildContext context) =>
      _TapPassThroughScope(regions: _regions, child: widget.builder(_regions));
}

class _TapPassThroughScope extends InheritedWidget {
  const _TapPassThroughScope({required this.regions, required super.child});

  final _TapPassThroughs regions;

  @override
  bool updateShouldNotify(_TapPassThroughScope oldWidget) =>
      !identical(oldWidget.regions, regions);
}

/// Refuse le toucher qui tombe sur une zone [PdlMapTapPassThrough] : le test
/// passe alors aux couches du dessous, jusqu'à la zone elle-même.
class _PassThroughHitTest extends SingleChildRenderObjectWidget {
  const _PassThroughHitTest({required this.regions, super.child});

  final _TapPassThroughs regions;

  @override
  _RenderPassThroughHitTest createRenderObject(BuildContext context) =>
      _RenderPassThroughHitTest(regions);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPassThroughHitTest renderObject,
  ) => renderObject.regions = regions;
}

class _RenderPassThroughHitTest extends RenderProxyBox {
  _RenderPassThroughHitTest(this.regions);

  _TapPassThroughs regions;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (regions.contains(localToGlobal(position))) return false;
    return super.hitTest(result, position: position);
  }
}
