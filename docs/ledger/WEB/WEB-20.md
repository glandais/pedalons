---
id: WEB-20
title: "Trombinoscope, la matrice rôle × réglage"
status: done
group: "La recette web, automatisée"
---

## Livré

`WEB-20` **Trombinoscope, la matrice rôle × réglage** : réglage désactivé, un membre ordinaire
prend un 403 ; un organisateur voit la liste sans rôles ni dates ; le sélecteur de meneur
propose toujours des candidats. Réglage activé, le membre voit tout. `?search=` avec l'adresse
exacte d'un coéquipier ne remonte rien en membre ni en organisateur, et le remonte en admin
d'équipe. — `member-directory.e2e.ts`, sur une équipe de test et non sur `gaby`. *L'entrée
« Membres » est un écran mobile (`web: false`), hors de portée de Playwright ; sur le web, le
403 est vérifié sur l'API, l'écran d'admin redirigeant vers la page d'équipe.*
