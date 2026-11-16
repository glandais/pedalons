---
id: MOB-47
title: "Contact du vendeur : l'échec d'envoi (500) de bout en bout"
status: open
group: "Recette sur une application qui tourne"
verified: 2026-11-16
---

## Reste à faire

`MOB-47` **Contact du vendeur : l'échec d'envoi (500) de bout en bout** — reste de `MOB-12`,
recetté le 4 octobre 2026 sauf ce cas. Le comportement de l'app est déjà tenu par un test de
widget (`ad_detail_page_test.dart`, « un 500 est un échec franc, et le brouillon survit » :
`AD_CONTACT_DELIVERY_FAILED` nomme l'échec, aucune confirmation, brouillon gardé,
« Réessayer »). Ce qui manque est le chemin réel, que la prod ne sait pas provoquer : un test
Patrol sur la pile e2e (`ad_contact_test` ne couvre que l'envoi réussi, `opted_out` et
`rate_limited`), avec le mode chaos de mailpit (`axllent/mailpit`,
`docker-compose.e2e.yml`, à activer sur ce service) pour que le relais SMTP refuse l'envoi à
la demande. Remplace la recette manuelle (pendant web : `page.route`).
