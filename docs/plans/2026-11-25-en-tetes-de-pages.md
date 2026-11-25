# En-têtes de pages : six règles, cinq lots

Écrit le 25 novembre 2026. **État : décidé ; lots 1 à 5 codés le 25 novembre 2026 (`WEB-205` à `WEB-209` ; recette des lots 2, 4 et 5 à faire).** Source : l'audit des en-têtes du
25 novembre 2026 (89 pages du site, lu dans le code, rien vu dans un navigateur), ses corrections
immédiates (`WEB-204`), une planche de design des suggestions, et les arbitrages du propriétaire du même
jour (§2). Ledger : `WEB-205` à `WEB-209` (un lot chacun), `MOB-184` (l'app).

Déjà livré avant ce plan : « Modifier » dans la retouche (`WEB-201`), « GPS » dans la barre d'actions
des pages parcours, sortie, groupe et étape (`WEB-203`), cinq libellés et boutons corrigés (`WEB-204`).

---

## 1. En une page

Aucun composant d'en-tête n'est partagé : cinq versions maison se répartissent les pages de détail
(`RouteDetailPage`, `PublicationHeader`, `PostDetailPage` et `AdDetailPage`, `ChildDetailShell`,
`GpxPreviewView`), et chaque liste, formulaire ou carte de connexion construit le sien. Six règles :

1. **Un seul h1 par page**, le nom de ce qu'on regarde. Dans `TeamLayout`, le h1 est l'équipe et la page
   un h2. La taille reste libre (`<Title order={1} size="h2">`).
2. **Un en-tête de détail commun**, `DetailHeader`, qui remplace les cinq versions.
3. **Un ordre d'actions fixe** : inscription ou action principale · GPS · Modifier ▾ · Retoucher ·
   Partager · ⋯ (chacun seulement s'il existe).
4. **Un style par action** : Modifier en contour avec crayon et menu ▾ (Dupliquer, Publier/Dépublier,
   Annuler, Supprimer) ; Supprimer rouge, dans ce menu ; GPS neutre (`default`) ; Partager et ⋯ en icônes.
5. **Rien n'est coupé sur téléphone** : les actions passent à la ligne, le titre tient sur deux lignes
   avant l'ellipse (avec info-bulle).
6. **Un format de titre d'onglet**, « Libellé · Contexte — Site », calculé par une seule fonction pour le
   serveur (`lib/seo.ts`) et le client (`components/common/Layout.tsx`).

## 2. Décisions du 25 novembre 2026

| # | Question | Décision |
|---|---|---|
| D1 | Titre d'un formulaire : nom (BRANDING §8.3) ou verbe (§8.2) ? | Le titre reprend le bouton qui a ouvert la page (« Créer une publication », « Modifier la publication ») ; exception à écrire dans §8.3. Les autres pages gardent un nom. |
| D2 | Format du titre d'onglet | « Libellé · Contexte — Site » : « — » devant le nom du site, « · » à l'intérieur ; le contexte est l'équipe sur ses sous-pages, « Administration » en administration. |
| D3 | Menu ⋯ sur un groupe et une étape | Oui : il signale la sortie ou le voyage parent. Aucun nouveau `ReportTargetType`. |
| D4 | Supprimer un parcours | Dans le menu ▾ de Modifier, avec Dupliquer, comme sortie, voyage et publication ; toujours confirmé. |
| D5 | Partager sur une annonce | Oui, avec les règles de visibilité de la publication. |
| D6 | GPS sur un voyage qui a son propre parcours et aucune étape | Oui, après « Rejoindre le voyage », avec la règle des cartes d'étape : pour qui a rejoint le voyage, jamais sur un voyage annulé (précisé le 25 novembre 2026 après relecture). Avec des étapes, chaque carte d'étape garde le sien. |
| D7 | GPS sur la carte du groupe (app) contre l'en-tête (site) | Aligner l'app sur le site au prochain lot mobile (`MOB-184`) ; d'ici là l'écart reste écrit dans BRANDING §7.7. |
| D8 | Lien qui recharge toute la page vers la création et la modification d'un parcours (`<Button component="a" href>` dans `RoutesListHeader`, `RouteListPage` et `RouteDetailPage`, `reloadDocument` dans `DashboardHeader`) | Introduit au passage à Mantine (`67af78bfb`, 11 janvier 2026), qui a converti 44 `<Link>` en `component={Link}` et ces seuls liens (plus `paths.teams()` de `TeamSettingsPage`) en `<a href>`, sans raison écrite ; le formulaire est déjà ouvert sans rechargement depuis `QuickActions`, `FirstSteps`, `CardActionsMenu`, le générateur et la duplication, sans état global à remettre à zéro. Analyse du 25 novembre 2026 : aucune raison, donc `PrefetchLink` partout, `TeamSettingsPage` compris, et le champ `reloadDocument` de `CreateSplitButton` disparaît. |
| D9 | Dupliquer sur l'aperçu GPX, ouvert à toute personne connectée alors que Modifier ▾ est au seul propriétaire | Dans le menu de Modifier pour le propriétaire ; un bouton « Dupliquer » à la place de Modifier pour les autres personnes connectées (`flow-gpx-tools.e2e.ts` garde ce cas). |
| D10 | Actions que la règle 3 ne nomme pas : « Modifier une copie » (parcours, pour qui ne peut pas modifier), « Enregistrer comme parcours » (aperçu GPX) | À l'emplacement de Modifier, en contour ; sur l'aperçu du propriétaire, « Enregistrer comme parcours » juste avant Modifier ▾. |
| D11 | Parcours supprimé | Modifier ▾ reste et son menu ne propose que Restaurer (vert) : supprimer un parcours déjà supprimé ne change rien (`RouteService.deleteRoute`), donc pas de Supprimer, contrairement à la publication. Corrigé le 25 novembre 2026 après relecture. |

## 3. Les lots

Ordre : du moins risqué au plus structurant. Les numéros suivent la planche de design.

### Lot 1 — lexique et titre d'onglet (`WEB-205`)

Textes et une fonction ; aucune mise en page.

- **Lexique** (BRANDING §8, D1) :
  - 29. Titres de création : « Nouvelle publication » → « Créer une publication » (`posts.create.title`),
    « Nouvelle annonce » → « Créer une annonce » (`ads.create.title`), « Créer un nouveau parcours » →
    « Créer un parcours » (`routes.create.title`).
  - 30. L'outil GPX hors équipe « Créer un parcours » → « Tracer un fichier GPX »
    (`gpxTools.createFromScratch.title`) ; « Lister mes fichiers » → « Mes fichiers GPX ».
  - 31. Boutons « Ajouter une page » (`teams.pages.add`), « Ajouter un lieu » (`places.add`),
    « Nouveau tag » (`tags.admin.add`) → « Créer une page / un lieu / un tag ».
  - 32. « Admin(s) plateforme » → « Administrateur(s) plateforme » (`admin.users.*`) ;
    « Administration plateforme » → « Administration de la plateforme ».
  - 33. « Compte activé ! » → « Compte activé » (`auth.verifyEmail.success.title`).
  - 34. La vue calendrier d'une équipe : titre « Agenda » et onglet « Calendrier » → « Agenda » aux deux ;
    « Réglages » (`NotificationListPage`, `subtle`) → « Gérer les notifications », même variante que
    « Ouvrir mes notifications » (`ProfileNotificationsPage`).
  - 35. « Modifier » d'un groupe et d'une étape → « Modifier la sortie », « Modifier le voyage » ;
    sous-titres de formulaire à l'impératif (« Modifiez les informations du parcours »…).
  - 36. Fil d'Ariane de l'authentification en noms (« Connexion », « Nouveau mot de passe »,
    « Autorisation d'une application », `routes.config.ts`), les boutons gardant l'infinitif ; clé
    `trips.stage.joined` pour le badge d'une étape (`StageDetailPage`, au lieu de
    `rides.detail.groups.joined`) ; « Vérification en cours… » avec le caractère « … ».
  - BRANDING §8.3 reçoit l'exception D1.
- **Titre d'onglet** (D2) :
  - 37. `formatPageTitle(label, context, appName)`, lue par `seo.ts` (`<title>` du serveur, `routeMeta.ts`)
    et `Layout.tsx` (client) ; les pages plein écran (`*FullscreenMapPage`, `GpxBlankMapPage`) passent par
    elle.
  - 38. L'équipe en contexte sur toutes ses sous-pages (« Agenda · N Peloton — Pédalons »).
  - 39. Création et modification nommées : « Modifier · {nom} », « Créer un parcours · {équipe} » (fin de
    `actions.edit` et `actions.new` comme libellé de fil d'Ariane).
  - 40. Aperçu GPX : le nom du fichier (entité `gpxPreview` dans `useBreadcrumbData`) ; « Carte des
    parcours » au lieu de « Carte ».
  - 41. `meta` statiques pour la confidentialité, les conditions, l'aide, l'authentification et la 404
    (`routes.config.ts`).
  - 42. Pendant un chargement, le libellé de la route plutôt que « ... » (`useBreadcrumb`).

### Lot 2 — un `DetailHeader` commun (`WEB-206`)

- 1. `components/publication/DetailHeader.tsx` : emplacements contexte, titre, badges, actions ; il fixe
  l'écart entre boutons (`gap="xs"`) et le retour à la ligne. `PublicationHeader` et `ChildDetailShell`
  le composent ; `RouteDetailPage`, `PostDetailPage`, `AdDetailPage` et `GpxPreviewView` l'adoptent.
- 2. L'ordre de la règle 3 est celui du composant, pas des pages.
- 3. Modifier en contour, crayon et menu partout (aujourd'hui `default` sans icône sur le parcours,
  `default` sur l'annonce, `IconEdit` sur l'aperçu GPX).
- 4. Dupliquer et Supprimer dans le menu de Modifier sur le parcours et l'aperçu GPX (D4), Restaurer aussi sur un
  parcours supprimé (D11) ; Dupliquer reste un bouton pour qui n'est pas propriétaire de l'aperçu (D9) ; « Modifier une
  copie » et « Enregistrer comme parcours » à l'emplacement de Modifier (D10).
- 5. Partager et ⋯ en fin de barre sur le groupe et l'étape ; ⋯ signale le parent (D3).
- 6. Actions qui passent à la ligne (`nowrap` aujourd'hui sur la publication et l'annonce).
- 7. Titre sur deux lignes puis ellipse avec info-bulle (`nowrap` sur `PublicationHeader`, `lineClamp={1}`
  sur la publication).
- 8. Badge de statut en fond doux (`light`) partout.
- 9. Aperçu GPX : la rangée d'actions sous la carte monte dans l'en-tête.
- 10. Annonce : « Répondre à l'annonce » en action principale, galerie sous le titre, Partager (D5).
- 11. D8 : `PrefetchLink` vers la création et la modification d'un parcours (`RouteDetailPage`, `RoutesListHeader`,
  `RouteListPage`, `DashboardHeader`) et vers les équipes (`TeamSettingsPage`) ; `reloadDocument` quitte `CreateSplitButton`.
- Le titre de chaque page de détail devient le h1 (`<Title order={1} size="h2">`) : `PublicationHeader`, la
  publication et l'annonce l'ont en h2 aujourd'hui.
- 12. Les deux boutons `variant="default"` dont Mantine ignore la `color` : retrait du logo
  (`MediaEditor.tsx`), « Supprimer » de « Mes fichiers GPX » (`MyGpxPreviewsPage.tsx`).
- Et D6 : GPS sur un voyage qui a son propre parcours sans étapes.

### Lot 3 — un h1 par page (`WEB-207`)

- 13. h1 sur les listes hors équipe (`TeamListPage`, `NotificationListPage`, `AllRoutesPage`,
  `CalendarPage`, la carte d'Explorer qui n'a pas de titre) et le profil (`ProfileShell`).
- 14. Générateur : son h1 passe en h2 sous celui de l'équipe (`RouteGeneratorPage`).
- 15. Gestion de l'équipe (`TeamAdminLayout`) : h1, sections en h2 (Lieux et Tags sont en h4,
  Signalements n'a pas de titre).
- 16. Administration de la plateforme (`AdminLayout`) : un h1 par page.
- 17. Cartes transactionnelles et migration biketeam : h1, sections en h2 (lot 5 pour la carte).
- 18. `e2e/routes-render.e2e.ts` vérifie « exactement un h1 visible » sur chaque route et chaque rôle.
- Les pages de détail reçoivent leur h1 par le lot 2.

### Lot 4 — bandeau d'équipe et administration (`WEB-208`)

- 19. Bandeau (`TeamLayout`) : Rejoindre/Quitter · Créer ▾ · Gérer · Partager.
- 20. Sur téléphone, Gérer en icône avec libellé accessible, comme Quitter.
- 21. Gestion de l'équipe : le nom et l'avatar de l'équipe en tête (seul le fil d'Ariane le dit).
- 22. Titres de section = le mot de l'onglet (« Pages », « Paramètres », « Membres ») ; un seul `py`.
- 23. Administration de la plateforme : sans « Retour à l'application » (l'en-tête du site suffit : le fil d'Ariane de l'administration s'arrête à `/admin`), sous-titre
  du tableau de bord sous le titre.
- 24. Un `label` sur les filtres (`AdminTeamsPage`, `AdminUsersPage`) et la recherche des publications
  (`TeamPostsPage`).

### Lot 5 — une carte transactionnelle commune (`WEB-209`)

- 25. Un composant : centré à 70 vh, 440 px, rayon 16 px, ombre `lg`, h1, une phrase, le contenu, les
  actions pleine largeur, le lien de retour centré en dernier. Pages : connexion (modes inscription et
  code compris, `LoginForm`, `OtpLogin`), mot de passe oublié, réinitialisation, vérification de l'adresse,
  invitation, OAuth, appareil ; la migration biketeam garde 640 px.
- 26. « Se connecter » de l'invitation pleine largeur.
- 27. Un seul lien de retour (aujourd'hui une icône en ligne ou un groupe avec icône).
- 28. 404 : h1 « Page introuvable », « La page que vous cherchez n'existe pas ou a été déplacée. »,
  `paths.home()` au lieu de `to="/"`.
- L'icône d'en-tête d'OAuth prend la couleur du thème (`ThemeIcon color="blue"` aujourd'hui).

## 4. Tests

- Lot 1 : test unitaire de `formatPageTitle` ; les tests de page qui lisent un titre ou un libellé changé ;
  `pnpm i18n:check`.
- Lot 2 : `DetailHeader.test.tsx` (ordre, menu ; le retour à la ligne, affaire de mise en page que jsdom ne calcule pas, se voit en recette) ; les tests des pages qui l'adoptent ;
  les e2e qui ouvrent les menus (`flow-posts`, `flow-routes`, `flow-gpx-tools`).
- Lot 3 : l'assertion de `routes-render.e2e.ts`.
- Lots 4 et 5 : tests de composant ; recette sur téléphone.

## 5. Hors de ce plan

- L'app mobile, sauf `MOB-184`.
- L'en-tête interne de `ModerationQueue`, non audité.
