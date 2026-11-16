---
id: NOTIF-3
title: "Webhook d'équipe : le *DNS rebinding* n'est pas couvert"
status: open
verified: 2026-11-16
---

## Reste à faire

`NOTIF-3` **Webhook d'équipe : le *DNS rebinding* n'est pas couvert** — `WebhookHttpClient`
refuse toute résolution vers une adresse interne, mais `HttpClient` résout de nouveau à la
connexion : un nom qui change de réponse entre les deux passe. Le fermer voudrait dire
épingler l'adresse vérifiée pour la connexion (voir la javadoc de `WebhookHttpClient`).
