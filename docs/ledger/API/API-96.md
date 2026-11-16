---
id: API-96
title: "La reprise des mails d'export ne remplace plus le lien d'un mail encore en cours d'envoi"
status: done
group: "Concurrence : constats de la modélisation formelle du 11 octobre 2026"
done: 2026-10-11
---

## Livré

`API-96` **La reprise des mails d'export ne remplace plus le lien d'un mail encore en cours d'envoi** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean) — pendant un déploiement, `retryPendingEmails` sur l'autre instance prenait toute ligne READY sans `emailSentAt`, y compris celle dont l'instance A envoyait le mail. Elle changeait le hash du jeton et envoyait un second mail, et le lien du premier tombait en 404. La reprise passe désormais par `UserExportRepository.findEmailRetryDue` : seules les lignes dont le dernier envoi a échoué (`errorMessage` renseigné) ou dont le lien a été émis il y a plus de `pedalons.export.email-retry-grace-minutes` (10 min) sont reprises. L'heure d'émission se déduit de `expiresAt - expiryDays`, donc aucune migration n'est nécessaire. La rotation passe par un compare-and-set, `claimEmailRetry`, dont le WHERE reprend le même prédicat et qui remet `errorMessage` à null, si bien que deux instances qui relancent en même temps n'envoient qu'un mail. Couvert par `UserExportEmailRetryRaceTest`. **À ne pas défaire** : la reprise ne touche pas un lien récent sans échec enregistré ; markReady et la reprise posent tous deux `expiresAt = now + expiryDays` (la garde en dépend) ; la rotation reste une mise à jour conditionnelle, pas un findById suivi d'un set.
