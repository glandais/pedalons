---
id: BILL-1
title: "Décider, vérifier, puis poser le socle"
status: open
size: "M"
verified: 2026-11-16
---

## Reste à faire

`BILL-1` **Décider, vérifier, puis poser le socle (M)** — trancher ce qui reste du §11 du plan
(objectif, prix, date de bascule et première période, échéance commune ou non, droits avant
paiement, carte, devis, majeure ou mineure, TVA et mentions avec l'expert-comptable,
rétractation ; le seuil du gratuit et les équipes offertes sont tranchés) ; vérifier dans le
bac à sable Qonto ce que le §9 laisse ouvert (clé d'API suffisante pour les factures et les
webhooks, rapprochement automatique des virements, avoirs) ; puis le lot 1 du §10 : la
prochaine migration Flyway (`team_subscriptions`, `billing_invoices`, `billing_events`),
`TeamSubscription`, `TeamEntitlements` et son résolveur, `entitlements` dans `TeamDetailDto`
(`tier`, `memberLimit` et `plannerQuota` y sont déjà, par `BILL-10`), `AdminTeamDto` et
`PATCH /api/admin/teams/{id}/subscription`, `BILLING_ENABLED=false`, et la migration de
lancement qui pose « Club offert jusqu'au 31 mars 2027 » sur toute équipe existante —
**aucun refus actif à ce stade**. Les lots suivants (`BILL-2` à `BILL-9`, §10 du plan) ne
sont créés ici qu'une fois `BILL-1` tranché. Prérequis avant le premier euro encaissé :
Open-Meteo en plan payant (`OPS-29`), conditions VersaTiles relues (§8 du plan ; le géocodage
est chez Stadia Maps depuis `OPS-49`, un plan payant déjà, plus rien à relire côté
Nominatim), et aucun environnement hors prod capable d'émettre une facture.
