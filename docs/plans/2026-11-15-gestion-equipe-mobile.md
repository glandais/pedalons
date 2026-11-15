# Créer et gérer une équipe dans l'application mobile

Écrit le 15 novembre 2026. **État : lots 1 à 3 écrits le 15 novembre 2026 (`MOB-165`, `MOB-166`
et `MOB-167` — restent leurs tests Patrol à lancer — et `WEB-184`, livré) ; lots 4 et 5 conçus,
pas codés.** Ce que les lots 1 à 3 ont tranché en codant est noté « Fait » dans les sections 4,
5, 6 et 7.1. Ledger : `MOB-165` (socle et
création), `MOB-166` (paramètres et webhook), `MOB-167` (membres et invitations), `MOB-168` (lieux et
signalements), `MOB-169` (tags et pages), `WEB-184` (libellé `USER_TEAM_LIMIT_REACHED`). Numéros
réservés le 15 novembre 2026, entrées créées le même jour dans `LEDGER_NEXT.md`. Branche prévue :
`feat/mobile-gestion-equipe`, un commit par lot.

Chemins relatifs à `mobile/lib/` sauf mention contraire.

---

## 1. En une page

Aujourd'hui l'app ne sait que rejoindre ou quitter une équipe et accepter une invitation reçue. Le
bloc « Administration » du tableau de bord est en lecture seule : ses trois boutons (« Inviter »,
« Gérer les membres », « Paramètres ») et l'entrée « signalements » ouvrent le site
(`features/teams/presentation/team_web_paths.dart`). Créer une équipe, gérer ses lieux, ses tags et
ses pages n'ont aucun point d'entrée.

Ce plan amène dans l'app, à parité fonctionnelle avec le site :

1. la **création d'équipe** ;
2. les **paramètres** (profil, slug, logo, modules, fuseau, visibilité, webhook, suppression) ;
3. la **gestion des membres** (rôles, retrait, invitations par e-mail) ;
4. les **lieux**, les **signalements**, les **tags** et les **pages personnalisées**.

**Aucun changement backend ni de contrat d'API** : le client Dart généré expose déjà tous les
endpoints. Le seul contrat touché est `contracts/routes.yaml`. Un seul écart fonctionnel voulu avec
le site : la section « Paramètres plateforme » (§3, D1).

### Décisions du ledger rouvertes

| Décision | Ce qu'elle disait | Ce que le plan en fait |
|---|---|---|
| `MOB-144` | « Créer une équipe depuis l'app : non » (12 novembre 2026) | Rouverte : la création arrive (lot 1). La ligne quitte « Délibérément dehors », et la mention « l'app ne crée ni annonce ni équipe » de `LEDGER_DONE.md` est corrigée |
| `MOB-24` | L'administration d'équipe reste au site | Sa part « administration d'équipe » est livrée ; ne reste dehors que le planificateur de parcours sur carte |
| D20 du plan des tags (`plans/archive/2026-10-01-tags.md`) | « Mobile : affichage + filtre seulement » | Rouverte : l'app administre le vocabulaire (lot 5). Le commentaire de `features/tags/providers/team_tags_provider.dart` est à corriger |
| `MOB-54` | Les chemins d'admin sont des `appScreen: false` ouverts dans le navigateur | Dépassée : ces routes deviennent des écrans, `team_web_paths.dart` disparaît |

## 2. État des lieux (15 novembre 2026)

### 2.1 Ce que fait le site

Droits (`frontend/src/lib/teamAccess.ts`) : `isOrganizer` = admin de plateforme, `ADMIN` ou
`ORGANIZER` ; `isAdmin` = admin de plateforme ou `ADMIN`. Un admin de plateforme non membre a
`team.role == null`.

« Gestion de l'équipe » (`TeamAdminLayout.tsx`) est un jeu d'onglets, dans cet ordre : Modèles de
sortie, Lieux, Tags\*, Pages\*, Gestion des membres\*, Signalements, Paramètres\* (\* = admin
seulement). `/admin` ne rend rien et redirige vers les modèles de sortie.

Faits qui contredisent ce qu'on supposerait :

- **Pas de champ logo séparé, ni bannière, ni couleurs, ni liens sociaux.** Le logo vit dans
  l'éditeur de description (`media.assets.logo`). À la création, logo, images et pièces jointes
  sont masqués : l'upload (`POST /api/teams/{slug}/assets`) exige un slug.
- **Le slug** est généré par le backend, jamais saisi à la création, modifié ensuite par un appel à
  part (`PATCH /api/teams/{slug}/slug`).
- **La visibilité ne se choisit pas à la création** : une équipe naît `TEAM`.
- **Pas de politique d'adhésion pour l'admin d'équipe** (`joinable` est un réglage de plateforme),
  **pas de demandes d'adhésion à valider**, pas de transfert de propriété, pas de restauration
  d'équipe hors administration de plateforme.
- **Invitations par e-mail seulement** : pas de lien, pas d'action en masse, pas d'export.
- **Le site ne sait pas rétrograder un admin** (le backend le permet, sous `LAST_ADMIN`).
- **`memberId` des endpoints de membre est l'identifiant de l'utilisateur** (`member.user.id`), pas
  celui de l'adhésion.
- **Erreurs** : presque toutes passent par un toast générique `errors.api.<CODE>`.

### 2.2 Ce qu'a l'app

- `features/teams/data/team_repository.dart` : lecture, rejoindre, quitter. Aucune écriture d'admin.
- `features/teams/data/invitations_repository.dart` : `listMine`, `accept` seulement.
- `team_members_page.dart` : lecture seule ; toucher une ligne ouvre signaler/bloquer.
- Pas de provider « est admin de l'équipe » : des `team.role == 'ADMIN'` en ligne, et
  `teamManagePermission` (`features/rides/providers/ride_editor_providers.dart`) qui lit « Mes
  équipes » (d'où `MOB-96`).
- `api/pedalons_api_client.dart` : il manque les providers de `TeamInvitationsClient` et
  `TeamWebhookClient` ; tous les autres clients nécessaires y sont.
- Routes (`contracts/routes.yaml`) : `teamsNew`, `teamAdmin`, `teamAdminPlaces`, `teamAdminTags`,
  `teamAdminPages`, `teamAdminPageNew`, `teamAdminPageEdit` sont `web` seulement ;
  `teamAdminMembers`, `teamAdminReports`, `teamSettings` sont `mobile: true, appScreen: false`.
- Aucun test Patrol ne couvre une action d'administration d'équipe.

### 2.3 Le modèle d'éditeur à suivre

`features/posts/presentation/pages/post_editor_page.dart` (`MOB-164`) :

1. page publique `ConsumerWidget` qui tranche le **refus avant de lire l'entité** ;
2. formulaire privé `ConsumerStatefulWidget`, clé `ValueKey(entity.id ?? 'new-…')` ;
3. modèle immuable (`XForm.initial` / `.fromX`, `copyWith`, `toRequest()`, getters de validité),
   sans `Form` ni `validator:` ; un `TextEditingController` par champ texte ;
4. état modifié par comparaison du JSON de `toRequest()`, `PopScope` + `confirmDestructive` ;
5. erreurs de champ seulement après une tentative d'enregistrement, erreurs serveur dans un
   `PdlBanner` en tête, codes lus par `resolveApiError` (`core/utils/api_error_handler.dart`) ;
6. `PdlScreenScaffold` + `PdlActionBar` à un bouton, corps en `EditorSection` ;
7. un seul point d'invalidation par entité (`notifyXChanged`).

## 3. Décisions (15 novembre 2026, avec le propriétaire)

| # | Décision | Raison |
|---|---|---|
| D1 | **La section « Paramètres plateforme » reste au site.** L'app ne montre que la visibilité de l'équipe, modifiable si `visibilityEditable` ou admin de plateforme, sinon en badge. Palier, note, `joinable`, `addMemberAllowed`, traceur, contenu public par lien : pas dans l'app | L'app n'a aucune administration de plateforme ; évite le second appel `PATCH /api/admin/teams/{id}/attributes` et son échec partiel. Seul écart fonctionnel avec le site |
| D2 | **L'app administre les tags** (D20 rouverte) | Les éditeurs de l'app posent déjà des tags ; l'écran n'a aucun point dur mobile |
| D3 | **Pas de compteur de caractères** sous la description d'équipe ni sous une page | Les « 2000 » et « 10000 » du site ne sont appliqués nulle part (contrat : 100 000) ; les autres éditeurs de l'app n'en ont pas |
| D4 | **Le libellé de `USER_TEAM_LIMIT_REACHED` est corrigé dans l'app et sur le site**, dans le lot 1 | Le texte actuel (« limite d'équipes rejoignables ») est faux : le code est levé quand la personne administre déjà une équipe (§5.2) |
| D5 | **Un hub « Gestion de l'équipe »** en liste, pas d'onglets | L'app n'a pas de barre d'onglets imbriquée (`mobile/CLAUDE.md`) |
| D6 | **Les pages se réordonnent par boutons monter / descendre** | Le site n'a que le glisser-déposer ; trois pages au plus, et des cibles de 44 px accessibles |
| D7 | **Le webhook est une `PdlFullSheet`** ouverte depuis Paramètres | Il a son propre « Enregistrer », distinct de celui du formulaire d'équipe |
| D8 | **Parité stricte sur les règles de membres** : pas de rétrogradation d'un admin, pas d'ajout direct par `addMember` | « Iso fonctionnel » ; l'élargir se décide des deux côtés |

### Arbitrages des déclarations des stores (§8) — tranchés le 15 novembre 2026

| # | Question | Décision |
|---|---|---|
| O1 | La localisation d'équipe et l'adresse d'un lieu relèvent-elles de *Physical Address* ou de *Other User Content* ? | ***Physical Address*** (Play : *Address*), sous les lignes existantes (`MOB-159`) : un lieu de départ peut être le domicile de quelqu'un. Inscrit dans `mobile/store-metadata/data-safety.md` pour la localisation d'équipe avec le lot 1 (ligne d'inventaire #26) ; l'adresse d'un lieu suit avec le lot 4 |
| O2 | L'e-mail d'une personne invitée, saisi à la main, demande-t-il une déclaration propre ? | **Non** : ligne *Email Address* existante. Inscrit dans `data-safety.md` avec le lot 3 (ligne d'inventaire #28) ; la politique de confidentialité, relue, vaut pour l'app telle quelle |

## 4. Socle (lot 1)

### 4.1 Droits

Nouveau `features/teams/domain/team_permissions.dart`, reprise de `teamAccess.ts` :
`isTeamOrganizer` et `isTeamAdmin`, à partir du rôle de `TeamDetailDto` et de
`user.platformRole == 'PLATFORM_ADMIN'`. Deux providers par slug lisent **`teamDetailProvider`**, pas
« Mes équipes » : un admin de plateforme non membre y est donc traité correctement (le défaut
`MOB-96` ne se reproduit pas ici). `null` tant que la fiche charge : ni bouton, ni refus.

Le refus est rendu dans la page (`PdlEmptyState` + bouton Retour à clé), jamais par le routeur, qui
ne lit pas l'authentification.

### 4.2 Routes

`contracts/routes.yaml`, puis `pnpm generate-routes` dans `frontend/` :

| Route | Avant | Après |
|---|---|---|
| `teamsNew`, `teamAdmin`, `teamAdminPlaces`, `teamAdminTags`, `teamAdminPages`, `teamAdminPageNew`, `teamAdminPageEdit` | `web` | + `mobile: true`, `deeplink: true` |
| `teamAdminMembers`, `teamAdminReports`, `teamSettings` | `mobile: true, appScreen: false` | `appScreen` retiré, `deeplink: true` |

Chaque drapeau bascule **dans le commit de l'écran correspondant** (règle de `routes.yaml`), donc
lot par lot. Dans `config/router.dart` :

- `teamsNew` se déclare avant `:teamSlug`, comme `teamsDiscover` ; `teamAdminPageNew` avant
  `teamAdminPageEdit`. **Fait (lot 1)** : `teamsNew` est une route de premier niveau, déclarée
  **avant le shell** — go_router refuse à une route directe d'une branche un
  `parentNavigatorKey` autre que celui de la branche ; hors du shell, elle est plein écran sans
  clé ;
- les écrans d'édition sont des `GoRoute` à `parentNavigatorKey: _rootNavigatorKey` ;
- chaque route reçoit son entrée dans `_deepLinkHierarchies` (ancêtres : teams, team, `teamAdmin`),
  couverte par `test/deep_link_hierarchy_test.dart`. **Fait (lot 2)** : `_teamAdminAncestor` existe
  (`config/router.dart`), et `teamSettings` est une **sous-route** du hub (`_teamSettingsRoute`,
  dans les `routes:` de la `GoRoute` de `teamAdmin`, comme le formulaire d'un modèle sous sa
  liste) : un `go` vers elle reconstruit le hub dessous. Les écrans des lots 3 à 5 se déclarent de
  la même façon. Une route qui devient un écran s'ajoute aussi à `internalRouteTemplates`
  (`core/utils/link_launcher.dart`), sans quoi `link_launcher_test` échoue.

**Fait (lot 1)** : `teamAdminPlaces`, `teamAdminTags` et `teamAdminPages` n'avaient pas de builder
Dart ; le hub les ouvrant sur le site, elles sont passées `mobile: true, appScreen: false` comme
les trois autres (`MOB-54`), et `TeamWebPaths` a gagné `places`, `tags` et `pages`. Chaque lot retire
`appScreen` et ajoute `deeplink: true` pour ses routes. `teamAdminPageNew` et `teamAdminPageEdit`
restent `web` seulement jusqu'au lot 5.

`webOnlyRouteIds` se réduit à `features`. `team_web_paths.dart` perd une entrée par lot et disparaît
au lot 5 ; `test/features/teams/team_web_paths_test.dart` suit. La notification `CONTENT_REPORTED`
(`notification_display.dart`, `notifications_page.dart`) ouvre l'écran de l'app à partir du lot 4.

La page d'atterrissage d'invitation par jeton (route `invitation`) reste au site.

### 4.3 Hub « Gestion de l'équipe »

`features/teams/presentation/pages/team_admin_page.dart`, sur `teamAdmin`. Accès : organisateur.
Une liste de `PdlSettingRow`, dans l'ordre du site : Modèles de sortie (écran existant,
`Paths.rideTemplates`), Lieux, Tags\*, Pages\*, Membres\*, Signalements, Paramètres\*. Les lignes \*
ne sont rendues qu'à un admin. Tant qu'un lot n'est pas livré, sa ligne ouvre le site.

Entrées :

- bouton « Gérer » dans l'en-tête d'équipe (`team_header.dart`), pour un organisateur. **Fait
  (lot 1)** : une icône de barre (`PdlIcons.settings`, libellé d'accessibilité « Gérer l'équipe »,
  clé `keys.team.manageButton`) entre l'action d'adhésion et le partage — la barre porte déjà
  « Quitter » en toutes lettres ; le droit est lu sur l'équipe que l'en-tête affiche ;
- les boutons de `widgets/dashboard/dashboard_admin.dart` et l'entrée signalements de
  `dashboard_todo.dart`, repointés lot par lot.

### 4.4 Invalidation

`notifyTeamChanged(ProviderContainer, slug)` dans `features/teams/providers/` : fiche, « Mes
équipes », tableau de bord, découverte, et `invalidateMembershipScopedContent` quand la visibilité
ou le fuseau a changé. Il prend le conteneur, comme `notifyRideTemplatesChanged`, pour survivre à un
écran démonté. **Fait (lot 1)** : `features/teams/providers/team_change.dart`,
`notifyTeamChanged(container, slug, {contentScopeChanged})` — le drapeau est à passer à `true`
quand la visibilité ou le fuseau a changé ; après un changement de slug, l'appeler pour l'ancien et
pour le nouveau.

### 4.5 Sélecteur de lieu géocodé

`showAdPlacePicker` n'est pas réutilisable tel quel : libellés `ads.editor.*`, dépôt rangé dans
`features/ads/`, et la résolution de la position vit dans `ad_editor_page.dart` (`_pickPlace`).

Extraction vers `features/geocoding/` (pas `core/pdl`, qui n'importe aucun DTO et ne traduit rien) :

- `PlaceSearchRepository` et son provider, déplacés tels quels ;
- `pickGeocodedPlace(context, ref)` : recherche (`GET /api/geocode/search`, 3 caractères minimum)
  puis résolution (`GET /api/geocode/place`), rend `({name, lat, lon})` ou un échec typé
  (`unavailable` pour `GEOCODING_UNAVAILABLE`, `failed` sinon) ;
- un signal « résolution en cours » pour désactiver « Enregistrer », équivalent du
  `onResolvingChange` du site ;
- des clés neutres `geocoder.*`.

Chaque formulaire convertit vers son type : `TeamRequestGeometry`, `PlaceRequestGeometry` et
`AdRequestLocationGeometry` sont trois classes générées distinctes aux champs identiques, ordre
GeoJSON `[lon, lat]`. L'éditeur d'annonce passe sur le sélecteur commun ; restent aux annonces le
texte « environ 1 km », la carte en secteur et `adLocationOf`. `test/features/ads/ad_editor_page_test.dart`
change d'import.

**Fait (lot 1)** : `features/geocoding/data/place_search_repository.dart` et
`features/geocoding/presentation/geocoded_place_picker.dart` — `pickGeocodedPlace(context, ref,
{title, onResolvingChange})` rend `null` (feuille fermée), un `GeocodedPlace` (`name`, `lat`, `lon`,
`coordinates` dans l'ordre GeoJSON) ou un `GeocodedPlaceFailure` (`GeocodeFailure.unavailable` /
`failed`, avec son `message`). Clés `geocoder.*` : `label`, `search`, `empty`, `attribution`,
`resolving`, `resolveFailed`, `unavailable`, `none`, `saved` (`clear`, jamais lue, a été retirée
au lot 2 : `EditorClearButton` ne prend pas de libellé).

Vérifié en codant : le champ de recherche de `search_picker_sheet.dart` est un `PdlSearchField`, qui
temporise la saisie de 350 ms (`kSearchDebounce`, `core/pdl/pdl_search_field.dart`) ; le site attend
300 ms. Rien à ajouter.

## 5. Création d'équipe (lot 1, `MOB-165`)

### 5.1 Écran

`features/teams/presentation/pages/team_editor_page.dart` sur `teamsNew`, avec
`features/teams/domain/team_form.dart`. Accès : toute personne connectée. Entrée : « Créer une
équipe » dans la barre et l'état vide de `teams_page.dart`. Le mode mono-équipe du site n'a pas
d'équivalent (`MOB-88`).

| Champ | Contrôle | Règle | `TeamRequest` |
|---|---|---|---|
| Nom de l'équipe | texte | requis, 1 à 200, au moins un caractère non blanc | `name` |
| Description | `RichMarkdownEditorField`, `onInsertImage: null` | pas d'image ni de logo à la création | `media.markdown` |
| Localisation | `pickGeocodedPlace`, effaçable | facultative | `geometry` |
| Fuseau horaire | `showTimezoneSheet` | défaut : la préférence de fuseau du profil, sinon `Europe/Paris` (voir ci-dessous) | `timezone` |
| Activer les parcours | `PdlSwitch` | décoché : sorties et voyages passent à faux et se grisent | `enableRoutes` |
| Activer les sorties | `PdlSwitch` | grisé sans parcours | `enableRides` |
| Activer les voyages | `PdlSwitch` | grisé sans parcours | `enableTrips` |
| Activer les publications | `PdlSwitch` | | `enablePosts` |
| Activer les annonces | `PdlSwitch` | | `enableAds` |
| Ouvrir le trombinoscope aux membres | `PdlSwitch` | défaut faux | `enableMemberDirectory` |
| Publications au nom de l'équipe par défaut | `PdlSwitch` | grisé sans publications | `postsAsTeamByDefault` |

Valeurs initiales : tous les modules à vrai sauf le trombinoscope, `visibility: TEAM` (non
proposée), `postsAsTeamByDefault: true`.

Enregistrement : `createTeam`, `notifyTeamChanged`, message « Équipe créée », puis la page de
l'équipe. **Fait (lot 1)** : par `go`, pas `pushReplacement` — la page d'une équipe est une page
d'onglet, et l'empiler depuis un écran plein écran laisse un écran vide sans retour
(`mobile/CLAUDE.md`, ledgers `MOB-44`, `MOB-46`, `MOB-138`).

**Écart : le fuseau de départ n'est pas celui de l'appareil.** L'app ne connaît pas le nom IANA du
fuseau de l'appareil : `AppFormatters` ne manipule que la préférence `UserDto.timezone` et retombe
sur `.toLocal()`, et `editorTimezoneProvider` interroge un endpoint d'équipe (le fuseau d'un point).
Le formulaire part donc de la préférence de fuseau du profil et, sans elle, de `Europe/Paris` — le
défaut du serveur (`API-60`) —, affiché sur la ligne et modifiable par `showTimezoneSheet`. Lire le
fuseau de l'appareil demanderait un plugin natif (`flutter_timezone`) : à décider.

### 5.2 Erreurs

- `TEAM_CREATION_DISABLED` : clé déjà présente dans l'app.
- `USER_TEAM_LIMIT_REACHED` : **la clé est absente de `mobile/assets/l10n/fr.json` et `en.json`**,
  l'app afficherait `common.error`. À créer dans les deux langues. Le code n'est levé qu'à
  `TeamService.java:154`, quand la personne (hors admin de plateforme) est déjà `ADMIN` d'une équipe
  non supprimée du domaine ; être membre ne compte pas, et l'erreur ne porte **aucun
  `errorDetails`** : le texte reste sans nombre. Proposition : « Vous administrez déjà une équipe :
  il n'est pas possible d'en créer une autre. »
- **Site (`WEB-184`)** : même correction à `frontend/src/locales/fr/common.json:720` et
  `en/common.json:704`. Le plan de monétisation (`plans/2026-10-17-monetisation.md`) prévoit une
  limite par offre : le texte sera à revoir alors.

## 6. Paramètres et webhook (lot 2, `MOB-166`)

### 6.1 Paramètres

Même `team_editor_page.dart` en mode édition, sur `teamSettings`. Accès : admin.

En plus des champs de création :

- **Slug** : `PdlSettingRow`, puis `showSlugEditSheet` (après abandon confirmé d'un formulaire
  modifié), `changeTeamSlug`, `notifyTeamChanged`, `context.go(Paths.teamSettings(nouveau))`.
  `SLUG_TAKEN` et `INVALID_SLUG` en bandeau.
- **Logo, images, pièces jointes** : `EditorMediaActions` et `RideMediaSection`, upload immédiat
  par `uploadAsset(teamSlug, …)` (`LOGO`, `IMAGE`, `ATTACHMENT`) ; l'éditeur riche retrouve son
  outil image. Rester sur `pickImage` (images fixes).
- **Visibilité** : `PdlSettingRow` ouvrant une feuille à trois choix (« Équipe uniquement »,
  « Non répertorié », « Public ») si `team.visibilityEditable` ou admin de plateforme ; sinon un
  badge. Rien d'autre de la section plateforme (D1).
- **Zone de danger** : `PdlDangerZone`, « Supprimer l'équipe », `confirmDestructive`, `deleteTeam`,
  retour à la liste des équipes. `MIGRATED_TEAM` en bandeau.

Enregistrement, dans l'ordre du site :

1. si la visibilité repasse à `TEAM` : confirmation « Rendre l'équipe privée ? » (tout le contenu
   repasse en « Équipe uniquement », les liens partagés cessent de marcher, rouvrir l'équipe ne
   rouvre pas le contenu) ;
2. si le fuseau change : feuille de confirmation alimentée par `previewTeamTimezoneChange` —
   passage de `from` à `to`, nombre de rendez-vous à venir sans lieu de départ avec un exemple lu
   dans l'ancien fuseau, nombre de passés, et la phrase sur les rendez-vous situés par un lieu ou un
   parcours qui ne changent pas. Bouton de confirmation inactif tant que l'aperçu n'est pas chargé ;
   en cas d'échec, message et « Réessayer » ;
3. `updateTeam` (PUT), `notifyTeamChanged`, message, retour à l'équipe.

**À ne pas manquer : le PUT réécrit tous les champs.** `TeamForm.fromTeam` reprend `about.assets`
en entier (logo, images, pièces jointes), `geometry`, `timezone`, `postsAsTeamByDefault` et les six
modules ; `toRequest()` construit un `TeamRequest` propre (le site, lui, y recopie tout le
`TeamDetailDto`).

**Fait (lot 2)** — ce que le code a tranché :

- **Effacer la localisation passe par le PUT.** `TeamService.updateTeam` fait
  `team.setGeometry(request.geometry())` sans condition : une position nulle **ou absente** efface
  celle de l'équipe (seuls `timezone` et `postsAsTeamByDefault` sont « laissés tels quels » par
  omission). L'app envoie `geometry: null`, le site omet la clé (`point ?? undefined`) : même
  effet. C'est aussi pourquoi un formulaire intact doit renvoyer la position.
- **Accès** : `TeamEditorPage(teamSlug:)`. Le refus (`keys.teamEditor.forbidden`) est rendu avant
  le formulaire ; une fiche que le serveur refuse (403, ou 404 pour une équipe privée) rend le
  même refus, pas « Erreur de chargement » — `isTeamAccessRefusal`
  (`providers/team_access_probe.dart`), que le hub emploie aussi ; son « Retour » mène alors à
  « Mes équipes ». Une fiche déjà lue reste le formulaire en cours même si sa relecture échoue
  (équipe supprimée, adresse changée).
- **Slug** : la feuille commune a gagné un paramètre `hint` — l'ancienne adresse d'une équipe
  **redirige** vers la nouvelle (`slugService.createTeamRedirect`), celle d'un contenu non ; la
  feuille d'équipe dit « L'ancienne adresse redirigera vers la nouvelle ».
- **Visibilité** : `widgets/team_visibility_sheet.dart` (`showTeamVisibilitySheet`). Non
  modifiable, la ligne porte un `VisibilityBadge` et une phrase qui dit pourquoi
  (`teams.editor.visibilityLocked`), absente du site.
- **Fuseau** : `widgets/team_timezone_change_sheet.dart` (`confirmTeamTimezoneChange`,
  `timezoneChangeLines`). L'aperçu est lu **à l'ouverture de la feuille**, pas dès que le fuseau
  change dans le formulaire comme au site : une requête de moins par essai de fuseau, et « Changer
  le fuseau » inactif entre-temps de toute façon. Un type d'événement que l'app ne connaît pas
  (`TimezoneChangeEntityType.$unknown`) prend un exemple neutre (`…example.other`).
- **Confirmation « Rendre l'équipe privée »** : `confirmDestructive` (bouton en contour rouge), là
  où le site a une variante « avertissement » : l'app n'a pas de troisième ton de confirmation.
- **Suppression** : texte du site, sans gras (`confirmDestructive` prend une chaîne) ;
  `PdlDangerZone` a gagné `actionKey`. Après elle, `notifyTeamChanged(…, contentScopeChanged:
  true)` : le contenu de l'équipe a disparu avec elle.
- **Message de succès** : « Équipe mise à jour » (le site : « … avec succès »), dans le ton
  d'« Équipe créée ».
- **`errors.api.INVALID_TIMEZONE`** manquait à `fr.json` et `en.json` (l'app aurait dit
  « Erreur ») : ajoutée, texte du site.
- **Pas d'« Annuler »** à côté d'« Enregistrer » : le retour de la barre, avec sa confirmation
  d'abandon, comme les autres éditeurs de l'app.

### 6.2 Webhook

`features/teams/presentation/widgets/team_webhook_sheet.dart`, `PdlFullSheet` ouverte par une ligne
« Webhook » des Paramètres ; `features/teams/data/team_webhook_repository.dart` et le provider de
`TeamWebhookClient` à ajouter.

- Adresse actuelle : `maskedUrl` seulement (l'URL est un secret) et le type (Slack, Discord,
  Mattermost, JSON).
- URL : champ vide au départ ; laissé vide, il garde l'adresse actuelle (`url` omis). 1000
  caractères au plus.
- Langue (fr / en) : celle du webhook, sinon celle de l'app.
- « Envoyer les annonces » : `PdlSwitch`, vrai pour un nouveau webhook.
- Dernier envoi : statut, date, `lastError`.
- « Enregistrer » (`saveTeamWebhook`, inactif sans URL pour une première configuration ;
  `WEBHOOK_URL_INVALID` en bandeau), « Envoyer un message de test » (`testTeamWebhook`, résultat en
  `PdlBanner` avec le code HTTP), « Supprimer le webhook » (confirmation, `deleteTeamWebhook`).

Le bloc webhook du tableau de bord (`dashboard_admin.dart`) reste tel quel ; il est rafraîchi par
`notifyTeamChanged`.

**Fait (lot 2)** : `showTeamWebhookSheet(context, teamSlug)`, clés `keys.teamWebhook.*`.

- La feuille **reste ouverte** après « Enregistrer » et après la suppression, comme la section du
  site : un `PdlBanner` y dit « Webhook enregistré » / « Webhook supprimé » — un snackbar serait
  rendu sous la feuille. Elle repart alors de l'état enregistré (champ vide, adresse masquée).
- « `url` omis » : le client généré sérialise `url: null` (pas de `includeIfNull: false`), que
  `TeamWebhookService.save` lit comme une absence (`url == null || isBlank`). Même chose pour
  `geometry` ci-dessus.
- Après un message de test, la feuille relit le webhook : « Dernier envoi » a changé.
- La langue se choisit par un `PdlSegmented` (Français / English), pas une liste.
- Le libellé du type (Slack…) et du statut du dernier envoi réemploient
  `teams.dashboard.admin.webhook.kind.*` / `.status.*`.

## 7. Membres, lieux, signalements, tags, pages

### 7.1 Membres et invitations (lot 3, `MOB-167`)

`features/teams/presentation/pages/team_admin_members_page.dart` sur `teamAdminMembers`. Accès :
admin. `team_members_page.dart` (le trombinoscope) ne change pas.

- **En-tête** : compteur « n / limite membres » si `memberLimit` ; bouton « Inviter par e-mail »
  absent si `!team.addMemberAllowed`, inactif si l'équipe est pleine (sauf admin de plateforme),
  avec la notice « limite de l'offre gratuite » et le lien de contact.
- **Liste** : `TeamMembersNotifier` (pagination existante), recherche par nom ou e-mail, filtre de
  rôle en puces (Membre, Organisateur, Administrateur). Pas de tri, comme le site.
- **Ligne** : avatar, nom, « (vous) », « Membre depuis … », badge de rôle. Toucher une ligne ouvre
  une `PdlSheet` :
  - « Modifier le rôle » si la ligne n'est ni la sienne ni celle d'un admin : choix du rôle,
    `updateMemberRole` avec **`member.user.id`** ;
  - « Retirer de l'équipe » sur toute ligne sauf la sienne : confirmation, `removeMember` ;
    `LAST_ADMIN` en bandeau ;
  - signaler / bloquer, déjà en place.
- **Invitation** : `PdlSheet` — adresse e-mail (requise, forme `x@y.z`, 250 au plus), rôle (Membre
  par défaut), rappel que la personne ne rejoint l'équipe que si elle accepte. `invite` ; en cas
  d'erreur la feuille reste ouverte avec la saisie et un bandeau (`TEAM_INVITE_SELF`,
  `TEAM_INVITE_ALREADY_MEMBER`, `TEAM_MEMBER_LIMIT_REACHED` avec `limit`, `TEAM_INVITE_RATE_LIMITED`,
  `TEAM_INVITE_DELIVERY_FAILED` : clés déjà présentes). Le paramètre `?invite=1` de la route ouvre
  la feuille, pour le bouton « Inviter » du tableau de bord.
- **Invitations en attente** : section masquée si vide, une carte par invitation (adresse, rôle,
  « Invitation de … », « Expire le … »), en place du tableau de 520 px du site. « Renvoyer »
  rappelle `invite` avec la même adresse et le même rôle (le serveur révoque l'ancienne) ;
  « Annuler l'invitation » confirme puis `revoke`. Première page seulement, comme le site.

Données : `features/teams/data/team_invitations_repository.dart` et le provider de
`TeamInvitationsClient`. Après chaque écriture : liste des membres, invitations, et
`notifyTeamChanged` (le compteur et la répartition par rôle du tableau de bord en dépendent).

**Fait (lot 3)** — ce que le code a tranché :

- **Accès** : `TeamAdminMembersPage(teamSlug:, openInvite:)`, sous-route du hub
  (`_teamAdminMembersRoute`). La page publique tranche le refus (`keys.teamAdminMembers.forbidden`,
  403 et 404 de `GET team` compris) ; les membres et les invitations ne sont écoutés que par le
  corps rendu à qui administre. Un organisateur, un membre ou une équipe refusée ne déclenchent
  donc **aucune** requête de membres ni d'invitations — le test de page le vérifie.
- **Les invitations en attente sont au-dessus de la liste**, pas dessous comme au site : la
  liste se charge par défilement, une section placée après elle ne serait jamais atteinte dans
  une grande équipe. Ordre de l'écran : compteur et « Inviter par e-mail », invitations, barre
  épinglée (recherche, puces de rôle), liste.
- **Le bandeau d'erreur est dans la barre épinglée** (`LAST_ADMIN`, un renvoi ou une annulation
  refusés) : visible où que soit la liste.
- **Filtres** : `adminMemberFiltersProvider`, distinct de `memberFiltersProvider` — filtrer cet
  écran ne filtre pas le trombinoscope resté ouvert dessous. La liste est la même
  (`teamMembersProvider`, `TeamMembersNotifier` inchangé) ; une puce « Tous » lève le filtre de
  rôle, comme au trombinoscope.
- **Feuille d'une ligne** : le menu de modération (`showModerationMenu`), qui a gagné un
  paramètre `leading` (`ModerationMenuEntry`) — « Modifier le rôle » et « Retirer de l'équipe »
  précèdent Signaler et Bloquer. Le rôle se choisit dans une seconde feuille
  (`widgets/team_role_sheet.dart`) et part aussitôt, sans « Enregistrer » ; choisir le rôle
  actuel n'envoie rien. La confirmation du retrait nomme la personne (le site : « ce membre »).
- **Après un changement de rôle ou un retrait** : toute la famille `teamMembersProvider` est
  invalidée (la liste repart de sa première page, le trombinoscope est relu aussi), puis
  `notifyTeamChanged`. Un message « Rôle mis à jour », absent du site, confirme le changement.
- **Une invitation ne passe pas par `notifyTeamChanged`** : ni la fiche ni le tableau de bord
  n'en dépendent ; seule `teamInvitationsProvider` est relue (comme le site). Exception : un
  **409 à l'annulation** — l'invitation a peut-être été acceptée — relit les invitations, les
  membres, la fiche et le tableau de bord, et le bandeau dit
  `errors.api.TEAM_INVITE_NOT_PENDING`.
- **Feuille d'invitation** (`widgets/team_invite_sheet.dart`, `showTeamInviteSheet`) : le rôle
  se choisit par trois puces. « Envoyer l'invitation » reste actif et les erreurs de champ
  n'apparaissent qu'après une tentative (§2.3), là où le site désactive le bouton. En cas
  d'erreur du serveur la feuille reste ouverte avec un **bandeau** (le site : un toast).
- **Clés d'erreur** : `TEAM_INVITE_SELF`, `TEAM_INVITE_RATE_LIMITED` et
  `TEAM_INVITE_DELIVERY_FAILED` manquaient à `fr.json` et `en.json` (l'app aurait dit
  « Erreur ») : ajoutées, textes du site. `TEAM_INVITE_ALREADY_MEMBER` et
  `TEAM_MEMBER_LIMIT_REACHED` y étaient.
- **Lien de contact d'une équipe pleine** : la page d'assistance **du site** (`Paths.support()`,
  `openTeamWebPage`) — l'app n'en a pas l'écran. `support` passe donc `mobile: true,
  appScreen: false` dans `contracts/routes.yaml` (`MOB-54`) : `webOnlyRouteIds` finira à
  `features` et `support`, pas à `features` seul (§4.2). La notice est celle du site
  (`teams.adminMembers.full` + `.contact`) ; le tableau de bord garde la sienne, et les deux
  lisent `isTeamFull` (`domain/team_member_limit.dart`).
- **`?invite=1`** : `teamAdminMembersInviteLocation(slug)` ; la feuille ne s'ouvre que si
  l'équipe peut inviter (`addMemberAllowed`, pas pleine ou admin de plateforme), comme au site.
- **Déclarations des stores** : ligne #28 de `data-safety.md`, sous *Email Address* (O2). La
  politique de confidentialité (« Invitations dans une équipe », « Auprès d'autres membres »,
  durées de conservation) ne dit rien de propre au site : elle vaut pour l'app, inchangée.

### 7.2 Lieux (lot 4, `MOB-168`)

`features/places/` : page sur `teamAdminPlaces`, accès organisateur.

- Liste paginée (20) avec recherche par nom ou adresse ; ligne : nom, adresse, badges « Départ » /
  « Arrivée », lien « Voir sur la carte » ; menu modifier / supprimer (confirmation, `deletePlace`).
- Formulaire en `PdlFullSheet` : Nom (requis, 1 à 200), Adresse (3 à 200), Lien (3 à 200),
  Localisation (`pickGeocodedPlace`), « Peut servir de départ » et « Peut servir d'arrivée » (vrais
  par défaut). Adresse et lien vides partent absents. `createPlace` / `updatePlace`.
- Après écriture : invalider aussi la recherche de lieux des éditeurs de sortie et de voyage.

### 7.3 Signalements (lot 4, `MOB-168`)

`features/moderation/` : page sur `teamAdminReports`, accès organisateur ou admin de plateforme (un
admin de plateforme y arrive par notification sans être membre).

- `PdlSegmented` « À traiter » / « Traités » (`listTeamReports`).
- Carte par cible : type, nombre de signalements, « Masqué aux membres », date du dernier
  signalement, lien vers le contenu ou « Le contenu n'existe plus. », extrait, motifs, précisions.
  Les personnes qui signalent restent anonymes.
- « Supprimer le contenu » (absent pour une cible `MEMBER`, confirmation) et « Rejeter le
  signalement » : `resolveTeamReports`. Pour un membre signalé, le renvoi vers l'écran Membres.
- Après écriture : file, tableau de bord (« À traiter »), notifications.

### 7.4 Tags (lot 5, `MOB-169`)

Page sur `teamAdminTags` dans `features/tags/`, accès admin.

- Une puce par type (Sorties, Publications, Voyages, Parcours, Annonces) avec son compte ; un type
  est proposé si son module est actif **ou** s'il porte encore des tags.
- Ligne : puce du tag, usage (« Inutilisé » / « n contenus »), modifier, supprimer (confirmation
  avec le nombre de contenus dont il sera retiré, `deleteTeamTag`).
- Pied : « n / 100 tags pour ce type » ; à 100, « Nouveau tag » inactif (`TAG_LIMIT_REACHED`).
- Formulaire en `PdlSheet` : Libellé (requis, 32 au plus après rognage), Couleur (les 9 valeurs de
  `TagColor`, gris par défaut, pastilles tirées du code couleur généré depuis
  `contracts/brand-colors.yaml` — pas de table locale), aperçu. `createTeamTag` (`type`, `label`,
  `color`) ou `updateTeamTag` (`label`, `color` ; le type ne change jamais). `TAG_LABEL_TAKEN` en
  bandeau, feuille ouverte.
- Après écriture : `team_tags_provider.dart` et les compteurs de tags des listes.

### 7.5 Pages personnalisées (lot 5, `MOB-169`)

- **Liste** sur `teamAdminPages`, accès admin : « n pages sur 3 maximum », « Ajouter une page »
  masqué à 3 ; ligne : titre, badge de visibilité, boutons monter / descendre (D6,
  `reorderPages` avec la liste complète des identifiants), modifier, supprimer (confirmation),
  restaurer si `deleted` (`undeletePage`).
- **Éditeur** sur `teamAdminPageNew` / `teamAdminPageEdit`, sur le modèle de l'éditeur de
  publication : Titre (requis, 1 à 100), slug en édition (`changePageSlug`), contenu riche avec
  images et pièces jointes, visibilité par `VisibilityField` avec `VisibilityKind.teamPage` — les
  choix viennent du backend (`team.allowedContentVisibilities.teamPage` à la création,
  `page.permissions.allowedVisibilities` en édition, `MOB-137`). L'édition exige
  `page.permissions.canEdit`. `TOO_MANY_TEAM_PAGES` en bandeau.
- Après écriture : `notifyTeamChanged` (la fiche d'équipe porte `pages[]`, lue par « À propos ») et
  la page elle-même.

## 8. Déclarations des stores

Aucun nouveau type de donnée, mais la règle de `mobile/store-metadata/README.md` impose de mettre à
jour `mobile/store-metadata/data-safety.md` dans le commit de chaque écran : une ligne d'inventaire
(§2) par nouvelle saisie, le texte des §3 à §5, la date de vérification, et le **script de
vérification**, qui attend « exactement deux appels » à `file_picker`.

| Fonction | Verdict |
|---|---|
| Logo, images, pièces jointes | Couvert (*Photos*, *Files and docs*, *Other User Content*) |
| URL de webhook | Couvert (contenu saisi) |
| Localisation d'équipe, adresse d'un lieu | *Physical Address* / *Address*, lignes existantes (O1, §3) |
| E-mail d'une personne invitée | *Email Address*, ligne existante (O2, §3) |

Pas d'« historique de recherche » à déclarer : le filtre des journaux Caddy
(`docs/OPERATIONS.md`) efface `q`, `search` et `id`, les paramètres du géocodage et des recherches
de lieux et de membres — relu le 15 novembre 2026 sur la configuration que documente
`docs/OPERATIONS.md` (`delete q`, `delete search`, `delete id`), et `data-safety.md` §4 note le
filtre installé et vérifié sur l'hôte de production le 14 novembre 2026. La
saisie App Store Connect et l'import Play Console de `MOB-159` ne sont pas faits ; ces écrans s'y
ajoutent.

## 9. Tests

Par lot, sur le modèle de `test/features/posts/post_editor_page_test.dart` (dépôts remplacés par des
doublures écrites à la main, vraies traductions) :

- `*_form_test.dart` : validité, dépendances entre modules, `toRequest()` complet ;
- test de page : refus avant lecture, requête exacte envoyée, formulaire invalide qui n'envoie
  rien, erreur serveur qui garde la saisie, confirmation d'abandon ; pour les paramètres, les deux
  confirmations (privé, fuseau) et la conservation des `assets` ;
- clés dans `features/teams/keys.dart` (et les `keys.dart` des autres dossiers), agrégées dans
  `keys.dart` ;
- Patrol, un fichier par parcours, modules dans `patrol_test/modules/` : `team_create_test`,
  `team_settings_test`, `team_admin_members_test` (invitation lue dans mailpit, changement de rôle,
  retrait), `team_places_test`, `team_reports_test`, `team_tags_admin_test`,
  `team_pages_admin_test`. Les données se sèment par `patrol_test/api/` (`newTeam`, `addMember`,
  `invite`, `newTeamPage` existent).

Rappels : `bash check.sh`, `../format.sh mobile` avant chaque commit ; prévenir avant tout run sur
la pile e2e.

## 10. Ordre et tailles

| Lot | Contenu | Ledger | Taille |
|---|---|---|---|
| 1 | Droits, routes, hub, `notifyTeamChanged`, sélecteur de lieu commun, création d'équipe, libellé `USER_TEAM_LIMIT_REACHED` (app et site) | `MOB-165`, `WEB-184` | M |
| 2 | Paramètres (slug, médias, visibilité, fuseau, suppression) et webhook | `MOB-166` | L |
| 3 | Membres et invitations | `MOB-167` | M |
| 4 | Lieux et signalements | `MOB-168` | M |
| 5 | Tags et pages ; suppression de `team_web_paths.dart` | `MOB-169` | M |

Chaque lot est livrable seul : le hub ouvre le site pour ce qui n'est pas encore fait. À la fin du
lot 5 : mise à jour de `MOB-144`, `MOB-24`, D20 et `MOB-54` (§1), et de `mobile/CLAUDE.md` si la
liste des écrans y figure.

## 11. Ce qui reste dehors

- **Paramètres plateforme** (palier, note, `joinable`, `addMemberAllowed`, `visibilityEditable`,
  traceur, contenu public par lien) : au site (D1), ledger `MOB-171` dans « Délibérément dehors ».
- **Page d'atterrissage d'invitation par jeton** (route `invitation`) : au site ; l'app garde la
  carte des invitations en attente.
- **Rétrograder un admin, ajouter un membre sans invitation** (`addMember`) : le site ne le fait pas
  (D8).
- **Restaurer une équipe supprimée** : administration de plateforme, au site.
- **Mode mono-équipe** : `MOB-88`.
- **Planificateur de parcours sur carte** : reste de `MOB-24`.
