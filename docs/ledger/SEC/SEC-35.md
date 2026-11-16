---
id: SEC-35
title: "limite de demandes OTP et « un seul code vivant » sérialisées par adresse"
status: done
done: 2026-10-11
---

## Livré

`SEC-35` **limite de demandes OTP et « un seul code vivant » sérialisées par adresse** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean). Avant, `createOtp` comptait les codes récents, invalidait les codes vivants puis insérait le nouveau, sans verrou : c'était un check-then-act. Deux demandes simultanées (un onglet web et l'app) ne voyaient chacune que les lignes déjà validées. Elles émettaient alors plus de 3 codes par fenêtre et laissaient plusieurs codes vivants à la fois, ce qui multipliait le budget de devinettes de l'audit H1. Désormais, `createOtp` charge le compte avec `UserRepository.findByEmailAndDomainForUpdate` (`SELECT … FOR UPDATE`) avant de compter. La seconde demande attend le commit de la première, puis elle est limitée ou invalide le code de la première. Le verrou ne couvre que la courte transaction de `createOtp` : le mail part après le commit et n'est jamais envoyé sous verrou. Une adresse inconnue ou non vérifiée ne verrouille rien, et l'anti-énumération est inchangée. Aucune migration. Couvert par `OtpRequestRateLimitRaceTest` et par `OtpVerifyRequestDeadlockRaceTest`. **À ne pas défaire** : tout chemin qui verrouille un code OTP prend d'abord ce verrou de compte, sinon on retombe dans l'interblocage décrit en `SEC-34`. Ni verrou consultatif (`pg_advisory_xact_lock`, SQL natif), ni index unique partiel : il demanderait une migration et ne couvrirait que la moitié « un seul code vivant ». `createEmailChangeToken` et `createPasswordResetToken` ont le même motif compter-puis-insérer et restent à traiter à part.
