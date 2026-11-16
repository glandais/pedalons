---
id: SEC-40
title: "La CSP complète du site n'est encore que rapportée (`Content-Security-Policy-Report-Only`) : lire les…"
status: open
verified: 2026-11-16
---

## Reste à faire

| ID | Priorité (audit) | Audit | Sévérité | Constat |
|---|---|---|---|---|
| `SEC-40` | — | Suite de `SEC-31` | Moyenne | La CSP complète du site n'est encore que rapportée (`Content-Security-Policy-Report-Only`) : lire les rapports `[csp-report]` de staging et de prod, puis passer `CSP_MODE=enforce` (procédure dans [`OPERATIONS.md`](../../OPERATIONS.md#content-security-policy)). Avant de basculer, vérifier dans un vrai navigateur sur staging, console ouverte et rapports lus : la carte (chaque fond, relief, mode sombre, tracé GPX), la visionneuse PDF d'une pièce jointe, un post markdown avec images externes, la PWA (installation, service worker, inscription au web push en prod), la connexion par passkey, la connexion et la synchronisation Strava, l'éditeur Tiptap. Durcir aussi la route de rapports (budget par client et dédoublonnage, le budget global de 120 lignes/min peut être épuisé par des rapports forgés) et le cache de dix minutes des hôtes raster (un changement de fournisseur de carte sans redémarrage du frontend reste bloqué jusque-là). Restera ensuite : les réponses non HTML (scripts, worker de carte) ne portent que les quatre directives de `SEC-30`. Taille : S |
