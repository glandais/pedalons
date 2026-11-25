# Flux des parcours : constats de l'audit du 25 novembre 2026

Écrit le 25 novembre 2026. **État : constats arbitrés le 25 novembre 2026 (§7), rien codé.** Source : deux passes
d'audit lues dans le code (aucun navigateur, aucun appareil, aucun test lancé), la première avant
`fe8c76ab1`, la seconde à `21654fb59` (17 commits plus tard : menus « Créer ▾ » et « Modifier ▾ »,
import de plusieurs GPX, « Dupliquer » dans l'app). Les statuts ci-dessous sont ceux de la seconde passe.

Périmètre : créer (GPX, tracé, depuis une sortie ou un voyage), modifier, générer (`WEB-179`,
`MOB-154`), retoucher (`WEB-201`, `MOB-185`), outils GPX, sur le site et dans l'app. Les pistes sont
indicatives ; une entrée sans piste attend un arbitrage.

Marques : **(vérifié)** relu dans le code ; **(à confirmer)** déduit du code, à voir dans un
navigateur ou sur un appareil. Gravité : **bloquant**, **gênant**, **mineur**. Chemins relatifs à
`frontend/src/` (W) et `mobile/lib/features/` (M) sauf mention contraire.

---

## 1. En une page

Les flux d'entrée ont convergé (même « Créer ▾ » Tracer / Importer des GPX / Générer, même
« Modifier ▾ » avec une section « Tracé »), mais quatre familles de défauts restent :

1. **Perte de saisie** : aucune garde sur le site ; plusieurs sorties sans confirmation dans l'app ;
   un import de plusieurs GPX qui arrache la personne de sa page (W) ou se termine en silence (M).
2. **Proposition transmise fragile** : la proposition du générateur ou de la retouche voyage par
   l'état de navigation (W) ou par `extra` (M), et se perd ou se rejoue selon le chemin.
3. **État périmé** : l'offre de retouche n'est jamais relue après un enregistrement, des deux côtés.
4. **Libellés et parité** : « Modifier » a trois sens, la même destination a trois noms, le quota se
   signale différemment selon l'écran et le client.

Les plus urgents : §2.1 (W-N1, M-N5, M-N1), §3.1, §4.1.

---

## 2. Perte de saisie et navigation

### 2.1 Les plus graves

| ID | Où | Gravité | Constat |
|---|---|---|---|
| W-N1 | W `components/route/useGpxUpload.tsx:73-77` | gênant (vérifié ; effet en navigateur à confirmer) | Après un import de plusieurs GPX, `navigate(paths.routes(team))` est appelé sans condition, même si la personne a quitté la page entre-temps : elle est arrachée de l'écran où elle est (éditeur de sortie compris) et perd sa saisie (aucune garde, W-F1). |
| M-N5 | M `routes/presentation/widgets/route_manage_menu.dart:301`, `routes/presentation/pages/route_editor_page.dart:778-779` | gênant (vérifié) | « Dupliquer » pousse l'éditeur de la copie **au-dessus de la fiche de l'original** ; « Enregistrer » fait `pop` et ramène sur l'original avec « Parcours enregistré ». On croit avoir modifié l'original. Le site ouvre la fiche de la copie. |
| M-N1 | M `route_editor_page.dart:503-531`, `:908-916` | gênant (vérifié) | Retour permis pendant un import de plusieurs GPX (`_dirty` et `_saving` faux) : la boucle continue, `if (!mounted) return` saute `notifyRouteChanged` et le bilan. Parcours créés en silence, listes et quota périmés. |
| M-F7 | M `route_editor_page.dart:909`, `:657` | gênant (vérifié) | `canPop: !_dirty \|\| _saving` : on peut quitter pendant l'enregistrement ; même conséquence que M-N1 (pas de relecture, pas de message). |

### 2.2 Gardes absentes ou contournées

| ID | Où | Gravité | Constat |
|---|---|---|---|
| W-F1 | W tout `src/` (ni `useBlocker` ni `beforeunload`) ; `components/route/RouteEditor.tsx`, `pages/route/CreateRoutePage.tsx`, `pages/route/EditRoutePage.tsx`, `GpxPreviewEditor.tsx` | gênant | Aucune garde contre la perte d'un tracé, d'une proposition ou d'une retouche : « Annuler », fil d'Ariane, lien retour, rechargement. L'app, elle, demande confirmation (`PopScope`). |
| W-F2 | W `components/route/CreateRouteModal.tsx:64-78` | gênant | Création depuis une sortie ou un voyage : pas de bouton Annuler (`showCancelButton={false}`) ; la croix ou Échap ferme sans confirmation. |
| W-F3 | W `pages/route/EditRoutePage.tsx:136-146` | gênant (à confirmer) | Changer l'adresse (slug) en édition navigue en `replace` sans état ; la requête repart sur une nouvelle clé, le squelette démonte `RouteEditor` : saisie, tracé en cours, retouche transmise **et fichier de « Remplacer le fichier GPX »** perdus. |
| M-N9 | M `route_editor_page.dart:969-973` | mineur (vérifié) | « Générer » sur la page de choix fait `pushReplacement` sans passer par `PopScope` : un tracé non terminé ou une proposition transmise est perdu. Depuis un générateur, la pile contient alors deux générateurs. |
| M-N10 | M `route_editor_page.dart:443-445`, `:545-549` | mineur (vérifié) | Import de plusieurs GPX depuis la page de choix avec un tracé ou une proposition en attente : `go()` sans confirmation. |
| M-N6 | M `core/widgets/duplicate_name_sheet.dart:61-83` | mineur (vérifié) | La feuille de duplication se ferme d'un glissement pendant l'envoi : la copie est créée sans rafraîchissement ni navigation. |

### 2.3 Retour, annulation, doublons

| ID | Où | Gravité | Constat |
|---|---|---|---|
| W-F7 | W `CreateRoutePage.tsx`, `EditRoutePage.tsx` (état d'historique) | mineur (à confirmer) | `location.state` (`generated`, `gpxFile`, `draw`) reste dans l'historique : Retour du navigateur après création rouvre le formulaire prérempli (doublon) ; après une édition, rejoue le remplacement de trace ou de fichier. |
| M-F11 | M `routes/presentation/pages/route_generator_page.dart:299` | mineur | Après création depuis le générateur, celui-ci reste sous la fiche avec ses propositions : Retour puis « Utiliser ce parcours » crée un doublon. |
| M-F12 | M `route_generator_page.dart:287-310` (`_use`), `route_retouch_page.dart:229-247` (`_choose`) | mineur (à confirmer) | Double appui non protégé : deux éditeurs (deux WebViews), ou un `pop` de trop qui referme la fiche. |
| M-F10 | M `route_retouch_page.dart:364-372` vs `route_generator_page.dart:540` | mineur | Retour incohérent : le générateur revient des résultats aux réglages, la retouche quitte tout et perd ses propositions. |
| W-F15 | W `CreateRoutePage.tsx:66-68` | mineur | « Annuler » mène toujours à la liste, quelle que soit l'entrée (accueil, tableau de bord, générateur dont les réglages sont pourtant dans l'URL). |
| W-F14 | W `pages/route/RouteDetailPage.tsx:122-158` | mineur | « Dupliquer » et « Modifier une copie » créent la copie dès le clic ; « Annuler » dans l'éditeur ne la supprime pas. |

---

## 3. Proposition transmise (générateur, retouche)

### 3.1 La proposition disparaît ou n'est pas reprise

| ID | Où | Gravité | Constat |
|---|---|---|---|
| M-F5 | M `route_editor_page.dart:777-778`, `:868-875` ; `routes/presentation/widgets/editor/gpx_pick_step.dart` | gênant | Création depuis le générateur ou « Nouveau parcours » : quitter le planificateur sans « Terminer » ramène à la page de choix ; la proposition devient invisible (bandeau « non repris » seulement dans la section Tracé, nom prérempli caché). Depuis les commits du 25, c'est aussi l'issue de tout `?tracer=1` quitté sans « Terminer ». |
| M-F6 | M `route_editor_page.dart:935` ; `widgets/editor/route_track_section.dart:135-141` | gênant | « Modifier » d'une retouche, planificateur quitté sans « Terminer » : « Enregistrer » reste actif et enregistre sans la trace retouchée, seul un bandeau prévient. |
| M-F4 | M `route_manage_menu.dart:331` ; site `components/routeRetouch/RouteRetouchModal.tsx:187-192` | gênant | « Ouvrir le générateur » depuis une retouche arrive sans réglages ; le site passe départ, distance et type (`generatorLinkFor`). Le message `noShorter` promet ce que l'app ne fait pas. |
| W-F8 | W `RouteEditor.tsx:164` | mineur | Proposition ignorée en silence si `canUsePlanner` est faux à l'arrivée (quota lu en retard, ou entrée non grisée depuis l'accueil, W-N7). |
| M-F18 | M `routes/domain/route_retouch.dart:164-182`, `route_editor_page.dart:318-323` | mineur (à confirmer) | « Nouveau parcours » depuis une retouche ne reprend ni description, ni tags, ni visibilité ; « Mixte » devient Route ou Gravel. |
| M-F19 | M `route_editor_page.dart:485-490` | mineur | Après une proposition, importer un GPX garde le nom « Parcours généré de … ». |

### 3.2 Retouche

| ID | Où | Gravité | Constat |
|---|---|---|---|
| M-F3 | M `route_retouch_page.dart:154-160`, `:325` | gênant | Mode « Déplacer l'arrivée » : un toucher sur la carte pendant l'affichage des résultats appelle `_reset()` et efface les propositions. |
| W-N4 / W-F24 | W `RouteDetailPage.tsx:233-234`, `:345-350` | gênant | La section « Tracé » de « Modifier ▾ » présente la retouche comme une modification du parcours ; sur un parcours à plusieurs traces, elle ne peut que créer un nouveau parcours, sans le dire. |
| M-F15 (reste) | M `routes/presentation/pages/route_detail_page.dart:345-356` | mineur | L'offre n'est lue que si `canEdit` : la retouche en nouveau parcours (offerte par le site à qui peut planifier sans modifier) manque dans l'app, comme « Modifier une copie » (`WEB-169`). |

---

## 4. État périmé, quota, erreurs

### 4.1 Offre de retouche jamais relue

| ID | Où | Gravité | Constat |
|---|---|---|---|
| W-F6 | W `components/routeRetouch/useRouteRetouchOffer.ts:18` ; `lib/routeCacheInvalidation.ts` | gênant (vérifié) | `staleTime` 5 min, et `invalidateRouteQueries` ne touche pas l'offre : après « Remplacer le fichier GPX » ou une retouche enregistrée, le menu propose les bornes de l'ancien tracé au lieu de « en cours d'analyse ». |
| M-F2 | M `routes/providers/route_changes.dart:30-47` ; `route_detail_page.dart:173-176` | gênant (vérifié) | Ni `notifyRouteChanged` ni le tirer-pour-rafraîchir n'invalident `routeRetouchOfferProvider` : même effet, et une ligne « en cours d'analyse » ne se réactive jamais sans rouvrir la fiche. |

### 4.2 Quota

| ID | Où | Gravité | Constat |
|---|---|---|---|
| M-N7 / M-F8 | M `routes/presentation/route_create_actions.dart:25-49`, `route_generator_page.dart:198-205`, `:291-295` | gênant | Les menus « Créer » ne grisent ni « Tracer » ni « Générer » quand le quota est épuisé (le site les grise, `useTeamCreateActions.ts:79-119`) ; le générateur ne relit pas l'équipe et ne refuse qu'après le calcul, par une snackbar. La retouche désactive ses boutons. Aucun ne donne la date de remise à zéro. |
| W-N7 | W `components/home/QuickActions.tsx:20-22` | mineur | À l'accueil, « Tracer » et « Générer » jamais grisés (la liste d'équipes ne porte pas le quota) ; on bascule ensuite en silence sur l'import GPX (W-F8). |
| W-F23 | W `RouteEditor.tsx:145-150` | mineur | En édition avec quota épuisé : mode GPX seul, le tracé enregistré n'est même plus visible, alors que modifier les métadonnées ne consomme rien. |
| W-F11, W-F13, M-F20 | W `components/gpxtool/GpxPreviewView.tsx:94-104`, `components/gpxtool/GpxPreviewEditor.tsx:84`, `pages/gpxtool/CreateGpxPreviewPage.tsx:96-99` ; M `gpxtools/presentation/pages/gpx_preview_editor_page.dart` | mineur | Outils GPX : équipes au quota épuisé non grisées dans « Enregistrer comme parcours » ; quota personnel non vérifié en arrivant sur la page (W) ni relu au retour au premier plan (M). |

### 4.3 Import de GPX

| ID | Où | Gravité | Constat |
|---|---|---|---|
| W-F9 / M-N3 | W `useGpxUpload.tsx:56-61` ; M `route_editor_page.dart:527-529`, `:541-544` | mineur | `catch` qui avale tout : réseau, droits, 5xx ou nom invalide deviennent « Fichiers refusés » sans raison. Avec 0 importé (M), on reste sur la page de choix sans bandeau. |
| W-N12 / M | W `useGpxUpload.tsx:56` ; M `_importAll` | mineur | Revêtement forcé à « Route » pour tout import multiple (et pour « Enregistrer comme parcours »), sans la suggestion de surface de l'édition. |
| M-N2 | M `gpx_pick_step.dart:108-109` ; `mobile/assets/l10n/fr.json:1434` | gênant | Aucune progression pendant l'import multiple (« Lecture du fichier… ») ; la clé `routes.create.importProgress` est inutilisée. Le site affiche n/total. |
| W-N2 | W `useGpxUpload.tsx:34`, `:41` | mineur | L'état « import en cours » est local à chaque instance : deux imports concurrents possibles (accueil + liste), même id de notification. |
| W-N8 | W `components/common/CreateSplitButton.tsx:40-41` | mineur | Tous les gestes grisés (quota épuisé + import en cours) : le bouton disparaît de l'en-tête. |
| M-N4 | M `routes/domain/gpx_check.dart:204-216` | mineur (à confirmer) | Un fichier court sans nom de trace (« a.gpx ») donne un nom de moins de 3 caractères, refusé par l'API. |

### 4.4 Erreurs, droits, planificateur embarqué

| ID | Où | Gravité | Constat |
|---|---|---|---|
| M-F13 | M `routes/data/planner_web_view.dart:52-66` | gênant (à confirmer) | Mort du processus de rendu ou erreur de ressource de la WebView non gérée : planificateur blanc sans « Réessayer » après un passage en arrière-plan (Android). |
| M-F14 | M `routes/presentation/pages/route_planner_screen.dart:150-157` | mineur (à confirmer) | Aucune sortie pendant le chargement du planificateur ; aggravé depuis que « Créer » et « Tracer » l'ouvrent en premier écran. |
| W-F17 | W `RouteEditor.tsx:122`, `:311` | mineur | Erreur de mutation jamais affichée dans le formulaire (toast global seul), relancée depuis `onSubmit`. |
| W-F16 | W `CreateRoutePage.tsx`, `EditRoutePage.tsx:86-88`, `pages/route/RouteGeneratorPage.tsx:55-57` | mineur | Refus de droits par redirection silencieuse ; l'édition renvoie à la liste, pas à la fiche. |
| M-F9 | M `route_generator_page.dart:114-121` | mineur | Refus du générateur toujours titré « Réservé au rôle Organisateur », même quand le planificateur est fermé. |
| W-N10 | W `components/home/memberHomeHelpers.ts:29` vs `components/team/dashboard/DashboardHeader.tsx:38` | mineur | Admin plateforme sans rôle : bouton « Créer » au tableau de bord, pas à l'accueil. |
| M-N11 | M `route_detail_page.dart:330-381`, `route_manage_menu.dart:63-65` | mineur (à confirmer) | Stylo affiché pour `canDelete` seul ; feuille vide possible pour un parcours supprimé avec `canEdit` sans `canDelete`. |
| M-F24 | M `route_editor_page.dart:726-729` | mineur | « Au moins 2 points de contrôle » affiché aussi quand le fichier importé dans le planificateur est perdu (`fileLost`). |
| M-N12 | M `route_detail_page.dart` (~206), `gpxtools/presentation/pages/gpx_preview_page.dart` (~259, 341-352) | mineur (à confirmer) | GPS dans la barre : l'issue de l'export s'affiche en tête du corps, hors de vue si l'on a fait défiler ; jusqu'à quatre actions dans la barre de l'aperçu. |

---

## 5. Libellés, écriture, parité

### 5.1 Libellés

| ID | Où | Gravité | Constat |
|---|---|---|---|
| W-F4 | W `RouteRetouchModal.tsx:342-352`, `RouteDetailPage.tsx:208` | gênant | « Modifier » a deux sens : Modifier ▾ → retouche → « Modifier » (qui **remplace la trace**) → éditeur « Modifier ». Même chose dans l'app (menu « Modifier » / sortie de retouche « Modifier »). |
| W-F19 | W `components/ride/RideEditor.tsx:394`, `:576` ; `components/trip/TripEditor.tsx:467`, `:617` | mineur | Troisième sens : « Modifier » pour changer le parcours choisi d'une sortie. |
| W-F5 | W `locales/fr/common.json` (`routeGenerator.*`, `routeRetouch.*`) | gênant | Une destination, trois noms : « Ouvrir dans l'éditeur », « Utiliser ce parcours », « Ouvrir dans le planificateur ». |
| W-N3 | W `pages/route/RouteListPage.tsx:119`, `components/team/dashboard/FirstSteps.tsx:83`, `useTeamCreateActions.ts:86-95` | gênant | Sur une même liste : l'en-tête « Tracer sur la carte ▾ » ouvre le tracé ; l'état vide et Premiers pas « Créer un parcours » ouvrent l'import. L'app ouvre le tracé partout (`firstRouteCreateLocation`). |
| W-N5 / M-N8 | W `CreateSplitButton.tsx:42-52` ; M `core/lists/create_split_button.dart:75-88` | mineur | Le bouton principal n'a pas le même nom : « Tracer sur la carte ▾ » (W), « Créer ▾ » qui lance le tracé sans le dire (M). |
| W-N9 / M-F23 | W `fr/common.json:2330`, `routes.upload.*` ; M `fr.json` (`routes.manage.*`, `routes.editor.*`, `routeGenerator.*`, `routeRetouch.*`) | mineur | GPX : « Importer des GPX » / « Importer un fichier GPX » / « Remplacer le fichier GPX » / « Remplacer le GPX » / « Envoyer un fichier GPX ». Calcul : « Générer » / « Proposer » ; « Modifier les réglages » / « Modifier la demande ». Quota : deux formulations. `useHint` dit « s'ouvre dans le planificateur » (c'est l'éditeur). Bilan « Fichiers refusés » au pluriel pour un seul, « 0 parcours importé ». |
| M-F22 | M `route_retouch_page.dart:483`, `:384` | mineur | Attente de la retouche « Génération… » ; retour annoncé « Fermer » au lieu de « Retour ». |
| M-N13 | M `fr.json:1597-1600`, `:1628-1629` | mineur | La page de choix (« Importer ou tracer le parcours ») tait le générateur qu'elle propose ; clés mortes `teams.dashboard.create.routeHint`, `routes.editor.pickButton`. |
| W-F20 | W `fr/common.json:1027`, `:1058` | mineur | Outils GPX : « fichier » partout, mais « Parcours créé » et « Nom du parcours ». |
| M-F16 | M `gpx_preview_page.dart:458-467` | mineur | « Enregistrer comme parcours » sans message ; la clé « Parcours créé dans {team} » est inutilisée. |
| W-F22 | — | corrigé | Icône « Générer » : `IconSparkles` partout depuis `b7271058d`. |

### 5.2 Écriture épicène

| ID | Où | Gravité | Constat |
|---|---|---|---|
| W-F18 / M-F21 | W `fr/common.json:741`, `:1660` ; M `fr.json:1698` (`routes.planner.quota.teamLift`) | mineur | « un administrateur de l'équipe peut nous contacter » : accord masculin dans une phrase qui décrit un droit (BRANDING §8.2). Les chaînes ajoutées le 25 respectent la règle. |

### 5.3 Parité et entrées manquantes

| ID | Où | Gravité | Constat |
|---|---|---|---|
| M-F15 | M `routes/` | gênant | « Modifier une copie » (`WEB-169`) absent de l'app, sans entrée au ledger. « Dupliquer » est arrivé (`ca16f8b04`). |
| W-F21 | W `FirstSteps.tsx:83`, `RouteListPage.tsx:119`, `pages/route/AllRoutesPage.tsx` | mineur | Générateur absent des Premiers pas et de l'état vide ; `AllRoutesPage` sans création ni lien vers les outils GPX. |
| W-F10, W-F12, M-F17 | W `components/gpxtool/GpxPreviewView.tsx:133-147`, `:193-200` ; M `gpx_preview_page.dart:46-51`, `widgets/gpx_preview_save_as_route_sheet.dart:94` | mineur | « Enregistrer comme parcours » ne demande que l'équipe (nom, surface Route, visibilité par défaut, sans tags) et s'offre à qui n'organise aucune équipe (liste vide). |
| W-N6 | W `RouteEditor.tsx:181-184` vs `:363-366` | mineur (à confirmer) | « Tracer sur la carte » du menu passe `draw:true` sans incrémenter `drawRequest` : le plein écran tactile ne s'ouvre pas, contrairement au bouton du formulaire. |
| M-N14 | M `route_create_actions.dart:54` ; site équivalent | mineur (à confirmer) | Teinte indigo des parcours codée en dur des deux côtés, hors de `contracts/brand-colors.yaml` (BRANDING §3.6) — à trancher : est-ce un enum au sens de la règle ? |

---

## 6. Tests manquants

| ID | Où | Constat |
|---|---|---|
| W-N11 | W | « Remplacer le fichier GPX » sans Vitest ni e2e (`route-replace-gpx-input` inutilisé) ; `initialGpxFile`/`initialDraw` non testés dans `RouteEditor.test.tsx` ; import d'un seul fichier vers le formulaire non testé ; `useGpxUpload` sans test unitaire (multi-fichiers couvert par l'e2e `flow-routes` seulement). |
| M-N15 | M `mobile/patrol_test/modules/route_editor.dart:47-79` | Patrol ne pilote que « Créer » (tracé) et la ligne « Importer » ; `_FixedPicker` rend un seul fichier, l'import multiple n'est jamais testé de bout en bout ; rien pour le tableau de bord, « Générer » de la page de choix, Dupliquer, Ajuster la distance / Déplacer l'arrivée ; rien sur Retour pendant l'import, l'échec serveur, ni la destination après la copie. |
| — | M | `MOB-154` et `MOB-185` ni recettés sur appareil ni couverts par Patrol : M-F2 à M-F6 et M-F10 à M-F12 sont à voir en premier pendant cette recette. |

---

## 7. Décisions du 25 novembre 2026

| # | Question | Décision | Constats couverts |
|---|---|---|---|
| D1 | Garde de sortie sur le site | **Tous les éditeurs** : un hook commun (`useBlocker` pour la navigation interne, `beforeunload` pour un rechargement) dans les éditeurs de parcours et d'aperçu GPX ; la modale de création depuis une sortie ou un voyage reçoit un bouton Annuler et la même confirmation. | W-F1, W-F2, W-F3, W-F15 |
| D2 | Transmission d'une proposition (générateur, retouche, fichier, tracé) | **Consommée une fois** : lue au montage puis retirée de l'historique (site) ou de l'`extra` (app) ; aucun brouillon persistant. Dans l'app, la page de choix montre « Une proposition attend » avec un bouton pour l'ouvrir au lieu de la cacher, et « Enregistrer » ne part pas sans elle sans le dire. | W-F7, W-F8, M-F5, M-F6, M-F11, M-F19, M-N9 |
| D3 | Vocabulaire | **Un lexique dans BRANDING §8**, appliqué au site et à l'app : « Modifier » = éditer ; « Remplacer la trace » en sortie de retouche ; « Ouvrir dans l'éditeur » pour toute proposition ; « Importer des GPX » / « Remplacer le fichier GPX » ; « Changer de parcours » dans les sorties et voyages. | W-F4, W-F5, W-F19, W-N3, W-N5, W-N9, M-N8, M-F23, M-N13 |
| D4 | Import de plusieurs GPX | **Bilan, et la liste seulement si la personne est restée** : progression n/total, bilan avec la raison de chaque refus, navigation vers la liste seulement si la personne est encore sur la page de départ ; l'app bloque Retour pendant l'import comme pendant un enregistrement. | W-N1, W-N2, W-F9, M-N1, M-N2, M-N3, M-F7 |
| D5 | Quota épuisé | **Griser partout** : `plannerQuota` ajouté à la liste d'équipes lue par l'accueil (changement de contrat), « Tracer » et « Générer » grisés dans les menus de l'app, le générateur mobile relit l'équipe à l'ouverture et désactive « Générer ». | W-N7, W-F8, M-N7, M-F8 |
| D6 | Parité de l'app | **Ajouter les deux** : « Modifier une copie » vers les outils GPX de l'app, et l'offre de retouche lue aussi sans `canEdit` (sortie « Nouveau parcours » seulement). | M-F15 |

**Lots livrés** : D1 (`WEB-213`), D2 (`WEB-214`, `MOB-187`), D3 (`WEB-215` ; « Remplacer le tracé »
plutôt que « la trace », que le lexique réserve), D4 (`WEB-216`, `MOB-188`).

**Corrections nettes livrées le 25 novembre 2026** : W-F6 et W-F18 (`WEB-212`) ; M-F2, M-N5, M-F3,
M-F4, M-F12, M-F21, M-F22 et M-F24 (`MOB-186`).

Restent sans décision et se traitent au fil des lots : les outils GPX (W-F10 à W-F13, W-F20, M-F16, M-F17,
M-F20), le planificateur embarqué (M-F13, M-F14), les tests (§6) et M-N14 (teinte indigo).

Une entrée au ledger (`WEB`, `MOB`) par lot ; ce plan la cite une fois créée.
