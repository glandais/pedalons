---
id: NOTIF-14
title: "La date en tête des titres, des objets et des aperçus"
status: done
done: 2026-11-07
---

## Livré

`NOTIF-14` **La date en tête des titres, des objets et des aperçus** (2026-11-07, contrat inchangé, règle `BRAND-8`) — aucun titre de push ni objet d'e-mail ne portait la date, rappel compris, et la date arrivait en fin de phrase, coupée dans les aperçus. `NotificationTexts` écrit le format unique « sam. 12 avr. · 09:00 » (EN « Sat, Apr 12 · 9:00 AM »), l'année seulement hors de l'année de l'envoi, dans le fuseau de la sortie (`Clock` injectée pour les tests), mention « heure de Tokyo (ven. 01:00 chez vous) » gardée dans les corps. Nouveaux espaces réservés `{when}` (date courte, titres et objets) et `{soon}` (« Demain 09:00 », rappel seulement). Titres : « {when} : {nom} » (publication), « Annulée, {when} : {nom} », « Demain 09:00 : {nom} », « Nouvel horaire, {when} : {nom} » (variante `.DATE_TIME`), « Groupe retiré, {when} : … », « Nouvelle inscription, {when} : … ». **Aucun mot relatif hors du rappel**, qui n'entre ni dans le digest ni dans le webhook. `Rendered.heading()` (absolu) titre chaque item du digest et ouvre le *preheader* caché ajouté à `base.*.html` (`{#if params.preheader??}`, les autres e-mails inchangés). Rien de stocké : titres et corps sont rendus à l'envoi, l'heure par personne de `NOTIF-13` est gardée. Couvert par `NotificationTextsTest` (dont `#otherYear_writesTheYear`, `#noRelativeWord_outsideTheRemindersTitle`, `#headingAndPreheader_openOnTheDateAndTheName`), `NotificationPhase5Test#cancellationEmail_leadsWithTheDate_inSubjectTitleAndPreheader`, `#digestItem_isHeadedByTheRidesDateAndName` ; suite backend passée (4501 tests). Non vu dans un vrai client mail (l'e-mail reste coupé en production, `NOTIF-2`).
