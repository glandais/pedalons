---
id: API-95
title: "Un échec du mail « export prêt » ne jette plus l'export RGPD terminé"
status: done
group: "Concurrence : constats de la modélisation formelle du 11 octobre 2026"
done: 2026-10-11
---

## Livré

`API-95` **Un échec du mail « export prêt » ne jette plus l'export RGPD terminé** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean) — l'envoi du mail et `markEmailSent` étaient dans le même `try` que la construction : une panne SMTP (ou de base sur `markEmailSent`) tombait dans le `catch`, `markFailed` repassait la ligne READY en PENDING (puis FAILED au troisième essai), annulait `storageKey` et `safeDelete` supprimait l'archive, que `retryPendingEmails` ne voyait donc jamais. Le mail part désormais par `UserExportService.sendReadyMail`, qui ne lève jamais, et un drapeau `ready` posé juste après `markReady` empêche le `catch` de rien annuler ni supprimer une fois la ligne READY (même si le commit a eu lieu et que l'appel lève quand même) : sur échec, `markEmailFailed` inscrit l'erreur dans `errorMessage` et la ligne reste READY avec son archive, reprise au tick suivant. `markFailed` n'agit plus que sur une ligne PROCESSING. Couvert par `UserExportMailFailureKeepsArchiveTest` (3 cas). **À ne pas défaire** : le drapeau `ready` : rien après `markReady` ne doit pouvoir faire supprimer l'archive par le `catch`, et `markFailed` garde sa garde `status == PROCESSING`.
