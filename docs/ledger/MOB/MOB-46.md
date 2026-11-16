---
id: MOB-46
title: "Un lien relatif vers une section d'équipe ouvrait une page vide sans retour"
status: done
group: "Défauts trouvés par la recette du 4 octobre 2026"
---

## Livré

`MOB-46` **Un lien relatif vers une section d'équipe ouvrait une page vide sans retour** — même
cause que `MOB-44` : `openLink` (`core/utils/link_launcher.dart`) poussait par `context.push` toute
route interne reconnue, depuis une publication plein écran. Il passe désormais par `pushLocation`.
