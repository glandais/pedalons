# `core/pdl` — la bibliothèque de composants Pédalons

Point d'entrée unique : `import 'package:pedalons/core/pdl/pdl.dart';`.

Cette bibliothèque n'est pas un dossier de widgets partagés de plus. Elle a un
contrat propre, et ce contrat est vérifiable en revue. Un widget qui ne peut pas
le tenir ne vit pas ici : il vit dans son *feature*, sans préfixe `Pdl`.

## Le contrat

### 1. Jetons obligatoires — aucun littéral de couleur

Toute couleur vient de `context.pdl` (`PdlColors`), toute mesure de
`PdlSpacing` / `PdlRadii` / `PdlMetrics`, tout style de texte de
`context.pdlText` (`PdlTypography`), toute durée de `PdlMotion`, toute icône de
`PdlIcons`.

Aucun `Color(0xFF…)`, aucun `Colors.red`, aucun `TextStyle(fontSize: 15)` posé à
la main. La seule exception tolérée est `Colors.transparent` — et encore, on lui
préfère `MaterialType.transparency` ou une couleur nulle, ce que fait le code
actuel.

Corollaire : **les deux modes marchent par construction**. Un composant qui lit
ses jetons n'a rien de spécial à faire pour le mode sombre. Les rares endroits
où le mode change la *forme* et pas seulement la teinte — l'ombre de la pastille
du segmenté, qui devient une bordure — passent par `PdlShadows.*(brightness)` et
sont commentés sur place.

### 2. Cible tactile 44 px

Aucune action ne descend sous `PdlMetrics.tapTarget`. Cela vaut pour les tailles
compactes : `PdlButton(size: sm)` compacte la typographie et les gouttières,
**jamais la cible**. Quand la charte impose un visuel plus petit que 44 — la
pastille de 34 px de `PdlChip`, le rail de 28 px de `PdlSwitch` — le visuel est
centré dans une boîte de 44.

Un test de `test/core/pdl/` mesure `PdlChip`, `PdlButton(size: sm)`,
`PdlSettingRow` et `PdlSegmented`. Ajoutez-y tout nouveau composant actionnable.

### 3. Aucune importation de `api/generated`

`core/pdl` ne connaît aucun DTO. Un composant qui a besoin d'une teinte métier
prend un `PdlTone` en paramètre ; c'est l'appelant qui traduit son enum via
`tone(PdlColors)` (`core/theme/enum_colors.dart`). Un composant qui a besoin
d'un libellé le prend en `String` : **`core/pdl` ne traduit rien**, les clés de
localisation appartiennent aux écrans.

> `core/theme/enum_colors.dart` importe bien `api/generated`, mais il vit dans
> `core/theme`. La frontière passe par le répertoire, et elle tient.

### Les deux `grep` de revue

```bash
grep -rn --include='*.dart' "api/generated" mobile/lib/core/pdl   # doit rester vide
grep -rn --include='*.dart' '\bIcons\.'     mobile/lib/core/pdl   # doit rester vide
```

Deux précisions sur la forme de ces commandes, qui ne changent rien à la règle :

* `--include='*.dart'` écarte ce fichier-ci, qui cite forcément les deux motifs
  qu'il interdit ;
* `\bIcons\.` et non `Icons\.` : sans la limite de mot, le motif attrape
  `PdlIcons.` — c'est-à-dire exactement l'usage conforme.

Le second `grep` impose le passage par `PdlIcons`, seul fichier de l'app
autorisé à nommer `Icons.*` — basculer un jour de Material outline vers Tabler
ne doit toucher qu'un fichier.

## Noms

Les noms sont tranchés (plan v2 §1.0.3-3) et **les alias sont interdits** :

| Retenu | Interdits |
|---|---|
| `PdlButton(variant:)` | `PdlTextButton`, `PdlTextAction`, `PdlLoadingButton` |
| `PdlProgressBar` | `PdlSeatsBar` |
| `PdlColorTrack` | `PdlGroupTrack` |
| `PdlThumb` | `PdlThumbnail` |
| `PdlCardMedia` | `PdlMediaHeader` |
| `PdlPinnedToolbar` | `PdlStickyToolbar` |
| `PdlSettingRow` | `PdlNavRow` |
| `PdlBottomTabs` | `PdlTabBar` |

## Vague A — les 20 primitives livrées

| # | Widget | Fichier |
|---|---|---|
| A1 | `PdlSkeleton` | `pdl_skeleton.dart` |
| A2 | `PdlBadge` | `pdl_badge.dart` |
| A3 | `PdlButton` | `pdl_button.dart` |
| A4 | `PdlAvatar` | `pdl_avatar.dart` |
| A5 | `PdlCard` | `pdl_card.dart` |
| A6 | `PdlStat` | `pdl_stat.dart` |
| A7 | `PdlStatRow` | `pdl_stat_row.dart` |
| A8 | `PdlProgressBar` | `pdl_progress_bar.dart` |
| A9 | `PdlColorTrack` | `pdl_color_track.dart` |
| A10 | `PdlNumberPill` | `pdl_number_pill.dart` |
| A11 | `PdlChip` | `pdl_chip.dart` |
| A12 | `PdlSearchField` | `pdl_search_field.dart` |
| A13 | `PdlSectionHeader` | `pdl_section_header.dart` |
| A14 | `PdlSegmented` | `pdl_segmented.dart` |
| A15 | `PdlSwitch` | `pdl_switch.dart` |
| A16 | `PdlInfoLine` | `pdl_info_line.dart` |
| A17 | `PdlSettingRow` | `pdl_setting_row.dart` |
| A18 | `PdlScrim` | `pdl_scrim.dart` |
| A19 | `PdlBlurSurface` | `pdl_blur_surface.dart` |
| A20 | `PdlFilterButton` | `pdl_filter_button.dart` |

Un fichier par widget, une entrée par fichier dans `pdl.dart`.

## Vague B — les 26 composés livrés

| # | Widget | Fichier |
|---|---|---|
| B1 | `PdlChipRow` | `pdl_chip_row.dart` |
| B2 | `PdlAvatarStack` | `pdl_avatar_stack.dart` |
| B3 | `PdlTeamLine` | `pdl_team_line.dart` |
| B4 | `PdlPlaceRow` | `pdl_place_row.dart` |
| B5 | `PdlThumb` | `pdl_thumb.dart` |
| B6 | `PdlCardMedia` | `pdl_card_media.dart` |
| B7 | `PdlEmptyState` | `pdl_empty_state.dart` |
| B8 | `PdlBanner` | `pdl_banner.dart` |
| B9 | `PdlPagedListFooter` | `pdl_paged_list_footer.dart` |
| B10 | `PdlPersonRow` | `pdl_person_row.dart` |
| B11 | `PdlAttachmentRow` | `pdl_attachment_row.dart` |
| B12 | `PdlLegendRow` | `pdl_legend_row.dart` |
| B13 | `PdlClimbRow` | `pdl_climb_row.dart` |
| B14 | `PdlStatCellRow` | `pdl_stat_cell_row.dart` |
| B15 | `PdlAvatarEditor` | `pdl_avatar_editor.dart` |
| B16 | `PdlDangerZone` | `pdl_danger_zone.dart` |
| B17 | `PdlRangeFilter` | `pdl_range_filter.dart` |
| B18 | `PdlGalleryDots` | `pdl_gallery_dots.dart` |
| B19 | `PdlPriceBlock` | `pdl_price_block.dart` |
| B20 | `PdlBadgeStack` | `pdl_badge_stack.dart` |
| B21 | `PdlSkeletonCard` | `pdl_skeleton_card.dart` |
| B22 | `PdlDeadEndEmpty` | `pdl_dead_end_empty.dart` |
| B23 | `PdlScopeSelector` | `pdl_scope_selector.dart` |
| B24 | `PdlMarkdownBody` | `pdl_markdown_body.dart` |
| B25 | `PdlImageViewer` | `pdl_image_viewer.dart` |
| B26 | `PdlMonthGrid` + `PdlDayHeader` | `pdl_month_grid.dart` |

Quatre d'entre eux **remplacent** un widget existant, qui n'est plus qu'une
façade portant ce que `core/pdl` ne peut pas connaître — un DTO, une route, une
clé de traduction : `core/widgets/team_banner.dart` (B3),
`core/pagination/paged_list_footer.dart` (B9),
`core/widgets/markdown_content.dart` (B24) et `RoutesEmptyState` de
`features/routes/.../routes_page.dart` (B22). `PdlEmptyState` et
`PdlDeadEndEmpty` composent, eux, `core/animations/animated_empty_state.dart`.

Quatre écarts assumés à la charte, documentés sur place :

* **`PdlTeamLine` mesure 24 px** et non 44 (`.teamline { min-height: 24px }`) :
  c'est un lien inline dans une carte déjà tappable en entier. `minHeight` le
  remonte là où il est seul.
* **`PdlBanner(warn)` emploie la paire `warning`** et non l'orange `#fff4e6` de
  la planche : seule la paire sémantique est définie dans les deux modes.
* **`PdlAvatarEditor` ne sélectionne pas l'image** : `image_picker` demande une
  permission et produit des erreurs à traduire, deux choses qui appartiennent à
  l'écran. Le widget expose `onPick`.
* **`PdlMarkdownBody` lit le jeton d'accès** pour son image d'article : les
  images de contenu sont servies derrière l'API, et la visionneuse plein écran
  a besoin d'un `ImageProvider` authentifié. C'est le prolongement de
  `AuthenticatedImage`, déjà employé là depuis la vague B. Ce qui ne bouge pas :
  **aucun import de `api/generated`**, et **rien n'y est traduit** —
  `codeCopiedLabel` et `imageCloseLabel` sont des `String` fournis par
  l'appelant, et le repli du second est `MaterialLocalizations`.

Ce que `PdlMarkdownBody` **ne fait pas** : ouvrir un lien. Il reçoit
`onLinkTap` ; sans lui, `markdown_widget` n'attache aucun
`TapGestureRecognizer` et le lien est stylé mais inerte — c'était le défaut
F-DE-6. La résolution (route interne, application externe, bandeau d'échec)
vit dans `core/utils/link_launcher.dart`, et `core/widgets/markdown_content.dart`
la branche. **Aucun écran ne doit instancier `PdlMarkdownBody` directement.**

## Vague C — les 10 coquilles d'écran livrées

| # | Widget | Fichier |
|---|---|---|
| C1 | `PdlAppBar` · `PdlAppBarAction` · `PdlSliverAppBar` | `pdl_app_bar.dart` |
| C2 | `PdlBottomTabs` · `PdlTabItem` | `pdl_bottom_tabs.dart` |
| C3 | `PdlPinnedToolbar` | `pdl_pinned_toolbar.dart` |
| C4 | `PdlActionBar` | `pdl_action_bar.dart` |
| C5 | `PdlSheet` · `PdlSheetHandle` | `pdl_sheet.dart` |
| C6 | `PdlFullSheet` | `pdl_full_sheet.dart` |
| C7 | `PdlDetentSheet` | `pdl_detent_sheet.dart` |
| C8 | `PdlScreenScaffold` | `pdl_screen_scaffold.dart` |
| C9 | `PdlStageRail` · `PdlStageRailItem` | `pdl_stage_rail.dart` |
| C10 | `PdlPrevNextNav` · `PdlPrevNextTarget` | `pdl_prev_next_nav.dart` |

`PdlBottomTabs` **remplace** la `NavigationBar` provisoire de
`core/adaptive/adaptive_scaffold.dart` ; la bascule vers `NavigationRail`
au-delà de 600 px est conservée telle quelle.

### La troisième règle de revue

```bash
grep -rn --include='*.dart' "showModalBottomSheet" mobile/lib   # seul pdl_sheet.dart
```

`PdlSheet.show()` force `useRootNavigator`, `isScrollControlled`,
`useSafeArea` et `barrierColor` — les quatre drapeaux dont l'oubli produisait
une feuille rendue sous la barre d'onglets et un « Trier par » écrasé à 1 pt.
Le `grep` ne renvoie plus que `pdl_sheet.dart:90` (et des commentaires) : les
trois écrans qui appelaient encore la fonction Material en direct
(`route_filter_sheet`, `route_detail_page`, `profile_page`) ont basculé.

Trois écarts assumés de la vague C, documentés sur place :

* **La hauteur des barres est un plancher, jamais un plafond** — 56 pour C1,
  52 pour C2, 64 pour C9 et C10 : à 130 % d'agrandissement typographique une
  hauteur figée rogne le libellé, c'est-à-dire la seule chose qui dit où l'on
  est. Seule C1, dont le contenu est une ligne unique, garde ses 56 px exacts.
* **Le bas de C2 et de C4 emploie l'inset système réel** et non les 22 px de la
  planche, qui *sont* l'inset présumé de l'appareil maquetté. C4 garde 22 pour
  plancher.
* **C3 mesure sa hauteur en deux temps** : le premier cadre emploie
  `estimatedExtent`, le suivant la hauteur relevée. Un `SliverPersistentHeader`
  demande ses extents avant de construire son enfant ; c'est le seul moyen de
  ne pas figer la valeur.

### Deux suppressions (F-CO-5)

* `core/widgets/safe_network_image.dart` — `SafeCircleAvatar` et
  `SafeDecorationImage` étaient des doublons **non authentifiés** de
  `AuthenticatedCircleAvatar` / `AuthenticatedImage`. Aucun appelant : seul le
  barrel `core/widgets/widgets.dart` les exportait.
* `SliverContentWidthConstraint` de
  `core/adaptive/content_width_constraint.dart` — il rendait son sliver tel
  quel dans un `SliverToBoxAdapter` : il ne contraignait rien et piégeait. La
  contrainte de 600 px passe désormais par
  `PdlScreenScaffold(constrainWidth: true)`.

## Hors vagues — livrés depuis

Exportés par `pdl.dart` comme le reste, et soumis au même contrat (jetons,
44 px, aucun DTO).

| Widget / type | Fichier | Rôle |
|---|---|---|
| `PdlRefresh` | `pdl_refresh.dart` | Le « tirer pour rafraîchir » de l'app, avec une secousse (`mediumImpact`) au relâchement au-delà du seuil |
| `PdlTag` · `PdlTagRow` · `PdlTagEntry` | `pdl_tag.dart` | Les tags d'équipe d'un contenu (ledger `MOB-39`) : contour neutre, pastille de la famille, libellé neutre — **jamais** la forme d'un badge, pour qu'un tag vert ne se lise pas « Publié ». Tronqué (« +n ») en carte, complet en fiche |
| `PdlWindArrow` | `pdl_wind_arrow.dart` | La flèche de vent, dessinée vers le haut puis tournée de l'angle reçu — vent relatif au sens de marche ou absolu, au choix de l'appelant ; toujours doublée d'un libellé |
| `PdlSegmentBar` · `PdlSegmentBarEntry` | `pdl_segment_bar.dart` | Une barre découpée en tronçons proportionnels — le vent le long d'un parcours, l'exposition au vent ; jamais seule, la couleur ne dit pas tout |

**`map/` — la carte Pédalons**, sans DTO : l'écran traduit ses DTO en types
`Pdl*` avant de les passer.

| Widget / type | Fichier | Rôle |
|---|---|---|
| `PdlMap` | `map/pdl_map.dart` | La carte (MapLibre) |
| `PdlMapController` · `PdlMapTrack` · `PdlMapPoint` · `PdlMapBox` · `PdlHillshade` · `PdlKmMarker` | `map/pdl_map_controller.dart` | Tracés, points, emprise, estompage, bornes kilométriques |
| `PdlMapMarker` · `PdlMapMarkerTarget` · `PdlMapBearing` | `map/pdl_map_marker.dart` | Marqueurs Flutter génériques (position + widget + libellé, égalité de valeur) posés dans un `WidgetLayer` de `PdlMap` ; cible de 44 px, toucher rendu par id — les pastilles météo du plein écran d'un groupe, `MOB-92`. Un marqueur reste droit quand la carte tourne : `PdlMapBearing.of(context)` donne le cap à son contenu, qu'une direction absolue (flèche de vent) retranche |
| `PdlMapHero` · `PdlMapStyleOption` · `PdlMapHeroSwitch` | `map/pdl_map_hero.dart` | La coquille d'une carte occupant une surface : voiles, plein écran, sélecteur de fond de carte et ses interrupteurs de mode |
| `PdlMapButton` · `PdlMapButtonColumn` · `PdlMapPill` · `PdlMapFloatingCard` | `map/pdl_map_buttons.dart` | Contrôles posés sur la carte, sur voile de lisibilité |
| `PdlMapAttribution` · `PdlMapCredit` | `map/pdl_map_attribution.dart` | Crédit des fournisseurs de tuiles |
| `PdlMapCamera` | `map/pdl_map_camera.dart` | Position de caméra et projection Web Mercator |
| — | `map/pdl_mass_layer.dart` | La couche de masse : tuiles vectorielles de parcours du backend (`?t=` jeton de tuiles) ; l'en-tête du fichier explique pourquoi le repli GeoJSON a disparu |

**`elevation/` — le profil altimétrique**, pur Dart côté données.

| Widget / type | Fichier | Rôle |
|---|---|---|
| `PdlElevationProfile` | `elevation/pdl_elevation_profile.dart` | Le profil, avec axe et info-bulle ; `barColors` (une couleur par barre, comparée par identité) remplace l'échelle de pente — le mode revêtement de la fiche parcours, `MOB-81` |
| `ElevationSamples` · `ElevationPoint` · `ElevationBar` · `ElevationReading` | `elevation/elevation_samples.dart` | Modèle de données et agrégation |
| `ElevationAreaPainter` · `ElevationCursorPainter` | `elevation/elevation_*_painter.dart` | Les deux couches peintes : l'aire, puis le réticule |

## Voir le rendu

`lib/dev/pdl_gallery_page.dart` rend les 20 primitives, les 26 composés et les
10 coquilles dans leurs variantes, avec une bascule clair / sombre.
`lib/dev/pdl_shell_demo_page.dart` empile la coquille complète — C1 + C3 +
liste longue + C4 + C2 — et sert de sujet à `test/core/pdl/wave_c_test.dart`.
Ce sont deux pages de **debug**, volontairement absentes du `GoRouter` ; leur
en-tête explique comment les ouvrir.
