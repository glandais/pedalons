---
id: SEC-14
title: "Images externes dans le markdown ; le parseur XML et le paramètre non encodé sont livrés sous `SEC-21`"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `SEC-14` | **Images externes dans le markdown** (audit de septembre 2026, informationnel ; le parseur XML et le paramètre non encodé sont livrés sous `SEC-21`) | Gardées telles quelles (décidé le 17 novembre 2026 avec le propriétaire, sans mesure préalable en production) | Une image écrite `![](https://…)` dans une sortie, une publication ou une page est chargée par chaque lecteur, sur le site (`MarkdownDisplay.tsx`, CSP `img-src https:` de `frontend/server/csp.js`) comme dans l'app (`_MarkdownImage`, `pdl_markdown_body.dart`) : l'hôte externe reçoit l'adresse IP, l'heure et l'adresse de l'image. Aucune information de compte ne fuit : l'app ne joint le jeton qu'aux adresses de l'API (`authHeadersFor`, `credential_scope.dart`), et le site n'en joint jamais. Seuls un lien collé à la main ou un contenu migré produisent une image externe ; une image envoyée passe par la directive `::asset`. Écartés : un lien à la place de l'image, l'affichage sur clic, un proxy par imgproxy (le serveur deviendrait un client HTTP ouvert à toute URL saisie par un membre). La politique de confidentialité le dit (§4, « Images hébergées ailleurs », FR et EN, mise à jour du 17 novembre 2026) |
