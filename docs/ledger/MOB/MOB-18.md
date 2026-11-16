---
id: MOB-18
title: "Pièces jointes"
status: done
group: "Recette sur une application qui tourne — 4 octobre 2026"
---

## Livré

`MOB-18` **Pièces jointes** — le bloc apparaissait sur les huit écrans à `MediaDto` (sortie,
publication, annonce, parcours, voyage, étape, page d'équipe, « à propos ») avec un fichier et
disparaissait sans ; une publication et un « à propos » faits d'une seule pièce jointe sans texte
affichaient le bloc. Noté en chemin : un asset ne s'attache qu'à un contenu : le joindre à un second
est ignoré sans erreur (l'API répond 200 et le second contenu ne le porte pas) — `API-68`.
