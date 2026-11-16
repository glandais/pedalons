---
id: WEB-33
title: "Actions sur les cartes : modifier, publier, supprimer, ajouter au calendrier"
status: done
group: "Référencement"
done: 2026-09-30
---

## Livré

`WEB-33` **Actions sur les cartes : modifier, publier, supprimer, ajouter au calendrier**
(2026-09-30, API 9.1.0, ajouts seulement ; ligne « Card CTAs » de [`BACKLOG.md`](../../BACKLOG.md)) —
un menu `⋯` en haut à droite des cartes, posé **à côté** du lien de la carte et non dedans
(`Card`, prop `actions`) : un bouton dans un `<a>` est du HTML invalide et ses clics ouvraient la
carte. Seules les **listes d'équipe** en portent (fil, parcours en vue cartes, annonces), parce
qu'elles ont déjà chargé le rôle du lecteur (`TeamDetailDto.role`) : l'accueil, le profil et
« tous les parcours » n'en ont pas, aucun DTO de liste ne disant ce que le lecteur peut faire.
Qui voit quoi (`components/card/CardActions.tsx`) : Modifier, Supprimer — et Publier sur un
brouillon — pour un ADMIN ou ORGANIZER de l'équipe, l'auteur ou l'admin pour une annonce (la
règle des `*AccessChecker`) ; « Ajouter au calendrier » pour tout lecteur d'une sortie ou d'un
voyage publié et pas encore `finished`. Une ligne supprimée (vue des admins) n'a pas de menu : on
la restaure depuis sa page. Supprimer passe toujours par `ConfirmDialog`. `CardAction.tsx`, qui
n'était utilisé nulle part, est retiré au profit de `CardActionsMenu`.
Le bouton `⋯` porte le nom de sa carte (« Actions — {titre} », `cards.actions.menu`) et **jamais**
« Options de gestion » : c'est le chevron des pages de détail, que le helper e2e `actionsMenu`
cible dans `main` ; sur une liste, chaque carte en aurait porté un de plus.
**Publier passe par un nouvel endpoint** `PATCH …/{slug}/status` (`StatusChangeRequest`) sur les
sorties, voyages, publications et annonces, et **jamais par la mise à jour complète** : une ligne
de liste est une projection COMPACT sans les groupes d'une sortie ni les étapes d'un voyage, et la
renvoyer en `PUT` les supprimerait (et préviendrait les inscrits d'un groupe retiré). Mêmes
effets qu'un changement de statut par la mise à jour : `publishAt` effacé hors brouillon,
`publicationStatusChanged` dans la boîte d'envoi des notifications, les étapes qui suivent leur
voyage ; une annonce refuse `CANCELLED`. **Le `.ics` unitaire** est un autre endpoint,
`GET …/rides/{slug}/ics` et `…/trips/{slug}/ics` (`PublicationIcsService`), en
`Content-Disposition: attachment` : il se construit sur le DTO de la page de détail, donc lisible
par qui peut lire la sortie — un visiteur anonyme sur une sortie publique compris — et **sans le
jeton d'abonnement** des flux de `CalendarService` ; le web le télécharge par un simple lien (le
cookie de rafraîchissement authentifie un `@PermitAll`). Un voyage y donne un événement « journée
entière » par étape. Tests : `api/common/StatusAndIcsResourceTest` (backend : statut par rôle, 401,
400, groupes et étapes conservés, étapes qui suivent, annonce `CANCELLED` refusée, `.ics` par
visibilité et par étape) et `components/card/CardActions.test.tsx` (Publier appelle l'endpoint de
statut et jamais `updateRide`, qui voit quoi, confirmation). **Ne pas** publier depuis une liste
par la mise à jour complète, ni faire passer le `.ics` unitaire par le jeton d'abonnement.
