# Éditeur de parcours web — desktop et web mobile

Écrit le 17 octobre 2026. **État : lot 1 livré le 17 octobre 2026 (§5), A10 compris ; lots 2 à 4 à faire.**
Ledger `WEB-100` (une seule
entrée, qui pointe ici) : le suivi fin se fait **dans ce plan**, cases à cocher comprises, pas dans
le ledger. Une tâche n'en sort vers `LEDGER_NEXT.md` que si elle quitte le périmètre du plan
(backend partagé, autre client) ou si le plan est archivé avec des restes.

Fait suite aux deux documents de recherche du même jour :
[l'existant](../research/2026-10-17-editeur-parcours-existant.md) et
[l'état de l'art](../research/2026-10-17-editeur-parcours-etat-de-l-art.md), dont le §8 numérote
dix-huit propositions (citées ici « §8 n° x »). Ce plan les reprend pour le **web seulement**, les
vérifie dans le code et ajoute l'ergonomie desktop et web mobile que la recherche ne couvrait pas.
L'app Flutter (§8 n° 18) est hors périmètre.

Chemins relatifs à `frontend/src/` sauf mention contraire. Lignes lues le 17 octobre 2026 sur
`feat/routing-web-mobile` (base `ecfa45ab`).

---

## Sommaire

1. [En une page](#1-en-une-page)
2. [Le moteur de routage passe chez Stadia Maps](#2-le-moteur-de-routage-passe-chez-stadia-maps)
3. [Corrections aux documents de recherche](#3-corrections-aux-documents-de-recherche)
4. [Constats dans le code](#4-constats-dans-le-code)
5. [Lot 1 — robustesse](#5-lot-1--robustesse)
6. [Lot 2 — disposition et web mobile](#6-lot-2--disposition-et-web-mobile)
7. [Lot 3 — le standard attendu](#7-lot-3--le-standard-attendu)
8. [Lot 4 — différenciation](#8-lot-4--différenciation)
9. [Tests](#9-tests)
10. [Décisions à prendre par le propriétaire](#10-décisions-à-prendre-par-le-propriétaire)
11. [Délibérément dehors](#11-délibérément-dehors)

---

## 1. En une page

L'éditeur (`components/planner/RoutePlanner.tsx`, `hooks/useRoutePlanner.ts`, `lib/planner.ts`)
fait le noyau : ajouter, insérer, déplacer, supprimer, ligne droite avec `Ctrl`, annuler. Il est
utilisable à la souris, **difficilement au doigt**, et il lui manque ce que tout concurrent montre
pendant l'édition : profil altimétrique, inverser / aller-retour / boucle, recherche d'adresse.

Quatre lots, chacun livrable seul :

| Lot | Contenu | Taille | Dépend de |
|---|---|---|---|
| **1. Robustesse** | Annulation et verrou pendant le calcul, `Ctrl+Z` hors des champs, tactile décidé par le pointeur, aide aux gestes, menus fiables, tests de `lib/planner.ts` | S à M (≈ 1 semaine) | — (la partie backend attend Stadia, §2) |
| **2. Disposition** | Plein écran d'édition, barre sous le pouce, cibles 44 px, un seul panneau ouvert, recherche d'adresse, cadrage `fitBounds` | M | 1 |
| **3. Standard** | Profil altimétrique d'édition, inverser / aller-retour / boucle, ligne droite visible, clavier, défilement au bord | M | 1, 2 |
| **4. Différenciation** | Éviter côtes / trafic, points d'auteur conservés, surface par point, points de parcours | M à L | 3, API |

Le lot 2 passe **avant** les fonctions : sans lui, chaque bouton du lot 3 serait à placer deux fois
(barre du haut, puis barre du bas).

Tailles : S = quelques heures à un jour, M = quelques jours, L = une à deux semaines.

---

## 2. Le moteur de routage passe chez Stadia Maps

Échange du 17 octobre 2026 avec la session qui fait le travail. Valhalla auto-hébergé est
**remplacé** par l'API Stadia Maps (compatible Valhalla), sur `develop`, pas encore committé au
moment d'écrire. **Ne pas toucher `RouterService` ni le client de routage avant ce commit.**

Ce qui ne change pas : `/api/router` garde la même forme (`RouterRequest`, `RouterProfile`,
`RouterResponse` avec `route` LineString 3D, `dist`, `ascend`). Le contrat passe en `11.5.2`
(routage) puis `11.5.3` (géocodage), descriptions seules. Le géocodage passe aussi chez Stadia.

Ce que ça change pour ce plan :

- **Chaque requête est facturée sur un quota mensuel**, `429` une fois épuisé. L'annulation, le
  verrou et l'absence de doublons du lot 1 deviennent une question d'argent. Coût actuel par
  geste : ajout = 1 requête, insertion ou déplacement = 2, suppression d'un point intérieur = 1.
  Annuler / rétablir ne coûte rien (instantanés en mémoire), il faut le garder ainsi.
- **Les timeouts sont faits** côté Stadia (3 s connexion, 15 s lecture) : §8 n° 3 est à moitié
  fait. Restent un code d'erreur dédié au lieu de `UNKNOWN`, et le contrôle du drapeau sur
  `/api/router` (§8 n° 4).
- **Livré sur `develop` le 17 octobre 2026** (`1727269d`, contrat `11.5.3`, `OPS-48`, `OPS-49`).
  Les codes d'erreur distincts n'y étaient pas ; A10 les a ajoutés (§5). Le même commit pose sur le planificateur la barre de recherche de lieux Stadia
  (`MapSearchControl`, ledger `WEB-99`), appelée depuis le navigateur sans clé : B3 s'en trouve
  réduit.
- Limites publiées : 50 points par requête, 500 km à vol d'oiseau à vélo. Le planificateur route
  segment par segment, il n'est pas gêné ; un « trop long » revient en `400` code `154`, que
  A10 traduit en `ROUTING_SEGMENT_TOO_LONG`.
- `use_roads` vérifié en direct ; `use_hills` probable, non testé ; `trace_attributes` est un
  endpoint séparé, donc **facturé en plus** ; `exclude_polygons` non vérifié.

Les codes d'erreur distincts, d'abord suggérés à la session Stadia, ont finalement été faits
ici, en A10.

---

## 3. Corrections aux documents de recherche

1. **§8 n° 9 cite le mauvais composant.** `components/common/PlaceAutocomplete.tsx:37` interroge
   `useListPlaces` : les lieux de l'équipe. Le géocodeur d'adresses est
   `components/common/GeocoderAutocomplete.tsx` (`GET /api/geocode/search`), déjà utilisé par
   `TeamForm.tsx`.
2. **L'altitude est déjà dans l'éditeur.** `/api/router` renvoie des coordonnées 3D,
   `lib/planner.ts:81` les garde et `getAscend` (`:46-53`) les lit. Le profil d'édition (§8 n° 7)
   ne demande aucun changement d'API. Seul le D+ diverge : somme client sans bande morte après
   Douglas-Peucker, `dist` / `ascend` du serveur ignorés (`lib/planner.ts:227-242`).
3. **Annuler une requête est purement frontend.** Le client généré
   (`api/endpoints/router/router.ts:20`) accepte un `AbortSignal` ; `router()` dans
   `lib/planner.ts` ne le transmet pas.

---

## 4. Constats dans le code

- **La carte vit dans un formulaire qui défile**, en `h="70dvh"` (`components/route/RouteEditor.tsx:204`,
  `components/gpxtool/GpxPreviewEditor.tsx:121`). Nom, description, surface et « Enregistrer »
  sont dessous. MapLibre capte le toucher sur le canvas : au doigt, la page ne défile que par les
  30 % restants. `CreateRouteModal` est `fullScreen` mais enferme tout le formulaire.
- **Le mode tactile est figé au montage** (`RoutePlanner.tsx:165`, `'ontouchstart' in window`).
  Un portable tactile passe entièrement en mode tactile : plus de mini-carte, plus de fantôme au
  survol. Le dépôt a mieux : `useMediaMatch` (`hooks/useResponsive.ts`), `(pointer: coarse)`
  (`NotificationPreferences.module.css`).
- **Les gestes ne sont documentés qu'à moitié** (`locales/*/common.json`, clés d'aide du
  planificateur) : ni « glisser depuis le tracé pour insérer », ni « taper sur le tracé », ni
  `Ctrl`. L'aide disparaît au premier point.
- **Deux panneaux au même endroit** : sélecteur de profil (`RouterProfileSelector.tsx`) et de fond
  (`MapStyleSwitcher.tsx`), mêmes `top` / `left` / `zIndex`. Ouverts ensemble ils se superposent,
  aucun ne se ferme au clic extérieur ; sur 360 px ils couvrent les deux tiers de la carte.
- **Boutons de carte à 29 px** (`index.css`), sous les 44 px que `lib/theme.ts` impose aux boutons
  Mantine sur mobile. La barre est en haut de la carte, hors de portée du pouce.
- **Aucun retour pendant un calcul** hormis « Calcul… » dans la barre ; la carte reste cliquable,
  deux gestes rapides lancent deux calculs concurrents sur le même état
  (`useRoutePlanner.ts:113-133`). L'erreur affichée est `err.message` ou `'Failed'`, non traduite.
- **L'appui long ouvre le menu en plein glisser** : annulé seulement au-delà de 10 px, alors que
  le drag du marqueur démarre à 3 px (seuil MapLibre, lu dans sa doc) ; `handleMarkerDragStart` ne
  coupe pas le minuteur. Le menu est placé à la main et sort du conteneur près du bord haut.
- **Clavier** : `Ctrl+Z` capturé partout, champs texte compris (`RoutePlanner.tsx:224-245`), alors
  que `useHideTrackKey` filtre déjà les champs ; marqueurs sans rôle ni `tabIndex` ; pas d'`Échap`
  pour abandonner un fantôme ; seul `Control` est suivi — sur macOS, Ctrl+clic ouvre le menu
  contextuel (à vérifier en main).
- **Cadrage initial par heuristique** d'étendue, sans tenir compte du ratio du conteneur : un
  tracé large déborde d'un téléphone en portrait. `RouteTrackMap` fait déjà un `fitBounds`.
- **Tests**, avant le lot 1 : `e2e/gpx-planner.e2e.ts` couvrait deux clics et l'enregistrement, exclu en CI
  (`E2E_NO_ROUTING`) ; aucun drag, insertion, suppression, undo ; aucun test unitaire de
  `lib/planner.ts`.

Les constats ci-dessus décrivent l'état **avant** le lot 1 ; ceux que le lot 1 a levés sont cochés
au §5.

---

## 5. Lot 1 — robustesse

- [x] **A1. `Ctrl+Z` ignoré dans les champs** (S, §8 n° 1) — extraire le filtre de
      `useHideTrackKey` en `isEditableTarget(event.target)` et l'appliquer dans
      `RoutePlanner.tsx:224-245`.
- [x] **A2. Annulation, verrou, erreurs traduites** (S/M, §8 n° 2) — un `AbortController` par
      opération dans `executeRouteOperation`, `signal` passé par `add` / `insert` / `remove`
      jusqu'à `route(…, undefined, signal)` ; une opération abandonnée ne touche ni l'historique
      ni la route. Pendant `isLoading` : `draggable={false}` sur les marqueurs, clics ignorés,
      curseur `progress`, `Loader` en surimpression sur la carte. Erreur traduite
      (`planner.error.routing`, et `quotaExceeded` / `segmentTooLong` si la session Stadia livre
      les codes, §2). Prérequis de B1.
- [x] **A3. Profil mémorisé, `Alt` en plus de `Ctrl`** (S, §8 n° 5) — `useLocalStorage` de
      `@mantine/hooks` pour le profil (`useRoutePlanner.ts:90`) ; `ctrlKeyRef` devient
      `directKeyRef` et suit aussi `Alt`, pour macOS (Q3 tranchée : `Ctrl` et `Alt`).
- [x] **A4. Tactile décidé par le pointeur** (S) — `useMediaMatch('(pointer: coarse)')` pour la
      disposition, `pointerType` de l'événement pour chaque geste (tap-insertion, appui long).
      Un portable hybride garde souris et doigt. Prérequis de B5.
- [x] **A5. Aide aux gestes complète et permanente** (S, étend §8 n° 5) — bouton « ? » ouvrant un
      `Popover` Mantine dont le contenu suit le pointeur : ajouter, glisser, insérer, supprimer,
      ligne droite, annuler, `h`. Compléter les deux textes d'accueil, fr et en.
- [x] **A6. Un seul panneau ouvert, ancré à son bouton** (S) — profil et fond de carte en
      `Popover` Mantine (`closeOnClickOutside`, `position="right-start"`), un état partagé « panneau
      ouvert » ; en `(pointer: coarse)`, `Drawer position="bottom"`.
- [x] **A7. Curseurs et libellés** (S) — `grabbing` pendant le drag d'un marqueur, `progress`
      pendant un calcul, `aria-label` sur la corbeille (`title` seul aujourd'hui).
- [x] **A8. Menu tactile fiable** (S) — couper le minuteur d'appui long dans
      `handleMarkerDragStart` ; remplacer la `Box` placée à la main par un `Menu` Mantine
      (`withinPortal`, retournement auto) ou une feuille d'actions en bas d'écran.
- [x] **A9. Tests unitaires de `lib/planner.ts`** (S, §8 n° 6) — module pur, routeur simulé ;
      indispensable avant B2 qui y ajoute des opérations.

**Ce qu'a donné le lot 1** (17 octobre 2026, frontend seul, contrat inchangé) :

- **Un défaut existant corrigé** : en ligne droite, `add` et `insert` recalaient le point de
  contrôle voisin sur la cible, et le tracé s'effondrait sur un point. Ils ne recalent plus que
  sur un segment routé (`isRouted`, `lib/planner.ts`).
- **Verrou et annulation** : un geste de routage pendant un calcul est ignoré ; le démontage, un
  changement de profil, annuler, rétablir et vider abandonnent le calcul en cours. Pendant un
  calcul, annuler n'abandonne que ce calcul et ne dépile pas le geste précédent. Un signal déjà
  abandonné n'émet aucune requête.
- **Panneaux** : `MapPanel` (`components/map/`) sert au fond de carte, au profil et à l'aide :
  `Popover` au pointeur fin, `Drawer` au doigt, un seul ouvert à la fois (état dans
  `PedalonsMap`), `zIndex` 1001 au-dessus du profil d'altitude de `RouteMapView`. Le clic qui
  ferme un panneau ne pose pas de point (fenêtre de 500 ms, approximative).
- **Appui long** : seuil de 3 px aligné sur MapLibre, minuteur coupé au début d'un drag, `Menu`
  Mantine ancré au point d'appui ; un `contextmenu` venu d'un doigt, ou de Ctrl+clic sur Mac, ne
  supprime plus le point.
- **Aide** : sur Apple elle n'annonce que « ⌥ + clic » pour la ligne droite, Ctrl+clic y étant un
  clic droit (`lib/platform.ts`).
- **Marqueurs** : `role="button"`, nom « Point n », `tabIndex`, suppression par `Suppr` ou
  retour arrière. Départ et arrivée ne sont distingués que par la couleur : reste pour B7.
- **Tests** : `lib/planner.test.ts` (dont le coût de chaque geste en requêtes),
  `lib/editableTarget.test.ts`, `hooks/useRoutePlanner.test.tsx` (verrou, abandon, historique) ;
  `e2e/gpx-planner.e2e.ts` simule le routeur (`stubRouter`) pour ajout, glisser, insertion,
  suppression, appui long, ligne droite, annuler / rétablir et Ctrl+Z dans un champ, en comptant
  les requêtes. Seul le premier test de tracé atteint Stadia (`watchRouter`, une requête par
  projet Playwright) quand une clé est présente ; sans clé il simule aussi, et plus aucun fichier
  n'est écarté par `E2E_NO_ROUTING`.
- **Révélé par le premier passage e2e** : le clic que le navigateur émet au lever du doigt,
  après un appui long, refermait aussitôt le menu ; `touchend` l'annule désormais
  (`preventDefault`), et la carte ignore encore un clic pendant 700 ms après l'ouverture. Côté
  tests, chaque contexte a sa propre session du propriétaire, et la connexion est relancée sur
  `429` : le verrou de `SEC-36` compte une connexion en cours comme un échec, et plus de cinq
  connexions simultanées sur une adresse se font refuser sans qu'aucune n'échoue.
- **Non vérifié à la main** : rien n'a été essayé sur un vrai appareil tactile ni sous Safari iOS
  (repli sur le `pointerType` du dernier `pointerdown` pour le tap d'insertion).
- [x] **A10. Côté backend, après le commit Stadia** (S, §8 n° 3 et 4) — livré le 17 octobre 2026,
      contrat `11.6.0`, migration `V72`. Trois décisions du propriétaire :
      1. **Erreurs distinctes** : `ROUTING_QUOTA_EXCEEDED` (Stadia `429`) et `ROUTING_UNAVAILABLE`
         (5xx, délai, réseau, clé refusée) sortent en `503` par `ServiceUnavailableException`,
         journalisée en une ligne WARN sans pile ; `ROUTING_SEGMENT_TOO_LONG` (code Valhalla 154) et
         `ROUTING_NO_ROUTE` (170, 171, 441, 442) en `400` ; un autre `400` reste `UNKNOWN`. Le
         planificateur affiche un message par code, sans le toast global (`lib/plannerErrors.ts`).
      2. **`teamSlug` facultatif sur `/api/router`**, vérifié avant l'appel facturé : avec une
         équipe, elle doit être du domaine (404 sinon), l'utilisateur doit pouvoir y créer un
         parcours (`RouteAccessChecker`, 403 sinon), puis son `enableRoutePlanner` doit être vrai ;
         sans équipe, `enableGpxPlanner` du domaine. Les droits passent avant le drapeau, qui
         n'est donc pas révélé à un non-membre. `RouteEditor` envoie l'équipe, les outils GPX non.
      3. **Un aperçu tracé ne devient pas un parcours d'une équipe sans planificateur** : colonne
         `gpx_previews.drawn` (`V72`, `NOT NULL DEFAULT false`), posée par `from-points` et par une
         mise à jour à partir de points, retirée par une mise à jour à partir d'un fichier ;
         `drawn` dans `GpxPreviewDto` ; la page de l'aperçu grise ces équipes avec une
         explication. Contournable par export puis réimport du GPX, assumé (ledger `API-127`).
      Tests : `RouterResourceTest` (Stadia simulé, multi-domaine), `GpxPreviewResourceTest`,
      `plannerErrors.test.ts`, `GpxPreviewView.test.tsx`, scénario e2e du quota épuisé.

---

## 6. Lot 2 — disposition et web mobile

- [x] **B4. Mode édition plein écran** (M, nouveau) — un contrôle « Agrandir » ouvre le
      planificateur seul, en `100dvh` flex comme `RouteFullscreenView` : barre de 48 px avec
      « Terminer », carte `flex: 1`, bandeau profil (B1). En `(pointer: coarse)`, ouverture en
      plein écran par défaut ; le formulaire ne garde qu'une vignette non interactive (distance,
      D+) et un bouton « Modifier le tracé ». L'état de `useRoutePlanner` doit survivre : remonter
      le hook dans `RouteEditor` / `GpxPreviewEditor`, ou rendre le même sous-arbre par `Portal`.
      Forme tranchée (Q1) : l'aspect de `RouteFullscreenView`, dont on extrait une coque commune,
      au-dessus du formulaire, sans URL propre ; le retour du navigateur le ferme.
- [x] **B5. Barre sous le pouce, cibles de 44 px** (S/M, nouveau) — en `(pointer: coarse)`, barre
      fixée en bas (`ActionIcon size="xl"`) : annuler, rétablir, ligne droite (B6), inverser (B2),
      profil, aide ; puce distance / D+ au-dessus ; la colonne MapLibre ne garde que zoom et fond,
      boutons à 44 px par une règle `@media (pointer: coarse)` dans `index.css`. Dépend de A4, B4.
- [x] **B3. Ma position, partir d'ici** (S, §8 n° 9 corrigé) — la recherche de lieux est déjà
      sur la carte (`MapSearchControl`, ledger `WEB-99`, en haut à droite) ; reste « Démarrer
      ici » après une sélection si le tracé est vide, et le comportement de la barre sur 360 px
      et sous le clavier virtuel ; `GeolocateControl` comme `GpxBlankMapPage`. Ajouter
      `interactive-widget=resizes-content` à la balise viewport (`frontend/index.html`) pour que
      `100dvh` suive le clavier virtuel.
- [x] **B10. La carte bouge sous le curseur au premier point** (S, nouveau, vu en e2e) — la
      barre au-dessus de la carte change de hauteur quand le premier point est posé, la carte est
      redimensionnée et son contenu glisse d'une quinzaine de pixels : le point suivant tombe à
      côté de l'endroit visé. Réserver la hauteur de la barre dès l'ouverture, ou la sortir du
      flux, dans le même lot que B4.
- [x] **B8. Cadrage par `fitBounds`** (S, nouveau) — remplacer l'heuristique de
      `RoutePlanner.tsx:87-118` par `fitBounds(bounds, { padding })` à `onLoad`, comme
      `RouteTrackMap`.

**Ce qu'a donné le lot 2** (17 octobre 2026, frontend seul, contrat inchangé, ledger `WEB-100`) :

- **À ne pas défaire** : une seule instance MapLibre, jamais remontée ; ouvrir, fermer ou
  remonter le plein écran ne fait aucun appel au routeur (facturé à la requête) ; le retour du
  navigateur ferme le plein écran par un `pushState` qui recopie `history.state`, pas par
  `navigate()` ; Échap ne ferme ni le plein écran ni, à travers lui, le formulaire de création
  (`closeOnEscape` coupé) ; au doigt le plein écran ne s'ouvre que sur un geste, jamais au
  chargement ; « Démarrer ici » ne pose que le premier point (zéro requête).

- **Un seul MapLibre, déplacé** : `useRoutePlanner` remonte dans `RoutePlannerField`, qui rend
  `RoutePlanner` (désormais une vue) dans un `div` hôte que React ne gère pas, déplacé à la main
  entre l'emplacement du formulaire et celui du plein écran. Le canvas, la vue, l'historique
  annuler / rétablir et le geste en cours survivent ; ouvrir, fermer ou remonter n'appelle jamais
  le routeur (test : même objet `route` avant et après, e2e : `routerRequests` constant). Au doigt
  la carte n'est construite qu'à la première ouverture, puis reste montée hors du DOM, inactive
  (`active=false` coupe Ctrl+Z et `h`).
- **Plein écran** : `Modal.Root` Mantine sur la coque `MapFullscreenShell`, extraite de
  `RouteFullscreenView` (page carte inchangée, `GpxBlankMapPage` l'adopte). Pas de route : le
  retour du navigateur le ferme par `useHistoryOverlay` (`pushState` à la main qui recopie
  `history.state`, jamais `navigate()` : pas de saut en haut de page, pas de page vue comptée).
  Emplacement `bottom` prêt pour le profil d'édition du lot 3.
- **Au doigt** : le formulaire n'a qu'une vignette (`RoutePlannerPreview`, silhouette SVG de
  `trackSilhouette.ts`, distance, D+, points) ; « Modifier le tracé », « Tracer le parcours » et
  « Tracer sur la carte » ouvrent le plein écran, jamais le chargement. Barre du bas
  (`PlannerBottomBar`) en cibles de 44 px, statut dans une puce au-dessus ; règle
  `@media (pointer: coarse)` de 44 px pour les contrôles de **toutes** les cartes.
- **B10, B8** : barre de statut en ligne à hauteur fixe (`PlannerStatus` sur une ligne, tronquée
  avec infobulle) ; `initialViewState = { bounds, fitBoundsOptions: { padding: 40, maxZoom: 15 } }`
  dans un conteneur qui a déjà sa taille, ce qui respecte le ratio d'un téléphone en portrait.
- **B3** : `MapSearchControl` accepte `onResultSelected` (dans un ref), `GeolocateControl` en haut à
  gauche sans suivi ; une sélection ou une position sur un tracé vide propose « Démarrer ici »
  (marqueur et bouton) qui pose le premier point : zéro requête. Résultats de recherche bornés par
  `50dvh`, `interactive-widget=resizes-content` dans la balise viewport.
- **Réponses aux questions de l'architecte** (propriétaire, 17 octobre 2026) : **L2-1** Échap est
  sans effet sur le plein écran (`closeOnEscape` faux) et, tant qu'il est ouvert, ne ferme pas le
  formulaire de création dessous ; il ferme toujours un panneau de carte, le menu d'appui long et
  les résultats de recherche. **L2-2** « Terminer » et la flèche retour ferment en gardant le
  tracé, pas d'« Abandonner ». **L2-3** au doigt le plein écran s'ouvre sur un geste seulement.
  **L2-4** aperçu = silhouette + chiffres, un toucher ouvre. **L2-5** barre du bas : annuler,
  rétablir, profil, aide, vider (rouge, sans confirmation, notification « Tracé effacé » avec
  « Annuler »), « Terminer » ; pas de « Masquer le tracé » au doigt. **L2-6** statut dans une puce
  (au-dessus de la barre au doigt, en bas au centre de la carte à la souris). **L2-7** 44 px sur
  toutes les cartes. **L2-8** la vue est conservée à l'ouverture et à la fermeture. **L2-9**
  « Démarrer ici » après une recherche ou une position, tracé vide seulement. **L2-10** la bascule
  GPX / tracé perd toujours le tracé (hors lot).
- **Tests** : `useHistoryOverlay.test.ts`, `RoutePlannerField.test.tsx`,
  `RoutePlannerPreview.test.tsx`, `MapFullscreenShell.test.tsx`, `trackSilhouette.test.ts` ;
  `gpx-planner.e2e.ts` passe par le dialogue sur Pixel 7 et ajoute agrandir / terminer, retour et
  avancer du navigateur, Échap, carte unique, cibles de 44 px, « Démarrer ici » (recherche et
  position), cadrage d'un long aperçu.
- **Non vérifié, à faire à la recette (§9)** : un vrai téléphone Android **et** un iPhone. Safari
  iOS ignore `interactive-widget=resizes-content` : le clavier y recouvre la barre du bas et les
  résultats. À regarder aussi : le canvas WebGL après déplacement dans le DOM, le retour système
  Android, l'orientation, l'appui long, le défilement des panneaux sous le verrou de la modale.
  Pas de scénario e2e de création de parcours d'équipe : l'Échap depuis `CreateRouteModal`
  (`closeOnEscape={!plannerFullscreen}`) reste à essayer à la main.

---

## 7. Lot 3 — le standard attendu

- [ ] **B1. Profil altimétrique pendant l'édition** (M, §8 n° 7) — adaptateur pur
      `plannerRouteToMappable(route)` dans `lib/planner.ts` (distance cumulée, `climbs: []`,
      `waypoints: []`) pour alimenter `ElevationChart` tel quel. Survol synchronisé par
      `HoverMarker`, comme `RouteTrackMap`. Desktop : bandeau fixe de 160 px sous la carte.
      Mobile : bandeau repliable d'environ 110 px au-dessus de la barre B5, pas une modale, le
      profil doit rester visible pendant qu'on tape. D+ affiché : décision Q5. Dépend de A2, B4.
- [ ] **B2. Inverser, aller-retour, boucler** (M, §8 n° 8) — trois fonctions pures dans
      `lib/planner.ts`, passées par `executeRouteOperation` pour l'historique. **Coût Stadia** :
      l'aller-retour réutilise la géométrie inversée sans routage (0 requête) ; la boucle route un
      seul segment ; l'inversion re-route tous les segments (sens uniques), soit N requêtes,
      ou se contente d'inverser la géométrie (0 requête, faux sur les sens uniques) — décision Q6.
      Boutons dans la barre, raccourci dans le libellé. Dépend de A9.
- [ ] **B6. Ligne droite comme état visible** (M, §8 n° 10) — bascule dans la barre en plus du
      modificateur ; `direct: boolean` sur `RoutePoint`, posé par `router()` ; `geojson()` produit
      une feature par segment et une seconde couche en `line-dasharray` les rend en pointillés.
      Avertissement à l'enregistrement au-delà d'environ 300 m de ligne droite. C'est l'équivalent
      tactile du `Ctrl`.
- [ ] **B7. Clavier et accessibilité des points** (M, §8 n° 12) — marqueurs `role="button"`,
      `tabIndex={0}`, `aria-label` « Point n sur m » ; `Suppr` supprime, flèches déplacent,
      `Échap` abandonne un fantôme et ferme les panneaux. Un déplacement au clavier ne route
      qu'au relâchement, pas à chaque flèche (coût Stadia).
- [ ] **B9. Défilement au bord pendant un drag** (S/M, nouveau) — à moins de 40 px du bord,
      `panBy` à chaque frame ; sans lui, sortir un point du cadre est impossible au doigt.

---

## 8. Lot 4 — différenciation

Les parties API sont décrites au §8 de l'état de l'art ; ce plan ne garde que la face web.

- [ ] **C2. Éviter les côtes, éviter le trafic** (S côté web, §8 n° 14) — deux `Slider` dans le
      panneau de profil (A6), `use_hills` / `use_roads` dans `RouterRequest`, contrat bumpé.
      `use_hills` à vérifier chez Stadia (§2).
- [ ] **C4. Conserver les points d'auteur à l'enregistrement** (M, §8 n° 11) — sans lui, les
      segments en ligne droite de B6 redeviennent routables à la réouverture ; décision Q7.
- [ ] **C1. Surface par point** (L, §8 n° 13) — `ElevationChart` colore déjà par segment, un
      second mode suffit ; sur la carte, même mécanique de couches que B6. Côté API,
      `trace_attributes` est facturé à part chez Stadia : l'appeler **une fois à
      l'enregistrement**, pas à chaque geste.
- [ ] **C3. Points de parcours d'auteur** (L, §8 n° 15) — appui long ou clic droit sur le tracé,
      « Ajouter un point de parcours » ; `WaypointMarker` existe déjà.
- [ ] **C5. Popularité interne** (§8 n° 17) et **C7. zones à éviter** (§8 n° 16) — sans apport
      UI propre ici ; `exclude_polygons` à vérifier chez Stadia.

---

## 9. Tests

- Unitaires (Vitest) : `lib/planner.ts` avec un routeur simulé (A9) ; chaque nouvelle opération
  (B2, B6) y ajoute ses cas ; le compteur d'appels au routeur simulé vérifie aussi le coût par
  geste du §2.
- e2e : `e2e/gpx-planner.e2e.ts` simule le routeur (`stubRouter`) et compte les requêtes, sur les
  deux projets Playwright (desktop et Pixel 7) ; chaque nouveau geste y ajoute son scénario et son
  coût. Un seul test atteint Stadia (`watchRouter`) quand une clé est présente : ne pas en ajouter
  d'autres, chaque passage de CI est facturé.
- Recette à l'œil sur un vrai téléphone pour le lot 2 : défilement, clavier virtuel, appui long,
  orientation.

---

## 10. Décisions à prendre par le propriétaire

| # | Question | Proposition | Ce que l'autre choix implique |
|---|---|---|---|
| Q1 | Forme du plein écran (B4) | **Tranché le 17 octobre 2026 : l'aspect de la page carte d'un parcours (`RouteFullscreenView` : barre de 48 px, carte sur toute la hauteur, bande de profil au lot 3), rendu au-dessus du formulaire sans URL propre**, le retour du navigateur le ferme | Page dédiée en `layout: 'bare'` : URL propre, mais tracé non enregistré à faire transiter, routes, SSR et liens profonds à ajouter |
| Q2 | Ambition du web mobile | **Tranché le 17 octobre 2026 : édition complète** (B5, B6, B9) ; au doigt, l'éditeur s'ouvre directement en plein écran | Retouches seulement : la moitié du lot 2 tombe |
| Q3 | Modificateur ligne droite | **Tranché le 17 octobre 2026 : `Ctrl` et `Alt`**, la bascule B6 en plus | `Alt` seul : cohérent avec macOS, rompt l'habitude actuelle |
| Q4 | Quota de géocodage par utilisateur | **Caduque** : la recherche de la carte (`WEB-99`) appelle Stadia depuis le navigateur, authentifiée par le domaine ; aucune requête ne passe par notre serveur | — |
| Q5 | D+ affiché pendant l'édition | Celui du serveur (`ascend` par segment), cohérent avec le parcours enregistré | Celui du client : instantané, mais diverge à l'enregistrement |
| Q6 | Inversion | Re-router tous les segments | Inverser la géométrie : gratuit, faux sur les sens uniques |
| Q7 | Lier C4 et B6 | Les livrer ensemble | Accepter que les lignes droites se re-routent à la réouverture |
| Q8 | Mini-carte | **Tranché le 17 octobre 2026 : gardée avec une souris, absente au doigt** (déjà le cas depuis A4) | La rendre débrayable, ou la retirer |

---

## 11. Délibérément dehors

- **Édition dans l'app Flutter** (§8 n° 18) : autre client, autre plan ; le web mobile du lot 2
  en est le banc d'essai.
- **Heatmap d'activités, navigation guidée, photos, import par URL** : voir §8.4 de l'état de
  l'art.
- **Cache client des segments** entre sessions : annuler / rétablir ne coûte déjà rien, et le
  cache serveur suggéré par la session Stadia est plus rentable ; à reconsidérer si la facture le
  demande.
