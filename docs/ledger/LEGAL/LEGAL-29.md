---
id: LEGAL-29
title: "La politique ne dit plus le point exact d'une annonce visible du rôle Administrateur de l'équipe"
status: done
done: 2026-11-14
---

## Livré

`LEGAL-29` **La politique ne dit plus le point exact d'une annonce visible du rôle Administrateur de l'équipe** (14 novembre 2026, contrat inchangé) — `privacy/privacy-policy.{fr,en}.md`, § des petites annonces : « il n'est visible précisément que de vous et de l'administration de la plateforme ». Depuis `SEC-26`, `GET …/classifieds/{slug}/edit` ne sert le point exact qu'à la personne qui a publié l'annonce (`AdService.getAdEdit` → `isAuthor`) ; un rôle Administrateur qui la modifie reçoit le point flouté. Relevé en instruisant `MOB-159`. **À ne pas défaire** : l'administration de la plateforme reste nommée — l'exploitant a accès à la base, où le point exact est stocké. Parité FR/EN tenue, date de mise à jour portée au 14 novembre 2026 ; le texte étant un asset de l'app, il n'y paraît qu'à la build suivante. Aucun test : c'est un texte.
