---
id: OPS-4
title: "Les quatre gabarits d'invitation en production : les recevoir"
status: open
group: "Recette du backend en conditions réelles"
kind: recette
verified: 2026-11-16
---

## Reste à faire

`OPS-4` **Les quatre gabarits d'invitation en production : les recevoir** —
`team-invitation.{fr,en}` et `team-invitation-signup.{fr,en}` vivent dans `templates/mail/` et
partent par le relais SMTP de Scaleway TEM. Params des quatre : `appName`, `inviterName`,
`teamName`, `invitationUrl`, `expiresInDays`. Un envoi réel par TEM est constaté le
16 octobre 2026 : deux invitations créées après la bascule, toutes deux `ACCEPTED` (la
dernière le 3 octobre), aucun `TEAM_INVITE_DELIVERY_FAILED` dans les journaux sur sept jours —
sans savoir laquelle des quatre variantes est partie ni à quoi elle ressemblait. Relu le
16 novembre 2026 : aucune invitation créée depuis, `team_invitations` ne compte toujours que
ces deux lignes après la bascule. **Reste** :
recevoir chacune des quatre (fr/en × compte existant/inscription) et en vérifier le rendu,
dans la même séance qu'`OPS-3`. Si le relais refuse le message, `POST …/invitations` répond
**500 `TEAM_INVITE_DELIVERY_FAILED`** — délibérément, plutôt qu'un `INTERNAL_ERROR` opaque —
et la transaction est annulée : aucune invitation fantôme ne subsiste. Taille : XS.
