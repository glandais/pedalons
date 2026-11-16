---
id: MOD-1
title: "La file plateforme regroupe par (type, id, équipe)"
status: done
done: 2026-09-30
---

## Livré

`MOD-1` **La file plateforme regroupe par (type, id, équipe)** (2026-09-30, **API 5.7.0**) — un
membre signalé dans deux équipes devenait une seule carte, étiquetée avec la première équipe, et
une seule décision closait les signalements des deux. `ModerationService` regroupe maintenant par
`TargetKey(type, id, teamId)` ; seul un membre peut tomber dans deux cartes, une publication ou un
commentaire n'ayant qu'une équipe. Une carte s'adresse par ce qu'elle expose déjà : `targetType`,
`targetId` et `teamSlug`. `ModerationDecisionRequest` gagne un `teamSlug` **facultatif** (ajout,
d'où le mineur) : sur `POST /api/admin/reports/resolve` il limite la décision aux signalements de
cette équipe (équipe inconnue : 404) ; absent, la décision vaut pour toutes les équipes comme
avant ; la file d'une équipe l'ignore, son chemin nomme déjà l'équipe. Le web
(`ModerationQueue.tsx`) envoie toujours `teamSlug` et met l'équipe dans la clé de la carte ; le
mobile n'a pas de file de modération, son client est seulement régénéré. Couvert par
`ModerationResourceTest.platformQueue_aMemberReportedInTwoTeams_isTwoItems_decidedOneByOne`
(deux cartes, rejeter celle de team2 laisse celle de team1 ouverte) et
`platformResolve_withAnUnknownTeam_is404`. Ne pas rendre `teamSlug` obligatoire sans bump majeur,
et ne pas retirer l'équipe de la clé de regroupement.
