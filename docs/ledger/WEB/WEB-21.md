---
id: WEB-21
title: "Invitation par e-mail"
status: done
group: "La recette web, automatisée"
---

## Livré

`WEB-21` **Invitation par e-mail** : réponse et écran identiques avec et sans compte, seul le
mail diffère ; « Renvoyer » remplace le jeton, « Annuler » retire l'invitation ; accepter
depuis un autre compte donne un message dédié et un bouton « se déconnecter », qui **ramène à
l'invitation** ; accepter deux fois ne crée qu'une adhésion, et le lien rejoué dit « Vous
faites déjà partie de… ». — `invitations.e2e.ts`. *Non couvert : l'invitation expirée
(14 jours d'horloge).*
