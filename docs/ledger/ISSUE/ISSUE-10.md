---
id: ISSUE-10
title: "Staging et la production servent publiquement leurs sourcemaps"
status: out
---

## Écarté

`ISSUE-10` **Staging et la production servent publiquement leurs sourcemaps** — écarté le
16 novembre 2026, décision du propriétaire : c'est assumé. `FRONTEND_SOURCEMAP=true` est dans
le `.env` de staging et dans celui de la production (relu sur le serveur ce jour-là, les deux
piles sur `3b8a0b8`) ; le conteneur frontend sert donc ses `.js.map` en 200 sous `/assets/`
(`https://www.pedalons.fr/assets/index-….js.map` rend un vrai fichier de 2 Mo). Motif : le
dépôt est public, un `.map` ne révèle rien que GitHub ne montre déjà, et il rend lisibles les
piles d'erreur du navigateur (`ISSUE-1`). À rouvrir si le dépôt devient privé, ou si le poids
servi gêne. L'étude `OPS-54` (image unique pour tous les environnements) peut encore sortir
les `.map` de l'image servie pour ses propres raisons : ce ne serait plus une correction de
sécurité.
