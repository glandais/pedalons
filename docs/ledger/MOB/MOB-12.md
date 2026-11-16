---
id: MOB-12
title: "Contact du vendeur (32)"
status: done
group: "Recette sur une application qui tourne — 4 octobre 2026"
---

## Livré

`MOB-12` **Contact du vendeur (32)** — sur une annonce d'un autre membre : 204 (confirmation),
`AD_CONTACT_OPTED_OUT` (vendeur ayant coupé « Être contacté »), `AD_CONTACT_RATE_LIMITED` (11ᵉ
message de l'heure, `Retry-After` dit « Réessayez dans 1 heure ») rendaient chacun leur écran ;
bouton absent sur sa propre annonce ; 9 et 2 001 caractères refusés côté client. Le 500
(`AD_CONTACT_DELIVERY_FAILED`), impossible à provoquer en prod, est scindé en `MOB-47`.
