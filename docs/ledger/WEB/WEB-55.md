---
id: WEB-55
title: "Le profil en vue d'ensemble et sous-pages, même arbre que l'app"
status: done
group: "Profil"
done: 2026-10-04
---

## Livré

`WEB-55` **Le profil en vue d'ensemble et sous-pages, même arbre que l'app** (4 octobre 2026,
**API 10.7.0**, maquette validée du 4 octobre). `/profil` (`ProfileOverviewPage`) : carte
d'identité (vers Mon compte), Mes sorties (prochaine sortie, à venir, historique), Mes équipes avec
le rôle (bureau), puis un raccourci par sujet avec sa **ligne d'état** (`profileStatus.ts`), lue
dans `/me` et `GET /api/users/me/profile-summary` (`API-69`). Neuf sous-pages
(`pages/profile/`) : `/profil/sorties` (`myParticipations`, onglets À venir · Historique, onglet et
page dans l'URL `?vue=` / `?p=`), `/profil/preferences` (unités, fuseau, thème Système / Clair /
Sombre, langue), `/profil/notifications` (Sur cet appareil, tableau type × canal groupé par famille
— `notificationFamilies.ts`, `CONTENT_REPORTED` ajouté sous « Équipes et modération » —, Résumé
quotidien par e-mail, Annonces des équipes, lien vers la boîte de réception, qui renvoie ici),
`/profil/appareils`, `/profil/securite`, `/profil/vie-privee` et sa sous-page
**`/profil/vie-privee/bloques`** (EN `/profile/privacy/blocked`, `blockedUsers`, désormais web,
`parentId: 'profile-privacy'` — déplacée de `/profil/bloques` le 4 octobre, fil d'Ariane Profil ›
Confidentialité › Utilisateurs bloqués), `/profil/compte` (Nom affiché toujours éditable, plus de
mode « Modifier le profil », adresse en lecture seule, zone de danger : titre `c="danger"`, carte
bordée par le nouveau `tone="danger"` de `ProfileCard`), `/profil/aide`. Les actions destructives
du profil (déconnecter un service, désappairer, erreur de connexion GPS — `GpsConnectionsManager`,
`PairedDevicesManager`) prennent aussi le jeton `danger`. Le tableau des notifications
(`NotificationPreferences.module.css`) enveloppe chaque case d'un `<label>` qui remplit sa cellule :
**cible de 44 × 44 px** sous `48em` ou en `pointer: coarse`, case visible à 20 px, densité
inchangée au bureau. Bureau : barre
latérale groupée (`ProfileShell.tsx`, non collante, `aria-current` sur l'entrée active) ;
téléphone : liste groupée sur `/profil` terminée par Se déconnecter. Fil d'Ariane Profil ›
Sous-page, le lien « ← Retour » (`navigate(-1)`) est supprimé. Préchargement serveur de chaque page
dans `pages/profile/profileData.ts` et `myRidesData.ts`, câblé dans `config/routes.config.ts`.
Supprimés : `UserProfilePage`, `pages/auth/profileData.ts`, `MyParticipations.tsx`,
`profileAnchors.ts`. `FeaturesPromoCard` (`WEB-51`) mène à `/profil/appareils` ; les pages d'aide
et la politique (`privacy/*.md`) citent les nouveaux chemins. Le thème et la langue de l'en-tête
mettent à jour le `/me` en cache. Tests : vitest `profileStatus.test.ts`, `ProfileShell.test.tsx`,
`NotificationPreferences.test.tsx`, `notificationFamilies.test.ts` (chaque `NotificationType` dans
exactement une famille), `ProfileOverviewPage.test.tsx` ; e2e `profile-navigation.e2e.ts`,
`ssr-session.e2e.ts` (HTML serveur de `/profil` et de `/profil/sorties` porteur de la sortie,
hydratation propre), `routes-render.e2e.ts` (une ligne par route du profil), `flow-account`,
`auth`, `flow-moderation` (`support/moderation.ts`, nouvelle URL des bloqués), `flow-device`,
`flow-notifications`, `pwa` repris — verts au 16 octobre 2026 (`WEB-56`). **Tranché le 4 octobre**
avec le propriétaire : Utilisateurs bloqués sous Confidentialité, même place que dans l'app. **À
ne pas défaire** : les actions destructives du profil utilisent le jeton `danger`, jamais `red`
brut ; la cible de 44 px des notifications est le `<label>` de la cellule, pas une case agrandie
(le tableau du bureau garde sa densité) ; **arbre unique et lexique commun** aux deux clients
(source web unique : `components/profile/profileNav.ts`) ; une route `/profil/<sujet>` par sujet,
**sans redirection** des anciennes ancres `/profil#notifications`, `#gps` ni de
`/profil/participations` (`WEB-58`) ; seuls les canaux de `NotificationPreferencesDto.channels`
ont une colonne, pas de résumé quotidien sans `EMAIL`, un type sans réglage serveur n'a pas de
ligne ; la bascule bureau / téléphone est **CSS seulement** (`visibleFrom` / `hiddenFrom`), jamais
un `matchMedia` lu en JS (hydratation) ; le thème de Préférences lit `user.theme`, pas l'état
local de Mantine ; `TimezonePreference` ne remplit le fuseau du navigateur qu'après hydratation
et `ErrorReportingPreference` lit `localStorage` dans un effet ; Se déconnecter une seule fois
dans le profil (le menu avatar et le tiroir gardent le leur) ; lignes du profil à `mih={44}`.
