---
id: SEC-16
title: "Les faits hors dépôt de l'audit, V3 à V8, tous tranchés"
status: done
done: 2026-09-30
---

## Livré

`SEC-16` **Les faits hors dépôt de l'audit, V3 à V8, tous tranchés** (2026-09-30 → 2026-10-01,
contrat inchangé) — vérifiés sur les hôtes, chacun avec son statut dans l'audit de septembre (archivé) :
V3 conforme par Caddy (`X-Forwarded-*` forgés sans effet), avec une faille annexe, Traefik joignable
en IPv6, fermée sous `SEC-29` ; V4 confirmé puis corrigé sous `SEC-30` (la CSP des scripts reste
`SEC-31`) ; V5 confirmé puis corrigé sous `SEC-32` (recette `OPS-26`, alerte `OPS-27`) ; V6 sans
tenants voisins (un domaine par base), mais d'autres sites de l'hôte sont des sous-domaines de
`pedalons.fr`, donc « same-site » pour la prod ; V7 non confirmé — Vert.x Mail 4.5.34 refuse CR et LF
dans un sujet et encode les autres séparateurs en RFC 2047, essayé sur son `MailEncoder` (annexe :
`SEC-33`, corrigé) ; V8 caduc — aucun SVG stocké en prod ni en staging, leur envoi refusé depuis `SEC-1`.
**À ne pas défaire** : V7 repose sur le client SMTP ; un changement de bibliothèque de courriel
doit reverser la question, ou `SEC-33` la régler côté application.
