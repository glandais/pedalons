---
id: WEB-7
title: "Idées de la liste « P2 (à planifier) » qui n'ont pas été retenues"
status: open
group: "Couverture e2e — ce que l'audit du 27 septembre laisse ouvert"
verified: 2026-11-16
---

## Reste à faire

`WEB-7` **Idées de la liste « P2 (à planifier) » qui n'ont pas été retenues** parmi les
    21 tests P2 écrits — quelques-unes peuvent être couvertes au passage par une autre spec, à
    vérifier avant de les écrire :
- Sorties : modale des participants avec le meneur marqué ; publication programmée dans le passé
  refusée ; calendrier au-delà de la fenêtre préchargée ; recherche dans les modèles.
- Articles et voyages : commentaire d'un compte supprimé ; modale des participants d'un voyage ;
  étape d'une équipe dont le module est coupé.
- Parcours : « cul-de-sac » (`RouteDeadEnd`) ; unités impériales dans les filtres ;
  « Enregistrer comme parcours » limité aux équipes éligibles (la visibilité du bouton est
  couverte par `flow-gpx-tools`, pas la liste des équipes) ; carte d'équipe sans fuite des
  tuiles TEAM ; hub GPX face à un fichier illisible. Le plein écran et son retour sont couverts
  par `routes-render` (`fullscreenMap`).
- Équipe : promotion en ADMIN et filtre par rôle ; page publique, suppression et restauration
  d'une page, plafond de 3 (les pages supprimées comptent-elles ?).
- Annonces : brouillon d'autrui introuvable par son URL ; défauts du formulaire (DRAFT par
  défaut, Annuler) ; signalement puis redirection.
- Transverse : navigation mobile (tiroir, entrée Admin selon le rôle, fil d'Ariane « Plus ») ;
  restauration du défilement au retour.
