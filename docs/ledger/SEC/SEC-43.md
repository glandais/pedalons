---
id: SEC-43
title: "Un ancien point d'API contourne la règle « personne ne rejoint une équipe sans un clic à soi »"
status: done
done: 2026-11-17
---

## Livré

`SEC-43` **Un ancien point d'API contournait la règle « personne ne rejoint une équipe sans un clic à
soi »** (audit de novembre 2026, C3, faible) — `POST /api/teams/{slug}/members` laissait un admin
d'équipe inscrire n'importe quel compte du site par son identifiant, sans son accord, dès que
l'équipe avait `addMemberAllowed` (le cas de toute nouvelle équipe, `BILL-10`). Aucun client ne
l'appelait ; seuls l'outillage et les tests s'en servaient. Depuis le 17 novembre 2026 (contrat
`16.1.1`, descriptions seulement), il répond 403 `FORBIDDEN` à tout le monde sauf un admin de la
plateforme (`TeamMembershipService.addMember`) : un admin d'équipe invite, la personne accepte.
Le plafond de membres ne s'y applique donc plus (l'admin de la plateforme en est exempté). Gardé
pour l'outillage de la plateforme : le seed des captures (`mobile/screenshots/seed.py`, qui ajoute
pendant que son organisateur est promu), Patrol et les e2e (`addMember` de
`frontend/e2e/support/data.ts` passe désormais toujours par `roleSession('admin')`). Couvert par
`TeamMembershipServiceTest` (`addMember_byATeamAdmin_isRefused`), `TeamMembershipResourceTest`
(`addMember_byTeamAdmin_isRefused_evenWhenTheTeamMayGrow`, `addMember_byPlatformAdmin_shouldSucceed`),
`TeamLimitsResourceTest` (`addMember_byATeamAdmin_isRefusedBeforeTheCap`) et l'e2e `flow-team`
(« an owner can only invite… »). Règle écrite dans `backend/SECURITY.md`.
