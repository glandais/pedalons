# Éditeur de parcours web — desktop et web mobile

Écrit le 17 octobre 2026, mis à jour le 19 octobre 2026. **État : lots 1 et 2 livrés le
17 octobre 2026 (§5 et §6, A10 compris) ; dans le lot 3, B11, B12, B6, B1 (profil d'édition : B1a le 18, B1b le 19 octobre), B7 et B9 sont livrés ;
le lot 4 est entamé par C2, C4 (C4a et C4b, livrés le 19 octobre) et C1a et C1b (livrés le 19 octobre) ; restent le reste du lot 3 (B2, mis de côté) et le lot 4 (C1c ; C3, C5, C7 ; C6 non attribué).**
Ledger `WEB-100` (une seule
entrée, qui pointe ici) : le suivi fin se fait **dans ce plan**, cases à cocher comprises, pas dans
le ledger. Une tâche n'en sort vers `LEDGER_NEXT.md` que si elle quitte le périmètre du plan
(backend partagé, autre client) ou si le plan est archivé avec des restes. **Les volets backend
du lot 3 et du lot 4** (l'endpoint de recalage de B2, l'état d'édition de C4 ; C4a et C4b sont livrés, voir §8) **restent sous
`WEB-100`**, comme A10 (D4, §10) : les versions de contrat et les migrations seront notées au
passage dans `LEDGER_DONE.md`.

Fait suite aux deux documents de recherche du même jour :
[l'existant](../research/2026-10-17-editeur-parcours-existant.md) et
[l'état de l'art](../research/2026-10-17-editeur-parcours-etat-de-l-art.md), dont le §8 numérote
dix-huit propositions (citées ici « §8 n° x »). Ce plan les reprend pour le **web seulement**, les
vérifie dans le code et ajoute l'ergonomie desktop et web mobile que la recherche ne couvrait pas.
L'app Flutter (§8 n° 18) est hors périmètre. Deux études plus récentes alimentent le lot 3 :
[le recalage Stadia](../research/2026-10-17-stadia-map-matching.md) (B2) et
[la suppression des points et des ancres](../research/2026-10-18-editeur-parcours-suppression.md) (B12).

Chemins relatifs à `frontend/src/` sauf mention contraire. Noms et chemins vérifiés dans le code
le 18 octobre 2026 sur `feat/routing-web-mobile` (base `111acaef`). Les numéros de ligne, qui ne
tombaient plus juste après les lots 1 et 2, sont retirés : chercher par le nom.

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
pendant l'édition : profil altimétrique, inverser / aller-retour / retour au départ, recherche d'adresse.

Quatre lots, chacun livrable seul :

| Lot | Contenu | Taille | Dépend de |
|---|---|---|---|
| **1. Robustesse** (livré) | Annulation et verrou pendant le calcul, `Ctrl+Z` hors des champs, tactile décidé par le pointeur, aide aux gestes, menus fiables, tests de `lib/planner.ts` | S à M (≈ 1 semaine) | — (volet backend A10 livré) |
| **2. Disposition** (livré) | Plein écran d'édition, barre sous le pouce, cibles 44 px, un seul panneau ouvert, recherche d'adresse, cadrage `fitBounds` | M | 1 |
| **3. Standard** | Profil altimétrique d'édition (B1, **livré**), inverser / aller-retour / retour au départ avec recalage (B2), ligne droite visible (B6, **livré**), clavier (B7, **livré**), défilement au bord (B9, **livré**), glisser une ancre au doigt (B11, **livré**), bornes indépendantes du zoom et suppression d'une ancre (B12, **livré**) | **L** | 1, 2 ; API pour B2 (endpoint de recalage) |
| **4. Différenciation** | Éviter côtes / trafic (C2, **livré**), état d'édition conservé (C4 : **C4a et C4b livrés**), surface par point (C1 : **C1a et C1b livrés**), points de parcours (C3), popularité interne (C5), zones à éviter (C7) ; C6 non attribué | M à L | C4 : B6 et B12 ; C2 : aucun morceau du lot 3 ; API pour C1, C2, C4, C7 |

Dans le lot 4, **C4 dépend de B6** (seul B6 crée l'information « ligne droite ») **et de B12**
(la provenance des points) ; B6 et B12 ne dépendent pas de C4. Le lot 2 passe **avant** les fonctions : sans lui, chaque bouton du lot 3 serait à placer deux fois
(barre du haut, puis barre du bas).

Tailles : S = quelques heures à un jour, M = quelques jours, L = une à deux semaines.

---

## 2. Le moteur de routage passe chez Stadia Maps

Échange du 17 octobre 2026 avec la session qui a fait le travail. Valhalla auto-hébergé a été
**remplacé** par l'API Stadia Maps (compatible Valhalla), livré sur `develop` (`1727269d`, voir
plus bas) : l'interdiction de toucher `RouterService` et le client de routage avant ce commit est
levée.

Ce qui ne change pas : `/api/router` garde la même forme (`RouterRequest`, `RouterProfile`,
`RouterResponse` avec `route` LineString 3D, `dist`, `ascend`). Le contrat est passé en `11.5.2`
(routage) puis `11.5.3` (géocodage), descriptions seules ; il est à `11.8.0` le 18 octobre 2026. Le géocodage passe aussi chez Stadia.

Ce que ça change pour ce plan :

- **Chaque requête est facturée sur un quota mensuel**, `429` une fois épuisé. L'annulation, le
  verrou et l'absence de doublons du lot 1 deviennent une question d'argent. Annuler / rétablir
  ne coûte rien (instantanés en mémoire), il faut le garder ainsi. Coût de chaque geste, livré
  puis à venir :

  | Geste | Requêtes facturées | État |
  |---|---|---|
  | Ajouter un point (le premier : aucune) | 1 | livré |
  | Insérer, déplacer un point de contrôle, glisser une ancre au doigt (B11) | 2 (1 à une extrémité, 0 en ligne droite) | livré |
  | Supprimer un point de contrôle intermédiaire | 1 (0 en ligne droite) ; **0 entre deux raccords du même import** depuis `sourceIdx` (C4a) | **livré** (C4a) ; B12 le garde (livré) |
  | Supprimer le départ ou l'arrivée | 0 | livré |
  | Annuler, rétablir, ouvrir ou fermer le plein écran | 0 | livré, à garder |
  | Supprimer une ancre importée (B12) | 1, **0 avec `Alt`** (ligne droite) | livré |
  | Restituer une portion du fichier en supprimant un point (C4) | 0 | **livré** (C4a) |
  | Déplacer un point au clavier (B7) | 2 (1 à une extrémité), **au relâchement seulement**, jamais à chaque flèche | **livré** (B7) |
  | Inverser, aller-retour (B2) | **1 ou 2** : un recalage, plus un raccord s'il reste des trous ; 0 en repli sur la géométrie inversée | à faire |
  | Retour au départ (B2) | 1 | à faire |
  | Surface par point (C1) | 1, **une fois à l'enregistrement** (`trace_attributes`, facturé à part) | à concevoir |
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

1. **§8 n° 9 cite le mauvais composant.** `components/common/PlaceAutocomplete.tsx` interroge
   `useListPlaces` : les lieux de l'équipe. Le géocodeur d'adresses est
   `components/common/GeocoderAutocomplete.tsx` (`GET /api/geocode/search`), déjà utilisé par
   `TeamForm.tsx`.
2. **L'altitude est déjà dans l'éditeur.** `/api/router` renvoie des coordonnées 3D,
   `lib/planner.ts` les garde (`createPoints`) et `getAscend` les lit. Le profil d'édition (§8 n° 7)
   ne demande aucun changement d'API. Seul le D+ diverge : `computeRoute` le somme côté client, sans bande morte, sur
   les points **après** Douglas-Peucker, et `router()` ne renvoie que les points, donc le `dist` et
   l'`ascend` du serveur sont ignorés. B1 donne la règle (D2).
3. **Annuler une requête est purement frontend.** Le client généré
   (`api/endpoints/router/router.ts`) accepte un `AbortSignal` ; `router()` dans
   `lib/planner.ts` ne le transmet pas.

---

## 4. Constats dans le code

- **La carte vit dans un formulaire qui défile**, en `h="70dvh"` (`components/route/RouteEditor.tsx`,
  `components/gpxtool/GpxPreviewEditor.tsx`). Nom, description, surface et « Enregistrer »
  sont dessous. MapLibre capte le toucher sur le canvas : au doigt, la page ne défile que par les
  30 % restants. `CreateRouteModal` est `fullScreen` mais enferme tout le formulaire.
- **Le mode tactile est figé au montage** (`RoutePlanner.tsx`, `'ontouchstart' in window`).
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
  (`useRoutePlanner.ts`). L'erreur affichée est `err.message` ou `'Failed'`, non traduite.
- **L'appui long ouvre le menu en plein glisser** : annulé seulement au-delà de 10 px, alors que
  le drag du marqueur démarre à 3 px (seuil MapLibre, lu dans sa doc) ; `handleMarkerDragStart` ne
  coupe pas le minuteur. Le menu est placé à la main et sort du conteneur près du bord haut.
- **Clavier** : `Ctrl+Z` capturé partout, champs texte compris (`RoutePlanner.tsx`), alors
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
      `RoutePlanner.tsx`.
- [x] **A2. Annulation, verrou, erreurs traduites** (S/M, §8 n° 2) — un `AbortController` par
      opération dans `executeRouteOperation`, `signal` passé par `add` / `insert` / `remove`
      jusqu'à `route(…, undefined, signal)` ; une opération abandonnée ne touche ni l'historique
      ni la route. Pendant `isLoading` : `draggable={false}` sur les marqueurs, clics ignorés,
      curseur `progress`, `Loader` en surimpression sur la carte. Erreur traduite
      (`planner.error.routing`, et `quotaExceeded` / `segmentTooLong` si la session Stadia livre
      les codes, §2). Prérequis de B1.
- [x] **A3. Profil mémorisé, `Alt` en plus de `Ctrl`** (S, §8 n° 5) — `useLocalStorage` de
      `@mantine/hooks` pour le profil (`useRoutePlanner.ts`) ; `ctrlKeyRef` devient
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
- **Correctifs du 18 octobre 2026** (`abcc83c5`, frontend seul) :
  - **Un toucher insère un point sur iPhone.** Au doigt, Safari émet un `mousemove` de
    compatibilité avant le clic d'un toucher, sans type de pointeur : le planificateur y voyait une
    souris qui survole le tracé, affichait le point fantôme, et le clic qui suivait était abandonné
    (il fallait un second toucher, sur le fantôme). Le **type du dernier pointeur vu**
    (`pointerdown` et `pointermove`) décide désormais : pas de fantôme pour un doigt, et le clic
    d'un doigt n'est plus bloqué. Le scénario e2e (`frontend/e2e/gpx-planner.e2e.ts`) **rejoue la
    séquence d'événements de Safari**, que le toucher de Chromium ne produit pas, et **il échoue
    sans la correction**.
  - **« Me localiser » devient une bascule** (`components/map/LocateControl.tsx`) : le premier appui
    localise, le suivant retire la position sans déplacer la carte. Il sert au planificateur, à la
    carte vierge des outils GPX (`GpxBlankMapPage`) et, ajouté par ce commit, à la carte des
    parcours (`RoutesTileMap`).
- **Non vérifié à la main** : rien n'a été essayé sur un vrai appareil tactile ni sous Safari iOS
  (le tap d'insertion se décide sur le type du dernier pointeur, voir ci-dessus).
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
      « Terminer », carte `flex: 1`, bandeau profil (B1). En `(pointer: coarse)`, le
      plein écran s'ouvre **sur un geste** (« Modifier le tracé », « Tracer le parcours »), jamais
      au chargement (L2-3) ; le formulaire ne garde qu'une vignette non interactive (distance,
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
      et sous le clavier virtuel ; `LocateControl` (`components/map/LocateControl.tsx`, une
      bascule depuis `abcc83c5`) comme `GpxBlankMapPage`. Ajouter
      `interactive-widget=resizes-content` à la balise viewport (`frontend/index.html`) pour que
      `100dvh` suive le clavier virtuel.
- [x] **B10. La carte bouge sous le curseur au premier point** (S, nouveau, vu en e2e) — la
      barre au-dessus de la carte change de hauteur quand le premier point est posé, la carte est
      redimensionnée et son contenu glisse d'une quinzaine de pixels : le point suivant tombe à
      côté de l'endroit visé. Réserver la hauteur de la barre dès l'ouverture, ou la sortir du
      flux, dans le même lot que B4.
- [x] **B8. Cadrage par `fitBounds`** (S, nouveau) — remplacer l'heuristique de
      `RoutePlanner.tsx` par `fitBounds(bounds, { padding })` à `onLoad`, comme
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
- **B3** : `MapSearchControl` accepte `onResultSelected` (dans un ref), `LocateControl` (bascule, `components/map/LocateControl.tsx`) en haut à
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

Ordre conseillé : **B12** d'abord (il pose la provenance `imported` et les bornes dont B2 et C4 se
servent), puis B6 (la ligne droite visible), puis B1 et B2.

- [x] **B1. Profil altimétrique pendant l'édition — B1a et B1b livrés** (M, §8 n° 7) — adaptateur pur
      `plannerRouteToMappable(route)` dans `lib/planner.ts` (distance cumulée, `climbs: []`,
      `waypoints: []`) pour alimenter `ElevationChart` tel quel. Survol synchronisé par
      `HoverMarker`, comme `RouteTrackMap`. Desktop : bandeau fixe de 160 px sous la carte.
      Mobile : bandeau repliable d'environ 110 px au-dessus de la barre B5, pas une modale, le
      profil doit rester visible pendant qu'on tape (emplacement `bottom` de `MapFullscreenShell`).
      Dépend de A2, B4. **Règle du D+ affiché** (D2, 18 octobre 2026 ; remplace Q5) :
      - **Source des altitudes** : le serveur, en mode FAST (Mapterhorn, `API-131`), partout.
        Segment routé : `RouterService.getRoute` appelle `gpxPipeline.process(raw, "route",
        ElevationQuality.FAST)` et renvoie `dist` et `ascend` (fait depuis `6cbce899`). Fichier
        importé : le serveur calcule la trace source **dès l'envoi initial du fichier**, en FAST
        aussi (voir C4, « Qui produit la trace source »). Routé et importé sont donc cohérents.
      - **Un segment routé garde l'`ascend` de sa réponse** : `router()` de `lib/planner.ts` ne
        renvoie aujourd'hui que les points, il doit rendre aussi `ascend`. Il se range **sur le
        point qui termine le segment** (champ `legAscend` sur `RoutePoint`, nom proposé) ; un point
        d'une portion importée ou d'un tracé chargé n'en porte pas. Une ligne droite : D+ à
        concevoir (ses points n'ont pas d'altitude, `ele` absent, aujourd'hui compté 0).
      - **Une portion importée** : somme des montées de la trace source entre l'indice de début
        et l'indice de fin de la portion (`sourceIdx`, voir C4), sans autre appel. Pour que deux
        portions voisines redonnent exactement le D+ de la trace, la trace source peut porter un
        cumul de montée par point, calculé par le serveur ; à concevoir (sinon, somme des
        différences positives des altitudes déjà filtrées par le pipeline).
      - **Après un re-routage partiel** (insertion, déplacement, suppression, B12) : seuls les
        segments remplacés reçoivent le `legAscend` de leur réponse ; les segments gardés, routés
        ou importés, gardent le leur. **D+ du tracé = somme des `legAscend` des segments routés +
        D+ des portions importées**, additionné à chaque `computeRoute`.
      - **Douglas-Peucker ne touche pas au chiffre** : il simplifie la géométrie, le D+ ne se
        recalcule jamais à partir des points simplifiés (c'est le défaut actuel de `getAscend`).
        Le point qui porte un `legAscend` (fin de segment) doit donc survivre à la simplification :
        un point de contrôle l'est déjà (`manual`), une borne de portion importée est à marquer de
        même (à concevoir).
      - **Écart assumé** avec le D+ du parcours enregistré, qui passe ensuite en HD (rattrapage
        d'`API-131`) : l'affichage d'édition est une estimation en FAST.
      - **Livré le 18 octobre 2026 (B1a).** Frontend seul, contrat inchangé.
        `PlannerElevationStrip` (bandeau de 160 px sous la carte : en bas du plein écran au
        desktop, sous l'emplacement de la carte en mode intégré ; au doigt, en-tête de 44 px avec
        bouton replier / déplier et D+, corps de 110 px au-dessus de `PlannerBottomBar`, choix
        mémorisé en `localStorage` sous try/catch). `plannerRouteToMappable` (index 1:1 avec
        `route.points`), `fillElevations`, `routeAscend` (remplace `getAscend`). `router()` rend
        `{ points, ascend }` ; `legAscend` se range sur le point qui termine la jambe, `importAscend`
        (cumul brut de `initialTrack` avant Douglas-Peucker, recalé sur `elevationGain` de la
        fiche, fil `initialAscend` jusqu'à `createRoute`). Survol : le profil pose un `HoverMarker`
        sur la carte (`planner-hover-marker`, `pointerEvents: none`), la carte surligne l'extrémité
        la plus proche du fantôme dans le profil ; la source du survol est mémorisée, seul un
        survol du profil dessine un marqueur. Défauts corrigés au passage : premier point sans
        altitude, `insert` qui ajoutait l'altitude du point inséré.
        - **Décisions du propriétaire (18 octobre 2026)** : **Q-A** D+ d'un tracé rouvert = cumul
          de montée par point sur tout `initialTrack`, recalé sur `elevationGain` (altitudes HD
          mêlées aux jambes FAST jusqu'à C4, écart assumé) ; **Q-B** bandeau de 160 px aussi en
          mode intégré au desktop ; **Q-C** D+ d'une ligne droite = max(0, altitude d'arrivée −
          départ) avec altitudes remplies par interpolation linéaire en distance, aux extrémités la
          plus proche connue ; tracé fait de lignes droites seules = 0 et bandeau « altitude
          inconnue ».
        - **Par défaut (non soumis)** : Q-D lignes droites en pointillés dans le profil
          (`dashedSegment`, prop facultative d'`ElevationChart`) ; Q-E bandeau mobile déplié par
          défaut ; Q-F pas de « ≈ » ; Q-G pas de zoom synchronisé carte / profil.
        - **Tests** : `planner.test.ts` (`describe('B1 elevation')`, trois tests qui figeaient les
          défauts réécrits, mock du routeur avec `ascend: 50`), `useRoutePlanner.test.tsx` (annuler /
          rétablir rend `legAscend` et `ascend`), `RoutePlannerField.test.tsx` (bandeau, repli au
          doigt, survol du profil vers le marqueur), `gpx-planner.e2e.ts` (`elevation profile while
          editing (B1)`, 6 scénarios dont le tracé rouvert aux valeurs réécrites).
        - **Écarts avec la spec** : survol à source (map / profile) plutôt qu'un simple index ;
          `onTouchEnd` / `onTouchCancel` sur le cadre (Chart.js n'écoute pas touchend) ;
          en-tête tactile de 44 px (et non 32) pour contenir le bouton ; `remove` entre deux
          bornes importées à moins de 5 m (saut sans appel au routeur) met `legAscend` à 0.
        - **Pièges** : `legAscend` doit être écrit après l'`await` comme `direct` ; il vaut
          `undefined` pour une ligne droite (la branche `direct` de `routeAscend` passe avant) ; la
          course du redimensionnement de la carte rend l'e2e du repli asynchrone (`expect.poll`) ;
          le test e2e « a user draws a route » peut échouer en `LOGIN_RATE_LIMITED` (429) en fin de
          longue série, il repasse seul.
        - **Reste (B1b)** : livré, ci-dessous. (La trace source FAST à l'envoi d'un GPX, `sourceIdx`
          et le cumul dead-band par point côté serveur sont livrés par C4a et C4b.)
      - **B1b livré le 19 octobre 2026.** Contrat **11.12.0**, pas de migration.
        - **Fait** : `POST /api/router/elevation` (`lineElevation`, `LineElevationService`) : pour
          chaque ligne droite (1 à 50), le chemin de 2 points passe par la chaîne complète de
          vcyclist (`processWithClimb` FAST : densification à 30 m, tunnels, lissage), sans Stadia ni
          stockage ; réponse `LineElevationResponse(lines: GpxImportTrack[], elevationFallback)`, un
          élément par ligne dans l'ordre. `PlannerTracks.toTrack` extrait de `GpxImportService`.
          Côté web : `RoutePoint.directProfile` (clé d'arête, échantillons, `ascend`) porté par le
          point d'arrivée, `withDirectProfiles` (sans Douglas-Peucker, mêmes `id`/`idx`),
          `straightEdgesMissingProfile`, `lib/plannerElevation.ts` (découpage, décodage, cache de
          session), effet de `useRoutePlanner` (application immédiate du cache, une requête groupée
          300 ms après le dernier changement, hors historique), bandeau qui déplie le relief sous une
          ligne droite (survol par indice du profil, `hoverPosition`).
        - **Décisions** : Q-C devient le **repli** (D+ du serveur quand on l'a, Q-C sinon ou en cas
          d'échec, sans message) ; appel paresseux en arrière-plan (A2) plutôt que dans le geste ;
          nouvel endpoint plutôt qu'un mode de `/api/router` (un ancien backend facturerait Stadia)
          ; bornes 50 lignes / 100 km par ligne / 200 km par requête (`ROUTING_SEGMENT_TOO_LONG`,
          contrôlées avant toute lecture du MNT), rien sous 10 m côté client ; profil non stocké dans
          l'état (version 1 inchangée, redemandé à la réouverture) ; pas d'indicateur de chargement ;
          tunnels aplanis acceptés ; un 404 ou 405 (ancien backend) coupe la fonction pour la session.
        - **Tests** : `RouterElevationResourceTest` (droits, validation dont `from` ou `to` absent et
          corps vide, bornes sans lecture d'altitude, forme de la réponse), `ArchitectureTest` ;
          `planner.test.ts`, `plannerElevation.test.ts`, `useRoutePlanner.test.tsx`,
          `useRoutePlannerImport.test.tsx`, `RoutePlannerField.test.tsx` ; e2e `gpx-planner`
          (`stubElevation`, décompte `elevationRequests` à côté de `routerRequests`, qui ne change pas :
          le glob `**/api/router` ne capte pas le nouvel endpoint).
        - **Écarts** : le survol d'un échantillon est perdu quand un profil arrive en arrière-plan
          (l'objet `Route` change) jusqu'au prochain mouvement de souris, accepté ; le routeur réel
          recale le point précédent sur la route, ce qui fait relire (gratuitement) la ligne droite
          qui y arrive, là où le routeur factice ne le fait pas.
- [ ] **B2. Inverser, aller-retour, retour au départ** (L, §8 n° 8) — trois opérations dans
      `lib/planner.ts`, passées par `executeRouteOperation` pour l'historique. Boutons dans la
      barre, raccourci dans le libellé. Dépend de A9 et de l'endpoint de recalage ci-dessous.
      - **Barre du bas pleine à 360 px depuis B6** (« Effacer » est déjà sorti dans l'en-tête du
        plein écran) : **menu « Plus »** (D8) — un bouton « … » de la barre ouvre un menu qui porte
        les trois opérations de B2 (et plus tard C3, C7) ; la barre garde annuler, rétablir, ligne
        droite, aide et « Terminer ».
      - **Retour au départ** (et non « boucle », que Komoot et Strava emploient pour un circuit
        proposé d'office, §11) : route un dernier segment du dernier point au premier, par le
        profil choisi. 1 requête.
      - **Inverser** : la trace inversée est recalée sur le réseau par un endpoint backend (Q6).
        **1 ou 2 requêtes** (un recalage, plus un raccord s'il reste des trous). Re-router entre les
        points de contrôle est écarté (Q6) ; inverser la géométrie seule (0 requête, faux sur les
        sens uniques) n'est que le repli.
      - **Aller-retour** : le retour est recalé de la même façon, avec le même repli (1 ou 2
        requêtes). Seul le retour est recalé, donc un aller-retour de plus de 200 km au total
        reste possible ; une inversion de plus de 200 km demande en revanche le découpage ci-dessous.
      - **Provenance (D1, 18 octobre 2026)** : un tracé recalé par B2, inversé ou aller-retour, est
        traité **comme un import**. C'est un morceau importé, avec sa propre trace source (la trace
        recalée que renvoie l'endpoint) ; ses points sont `imported` ; ses ancres servent de
        bornes, comme celles d'un fichier GPX (`spanBounds`, B12), et une suppression peut
        restituer la portion recalée (C4). Les points de contrôle de l'auteur, ré-ancrés sur la
        trace recalée, restent des points de contrôle (`manual`). Cela lève le conflit avec B12 :
        sans cela, `spanBounds` sauterait ces points et re-router irait d'un point de contrôle à
        l'autre. Pour l'inversion, tout le tracé devient un morceau importé ; pour l'aller-retour,
        l'aller garde sa provenance et seul le retour est un morceau importé.

      **Essais du 17 octobre 2026** (37 requêtes, GPX réels de 6 à 197 km, dont Nantes ; rapport
      complet, paramètres et seuils compris :
      [`../research/2026-10-17-stadia-map-matching.md`](../research/2026-10-17-stadia-map-matching.md),
      cité « étude » plus bas) :
      - `POST https://api-eu.stadiamaps.com/map_match/v1`, même en-tête `Stadia-Auth` et même
        costing que `/api/router`, `encoded_polyline` en précision 6, `shape_match: "map_snap"`
        (`walk_or_snap` donne la même réponse, `edge_walk` échoue en 443). 0,1 à 0,5 s.
      - Sens normal : fidèle à quelques mètres (+0,01 à +0,7 % de distance). **Trace inversée : un
        recalage seul ne suffit pas** (boucles et demi-tours à points espacés, +11 à +18 % ;
        coupures aux sens uniques, ronds-points, bretelles et points de contrôle à points denses,
        5 à 13 morceaux). La chaîne ci-dessous donne +0,1 à +2,6 % de distance sur quatre parcours,
        sans passage répété.
      - **Les GPX d'essai sont personnels et ne sont pas versés au dépôt public** (ils révéleraient
        des trajets) : les tests s'écrivent sur des **fixtures synthétiques** (traces et réponses
        Stadia fabriquées à la main, avec des `alternates` et une boucle).

      **Chaîne de recalage** (étude §4b et « Paramètres recommandés » ; à implémenter côté backend,
      1 ou 2 requêtes) :
      1. **Préparation** : la trace est inversée, dédoublonnée, simplifiée par Douglas-Peucker à 5 m
         (ce que fait déjà le planificateur ; 5 ou 20 m donnent la même fidélité) et **densifiée
         sur les segments de plus de 1 km** (deux points à plus de 2 km coupent la trace sans
         erreur) ; au moins 2 points. Corps : `costing` et `costing_options` du profil courant
         (comme `RouterProfile.getCostingOptions()`), `shape_match: "map_snap"`, `units:
         "kilometers"`, `encoded_polyline` en précision 6, pas de `trace_options` (sans effet
         mesuré). `directions_type: "none"` pour alléger la réponse (300 Ko pour 197 km) : **à
         essayer**, non testé.
      2. **Détection des trous** : on rassemble `trip` **et** `alternates[].trip` ; chaque
         discontinuité du recalage y renvoie un morceau de plus, qui est la suite de la trace, pas
         une variante. On les trie le long de la trace, on **écarte ceux de moins de 50 m** et on
         **rogne 100 m de chaque côté** de chaque trou. (`ValhallaResponse` ne lit aujourd'hui que
         `trip.legs[].shape` : il faut y ajouter `alternates` et `trip.summary.length`.)
      3. **Raccord** : **une seule** requête `route/v1` dont les locations sont `[fin₀, début₁,
         fin₁, début₂, …]`, en ne gardant que les legs pairs (0, 2, 4…), c'est-à-dire les trous,
         **sans `heading`** (la requête échoue en 442 avec). Au plus **24 trous** par requête (limite
         de 50 locations). Sans le rognage, un trou de 287 m a été relié par 8,6 km.
      4. **Nettoyage des boucles**, sans requête : quand le tracé repasse à **moins de 6 m** d'un
         point déjà parcouru, **entre 30 m et 3 km plus loin**, on coupe ce qui est entre les deux
         passages. Il **ne coupe ni un passage que la trace brute fait elle-même deux fois** (protégé
         si elle passe deux fois au même endroit à moins de 8 m), **ni un point de contrôle** : il a
         supprimé un éperon de 950 m qui menait à un point de contrôle, d'où l'écart de 356 m de
         `plan2_rev_final`.
      5. **Pipeline et ré-ancrage** : le résultat passe dans `GpxPipeline.process(…, "route",
         ElevationQuality.FAST)` (3D, `dist`, `ascend`, comme `/api/router`), puis chaque point de
         contrôle est ré-ancré sur le point le plus proche de la trace recalée, en gardant l'ordre.
      6. **Repli** sur la géométrie inversée brute, avec un avertissement (`fallback`), en cas
         d'**erreur Stadia**, de **longueur nulle** (trois points identiques rendent un 200 de
         longueur 0), de **raccord échoué**, ou de **résultat plus long de 25 %** que la trace
         inversée (**seuil à calibrer**).
      7. **Avertissement de détour** : tout écart de plus de 50 m avec la trace inversée est
         signalé à l'auteur (3,5 km de détour pour un trou de 500 m ont été vus sur une piste
         cyclable unidirectionnelle) ; le client les surligne.
      8. **Au-delà de 200 km** (code 154, comme le routage ; 16 000 points, code 153) : découper en
         tronçons de **190 km au plus, recouvrants d'environ 1 km**, recoller au premier point du
         recouvrement où les deux recalages coïncident (moins de 5 m), puis passer le même nettoyage.
         **Non testé** : le budget d'essai ne le permettait pas. Tant qu'il n'est pas fait, une
         inversion de plus de 200 km est refusée en `ROUTING_SEGMENT_TOO_LONG`.
      9. **Risques connus** : seuils (6 m, 30 m à 3 km, 100 m, 50 m) réglés sur cinq cas seulement ;
         une portion hors réseau est sautée sans erreur et le raccord peut y inventer un itinéraire ;
         un changement de version de Valhalla chez Stadia peut changer les boucles et les coupures.

      **Endpoint de recalage — proposition, à valider par le propriétaire** (volet backend, reste
      sous `WEB-100`, D4) :
      - **Chemin** : `POST /api/router/match`, dans `RouterResource` (`@Path("/api/router")`,
        `@RolesAllowed("user")`), service `RouterMatchService` voisin de `RouterService`, avec le
        post-traitement géométrique (boucles, rognage, ré-ancrage) dans une classe pure testable sans
        Stadia.
      - **Requête** `RouterMatchRequest` : `track` (`List<GeoPoint>`, de 2 à
        `GpxLimits.MAX_PLANNER_POINTS` points, **dans le sens à recaler** : le client inverse),
        `profile` (`RouterProfile`, le profil courant du planificateur), `teamSlug` facultatif (mêmes
        règles que `RouterRequest`), `controlPointIndices` facultatif (indices dans `track` des
        points de contrôle à protéger du nettoyage et à ré-ancrer ; triés, dans les bornes, sinon
        400).
      - **Réponse** `RouterMatchResponse` : `route` (LineString 3D, `GeoJsonLineString` comme
        `RouterResponse`), `dist`, `ascend` (FAST), `controlPointIndices` (indices dans `route` des
        points de contrôle ré-ancrés, même ordre), `fallback` (booléen) et `detours` (liste de
        `{fromIndex, toIndex, length}` pour les écarts de plus de 50 m).
      - **Contrôles avant tout appel facturé**, les mêmes que `/api/router` : `checkPlannerAllowed`
        de `RouterService` (privé aujourd'hui : à partager, par exemple en l'extrayant dans un
        composant commun) — avec équipe, du domaine (404 sinon), droit de créer un parcours (403
        sinon) puis `enableRoutePlanner` ; sans équipe, `enableGpxPlanner` du domaine
        (`ROUTE_PLANNER_DISABLED`) —, puis les bornes de taille.
      - **Erreurs** (réutiliser `RouterService.toRoutingException` pour la lecture du code
        Valhalla) : `429` → `ROUTING_QUOTA_EXCEEDED` (503) ; code 154 → `ROUTING_SEGMENT_TOO_LONG`
        (400, tant que le découpage n'est pas fait) ; les autres refus de recalage (443, 444, 445,
        171, 442) et les 5xx ou délais ne sont **pas** des erreurs pour l'auteur : repli en 200 avec
        `fallback = true`, pour qu'inverser reste possible. À valider : `ROUTING_UNAVAILABLE` n'est
        alors renvoyé que si le repli lui-même est impossible.
      - **Client Stadia** : `StadiaMapsClient` porte `@Path("/route/v1")` sur l'interface, donc une
        seconde méthode en `/map_match/v1` y donnerait `/route/v1/map_match/v1`. Proposition : une
        **seconde interface** `StadiaMapsMatchClient` (`@Path("/map_match/v1")`, même `configKey =
        "stadiamaps"` donc mêmes URL et délais, même `@ClientHeaderParam` d'autorisation), et un
        record de requête propre (`ValhallaMatchRequest`). Le raccord réutilise
        `StadiaMapsClient.route`.
      - **Contrat** : la version actuelle est `11.8.0` (`pedalons.api.version`, `application.properties`) ;
        un nouvel endpoint est une mineure, donc **`11.9.0`** si rien d'autre ne passe avant. Passer
        par la skill `contract-first-api`. Côté client, `signal` transmis comme pour `router()`.
      - **Coût** : 1 ou 2 requêtes facturées (jamais N). Annuler, rétablir et refaire ne rejouent
        rien.
- [x] **B6. Ligne droite comme état visible** (M, §8 n° 10, 18 octobre 2026) — bascule « Ligne
      droite » (colonne de contrôles à la souris, barre du bas au doigt) en plus du modificateur ;
      `direct: boolean` sur `RoutePoint`, porté par le point d'arrivée de l'arête, posé après
      l'`await` de chaque opération (`add`, `insert`, `remove`) ; `legsGeojson()` (`geojson()` reste
      une LineString, cinq consommateurs en dépendent) regroupe les arêtes de même nature, et la
      couche `route-line-direct` (`line-dasharray`) rend les tronçons droits en pointillés. C'est
      l'équivalent tactile du `Ctrl`. **C4 en dépend** (seul B6 crée l'information « ligne droite ») ;
      B6 ne dépend pas de C4 (Q7).
      - **Mode effectif** = touche OU bascule, fait dans le hook (`directModeRef`), pour `add`,
        `insert`, déplacement, suppression d'un point et d'une ancre. La bascule dure la session
        d'édition (survit au passage formulaire / plein écran), n'est ni stockée ni dans
        l'historique.
      - **Héritage à la suppression** : le raccord est droit si la touche ou la bascule le demande,
        **ou si tous les tronçons remplacés sont droits** (`isStraightSpan`) : aucun tronçon routé
        n'est perdu, 0 requête. Tronçons mixtes ou portion importée : 1 requête. Coupure du départ
        ou de l'arrivée : pas de raccord.
      - **Insertion et déplacement : mode courant, sans héritage** (touche OU bascule).
        **Tranché par le propriétaire (D6)** : l'alternative « hériter OU mode », plus proche de
        Komoot pour un polygone hors réseau, est écartée : elle rendrait impossible de re-router un
        tronçon droit autrement qu'en supprimant puis rajoutant le point.
      - **Avertissement à l'enregistrement, par tronçon** : dès qu'**un** tronçon droit dépasse
        300 m (`DIRECT_WARNING_METERS`), une alerte jaune non bloquante sous la carte (souris) ou
        l'aperçu (doigt) donne le total et le plus long. Le critère est le tronçon, pas le cumul :
        une ligne droite courte franchit un trou du routeur, une place, une passerelle ; un cumul
        gênerait à tort un parcours gravel fait de petits raccords.
      - **Q7** : un tracé chargé ou importé est entièrement « importé » et se dessine en trait
        plein, sans avertissement ; C4 rétablira ses pointillés.
      - **Barre du bas à 360 px** : avec la bascule elle débordait (≈ 382 px) ; « Effacer » est passé
        dans la barre d'outils du plein écran au doigt (≈ 328 px). **B2 (inverser) retombera sur ce
        problème** : réglé par le menu « Plus » (D8).
      - **Reste pour B1** : un point de ligne droite n'a pas d'`ele`, `getAscend` le compte à 0 m
        (défaut existant) ; B1 pourra colorer les tronçons `direct` d'après le même champ.
      - Tests : `lib/planner.test.ts` (`B6 straight lines`), `useRoutePlanner.test.tsx`,
        `RoutePlannerField.test.tsx`, `gpx-planner.e2e.ts` (`straight lines, visible (B6)`).
      - **Livré le 18 octobre 2026.** `direct` sur `RoutePoint`, `legsGeojson()` et la couche
        `route-line-direct` en pointillés, bascule `DirectModeControl` (colonne de contrôles à la
        souris, barre du bas au doigt, aide `PlannerHelpControl`), mode effectif dans le hook,
        héritage à la suppression, avertissement par tronçon à l'enregistrement. Tests : 1030
        unitaires (114 fichiers) ; e2e `gpx-planner` 50 passés, 14 ignorés (projets desktop et
        mobile), 0 échec. Écarts : « Effacer » déplacé dans l'en-tête du plein écran au doigt ;
        l'insertion et le déplacement n'héritent pas (confirmé, D6). Pièges : au
        doigt, après « Terminer », avec un point déjà posé le bouton d'ouverture s'appelle « Modifier
        le tracé » et non « Tracer le parcours » ; un test de borne sur un tracé importé ne prouve
        rien sur `direct` (tout y vaut `false`), partir d'un tracé qui a déjà un tronçon droit.
- [x] **B7. Clavier et accessibilité des points** (S/M, §8 n° 12) — marqueurs `role="button"`,
      `tabIndex`, `Suppr` ou retour arrière pour supprimer, `Échap` qui ferme panneaux, menu et
      recherche (L2-1, lot 1) ; **livré avec B9 le 18 octobre 2026** :
      - Nom « Point n sur m », « Départ, point 1 sur m », « Arrivée, point m sur m » (variable
        `total`, jamais `count`) ; départ en disque vert avec une flèche de lecture, arrivée en
        carré rouge avec un drapeau, via en disque bleu (`markerRole`, `plannerMarker.ts`).
        `StartMarker` et `EndMarker` (lecture seule) ne changent pas : hors périmètre.
      - Les flèches déplacent le point focalisé (10 px, 50 px avec Maj, `useKeyboardPointMove`) :
        l'aperçu est celui du glisser (marqueur, lignes de liaison, bornes figées au premier pas),
        le routage a lieu **une fois par rafale** (500 ms après le dernier relâchement, ou à
        `Entrée` ou à la perte du focus) : 2 requêtes, 1 à une extrémité. Le point garde son `id`
        (`insert(…, keepId)`, aussi au glisser souris) : le marqueur n'est pas remonté, le focus
        reste. Alt, Ctrl et Meta + flèche ne sont pas traités. `Échap` abandonne, sans requête.
        Une rafale est annulée si la route change (Ctrl+Z) ou au premier geste au pointeur.
      - Après `Suppr`, le focus va au voisin ; après une insertion, les enveloppes MapLibre sont
        remises dans l'ordre des points (l'ordre de Tab suit les points).
      - `Échap` pendant un geste au pointeur : le fantôme est abandonné sans requête ; le marqueur
        glissé à la souris est retenu à son origine jusqu'au relâchement (MapLibre n'a pas d'API
        d'annulation), sans requête ; l'ancre au doigt est abandonnée.
      - Aide : une ligne clavier, à la souris seulement.
      - Tests : `useKeyboardPointMove.test.ts`, `plannerMarker.test.ts`, `planner.test.ts`
        (`keepId`), `useRoutePlanner.test.tsx` (une entrée d'historique), `gpx-planner.e2e.ts`
        (`keyboard and accessibility of the points (B7)`, lancé le 18 octobre, 0 échec).
      - **Écarts** : (1) `Échap` pendant un glisser **à la souris** dans `CreateRouteModal` en
        mode intégré ferme aussi le formulaire : Mantine écoute `Échap` sur `window` en capture et
        passe avant nous, seule la cible `data-mantine-stop-propagation` l'évite (posée pendant une
        rafale de flèches, impossible pour un glisser souris) ; la recette manuelle reste à faire.
        (2) L'ordre du DOM est rétabli par un effet passif (pas `useLayoutEffect`) pour
        remettre le DOM dans l'ordre : le `addTo` de react-map-gl est lui-même passif, un marqueur
        inséré n'existe pas encore au moment d'un effet de mise en page. (3) L'origine du marqueur retenu est `route.points[idx]`, pas `event.lngLat` de `dragstart`
        (émis après le premier mouvement : décalage d'environ 14 px). (4) Le contournement
        d'`Échap` sur un marqueur glissé à la souris n'a pas pu être éprouvé sans e2e : à
        retirer, en gardant le fantôme, s'il se bat avec MapLibre.
- [x] **B9. Défilement au bord pendant un drag** (S/M, nouveau) — **livré le 18 octobre 2026** :
      à moins de 40 px du bord (au plus le quart de la carte), `panBy(…, { animate: false })` à
      chaque frame, vitesse linéaire jusqu'à 600 px/s sur le bord (`lib/edgePan.ts`,
      `useEdgeAutoPan`) ; le point reste sous le doigt ou la souris (`flushSync`). Marqueur
      (souris et doigt), fantôme (souris), ancre (doigt). Armé après 3 px de mouvement (une simple
      saisie près du bord ne défile pas) ; un second doigt bloque (`block`) ; la sortie de la carte
      à la souris suspend (`onPointerLeave`), un `pointerup` sur `window` termine. Les bornes
      restent celles du début du geste (aucune requête pendant le défilement) : un dépôt lointain
      peut donner `ROUTING_SEGMENT_TOO_LONG`, voulu. Tests : `edgePan.test.ts`,
      `useEdgeAutoPan.test.ts`, `gpx-planner.e2e.ts` (`scrolling at the edge during a drag (B9)`,
      lancé le 18 octobre : 5 cas par projet, 0 échec). Écart : le second doigt est envoyé en e2e par `touchStart` puis
      `touchMove` à deux points CDP (éprouvé depuis : voir les pièges).
      **Livré le 18 octobre 2026** (corrections de revue) : l'armement (3 px) se mesure depuis le
      **pointeur** (`event.lngLat` à la souris, `map.unproject(event.point)` au doigt), jamais
      depuis l'ancre ou le point accroché de la trace (jusqu'à 22 et 15 px du doigt ou de la
      souris : une simple saisie près du bord aurait défilé, puis le clic d'un toucher aurait
      inséré ailleurs). Les écouteurs `pointerup`/`pointercancel` de `window` sont posés de
      `begin` à `end` (plus seulement pendant la boucle) : un relâchement hors de la carte, après
      la sortie de la souris, désarme (sinon le retour dans la zone de bord, bouton relevé,
      relançait le défilement). Tests : `useEdgeAutoPan.test.ts` (relâchement après `stop`),
      e2e 70 passés, 28 ignorés (desktop et mobile). **Pièges** : (1) les contrôles de la carte
      (zoom, annuler…) avalent `mouseup`/`mousemove` : un glisser à la souris vers le bord
      gauche ne se relâche jamais pour MapLibre, les tests visent le milieu du bord haut ;
      (2) le second doigt doit atterrir au milieu de la carte, hors contrôles, sinon aucun
      `touchstart` n'atteint la carte ; (3) relâcher un marqueur au-dessus d'un contrôle laisse
      le glisser en cours (antérieur à B9, non traité).
- [x] **B11. Glisser une ancre au doigt** (S, nouveau, 18 octobre 2026) — un appui à moins de
      22 px d'une ancre visible la saisit au lieu de faire défiler la carte (`preventDefault` sur
      le `touchstart` MapLibre) ; au relâchement, les deux segments voisins sont routés à nouveau
      (2 requêtes, comme le glisser du fantôme à la souris) ; un toucher sans mouvement reste une
      insertion. Ancres plus grosses au doigt (rayon 8 px). Seuls les points de contrôle et
      « Démarrer ici » écartent le geste : une borne kilométrique posée sur une ancre ne
      l'empêche pas. Test : `gpx-planner.e2e.ts`, angle d'un tracé en L.
- [x] **B12. Bornes d'un geste indépendantes du zoom, et suppression d'une ancre** (M, nouveau) —
      étude du 18 octobre 2026 ([`../research/2026-10-18-editeur-parcours-suppression.md`](../research/2026-10-18-editeur-parcours-suppression.md)). Aujourd'hui chaque geste recalcule entre le premier point de
      contrôle ou la **première ancre visible au zoom courant** de part et d'autre
      (`findAnchorStartPoint` / `findAnchorEndPoint`, `hooks/useRoutePlanner.ts`) : le même geste
      donne un autre résultat selon le zoom. Mesures, routeur simulé : supprimer un point
      intermédiaire efface son détour au zoom 10, mais le laisse aux zooms 12 à 16 ; supprimer le
      départ d'un import de 40 km aux zooms 9 à 12 ne laisse que l'arrivée ; une insertion
      remplace 56 des 58 points d'un import au zoom 9, 7 au zoom 13 ; Douglas-Peucker recalculé
      sur tout le tracé après chaque geste fait apparaître ou disparaître des ancres loin du geste.
      **Décisions du propriétaire** (18 octobre 2026) :
      - **Provenance des points** : un champ `imported` sur `RoutePoint`, vrai pour les points
        d'un tracé chargé ou importé **et pour ceux d'un tracé recalé par B2** (D1), faux pour ceux
        du routeur. Deux fonctions de bornes pures dans `lib/planner.ts` : `legBounds` (premier
        point manual ou importé de chaque côté, sans zoom) et `spanBounds` (premier point manual, ou
        importé et visible au zoom courant ; les points du routeur toujours sautés).
      - **Supprimer ou déplacer un point de contrôle intermédiaire** : `legBounds`, d'un point de
        contrôle au suivant sur un tracé dessiné, aux raccords sur un import (1 requête, 2 pour un
        déplacement). « De point de contrôle à point de contrôle » à la lettre est écarté : un point
        inséré puis supprimé re-routerait tout un import, une boucle importée s'effondrerait.
        Depuis C4a (`sourceIdx`, indice source par point), supprimer entre deux raccords du
        **même import** rend la portion du fichier : **0 requête au lieu de 1** ; B12 s'est livré
        d'abord avec la requête.
      - **Supprimer le départ ou l'arrivée** : couper jusqu'à l'ancre visible (0 requête), refuser
        si le tracé tomberait sous deux points. **La fonction de bornes est `spanBounds`**, prise en
        partant du point supprimé vers l'intérieur du tracé, au zoom figé au début du geste. **Les
        points du routeur ne comptent jamais comme borne** : sur un tracé dessiné, la borne est donc
        le point de contrôle suivant, à tout zoom ; sur un tracé importé, c'est la première ancre
        visible (étude, R3). Sur un tracé mixte, la première borne rencontrée, point de contrôle ou
        ancre importée visible.
      - **Supprimer une ancre** : seulement sur un tracé importé (sur un tronçon routé, re-router
        entre ses voisines redonne le même chemin ; l'ancre y reste une poignée à glisser) ; entre
        les ancres visibles, au zoom figé au début du geste ; 1 requête, 0 avec Alt (ligne droite).
      - **Geste** : un menu « Supprimer », par clic droit au desktop (un marqueur à moins de 20 px a
        la priorité ; Ctrl + clic sur Mac ignoré) et par appui long de 500 ms au doigt (22 px,
        annulé au-delà de 3 px), avec les deux bornes affichées pendant le menu ; le relâchement
        n'insère rien et ne ferme pas le menu. Ce menu accueillera « Ajouter un point de parcours »
        (C3). **Le clic droit sur un point de contrôle garde son comportement actuel** : suppression
        immédiate, sans menu (`handleMarkerRightClick` dans `RoutePlanner.tsx`, qui ignore un
        `contextmenu` venu d'un doigt et Ctrl + clic sur Apple) ; l'étude (S5) ne le change pas, le
        menu ne concerne que les ancres.
      - **Retenus par défaut, sauf avis contraire** : insérer et glisser sans dépendre du zoom sur
        un tronçon routé (`spanBounds`) ; Douglas-Peucker recalculé seulement entre les bornes du
        geste ; raccord en ligne droite selon la touche tenue lors de la suppression (hérité des
        tronçons depuis B6, livré).
      - **Défauts trouvés par l'étude, à corriger avec** : un toucher sur le tracé peut viser un
        point de contrôle et le remplacer (la recherche des bornes exclut le point visé) ; un
        second doigt pendant le glisser d'une ancre ne l'annule pas.
      Aucun geste ne coûte plus qu'avant ; des requêtes plus longues rendent possible
      `ROUTING_SEGMENT_TOO_LONG`, qui laisse le tracé intact avec son message.
      **Tests : dix cas de `lib/planner.test.ts`** (étude §5), avec un routeur simulé qui trace un
      arc et une fixture importée aux ancres de niveaux connus :
      1. `createRoute` marque les points importés ; `add`, `insert` et `remove` produisent des
         points non importés ; l'instantané garde le champ ;
      2. `legBounds` sur un tracé dessiné rend les points manual voisins, au même résultat aux zooms
         0, 12 et 22 ;
      3. suppression d'un point de contrôle sur A → M → C au zoom 16 : une seule requête de A à C et
         le détour disparaît (la régression actuelle) ;
      4. la même sur un import : M inséré puis supprimé, les points importés hors des bornes gardent
         leur `id` et leurs coordonnées ; sur une boucle importée, le tracé ne s'effondre pas ;
      5. suppression du départ ou de l'arrivée : sur un tracé dessiné, coupe au point manual suivant
         à tout zoom, sans requête ; sur un import sans ancre visible, refus (tracé inchangé, aucune
         requête) ; avec une ancre visible, coupe à cette ancre ;
      6. suppression d'une ancre importée : une requête entre les voisines visibles, l'ancre et les
         points cachés disparaissent, 0 requête en ligne droite, un signal déjà abandonné n'envoie
         rien ;
      7. insertion : sur un tronçon routé, 2 requêtes depuis A et vers B à tout zoom ; sur un import,
         la portée visible est conservée (deux zooms, deux portées) ;
      8. déplacement d'un point de contrôle : utilise `legBounds` ;
      9. défaut 1 : une insertion près d'un point manual garde ce point ;
      10. recalcul local de Douglas-Peucker : les niveaux de zoom des points hors des bornes ne
          changent pas.

      Les cas existants de `remove` restent ; on y ajoute les vérifications de `from` et `to`, et le
      cas « insert used as a move » passe à `legBounds`. Et six scénarios e2e (clic droit et Alt +
      clic droit sur l'angle du tracé en L, appui long dont le relâchement n'insère rien, appui puis
      mouvement qui reste un glisser, suppression après un zoom avant, annulation gratuite).

      **Livré le 18 octobre 2026.** Champ `imported` sur `RoutePoint`, `legBounds` / `spanBounds` /
      `nearestSegment` dans `lib/planner.ts` (Douglas-Peucker recalculé entre les bornes seulement,
      `PlannerRefusedError` pour la coupe refusée), `removeControlPoint` / `removeAnchor` dans le
      hook, menu « Supprimer » au clic droit et à l'appui long, bornes affichées pendant le menu
      (`RoutePlanner.tsx`), textes fr et en. Tests : les dix cas de `planner.test.ts` (plus un
      onzième pour `nearestSegment`), quatre cas de `useRoutePlanner.test.tsx` (borne de
      `removeControlPoint`, refus de coupe, `removeAnchor` et son annulation à 0 requête) et les
      scénarios de `gpx-planner.e2e.ts`. **Écarts, confirmés par le propriétaire** (D5, D7) : (1) le refus de couper ne vaut
      que pour un tracé qui contient des points importés, pas pour tout tracé qui tomberait sous deux
      points (sur un tracé dessiné, supprimer un à un les derniers points reste possible) ;
      (2) `nearestSegment` teste les segments voisins de six sommets proches, pas du seul plus
      proche : une approximation, qui suffit tant que les sommets sont répartis (jamais deux fois le
      même détour sur un très long segment droit) ; (3) le glisser d'un point de contrôle ignore un
      relâchement dont les bornes ont été effacées par un second doigt.
      **Pièges trouvés par l'e2e** : Chrome retient les `touchmove` d'un toucher dont le
      `touchstart` n'a pas été annulé tant qu'ils restent sous ~15 px, donc l'appui sur une ancre
      est aussi suivi par ses événements pointeur (`followAnchorPress`), sans quoi un mouvement de
      4 px laisserait le menu s'ouvrir ; et les bornes kilométriques (`KmMarker`, partagé avec les
      cartes en lecture) passent en `pointerEvents: 'none'`, sans quoi un doigt posé sur l'une
      d'elles fait défiler la page au lieu d'attraper l'ancre dessous.

---

## 8. Lot 4 — différenciation

Les parties API sont décrites au §8 de l'état de l'art ; ce plan ne garde que la face web, plus,
pour C4, le volet backend. **C6 n'est pas attribué.** Les tâches C1, C2, C3, C5 et C7 sont **à concevoir avant de commencer** : leurs
questions ouvertes viennent du §10 de
[l'état de l'art](../research/2026-10-17-editeur-parcours-etat-de-l-art.md).

- [x] **C2. Éviter les côtes, éviter le trafic** (S côté web, §8 n° 14) — **livré le 19 octobre 2026.**
      Deux `Slider` (« Côtes », « Trafic ») dans le panneau de profil (A6), `useHills` / `useRoads`
      facultatifs dans `RouterRequest`, contrat **`11.9.0`**. Ne dépend d'aucun morceau du lot 3.
      - **Livré le 19 octobre 2026.** Décisions du propriétaire : **Q1** le curseur remplace la valeur
        du profil, absent = valeur du profil (appel Valhalla identique à l'octet près), les autres
        options du profil restent ; **Q2** mémorisation par profil ; **Q3** 5 crans (0, .25, .5, .75,
        1), mots aux extrémités (« Éviter » / « Indifférent », « Pistes » / « Routes »), aucun chiffre,
        lien « Valeurs du profil » ; **Q4** contrat `11.9.0`. Défauts : **Q5** rien pour RUN_HIKE ni
        MOTORCYCLE (curseurs cachés, champs ignorés par le backend hors costing `bicycle`) ; **Q7** C4
        n'enregistre pas le réglage par tronçon ; **Q8** pas de re-routage du tracé existant ; **Q9**
        pastille sur le bouton du panneau si réglage non standard.
      - **Backend** : `RouterRequest.useHills` / `useRoads` (`@DecimalMin 0`, `@DecimalMax 1`,
        nullables) ; `RouterService` fusionne dans une copie des `costingOptions` du profil
        (`use_hills`, `use_roads`) seulement si le costing est `bicycle`. Hors bornes : 400 avant tout
        appel Stadia. Un ancien backend ignore les champs (Jackson), donc déploiement roulant sans
        erreur. Clients Dart et TS régénérés.
      - **Frontend** : `lib/routerTuning.ts` (`PROFILE_DEFAULTS`, miroir de `RouterProfile.java`,
        nettoyage de la valeur stockée : non numérique, hors [0, 1] ou égale à celle du profil =
        absente), `RouterSettings` dans `planner.ts`, `useRoutePlanner` (`routerTuning`,
        `setRouterTuning`, clé `pedalons-router-tuning`, par profil ; un curseur annule le vol en
        cours, ne re-route rien, hors historique). Curseurs : valeur validée au relâchement
        (`onChangeEnd`), `size="lg"` au doigt, `aria-valuetext` en mots (`thumbValueText`), régler ne
        ferme pas le panneau. La pastille est visuelle ; l'état « réglage différent » est dans le nom
        accessible du bouton.
      - **Essais Stadia** (Givors → Lyon Confluence, environ 19 km, `bicycle` `road`, `use_roads`
        0,5, seul `use_hills` change) : 0,0 donne 19,44 km, 3023 s, altitude 156 à 199 m, tracé de
        vallée (D315, Vernaison, Irigny) ; 1,0 donne 18,90 km, 2879 s, 155 à 298 m, tracé par le plateau
        (Millery, Charly), jusqu'à 2,9 km d'écart au milieu. **Les curseurs changent donc bien le
        tracé sur un long tronçon**, pas sur un court (premier essai, 3,7 km à Lyon : seul le coût
        change). La réponse ne porte aucune montée : il faudrait la calculer à partir de
        `legs[].elevation` (un point tous les 30 m), avec un seuil d'hystérésis de 5 à 10 m (somme
        brute : 300 m pour un tracé entre 156 et 199 m). Le coût ne se compare pas d'un réglage à
        l'autre. Effet contre-intuitif : `use_hills` 1,0 est ici le plus court et le plus rapide,
        éviter les côtes coûte des kilomètres. L'aide l'écrit honnêtement (« Éviter les côtes peut
        rallonger la sortie »).
      - **Tests** : `planner.test.ts`, `routerTuning.test.ts`, `useRoutePlanner.test.tsx`,
        `RouterProfileSelector.test.tsx`, e2e « avoiding hills and traffic (C2) » (réglage sans
        requête, appliqué au tronçon suivant, mémorisé au rechargement). Backend, **écrits mais non
        lancés** (règle du CLAUDE.md) : `RouterResourceTest` (champs absents = options du profil,
        FASTBIKE + `useRoads`, BIKE + `useHills` 0, 400 hors bornes sans appel Stadia, profils non
        vélo, clés Jackson) ; à lancer par le propriétaire.
      - **Écart** : pas de D+ affiché pour le réglage (le routeur ne le renvoie pas, voir ci-dessus).
- [x] **C4. Conserver l'état d'édition à l'enregistrement** (L, §8 n° 11, élargi le 18 octobre
      2026) — aujourd'hui le client n'envoie qu'une liste de points (`fromPoints`,
      `GpxProcessingService`), que la chaîne GPX rééchantillonne et simplifie ; à la réouverture,
      seuls le départ et l'arrivée redeviennent des points de contrôle, et les points
      intermédiaires de l'auteur, la provenance des points et les lignes droites sont perdus.
      **Dépend de B6** (seul B6 crée l'information « ligne droite », `direct` sur `RoutePoint`) **et
      de B12** (la provenance `imported`) ; B6 et B12 ne dépendent pas de C4 (Q7). **Décisions du propriétaire** (18 octobre 2026) :
      - **Un état du planificateur stocké à part**, colonne JSONB facultative sur les pistes d'un
        parcours d'équipe (`gpx_tracks`, D3) et sur les aperçus des outils GPX (`gpx_previews`,
        colonne propre ; migration additive). Il contient une version de format, le profil de
        routage, et **une suite de morceaux** : chacun a un mode (routé, ligne droite, importé) et
        une géométrie (polyline précision 6) ; chaque jonction est soit un point de contrôle, soit
        un raccord (là où un import a été coupé). **Un morceau issu d'un recalage de B2 a le mode
        « importé »** (D1) : sa trace recalée est sa trace source.
      - **Trace source + plages** : l'état garde une fois la trace du fichier importé (simplifiée à
        quelques mètres) ; un morceau importé en désigne une plage d'indices au lieu de recopier sa
        géométrie.
      - **Le serveur dérive le tracé de l'état** : le client envoie l'état, le serveur concatène
        les morceaux et passe le résultat dans la chaîne GPX habituelle — une seule source, l'état
        et le tracé enregistré ne peuvent pas diverger.
      - **Restauration sans re-routage** (Q7) : l'éditeur relit l'état tel quel, ancres et
        provenance comprises ; zéro requête.
      - **Supprimer un point entre deux raccords du même import rend la portion du fichier**, sans
        requête ; on ne re-route que lorsque les bornes ne viennent pas du même import.
      - **Un aperçu devenu parcours d'équipe garde son état**, trace source comprise.
      - Un parcours sans état (ancien, ou importé d'un fichier) s'édite comme un import : un seul
        morceau importé du départ à l'arrivée. Un nouvel import de fichier remplace l'état.
      - L'état ne sert qu'à l'édition : un endpoint à part, appelé par la page de modification
        seulement ; ni les listes ni la fiche d'un parcours ne le portent.
      Exemple : un GPX de A à B, puis un glisser jusqu'à P entre les ancres a1 et a2, donne quatre
      morceaux — A→a1 importé, a1→P routé, P→a2 routé, a2→B importé —, A, P et B points de
      contrôle, a1 et a2 raccords. Supprimer P rend la portion du fichier entre a1 et a2.

      **Règle d'éditeur** : « rendre la portion du fichier » suppose un **indice source par point**
      (`sourceIdx` sur `RoutePoint`, indice du point dans la trace source de son import) et la
      **trace source gardée en mémoire** par l'éditeur (lue de l'état, ou de la réponse du serveur
      à l'envoi du fichier). Cela **modifie la suppression de B12** : entre deux raccords du même
      import (deux `sourceIdx` du même import), supprimer un point de contrôle recopie les points
      source de a1 à a2, **0 requête au lieu de 1** ; la requête de B12 ne reste que pour des bornes
      qui ne viennent pas du même import. `sourceIdx` sert aussi à B1 (D+ d'une portion importée).
      Lien avec B12 : la provenance d'un point se déduit du mode de son morceau ; B12 se livre sans
      C4 (un parcours rouvert est alors tout entier importé), C4 lui apporte la fidélité après
      enregistrement.

      **Backend — propositions, validées telles quelles par le propriétaire le 19 octobre 2026** (volet
      qui reste sous `WEB-100`, D4 ; livré par C4a, ci-dessous) :
      - **Colonnes** : `planner_state jsonb` (facultative) sur `gpx_tracks` (D3 : un tracé
        remplacé emporte son état) et sur `gpx_previews` (colonne propre aux aperçus des outils
        GPX). Dans les entités `GpxTrack` et `GpxPreview`, en `JsonBinaryType` comme `track_points`
        et `tracks`. Pour un parcours, l'état se range sur la **première piste** : le planificateur
        n'en produit qu'une ; un parcours à plusieurs pistes (GPX multi-traces) n'a pas d'état.
      - **Migration** : la dernière est `V74__elevation_refresh.sql`, la prochaine est donc
        `V75__planner_state.sql`, **purement additive** : deux `alter table … add column
        planner_state jsonb`, nullable et sans défaut. La version précédente ignore la colonne
        (déploiement roulant, start-first) : elle ne la lit ni ne l'écrit. Même forme que `V72`.
      - **Lecture** (réservée à l'édition) : `GET /api/teams/{teamSlug}/routes/{routeSlug}/planner-state`,
        avec les droits de l'édition du parcours (`@CheckAccess(entityType = ROUTE, action =
        UPDATE)`, comme `updateRoute`) ; `GET /api/gpx-previews/{previewId}/planner-state` pour un
        aperçu. 404 (ou corps vide) s'il n'y a pas d'état ou s'il est périmé (voir le jeton) : le
        client retombe sur un import d'un seul morceau. **À décider pour l'aperçu** : `getPreview`
        est `@Public` (le lien suffit à lire), mais l'état ne sert qu'à l'édition et la trace source
        n'a pas à être publique ; proposition : **le créateur seul lit**, comme lui seul écrit
        (`updatePreview` refuse les autres en 403). L'état n'apparaît ni dans `RouteDto`,
        `RouteDetailDto`, `GpxPreviewDto` ni dans les listes.
      - **Écriture** : pas d'endpoint dédié, l'état voyage avec le tracé pour que les deux soient
        écrits dans la même transaction. `RouteRequest` (création et modification d'un parcours),
        `GpxPreviewFromPointsRequest` et `GpxPreviewUpdateRequest` reçoivent `plannerState`
        (facultatif). Le serveur en dérive le tracé (concaténation des morceaux, puis
        `GpxProcessingService.fromPoints` et la chaîne habituelle, comme pour `points`). **Que
        devient `points`** : il reste accepté tel quel pour les clients sans état (ancien bundle
        pendant un déploiement roulant) et laisse l'état vide ; envoyé avec un état, c'est une
        erreur 400 (`PLANNER_STATE_INVALID`) ; `@NotEmpty` de `GpxPreviewFromPointsRequest.points`
        devient « `points` ou `plannerState` ». Un fichier (`gpxFile`) l'emporte sur l'un et l'autre,
        comme il l'emporte sur `points` aujourd'hui.
      - **Bornes de taille** : nombre de morceaux maximal **à fixer** (à mesurer sur des parcours
        réels) ; points de la trace source au plus `GpxLimits.MAX_PLANNER_POINTS` (100 000, le plafond
        de `points`) ; poids maximal du JSONB **à fixer** (à mesurer : trace source en polyline
        précision 6, plus les morceaux). La distance reste bornée par `GpxLimits.checkTracks`
        (SEC-6), puisque le tracé dérivé passe dans la chaîne GPX. **Validation des plages** :
        version de format connue, profil connu, indices de début et de fin dans la trace source avec
        début ≤ fin, morceaux contigus, polylines décodables, coordonnées dans les bornes WGS84
        comme `GeoPoint` ; tout manquement répond 400 avec un nouveau code `PLANNER_STATE_INVALID`
        (à ajouter à `ErrorCode`).
      - **Cohérence entre l'état et le tracé.** Chemins qui **remplacent un tracé**, et ce que
        devient l'état :
        1. *Import web d'un fichier à la modification* (`PUT …/routes/{routeSlug}` avec `gpxFile`) :
           `RouteService.updateRoute` vide `route.getTracks()` et en recrée ; la colonne étant sur
           la piste, **l'état part avec elle** (D3).
        2. *Remplacement par GPX depuis l'app mobile (`MOB-79`)* : `RouteRepository.updateRoute` envoie
           `gpxFile` au même `PUT` (l'app n'envoie jamais `points` ni d'état) : même chemin que 1,
           l'état est effacé.
        3. *Migration biketeam* : `BiketeamMigrationService` appelle `routeService.updateRoute` ou
           `createRoute` avec un fichier : même chemin, l'état est effacé (ou absent).
        4. *Modification avec `points`, sans état* : nouvelle piste, donc état effacé.
        5. *Mise à jour d'un aperçu* (`GpxPreviewService.updatePreview`, avec fichier ou points) :
           la colonne n'est pas une piste ; elle est **à vider explicitement** dans la transaction qui
           fait `setTracks`, sauf si la requête porte un état.
        Ne l'efface pas : un changement de titre ou d'adresse, le renommage d'un aperçu, et le
        **rattrapage HD** (`ElevationRefreshService` met les pistes à jour en place, géométrie 2D
        inchangée) ; l'état garde alors ses altitudes FAST, écart assumé (D2).
        **Jeton de révision** (proposition) : l'état porte un `trackRevision`, comparé à la lecture ;
        s'il ne correspond plus, l'état est ignoré (404). Pour un parcours, c'est le `fileId` du
        `ROUTE_ORIGINAL_GPX`, le jeton d'`API-131` : il change à chaque enregistrement du tracé, pas
        à un changement de titre, et le rattrapage HD ne réécrit pas l'original. Pour un aperçu,
        `files_revision` ne convient pas (le rattrapage HD en écrit une neuve) : proposition, une
        empreinte du tracé 2D enregistré (nombre de points de `tracks`, premier et dernier point),
        que le rattrapage ne change pas ; à valider. Le jeton couvre le déploiement roulant, où la
        version précédente remplace un tracé sans connaître l'état (pour un aperçu, elle laisse la
        colonne en place ; pour un parcours, elle recrée les pistes et l'état part de lui-même).
      - **Promotion d'un aperçu en parcours d'équipe** : `GpxPreviewService.createRoute` rejoue le
        GPX d'origine par `routeService.createRoute(teamSlug, request, gpxPath)`, qui n'a aucun
        état. Il faut donc **recopier l'état explicitement** : un paramètre facultatif de
        `RouteService.createRoute` qui l'écrit sur la première piste dans la même transaction, avec le
        `trackRevision` du nouveau parcours. Le contrôle `drawn` (`API-127`) ne change pas.
      - **Qui produit la trace source** : le serveur, **à l'envoi du fichier, en FAST** (D2) ; la
        trace est simplifiée à quelques mètres et ses altitudes sont celles du pipeline (un cumul de
        montée par point est à concevoir, B1). Les aperçus passent déjà par `computeGpx` en FAST. À
        concevoir : comment l'éditeur d'un parcours reçoit cette trace avant l'enregistrement (le
        fichier part aujourd'hui avec le formulaire) — endpoint de lecture sans enregistrement, ou
        aperçu implicite.
      - **`drawn` pour un état sans morceau routé** (proposition) : `drawn` suit l'état — vrai dès
        qu'il contient au moins un morceau routé ou en ligne droite, **faux pour un état fait de
        seuls morceaux importés** (un fichier, ou un tracé recalé par B2, D1), comme un fichier
        importé aujourd'hui. Contournement déjà assumé (`API-127`).
      - **Purge des aperçus** : `GpxPreviewCleanupScheduler` (tous les jours à 4 h) supprime les
        aperçus créés il y a plus de `GpxPreviewService.RETENTION_DAYS` = **30 jours** (`findExpired`
        sur `created_at`, pas sur la dernière sauvegarde). La ligne part avec sa colonne : l'état d'un
        aperçu disparaît avec lui, sans traitement propre ; un aperçu promu en parcours en a gardé
        une copie.
      - **Contrat** : la version suivante (mineure, après celle de B2 si elle passe d'abord), via la
        skill `contract-first-api` ; migration `V75`. Notées au passage dans `LEDGER_DONE.md` (D4).
      - [x] **C4a. Enregistrer et relire l'état** — **livré le 19 octobre 2026** (C4 est découpé le
        même jour : C4a maintenant, C4b plus tard).
        **Fait.** *Backend* : `PlannerState` (version, profil, sources, jonctions, morceaux
        ROUTED / DIRECT / IMPORTED) et sa validation (`PlannerStates` : version, profil, plages,
        contiguïté, polylines décodables, WGS84, bornes) ; `RouteRequest`,
        `GpxPreviewFromPointsRequest` et `GpxPreviewUpdateRequest` reçoivent `plannerState`, le
        serveur en dérive le tracé (`PlannerStates.validateAndDerive`, puis la chaîne GPX) ;
        `points` avec un état = 400 `PLANNER_STATE_INVALID`. `GET …/routes/{slug}/planner-state`
        (droits d'édition) et `GET /api/gpx-previews/{id}/planner-state` (créateur seul), `null`
        quand il n'y a pas d'état ou qu'il est périmé ; absent des DTO et des listes. Colonne
        `planner_state jsonb` sur `gpx_tracks` (première piste) et `gpx_previews` (migration
        `V75__planner_state.sql`, additive). Jeton de révision : `fileId` du `ROUTE_ORIGINAL_GPX`
        pour un parcours, empreinte du tracé 2D pour un aperçu. Remplacer le tracé (fichier,
        `points`) efface l'état ; titre, adresse et rattrapage HD le gardent. Promotion d'un aperçu :
        l'état est recopié, par son créateur seul. `drawn` faux pour un état de seuls morceaux
        importés. *Frontend* : `lib/plannerState.ts` (sérialisation à l'enregistrement,
        restauration sans requête), `lib/polyline.ts`, `lib/plannerSubmit.ts` (ce que chaque
        formulaire envoie), `sourceIdx` et trace source dans `useRoutePlanner` (`initialState`,
        `snapshot()`), suppression à 0 requête entre deux raccords du même import
        (`restoreSourceSpan`), profil de l'état adopté à l'ouverture ; pages de modification et
        d'aperçu qui lisent l'état avant d'ouvrir l'éditeur, un parcours rouvert sans état s'ouvre
        sur son tracé enregistré comme un import.
        **Bornes** (`GpxLimits`) : 2 000 morceaux (un point de contrôle tous les 100 m sur 200 km),
        8 sources (C4a n'en écrit qu'une), 100 000 points, 2 000 000 caractères de polylines ; pire cas
        estimé à 1,6 Mo de JSONB (100 000 points routés et 100 000 points source), **estimation, non
        mesurée sur de vrais parcours** ; les listes et les chaînes portent aussi `@Size` et
        `@Valid`, pour refuser avant la construction de tout le graphe. Au-delà des bornes côté
        client, l'éditeur envoie les points et le dit (« tracé enregistré sans ses points de
        contrôle »), après l'enregistrement réussi seulement. **Contrat `11.10.0`**, `V75`.
        **Tests** : backend `RoutePlannerStateResourceTest`, `GpxPreviewPlannerStateResourceTest`,
        `PlannerStatesTest`, `PolylineCodecTest`, `ElevationRefreshTest`,
        `GpxPreviewElevationRefreshTest` (aller-retour, droits, domaines, jeton, rattrapage HD,
        promotion, bornes) ; frontend `plannerState.test.ts`, `polyline.test.ts`,
        `plannerSubmit.test.ts`, `useRoutePlanner.test.tsx`, `RouteEditor.test.tsx`,
        `GpxPreviewEditor.test.tsx`, `RoutePlannerField.test.tsx`, e2e `gpx-planner`.
        **Écarts.** *É1* : le rattrapage HD reporte le jeton de l'aperçu sur la nouvelle révision,
        l'état garde donc ses altitudes FAST (D2). *É2* : un tracé non touché n'envoie rien à la
        modification (ni état ni points), la piste et son état restent. Sans état, la trace source
        est le tracé déjà enregistré (HD) : ses altitudes ne sont pas celles du FAST, et son D+ vient
        de la fiche. Un état de seuls morceaux importés vient du client : le serveur ne peut pas le
        distinguer d'un fichier qu'il a stocké, l'effet est celui d'un export puis d'un
        réimport du GPX (`API-127`, noté dans `GpxPreviewService.createRoute`).
      - [x] **C4b. Importer un fichier GPX dans l'éditeur** — **livré le 19 octobre 2026.**
        **Fait.** *Backend* : `POST /api/router/import-gpx` (multipart `gpxFile`, `teamSlug`
        facultatif, `operationId` `importGpx`), sans stockage ni appel Stadia ; `GpxImportService` :
        droits (`PlannerAccess`, extrait de `RouterService`, comportement inchangé), puis taille,
        puis lecture ; chaque piste passe par `GpxPipeline.processWithClimb` (FAST), qui partage
        l'étape « chemin dense » avec `processReported` et renvoie le cumul de montée dead-band
        de chaque point retenu (`climb[k] = cumulativeGain(dense)[indices[k]]`, dernier = D+).
        `GpxImportResponse` / `GpxImportTrack` (polylines `line`, `ele`, `climb`, `dist`,
        `ascend`) ; 8 pistes et 100 000 points au plus, sinon `PLANNER_IMPORT_TOO_LARGE`.
        `PlannerSource.climb` facultatif (format de l'état toujours en version 1), validé par
        `PlannerStates` (cardinal, croissant, bornes, budget de caractères, `climb` sans `ele`
        refusé). *Frontend* : bouton « Importer un fichier GPX » (carte au desktop, en-tête
        plein écran au doigt), choix Remplacer / Ajouter à la fin / Annuler, `sourceFromImport`,
        `routeFromSources`, `appendImport` (raccord droit 0 appel, < 5 m 0 appel, sinon 1 appel),
        `importGpx` dans `useRoutePlanner` (verrou, annulation, historique, réponse gardée pour
        réessayer), `snapshot().file` pour un import intact (enregistré comme le fichier), nom
        prérempli, notifications (altitudes de repli, waypoints perdus si le tracé change).
        **Décisions du 19 octobre 2026** : option A (traitement sans stockage), cumul par point
        dans vcyclist 6.10.0, toujours FAST, GPX multi-pistes = une source par piste reliées par
        des lignes droites (8 au plus, au-delà l'outil Fusionner), pas de limite de débit propre
        (`SEC-28` au proxy), droits identiques au routeur. **Contrat `11.11.0`**, pas de migration.
        **vcyclist `6.10.0`** (`ElevationGain.cumulativeGain`,
        `PathSimplifier.simplifyWithIndices`, publiés le 19 octobre 2026). **Correctif préalable** :
        `@JsonIgnoreProperties(ignoreUnknown = true)` sur l'état (commit `9e437bd5`), déployé en
        staging et en production avant C4b.
        **Tests** : backend `GpxPipelineTest` (dont un profil qui monte vraiment),
        `RouterImportResourceTest`, `PlannerStatesTest`, `RoutePlannerStateResourceTest`,
        `GpxPreviewPlannerStateResourceTest`, `GpxLimitsResourceTest`, `RouterResourceTest`,
        `ArchitectureTest` ; frontend `plannerImport.test.ts`, `useRoutePlannerImport.test.tsx`,
        `plannerState.test.ts`, `RoutePlannerField.test.tsx`, `RouteEditor.test.tsx`,
        `GpxPreviewEditor.test.tsx` ; e2e `gpx-planner` (C4b, dont la réouverture d'un import
        enregistré et la suppression entre raccords à 0 requête).
        **Écarts / décisions de revue.** *É1* : après un import, un geste puis un annuler, la route
        redevient l'import intact et `snapshot().file` rend le fichier (les copies d'historique
        d'un import sont reconnues). *É2* : enregistrer un import intact depuis les outils GPX
        passe par deux appels (envoi puis renommage, l'envoi n'accepte pas de nom) ; si le
        renommage échoue, on va à l'aperçu créé avec un avertissement plutôt que de laisser le
        formulaire rouvert. *É3* : le nom renvoyé perd ses caractères de contrôle et n'est pas
        coupé au milieu d'une paire de substituts ; `teamSlug` du multipart borné à 250.
        *É4* : le plafond de 100 000 points est contrôlé après le pipeline (risque accepté : coût
        borné par 4 000 km et 10 Mo, limite de débit au proxy, `SEC-28`).
- [ ] **C1. Surface par point** (L, §8 n° 13) — **conçu le 19 octobre 2026** (essais réels :
      [`../research/2026-10-19-stadia-surfaces.md`](../research/2026-10-19-stadia-surfaces.md) ;
      décisions au §10, « C1 »). Découpé en trois :
      - [x] **C1a — « non revêtu » en direct dans l'éditeur, 0 crédit** (contrat mineur, sans
            migration). Chaque manœuvre de `/route/v1` porte `rough` (compacté et pire) avec ses
            indices de shape : il ne rate jamais un passage non revêtu et en signale un peu trop
            (0 à 4,5 % de la distance sur 5 parcours). `ValhallaResponse` lit `maneuvers[]` ;
            `RouterService` reporte les plages sur les points de sortie du pipeline par la distance
            cumulée ; `RouterResponse.unpaved` facultatif. `PlannerPiece.unpaved` facultatif pour les
            morceaux ROUTED (état en version 1, `ignoreUnknown` déjà déployé). Client :
            `RoutePoint.unpaved` porté par le point d'arrivée comme `direct` ; importé = inconnu,
            ligne droite = hors réseau ; mode « Pente / Revêtement » du profil (`ElevationChart`
            `colorBy`), couleur sur la carte par expression `match` (le pointillé reste à B6).
            **C1a livré le 19 octobre 2026** (contrat **11.13.0**, aucune migration).
            *Backend* : `ValhallaResponse` lit `maneuvers[]` (`rough`, indices de shape),
            `UnpavedSpans.project` reporte les plages sur les points de sortie du pipeline par la
            distance cumulée (ramenée à la longueur brute), `RouterResponse.unpaved` et
            `PlannerPiece.unpaved` facultatifs (`UnpavedSpan` en `[from, to[` d'arêtes, borné par
            `GpxLimits`, `ignoreUnknown` conservé). *Web* : `RoutePoint.unpaved` porté par le point
            d'arrivée, `edgeSurface` (revêtu / non revêtu / inconnu / hors réseau),
            `surfaceStats`, mode « Pente / Revêtement » du profil (`ElevationChart` `colorBy`),
            couleur sur la carte par `match` sur la classe (familles de `brand-colors.yaml` via
            `SURFACE_TYPE_COLORS`, pointillé réservé aux lignes droites), légende et répartition.
            Un ancien backend ne répond rien : « inconnu » ; un ancien frontend ignore le champ.
            **Tests** : backend `UnpavedSpansTest`, `RouterResourceTest`, `PlannerStatesTest`,
            `RoutePlannerStateResourceTest`, `ArchitectureTest` ; frontend `plannerSurface.test.ts`,
            `PlannerElevationStrip.test.tsx`, `ElevationChart.test.tsx`, `useRoutePlanner.test.tsx` ;
            e2e `gpx-planner` (C1a, 3 scénarios).
            **Écarts / décisions de revue.** *É1* : `RoutePoint.unpaved` est une **fraction** (0..1,
            part de la longueur) et non un booléen, pour que la fusion d'arêtes par la
            simplification (RDP 5 m) garde la part pondérée. *É2* : convention d'arête,
            `PlannerPiece.unpaved` compte les arêtes de la pièce (l'arête `i` joint les points `i` et
            `i + 1`) ; le premier point prend la part de son successeur. *É3* : **le seuil de 0,5
            est abandonné** : une arête est « non revêtue » dès qu'une partie l'est (`share > 0`,
            `isUnpavedShare`), règle unique pour carte, profil, répartition et enregistrement, car
            `rough` ne rate jamais un passage non revêtu et l'affichage ne doit pas le perdre ;
            côté backend, une arête de sortie est non revêtue quand une plage `rough` la recouvre de
            plus de 5 m (ou de la moitié d'une arête plus courte), et non plus sur son milieu : un
            court passage sans virage, que le pipeline fond dans une longue arête, n'est plus perdu
            (`UnpavedSpansTest`). *É4* : couleurs, revêtu gris 7, hors réseau gris 5 (pointillé),
            inconnu gris 4, non revêtu orange 6 (famille GRAVEL), pour que l'inconnu reste lisible
            sur fond clair ; contrôle visuel sur écran non fait, le contraste est raisonné.
      - [x] **C1b — surface détaillée après l'enregistrement** (contrat mineur, migration
            `V76__track_surfaces.sql` additive). Conditions Stadia confirmées par le propriétaire le
            19 octobre 2026 (§10, « C1 »). `trace_attributes/v1` en `map_snap` sur le tracé stocké
            (`edge_walk` échoue sur un tracé simplifié, code 443), 190 km et 16 000 points au plus
            par tranche, 500 m de recouvrement ; costing `bicycle` **sans** `avoid_bad_surfaces`
            (qui rend les passages non revêtus `unmatched`), `pedestrian` pour RUN_HIKE, `auto` pour
            MOTORCYCLE ; projection en plages par distance (interpolation entre changements
            d'arête, intervalle coupé à mi-chemin quand la distance recalée dépasse 1,2 × + 30 m, ce
            qui neutralise les détours que `map_snap` insère aux demi-tours) ; morceaux DIRECT de
            l'état forcés à « hors réseau ». Plages `[de, à, code]` dans `gpx_tracks.surfaces` et
            `gpx_previews.surfaces` (JSONB à part : `PreviewTrack` n'a pas `ignoreUnknown`),
            document en `@JsonIgnoreProperties(ignoreUnknown = true)` avec `osmChangeset` et la
            longueur de calcul (rescale au rattrapage HD) ; file `surface_refresh` calquée sur
            `elevation_refresh` (délai de calme, jeton de révision, reprises, 400 définitif →
            « indisponible ») ; `TrackDto.surfaces` et `ways` facultatifs, rien dans les listes ;
            fiche et aperçu : mode « Revêtement », carte, barre de répartition, attribution OSM.
            Coût : 20 crédits par tranche de 190 km, une par enregistrement dans le délai de calme.
            Exports GPX et FIT inchangés (pas de champ standard).
            **C1b livré le 19 octobre 2026** (contrat **11.14.0**, migration **`V76`**).
            *Backend* : `StadiaTraceAttributesClient` (clé de configuration REST
            `stadiamaps-trace`, même clé Stadia), `Polyline6Encoder`, `TraceSurfaceProjection`
            (projection de `mapping.py` : interpolation entre changements d'arête, coupure à
            mi-chemin au-delà de 1,2 × + 30 m), `SurfaceRanges` (couverture, fusion, absorption des
            plages de moins de 20 m), `TraceSurfaceComputer` (tranches, recouvrement, costing par
            type d'activité), `PlannerStates.directRuns` (morceaux DIRECT → « hors réseau ») ;
            documents `TrackSurfaceDocument` (`gpx_tracks.surfaces`, plages `[de, à, code]` et
            `[de, à, use, lane]`, `osmChangeset`, longueur de calcul) et `PreviewSurfacesDocument`
            (`gpx_previews.surfaces`, avec le `files_revision` décrit), colonnes `@LazyGroup` ; file
            `surface_refresh` et `SurfaceRefreshWorker` calqués sur `elevation_refresh` (calme de
            90 s, jamais plus de 10 min, cinq essais, 400 par tranche → inconnu) ; le rattrapage HD
            reporte le jeton de révision et la lecture remet les plages à l'échelle de la longueur
            courante ; `pedalons.surface.enabled` (`SURFACE_ENABLED`) arrête demandes et worker, se
            coupe seul sans clé, coupé en `%test` et dans `.env.e2e`. `TrackDto.surfaceState`
            (`PENDING` / `READY` / `UNAVAILABLE`, absent = rien de connu) et `TrackDto.surfaces`
            (`SurfaceSpanDto` `{from, to, surface}` en mètres, `TrackSurface` à sept valeurs :
            cinq classes, `UNKNOWN`, `OFF_NETWORK`) sur le détail d'un parcours et l'aperçu ; rien
            dans les listes ni dans le bulk (`RouteSurfaces.NONE`) ; `use` et `cycle_lane` stockés,
            jamais exposés. *Web* : `lib/trackSurface.ts`, `RouteSurfaceSummary` (barre de
            répartition, légende, attribution OpenStreetMap, interrupteur qui colore le profil et la
            ligne par revêtement) sur la fiche et l'aperçu des outils GPX, couleurs des familles de
            `brand-colors.yaml` (enum `TrackSurface`, `pnpm generate-brand-colors`).
            **Tests** : backend `Polyline6EncoderTest`, `TraceSurfaceProjectionTest`,
            `SurfaceRangesTest`, `TraceSurfaceComputerTest`, `TrackSurfaceDocumentTest`,
            `PlannerStatesTest`, `SurfaceRefreshTest`, `GpxPreviewSurfaceRefreshTest`,
            `RouteSurfaceResourceTest`, `ArchitectureTest`, `RouterResourceTest`,
            `ElevationRefreshTest`, `GpxPreviewElevationRefreshTest`, `RouteQueryCountTest` (client
            Stadia toujours simulé) ; frontend `trackSurface.test.ts`, `plannerSurface.test.ts`,
            `RouteSurfaceSummary.test.tsx`, `mapUtils.test.ts`, `GpxPreviewView.test.tsx` ; e2e
            `route-surface` (surfaces simulées dans la réponse, la pile n'appelle pas Stadia).
            **Écarts / décisions de revue.** *É1* : `OFF_NETWORK` distinct de `UNKNOWN` dans le
            contrat (même famille grise, nuance différente) : une ligne droite voulue n'est pas un
            défaut de données, et séparer après coup demanderait un recalcul. *É2* : les codes
            stockés sont les valeurs brutes de Valhalla (`paved_smooth`…, plus `unknown` et
            `off_network`), la correspondance vers les classes se fait à la lecture : changer les
            classes ne demande aucun recalcul. *É3* : erreur définitive par tranche (400 : codes
            123, 154, 171, 443, 444) → tranche inconnue, document « indisponible » seulement si
            toutes le sont ; tout autre échec (429, 5xx, délai, 401/403) reprend toute la piste
            (2 min, 10 min, 1 h, 6 h) ; après le cinquième, aucun document et la demande reste en
            table pour diagnostic. *É4* : tranches de 188 km de cœur + 2 × 500 m et 15 000 points
            au plus (marges sous 200 km / 16 000). *É5* : à la promotion d'un aperçu, les surfaces
            sont recopiées pour tout appelant (elles sont publiques sur l'aperçu), sans nouvelle
            demande. *É6* : le plein écran (`RouteFullscreenView`) et l'éditeur n'affichent pas la
            surface détaillée, et l'état « en cours » n'est pas sondé (recharger la page) ; le worker
            traite une demande à la fois (20 s par tic de 30 s).
      - [ ] **C1c — après C1b** : rattrapage des anciens parcours (biketeam compris), plafonné et
            déclenché par l'exploitation ; suggestion de `surfaceType` dans le formulaire d'après
            les parts (seuils à valider), jamais automatique ; affichage mobile (tâche MOB à part).
- [ ] **C3. Points de parcours d'auteur** (L, §8 n° 15) — **à concevoir avant de commencer.** Appui
      long ou clic droit sur le tracé, « Ajouter un point de parcours » (dans le menu de B12) ;
      `WaypointMarker` existe déjà. Questions ouvertes (état de l'art §10, n° 2 et 3) : les types
      utiles à un club (regroupement, ravitaillement, danger) et leur correspondance avec les
      `course_point` FIT que reconnaissent Garmin, Wahoo et Karoo ; le comportement de Hammerhead
      sur les `<wpt>` GPX ; l'insertion « au meilleur endroit » (projection sur le segment le plus
      proche, ou minimisation de la longueur totale).
- [ ] **C5. Popularité interne** (§8 n° 17) et **C7. zones à éviter** (§8 n° 16) — **à concevoir
      avant de commencer** ; sans apport UI propre ici. C7 : `exclude_polygons` est **non vérifié**
      chez Stadia (§2), et la forme du stockage par équipe est à concevoir. C5 : surligner les
      tronçons déjà empruntés par les parcours de l'équipe (les tuiles MVT existent) ; le §10 de
      l'état de l'art n'a pas de question ouverte sur C5, à poser avant de chiffrer.

---

## 9. Tests

- Unitaires (Vitest) : `lib/planner.ts` avec un routeur simulé (A9) ; chaque nouvelle opération
  (B2, B6, B12) y ajoute ses cas ; le compteur d'appels au routeur simulé vérifie aussi le coût par
  geste du §2.
- e2e : `e2e/gpx-planner.e2e.ts` simule le routeur (`stubRouter`) et compte les requêtes, sur les
  deux projets Playwright (desktop et Pixel 7) ; chaque nouveau geste y ajoute son scénario et son
  coût. Un seul test atteint Stadia (`watchRouter`) quand une clé est présente : ne pas en ajouter
  d'autres, chaque passage de CI est facturé.
  - **Recalage (B2)** : ajouter un stub de `POST /api/router/match` à côté de `stubRouter`
    (`e2e/support/routes.ts`), qui répond une `RouterMatchResponse` fabriquée (avec et sans
    `fallback`, avec des `detours`) et compte les requêtes : inverser, aller-retour, repli et
    avertissement de détour s'y testent sans rien facturer.
  - **Règle : aucun test e2e n'appelle `map_match` pour de vrai.** Le recalage se teste chez Stadia
    à la main, une fois, pas en CI ; la chaîne elle-même (trous, raccord, boucles) se teste côté
    backend avec Stadia simulé.
- **Backend, à lancer par le propriétaire** (l'agent ne lance jamais les tests backend), Stadia
  simulé par `@InjectMock @RestClient` comme `RouterResourceTest` :
  - *Endpoint de recalage* (`StadiaMapsClient` pour le raccord, `StadiaMapsMatchClient` pour le
    recalage) : drapeau, équipe et droits refusés **avant tout appel** (aucune interaction avec les
    clients simulés), y compris entre domaines ; trace continue = 1 recalage et 0 raccord ; trous =
    1 recalage et 1 raccord, avec les legs pairs et sans `heading` ; repli sur erreur, sur longueur
    nulle, sur raccord échoué et sur résultat plus long de 25 % ; `429` → `ROUTING_QUOTA_EXCEEDED` ;
    ré-ancrage des points de contrôle ; plafonds de points. Le nettoyage des boucles, le rognage
    et le ré-ancrage sont des fonctions pures, testées à part sur des **fixtures synthétiques** (les
    GPX d'essai ne sont pas au dépôt).
  - *État d'édition (C4)*, dans `RouteResourceTest` et `GpxPreviewResourceTest` : aller-retour de
    l'état ; lecture réservée aux droits d'édition (membre sans droit : 403 ; aperçu : autre que le
    créateur) ; absent de `RouteDto`, `RouteDetailDto`, `GpxPreviewDto` et des listes ; remplacement
    du tracé par fichier ou par `points` qui efface l'état ; changement de titre et rattrapage HD qui
    le gardent ; jeton périmé = état ignoré ; promotion d'un aperçu en parcours qui recopie l'état ;
    plages ou version invalides et bornes de taille → 400 `PLANNER_STATE_INVALID` ; `points` et état
    ensemble → 400 ; `drawn` selon l'état.
- Recette à l'œil sur un vrai téléphone, **Android et iPhone**, pour le lot 2, B11 et la suite :
  défilement, clavier virtuel, appui long, orientation. Safari iOS ignore
  `interactive-widget=resizes-content` : à regarder en priorité sur l'iPhone.

---

## 10. Décisions à prendre par le propriétaire

| # | Question | Proposition | Ce que l'autre choix implique |
|---|---|---|---|
| Q1 | Forme du plein écran (B4) | **Tranché le 17 octobre 2026 : l'aspect de la page carte d'un parcours (`RouteFullscreenView` : barre de 48 px, carte sur toute la hauteur, bande de profil au lot 3), rendu au-dessus du formulaire sans URL propre**, le retour du navigateur le ferme | Page dédiée en `layout: 'bare'` : URL propre, mais tracé non enregistré à faire transiter, routes, SSR et liens profonds à ajouter |
| Q2 | Ambition du web mobile | **Tranché le 17 octobre 2026 : édition complète** (B5, B6, B9) ; au doigt, le plein écran s'ouvre **sur un geste** (« Modifier le tracé », « Tracer le parcours »), jamais au chargement (L2-3) | Retouches seulement : la moitié du lot 2 tombe |
| Q3 | Modificateur ligne droite | **Tranché le 17 octobre 2026 : `Ctrl` et `Alt`**, la bascule B6 en plus | `Alt` seul : cohérent avec macOS, rompt l'habitude actuelle |
| Q4 | Quota de géocodage par utilisateur | **Caduque** : la recherche de la carte (`WEB-99`) appelle Stadia depuis le navigateur, authentifiée par le domaine ; aucune requête ne passe par notre serveur | — |
| Q5 | D+ affiché pendant l'édition | **Tranché le 17 octobre 2026, précisé le 18 (D2) : celui du serveur, en altitude rapide** (FAST, `API-131`) : `ascend` de chaque segment routé, altitudes de la trace source pour une portion importée, calculées par le serveur dès l'envoi du fichier. Satisfaite pour le routeur depuis `6cbce899` ; la règle de calcul est livrée par B1a. Écart assumé avec le parcours enregistré, qui passe en HD | Celui du client : instantané, mais diverge à l'enregistrement |
| Q6 | Inversion | **Tranché le 17 octobre 2026 : recaler la trace inversée sur le réseau** (`map_match/v1` de Stadia, avec le profil courant du planificateur, 1 ou 2 requêtes facturées, voir B2) : mêmes routes sauf là où le sens l'interdit, plus court détour légal ailleurs ; repli sur la géométrie inversée seule, avec un avertissement, si le recalage échoue. Le tracé recalé est traité comme un import (D1). Re-router entre les points de contrôle est écarté : deux ancres éloignées laissent le routeur changer de routes, et une ancre de Douglas-Peucker tombe volontiers sur une intersection ou un rond-point à sens unique | Inverser la géométrie seule : 0 requête, sens uniques ignorés |
| Q7 | Lignes droites à la réouverture | **Tranché le 17 octobre 2026** : au chargement, le parcours n'est pas recalculé ; une ligne droite reste telle quelle tant que ses points ne sont pas modifiés. B6 ne dépend donc pas de C4 (c'est C4 qui dépend de B6) | Lier B6 et C4 pour retrouver les lignes droites en pointillés à la réouverture |
| Q8 | Mini-carte | **Tranché le 17 octobre 2026 : gardée avec une souris, absente au doigt** (déjà le cas depuis A4) | La rendre débrayable, ou la retirer |

### Décisions du propriétaire du 18 octobre 2026

- **D1.** Un tracé recalé par B2, inversé ou aller-retour, est traité **comme un import** : un
  morceau importé, avec sa propre trace source. Ses ancres servent de bornes, comme celles d'un
  fichier GPX, et une suppression peut restituer la portion recalée. Cela lève le conflit entre B2 et
  B12 : sans cela, `spanBounds` sauterait ces points et re-router irait d'un point de contrôle à
  l'autre. (B2, B12, C4.)
- **D2.** Le D+ des portions importées vient d'altitudes **calculées côté serveur en mode FAST**
  (l'altitude rapide d'`API-131`), **dès l'envoi initial du fichier** : la trace source porte des
  altitudes cohérentes avec celles du routeur, et le client en déduit le D+ des portions importées
  sans autre appel. Pour les segments routés, le client garde l'`ascend` que `/api/router` renvoie
  déjà en FAST. La règle de somme est à B1 ; l'écart avec le D+ du parcours enregistré, qui passe en
  HD, est assumé. Q5 est satisfaite depuis `6cbce899`.
- **D3.** L'état d'édition de C4 est stocké dans **`gpx_tracks`**, en colonne JSONB facultative : un
  tracé remplacé emporte son état. Les aperçus des outils GPX ont leur propre colonne dans
  `gpx_previews`.
- **Q-A, Q-B, Q-C (B1, 18 octobre 2026).** Q-A : le D+ d'un tracé rouvert est le cumul de montée par
  point de tout `initialTrack`, recalé sur `elevationGain` de la fiche. Q-B : bandeau de 160 px aussi
  sous la carte en mode intégré au desktop. Q-C : D+ d'une ligne droite = max(0, altitude d'arrivée
  − départ), altitudes remplies par interpolation ; tracé de lignes droites seules = 0 et « altitude
  inconnue ».
- **D5.** Supprimer le départ ou l'arrivée n'est refusé que sur un tracé qui contient des points
  importés et tomberait sous deux points ; sur un tracé dessiné, on peut supprimer les derniers
  points un à un. (B12.)
- **D6.** Insérer ou déplacer un point sur un tronçon droit suit le mode courant (touche OU
  bascule), sans hériter du mode du tronçon : glisser un tronçon droit hors mode le re-route. (B6.)
- **D7.** `nearestSegment` reste une approximation (segments voisins des six sommets les plus
  proches) ; une recherche exacte n'est pas justifiée pour un cas aussi rare. (B12.)
- **D8.** Les opérations de B2 (inverser, aller-retour, retour au départ) vont dans un menu
  « Plus » de la barre du bas au doigt, qui accueillera aussi C3 et C7. (B2.)
- **C2 (19 octobre 2026).** Q1 le curseur remplace la valeur du profil, absent = profil ; Q2
  mémorisation par profil ; Q3 cinq crans, mots, pas de chiffre, lien « Valeurs du profil » ; Q4
  contrat `11.9.0` ; défauts Q5 (rien pour RUN_HIKE), Q7 (C4 n'enregistre pas le réglage), Q8 (pas de
  re-routage du tracé existant), Q9 (pastille).
- **C4a (19 octobre 2026).** C4 est découpé : C4a maintenant (enregistrer et relire l'état :
  morceaux, points de contrôle, raccords, `sourceIdx` et trace source = le tracé déjà enregistré pour
  un parcours rouvert sans état, suppression à 0 requête, copie de l'état à la promotion), C4b plus
  tard (trace source FAST à l'envoi d'un fichier ; livré, voir C4b). Propositions backend **validées telles quelles** :
  `GET …/planner-state` séparé et réservé à l'édition ; état écrit avec le tracé (`RouteRequest`,
  `GpxPreviewFromPointsRequest`, `GpxPreviewUpdateRequest`), le serveur dérive le tracé ; points +
  état = 400 `PLANNER_STATE_INVALID` ; `V75` additive, `planner_state jsonb` sur `gpx_tracks` et
  `gpx_previews` ; jeton `fileId` du `ROUTE_ORIGINAL_GPX` (parcours) ou empreinte du tracé 2D
  (aperçu) ; `drawn` faux pour un état de seuls morceaux importés ; contrat `11.10.0`. **L'état d'un
  aperçu n'est lisible que par son créateur.**
- **C4b (19 octobre 2026).** Option A : endpoint de traitement sans stockage ; cumul par point
  dans vcyclist 6.10.0 ; contrat `11.11.0` (`POST /api/router/import-gpx`, `PlannerSource.climb`,
  `PLANNER_IMPORT_TOO_LARGE`), pas de migration ; bouton « Importer un fichier GPX » avec choix
  Remplacer / Ajouter à la fin ; import intact enregistré comme le fichier ; multi-pistes reliées en
  lignes droites, 8 au plus ; raccord d'un ajout qui échoue = opération entière en échec ; pas de
  limite de débit propre (`SEC-28`) ; droits du routeur ; au doigt, bouton dans l'en-tête plein
  écran en attendant le menu « Plus » (D8).
- **D4.** Les volets backend de B2 (l'endpoint de recalage) et de C4 **restent sous `WEB-100`**,
  comme A10. Les versions de contrat et les migrations seront notées au passage dans
  `LEDGER_DONE.md`.

### Décisions du propriétaire du 19 octobre 2026 (B1b)

- **Point 1** (altitudes FAST d'un tracé rouvert sans état) : **Délibérément dehors** (§11, `WEB-103`).
- **Point 2** : appel paresseux en arrière-plan, groupé, 300 ms après le dernier changement, vers un
  nouvel endpoint `POST /api/router/elevation` (FAST, sans Stadia) ; **Q-C devient le repli** ; le
  bandeau déplie le relief sous une ligne droite. Le relief passe par la chaîne complète de vcyclist
  (`processWithClimb`), sans densification ni lecture du MNT côté Pedalons.
- Défauts retenus : 50 lignes / 100 km par ligne / 200 km par requête / rien sous 10 m côté client,
  `ROUTING_SEGMENT_TOO_LONG` au-delà ; réponse en `GpxImportTrack` ; profil non stocké (état en
  version 1) ; pas d'indicateur de chargement ; tunnels aplanis acceptés ; contrat `11.12.0`.
- **C1 (19 octobre 2026).** Deux niveaux : « non revêtu » gratuit dans l'éditeur d'après `rough` de
  `/route` (C1a), surface détaillée calculée après l'enregistrement par `trace_attributes` en
  `map_snap` (C1b) ; calcul en arrière-plan sur le modèle du rattrapage HD (V74) ; les aperçus des
  outils GPX enrichis aussi ; cinq classes plus « inconnu » (asphalte gris, revêtement dégradé
  jaune, compacté et gravier orange, terre vert, sentier violet, inconnu gris clair), déclarées
  dans `contracts/brand-colors.yaml` ; le type de voie (`use`, `cycle_lane`) stocké sans être
  affiché ; C1c = rattrapage des anciens parcours (plafonné, déclenché par l'exploitation),
  suggestion de `surfaceType` dans le formulaire (jamais automatique), affichage mobile (tâche MOB
  à part). Les conditions Stadia (plan payant, stockage des plages dérivées malgré la clause de
  « cache ») sont **confirmées par le propriétaire le 19 octobre 2026** ; C1b est livré le même jour.
  Pas de second passage de costing sur l'inconnu ; exports GPX et FIT sans surface (`WEB-105`).

### Propositions de ce plan à valider

Écrites le 18 octobre 2026 sans décision du propriétaire : le chemin, les DTO et la gestion des
erreurs de l'endpoint de recalage et la seconde interface Stadia (B2) ; la version de contrat
pour B2 si elle passe avant (C2 a pris `11.9.0`, C4a `11.10.0`, B2 prendra la suivante) ; le nom
`legAscend` et le cumul de montée de la trace source (B1). Celles du volet backend de C4 sont
validées (19 octobre 2026, ci-dessus).

---

## 11. Délibérément dehors

- **Générateur de boucles** (un circuit d'une distance donnée proposé autour d'un point, comme chez
  Komoot ou Strava) : plusieurs requêtes facturées par proposition et un choix de points
  intermédiaires à concevoir, pour un outil où l'auteur dessine son parcours. Le lot 3 n'offre que
  le « retour au départ » (B2).
- **Édition dans l'app Flutter** (§8 n° 18) : autre client, autre plan ; le web mobile du lot 2
  en est le banc d'essai.
- **Heatmap d'activités, navigation guidée, photos, import par URL** : voir §8.4 de l'état de
  l'art.
- **Altitudes FAST d'un tracé rouvert sans état** (B1b, point 1, décidé le 19 octobre 2026) : il
  faudrait un appel à chaque ouverture (quelques secondes à froid sur un long parcours) et un échange
  de source délicat (le FAST simplifie avec d'autres sommets que `initialTrack`, d'où une course sur
  `sourceIdx` ou une ouverture retardée), pour un chiffre qui s'éloignerait de celui de
  l'enregistrement : les portions non retouchées gardent un D+ HD recalé sur `elevationGain`, vers
  lequel le tracé enregistré converge (il repasse en HD), et les portions retouchées sont déjà en
  FAST. Rouvert sous `WEB-103`.
- **Plafond de tuiles MNT et limite de débit propres à `/api/router/elevation`** : 50 lignes de
  quelques mètres dans 50 tuiles z12 distinctes coûtent 50 téléchargements à froid, écrits sans
  éviction dans `DemTileStore`. Même risque, plus étroit, que celui accepté pour `import-gpx` (C4b) ;
  seul `SEC-28` (proxy) limite le débit. Rouvert sous `WEB-104`.
- **Surface dans les exports GPX et FIT** (C1b, décidé le 19 octobre 2026) : FIT n'a pas de champ
  standard, une extension GPX serait ignorée des appareils, et les fichiers stockés seraient à
  réécrire après chaque calcul en arrière-plan. Pas non plus de **second passage de costing** sur
  les plages restées inconnues (piéton ou auto, 20 crédits de plus par tranche) : « inconnu »
  est une réponse honnête.
  Rouvert sous `WEB-105`.
- **Cache client des segments** entre sessions : annuler / rétablir ne coûte déjà rien, et le
  cache serveur suggéré par la session Stadia est plus rentable ; à reconsidérer si la facture le
  demande.
