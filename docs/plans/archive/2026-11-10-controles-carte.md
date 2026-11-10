# Contrôles de carte : zones fixes, web et mobile — conception technique (ledger `WEB-157`, `MOB-129`, `BRAND-10`)

## Context

L'inventaire des contrôles de carte (canvas https://claude.ai/artifact/2ZEa5qp31i2eJhgK91Cf94, page
« État actuel ») a montré : un ordre qui varie d'une carte à l'autre, 11 boîtes empilées dans le
planificateur, trois boutons « plein écran » différents, et trois recouvrements de la barre d'échelle
livrée en `0fe23357a` (① profil en surimpression web, ② interrupteur de mode mobile, ③ carte flottante
mobile). La page « Proposition » du canvas, validée par le propriétaire le 10 novembre 2026, fixe la
cible : **une zone par famille de contrôles, un ordre fixe, une ligne du bas (échelle + crédit) qui se
pose au-dessus de ce qui occupe le bas**.

Décisions du propriétaire (10 novembre 2026) :
- maquettes de la page « Proposition » validées, web mobile compris ; la ligne de résumé du
  planificateur tactile est **un seul bouton** de 48 px (pas un lien) ;
- **web** : l'interrupteur Pente · Revêtement · Météo **reste sous la carte** (pas dans l'en-tête du
  profil) — suite possible notée au ledger ;
- **mobile** : une vignette ne garde que **« Agrandir »** ; Calques (fond, ombrage, traces, Météo)
  se règle en plein écran ;
- exécution par **sous-agents Opus**, un commit par lot, autonomie, questions en cas de doute.

Écarts assumés par rapport aux maquettes (constatés dans le code) :
- **mobile : pas de bouton « Me localiser »** — il n'en existe aucun, et `AndroidManifest.xml`,
  `Info.plist` et `store-metadata/data-safety.md` excluent le puck MapLibre ;
- **planificateur tactile : pas de « Masquer le tracé »** (décision L2-5 du plan
  [`../2026-10-17-editeur-parcours-web.md`](../2026-10-17-editeur-parcours-web.md)) et le bouton reste **« Terminer »** (`planner.done`) :
  l'enregistrement est dans le formulaire (`RouteEditor.tsx:431`) ;
- mode sombre et carte d'annonce : inchangés (l'annonce garde échelle + crédit).

Branche : `feat/scalecontrol` (worktree courant, aujourd'hui au niveau de `develop`). IDs de ledger :
`WEB-157` (zones web), `MOB-129` (zones mobile), `BRAND-10` (charte §contrôles de carte),
`WEB-158` / `MOB-130` (recettes navigateur / appareil, ouvertes en fin de plan).

## Mode d'exécution

- **Lot 0** : ce plan et les entrées `WEB-157`, `MOB-129`, `BRAND-10` dans `LEDGER_NEXT.md`.
- **Lots 1 à 7** : un sous-agent `general-purpose`, `model: opus`, par lot, **en séquence** (un seul
  worktree) ; web et mobile ne se chevauchent pas mais restent séquentiels pour des commits propres.
  Brief = la section du lot dans le plan + fichiers + pièges + vérifications à lancer. Le sous-agent
  n'effectue **pas** le commit : le diff est relu, les vérifications relancées, `./format.sh <module>`
  passé, puis le lot est commité (`feat(maps): …`, corps Web :/Mobile :, `Co-Authored-By: Claude Fable 5.2`).
- Jamais de tests backend (aucun backend touché). **e2e Playwright / Patrol : pas lancés sans feu
  vert** (pile `tribly-e2e` partagée) — les specs sont adaptées dans les lots, la recette sort en
  `WEB-158` / `MOB-130`.
- Un seul simulateur ; pas de run sur appareil dans ce plan.

## Web

Contraintes établies : une position MapLibre est figée à la création (`useControl`) ; l'ordre dans un
coin suit l'ordre de montage (haut : `appendChild`, bas : `insertBefore`) ; les enfants de la carte ne
sont jamais rendus au SSR, donc lire `matchMedia('(pointer: coarse)')` de façon synchrone au montage
d'un contrôle est sûr.

### Lot 1 — Zones et ordre fixe (`WEB-157`)

- **`components/map/mapZones.ts` (nouveau)** : `useMapZones()` → `{ camera, display, side }`.
  Pointeur fin : `camera: 'top-left'`, `display: 'top-right'`. Pointeur grossier : les deux en
  `'bottom-right'` (colonne sous le pouce). Lecture synchrone de `matchMedia` (figée au montage, comme
  la position). `side` (`'left' | 'right'`) donne le côté des infobulles et popovers.
- **`MapControl.tsx`** : `MapControlGroup` prend `zone: 'camera' | 'display'` (plus de défaut
  top-left), pose une classe d'ordre `pdl-ctrl-<slot>` sur le conteneur de `PortalControl` ;
  `MapControlButton` : `Tooltip position` = côté opposé à la colonne (au lieu de `"right"` en dur).
- **`MapPanel.tsx`** : `Popover position` = `left-start` quand la colonne est à droite ; docstring
  mise à jour. Le tiroir (`Drawer`) au doigt est inchangé.
- **Ordre fixe par CSS** (`index.css`, généralise la règle `order` de l'échelle) : les quatre coins
  deviennent des colonnes flex ; `order` par contrôle — recherche, zoom/boussole
  (`:has(> .maplibregl-ctrl-zoom-in)`), me localiser (`:has(> .maplibregl-ctrl-geolocate)`), plein
  écran (`:has(> .maplibregl-ctrl-fullscreen)` et le lien/« Agrandir » via `pdl-ctrl-fullscreen`),
  puis fond de carte, masquer le tracé. L'ordre ne dépend plus du montage (règle le piège du
  remontage dans le planificateur, de `MapAttribution` et de `MapSearchControl` reconstruits).
- **Placement** : `MapSearchControl` → `top-left` (pleine largeur au doigt :
  `calc(100% - 20px)`) ; `NavigationControl`, `LocateControl`, `FullscreenControl`, lien plein écran
  de `RouteMapView`, « Agrandir » du planificateur → zone caméra ; `MapStyleSwitcher`,
  `HideTrackControl` → zone affichage ; `MapScale` → `bottom-left` ; `MapAttribution` reste
  `bottom-right` (au doigt, sous la colonne : `order` en dernier).
- **Tailles** : 36 px au pointeur fin (aujourd'hui 29 px de maplibre-theme), rayon 8 px
  (`--ml-ctrl-border-radius`), 44 px au doigt (déjà en place) ; état actif = fond doux + icône
  (classe `active` existante).
- Commentaires de doctrine à réécrire : `PedalonsMap.tsx:15-20`, `MapControl.tsx:35-36`,
  `MapSearchControl.tsx:29-34`, `MapScale.tsx:9-10`, `RoutesMapView.tsx` (profil bas gauche).
- Tests : `mapZones.test.ts` (fin/grossier), test de `MapControlGroup` (classe d'ordre, côté de
  l'infobulle). e2e à adapter si un sélecteur dépend d'une position (aucun repéré : ils passent par
  les libellés).

### Lot 2 — La ligne du bas flotte (corrige ①)

- Variables CSS `--map-inset-bottom-left` / `--map-inset-bottom-right` posées sur l'enveloppe de la
  carte ; `index.css` : `.maplibregl-ctrl-bottom-left { bottom: var(--map-inset-bottom-left, 0) }`,
  idem droite. (Pas de préfixe `--pdl-*` : BRANDING l.27 les réserve aux maquettes.)
- `RouteMapView.tsx:180-198` (profil pleine largeur, `clamp(110px, 38%, 200px)`) : la même
  expression dans les deux variables, sur la `Box` relative de `RouteTrackMap` (prop
  `bottomInset`).
- `RoutesMapView.tsx:752-771` (Paper bas gauche, 120/140/150 px) : hauteur et variable gauche
  définies ensemble (classe CSS avec les mêmes ruptures) ; à droite seulement sous `sm`
  (`calc(100% - 40px)` de large → le ⓘ reste découvert, l'échelle monte).
- Plein écran natif de `RoutesMapView` (le profil n'est pas dans l'élément plein écran) : remise à
  zéro sous `.maplibregl-map:fullscreen` et `.maplibregl-pseudo-fullscreen`.
- Planificateur : inset = hauteur de la barre d'outils (lot 3) ; la mini-carte
  (`RoutePlannerMiniMap`, `bottom=48 right=16`) est remontée de la même valeur.
- `LEDGER` : note sous `WEB-115` inutile — la légende garde son crédit en clair (décision à ne pas
  défaire).

### Lot 3 — Planificateur à la souris : barre d'outils

- **`components/planner/PlannerToolbar.tsx` (nouveau)** : `role="toolbar"`, en bas au centre de la
  carte (frère absolu, comme l'actuel `Stack` de `RoutePlanner.tsx:2156-2193` qu'il remplace) :
  résumé (distance · D+ · points, état calcul/erreur repris de `PlannerStatusChip`) | annuler,
  rétablir | mode direct, profil de routage | importer, aide. Boutons 36 px, mêmes libellés et
  raccourcis (`planner.undo`, `planner.direct.toggle.mouse`…) → sélecteurs e2e inchangés.
- `MapPanel` : troisième valeur `trigger="toolbar"` → popover ouvert **vers le haut**
  (`position="top"`) depuis un bouton de la barre ; `RouterProfileSelector` et `PlannerHelpControl`
  l'utilisent. `panelJustDismissed()` conservé.
- `RoutePlanner.tsx:1717-1746` : suppression des 5 boîtes de colonne (`UndoRedoControl`,
  `DirectModeControl`, Import, aide, profil) ; restent en colonne : caméra (zoom, me localiser,
  agrandir) et affichage (fond, masquer le tracé). `UndoRedoControl.tsx` / `DirectModeControl.tsx`
  supprimés si plus d'appelant. Consignes « 0 point » : au-dessus de la barre.
- Disposition `inline` et `fullscreen` souris : même barre (la puce n'existait qu'en plein écran).
- e2e `gpx-planner.e2e.ts` : `clickMap` vise le centre ±130/+60 px — vérifier que la barre (≈ 60 px
  en bas) n'intercepte rien sur le projet `desktop` ; adapter 859-870 (aide : Échap).
- Tests : `PlannerToolbar.test.tsx` ; `RoutePlannerField.test.tsx:277` (Import depuis la carte) à
  adapter.

**Arbitrages pris à l'exécution (10 novembre 2026), font foi sur la liste ci-dessus :**

| Sujet | Décision |
|---|---|
| Barre de statut en ligne (48 px au-dessus de la carte, B10 du plan éditeur) | **Supprimée** : le résumé est dans la barre d'outils, et le garder aux deux endroits doublait « N points » et « X km » (les e2e les cherchent en mode strict). Ce que B10 garantissait tient toujours : la carte ne change pas de hauteur au premier point |
| « Effacer » en disposition intégrée | Dans la barre d'outils (il vivait dans la barre supprimée), désactivé sans point au lieu de masqué. En plein écran, l'en-tête du dialogue garde le sien |
| Ligne du bas du planificateur | **Toujours** remontée de 54 px (`.planner-map--toolbar`) : la largeur de la barre et celle du crédit varient, aucun seuil ne garantit qu'ils ne se touchent pas. La mini-carte monte d'autant |
| Slots d'ordre | Réduits à `fullscreen`, `style`, `hide-track` ; `UndoRedoControl` et `DirectModeControl` supprimés |

### Lot 4 — Planificateur au doigt : barre du bas sur deux lignes

- `PlannerBottomBar.tsx` : ligne 1 = **bouton pleine largeur de 48 px** « 42,6 km · 640 m D+ ·
  7 points — Profil ⌃ » (`aria-expanded`), qui replie/déplie la bande de profil existante
  (`STRIP_BODY_HEIGHT_TOUCH`, clé `pedalons-planner-profile-collapsed`, `RoutePlannerField.tsx:716-766`)
  et porte l'état calcul/erreur (remplace la puce `bottom:'100%'`) ; ligne 2 = annuler, rétablir,
  ligne droite, profil, aide (44 px) + « Terminer ». Règle le manque de place à 360 px (B2 du plan
  éditeur). Stats retirées de l'en-tête du dialogue au doigt (doublon).
- Nouvelles clés i18n fr + en (`planner.summary.showProfile` / `.hideProfile`), `pnpm format`.
- e2e à adapter : 909-936 (cibles ≥ 44, + le bouton résumé), 942-951 (360 px), 1686-1718 (profil
  au-dessus de la barre).

**Arbitrages pris à l'exécution (10 novembre 2026), font foi sur la liste ci-dessus :**

| Sujet | Décision |
|---|---|
| Consignes « 0 point » au doigt | Sur la carte, **en haut**, sous la recherche : la ligne de résumé a une hauteur fixe (la carte ne change pas de taille au premier point) et le bas de la carte reste à l'échelle et au crédit |
| Poignée de repli de la bande de profil | Supprimée : le bouton résumé est le seul contrôle de l'action. Repliée, la bande n'est plus rendue (son en-tête de 44 px restait) ; même clé `localStorage` |
| Stats de l'en-tête du dialogue | Retirées au doigt (doublon du résumé) ; Importer et Effacer y restent |
| Erreur dans le résumé | Deux lignes au plus, le mot « Profil » cède la place (le chevron reste) |
| `PlannerStatusChip` | Supprimé, plus d'appelant |

## Mobile

Contraintes établies : échelle et crédit sont des enfants de `MapLibreMap` (dans la vue de la carte),
donc **sous** toutes les couches du hero ; ne rien insérer avant la carte ni l'envelopper de façon
conditionnelle dans le `Stack` du hero (recrée la vue native) ; les `children` de la carte n'existent
pas en test de widget.

### Lot 5 — `PdlMapHero` : ligne du bas, colonne, Fermer (`MOB-129`)

- **`PdlMapBottomInset`** (InheritedWidget public, `core/pdl/map/`) : posé par le hero **toujours**
  autour de `mapBuilder` (forme d'arbre stable), lu par `PdlMapScaleBar` et `PdlMapAttribution` qui
  l'ajoutent à leur marge basse. Hors hero (annonce) : 0.
- `PdlMapHero` devient `StatefulWidget` : nouveau paramètre **`bottomLayer`** (widget) posé par le
  hero en `Positioned(left 12, right 12, bottom 12)` + `SafeArea(bottom)` en plein écran ; sa hauteur
  et celle de `floatingCard` sont **mesurées** (render object de mesure, callback post-frame) →
  inset. Paramètre `bottomInset` (double, défaut 0) pour un occupant externe (feuille de la fiche
  parcours). `foreground` reste pour le reste (contrôles « Autour de moi »).
- **Colonne de boutons** : ancrée en bas à droite, au-dessus du ⓘ (`bottom = inset + hauteur du
  crédit + chipGap`), plus centrée verticalement.
- **Plein écran** : le bouton de sortie quitte la colonne → `PdlMapButton(PdlIcons.close)` en haut à
  gauche (libellé `labels.exitFullscreen` inchangé) ; la `pill` se décale (`left = 12 + 44 + 8`).
- **Vignette** : nouveau paramètre `vignette` ; quand vrai, la colonne ne rend que « Agrandir »
  (pas de Calques). Appelants : `route_map.dart` (`allowFullscreen && !fullscreen`),
  `ride_groups_map.dart`, `trip_map.dart` (`!fullscreen`). `RoutesMapView` et la fiche parcours
  (cartes interactives) gardent Calques.
- Tests à adapter (cherchent `PdlIcons.fullscreenExit`) : `pdl_map_hero_fullscreen_test.dart`,
  `ride_groups_map_wind_test.dart`, `ride_solo_weather_map_test.dart`, `stage_map_weather_test.dart`,
  `trip_map_weather_test.dart` ; `map_tap_target_test.dart` (44 px du bouton Fermer). Nouveaux tests :
  inset = hauteur mesurée de `bottomLayer` / `floatingCard` ; vignette sans Calques ; `PdlMapScaleBar`
  et `PdlMapAttribution` décalés par `PdlMapBottomInset` (posés à la main dans `mapBuilder`, comme le
  fait déjà le test du ⓘ).
- `core/pdl/README.md` (tableau `map/`) mis à jour. Règles `core/pdl` : aucun littéral, 44 px, aucun
  DTO ; `grep` de revue vides.

### Lot 6 — Écrans : calque du bas unique (corrige ②, ③)

- `route_color_mode_switch.dart` : `routeMapBottomLayer` → renvoie le **contenu** d'une seule carte
  (`PdlMapFloatingCard` : interrupteur pleine largeur + légende), passé à `PdlMapHero.bottomLayer`
  (plus de `Positioned` maison ni de `right: 56`). `RideWindMapLegend` : variante sans sa propre
  surface. `passTouches` conservé (vignette de l'onglet Météo) ; clés (`fullscreenColorBy`,
  `windMapLegend`, `windMapCredit`, `trip.fullscreenMapColorBy`) inchangées.
- Appelants : `route_map.dart` (`RouteMapLayer.foreground` → `bottomLayer`), `ride_groups_map.dart`
  (+ la pilule du parcours passe de `PdlMap.overlays` au `pill` du hero, sinon elle heurte
  « Fermer »), `trip_map.dart`, `stage_detail_page.dart`.
- `routes_map_view.dart` : `floatingCard` mesurée par le hero (rien à faire de plus) + `SafeArea`
  bas en plein écran.
- `route_detail_page.dart` : `bottomInset = hauteur × cran` de `PdlDetentSheet` (échelle, ⓘ et
  Calques au-dessus de la feuille aux crans 0,18 et 0,5).
- Ne pas toucher `ad_location_map.dart` (le test Patrol interdit tout overlay sur sa carte).
- Invariants à garder : `MOB-93` (ⓘ touchable à travers la couche de toucher), `MOB-107` (pastilles
  du voyage en plein écran seulement), `MOB-105` (interrupteur unique, même état).

**Arbitrages pris à l'exécution (10 novembre 2026), font foi sur la liste ci-dessus :**

| Sujet | Décision |
|---|---|
| Largeur de l'interrupteur dans la carte du bas | **Pleine largeur** de la carte (maquette) ; le plafond 120 px × segments ne vaut plus que sous la carte encastrée |
| `overMap` | Gardé, sens nouveau : « dans la carte du bas » = pleine largeur, sans ombre ni filet à lui (la carte les porte) |
| Surface de `RideWindMapLegend` | **Retirée** plutôt qu'une variante : tous ses appelants passent par `routeMapBottomLayer` |
| Légende seule (vignette, onglet Météo) | Même carte, mais **à la largeur de son contenu**, à gauche ; contenu complet (parts, notes, crédit) — sur 240 px, carte ≈ 70–115 px, « Agrandir » au-dessus |
| `passTouches` | L'`IgnorePointer` enveloppe toute la carte du bas, marges comprises |
| « Autour de moi » | Réserve droite retirée ; sous la rangée « Fermer » / pilule (top 64), sans chevauchement |
| Fiche parcours, cran 0,92 | `bottomInset` plafonné au cran médian (sinon échelle, ⓘ et Calques montaient sous la barre du haut) ; suit le cran franchi, pas le glissé continu (reconstruirait la carte à chaque image) |

## Lot 7 — Docs, charte, clôture

- `docs/BRANDING.md` : nouvelle sous-section « Contrôles de carte » (zones, ordre, tailles 36/44,
  ligne du bas, vignette) — `BRAND-10`.
- `WEB-157`, `MOB-129`, `BRAND-10` → `LEDGER_DONE.md` (date, tests, décisions à ne pas défaire :
  zones, ordre par CSS, inset, pas de localisation mobile, interrupteur web sous la carte).
  Ouvrir `WEB-158` (recette navigateur + e2e `gpx-planner`, téléphone réel) et `MOB-130` (recette
  appareil : iPhone SE, texte à 130 %, zone sûre) ; suite possible « interrupteur dans le profil
  web » en « Délibérément dehors ».
- Plan → `docs/plans/archive/` + ligne dans son README ; canvas : note « livré » sur la page
  Proposition.

## Fichiers critiques

Web : `frontend/src/components/map/{PedalonsMap,MapControl,MapPanel,MapStyleSwitcher,HideTrackControl,LocateControl,MapSearchControl,MapScale,MapAttribution}.tsx`,
`frontend/src/index.css`, `components/route/{RouteTrackMap,RouteMapView,RoutesMapView,RoutesTileMap}.tsx`,
`pages/gpxtool/GpxBlankMapPage.tsx`, `components/planner/{RoutePlanner,RoutePlannerField,PlannerBottomBar,RouterProfileSelector,PlannerHelpControl,PlannerStatus}.tsx`,
`locales/{fr,en}/common.json`, `e2e/gpx-planner.e2e.ts`.

Mobile : `mobile/lib/core/pdl/map/{pdl_map_hero,pdl_map,pdl_map_scale,pdl_map_attribution,pdl_map_buttons}.dart`,
`features/routes/presentation/widgets/{route_map,route_color_mode_switch,routes_map_view}.dart`,
`features/routes/presentation/pages/route_detail_page.dart`,
`features/rides/presentation/widgets/{ride_groups_map,ride_wind_map_legend}.dart`,
`features/trips/presentation/{widgets/trip_map,pages/stage_detail_page}.dart`, `lib/core/pdl/README.md`.

## Vérification

- Web, à chaque lot : `pnpm typecheck`, `pnpm lint`, `pnpm vitest run src/components/{map,route,planner}`,
  `pnpm i18n:check` (lot 4), `./format.sh frontend`.
- Mobile, à chaque lot : `flutter analyze`, `flutter test` (suite complète, ~3 min),
  `./format.sh mobile`, les deux `grep` de `core/pdl`.
- À l'œil, avec l'accord du propriétaire pour ouvrir un navigateur (`pnpm dev` sur staging, pas la pile e2e) :
  fiche parcours, groupe avec profil en surimpression, carte des parcours, planificateur souris et
  largeur téléphone — ordre des colonnes, échelle/crédit au-dessus du profil, popovers du bon côté.
- Non lancés ici : e2e Playwright et Patrol, recette sur appareil → `WEB-158`, `MOB-130`.
