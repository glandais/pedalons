---
id: API-39
title: "T5.4 — Trombinoscope : débloqué par un réglage d'équipe (contrat `3.0.0`)"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
---

## Livré

### `API-39` T5.4 — Trombinoscope : débloqué par un réglage d'équipe (contrat `3.0.0`)

**Livré** — la page web des membres est venue ensuite, `WEB-1`. L'oracle
d'énumération est traité, l'autorisation est graduée, et l'ajout d'un membre par sélection
d'utilisateur a été remplacé par une invitation par e-mail.

**Le réglage.** `Team.enableMemberDirectory` (`V33`), famille des `enable*`, éditable par l'admin
d'équipe — mais **`DEFAULT FALSE`**, le seul du lot : ouvrir le trombinoscope montre l'annuaire
complet à chaque membre, c'est un geste de l'équipe et pas un effet de bord de la migration.

**L'autorisation, graduée sur deux axes** (`UserTeamAccessChecker`, `TeamMembershipService`) :

| Rôle | Accès | `search` porte sur | `role` / `joinedAt` |
|---|---|---|---|
| admin (d'équipe ou plateforme) | toujours | nom **ou e-mail** | présents |
| organisateur | toujours | nom seul | présents si le réglage est activé |
| membre | si le réglage est activé | nom seul | présents |
| non-membre | 403 | — | — |

L'organisateur voit la liste quoi qu'il arrive : il lui faut des candidats pour désigner un meneur de
groupe, et `RideService` refuse un meneur non-membre. Ce que le réglage lui retire, ce sont les rôles
et les dates, pas les gens. `LIST` a dû être **extrait** de sa branche commune avec
`CREATE`/`UPDATE`/`DELETE` : les laisser fusionnés aurait ouvert l'ajout et le retrait de membres.

**L'oracle est fermé** : `UserTeamRepository.findByTeam` prend un `searchEmail` que seul un admin
reçoit. `MemberDto.role` et `joinedAt` deviennent nullables — c'est, avec la suppression ci-dessous,
la raison du **MAJOR**.

**`GET /api/users/search` est supprimé.** Son seul appelant produit était `UserAutocomplete`, sur deux
écrans qui n'existent plus sous cette forme. Le sélecteur de meneur passe par
`TeamMemberAutocomplete`, qui interroge `…/members`. Le garde-fou serveur reste
`RideService.resolveLeader` (`RIDE_GROUP_LEADER_NOT_MEMBER`).

**L'ajout d'un membre est devenu une invitation** (`V34`, table `team_invitations`) : `POST`/`GET`/
`DELETE /api/teams/{teamSlug}/invitations`, `POST /api/invitations/preview` (public) et `/accept`,
plus `GET /api/users/me/invitations`. Quatre décisions à ne pas défaire :

- **Personne ne rejoint une équipe sans un clic à soi**, compte préexistant ou non. `AuthService`
  n'est pas touché : s'inscrire n'est pas accepter, et avec deux invitations en attente il n'y aurait
  rien pour choisir. D'où `/me/invitations`, qui est le seul rattrapage de l'inscription spontanée.
- **La création répond à l'identique que le compte existe ou non** — seul le gabarit d'e-mail change.
  Sinon tout admin d'une équipe qu'il vient de créer dispose d'une sonde d'existence de compte, ce que
  `requestOtp` / `requestPasswordReset` / `requestEmailChange` refusent déjà. Prix assumé : une faute
  de frappe ne se signale pas — d'où la liste des invitations en attente, qui la rend visible.
- **`addMemberAllowed` n'est pas revérifié à l'acceptation.** Il garde l'acte de l'admin, pas le
  consentement de l'invité. Idem pour le rôle de l'inviteur : le recours est la révocation, explicite.
- **L'acceptation est idempotente et n'écrase jamais le rôle** : une invitation MEMBER ne rétrograde
  pas un ADMIN.

Trois plafonds (`pedalons.teams.invitations.*`) : 20/h par inviteur et 50/j par équipe → **429** ;
5/j **par adresse** → **échec silencieux** (l'invitation existe, le mail n'est pas envoyé), sinon on
révélerait à l'admin A que l'admin B, d'une autre équipe, vient d'inviter la même personne.

Le mobile est fonctionnel : l'écran existait déjà, seule l'entrée de navigation a été conditionnée au
réglage. La recette web est `WEB-20` à `WEB-22`.
