# Constat sur les captures des galeries de listes (2026-11-12)

Ce que montrent les captures de `captures/app/` (73 images, 390 × 844 pt) et `captures/site/` (150 images, 1280 px et
390 px), prises après le lot 0. Relevé fait en regardant les images, par les deux sous-agents qui ont construit les
galeries ; relu par échantillon (parcours filtrés et agenda en erreur, des deux côtés). Rien n'a été corrigé.

Ce constat complète le [tri](tri.md) : il confirme des règles, et ajoute ce que la lecture du code n'avait pas vu.

## Cas montés

- **Site** : les 75 cas du [cahier](galerie.md). `annonces-criteres` ouvre la liste des types (pas de panneau) ;
  `accueil-criteres` ouvre la liste « Équipes » ; `parcours-tri` ouvre le panneau puis le tri, qui est dedans.
- **App** : 73 cas. Omis : `agenda-criteres` et `annonces-criteres` — ces deux listes n'ont pas de feuille de filtres,
  tout est en ligne dans la barre. `parcours-carte` montre la barre seule (pas de carte native en test).
- L'horloge du site est figée à midi ; celle de l'app ne l'est pas (les pages lisent `DateTime.now()`).

## Ce qui confirme une règle du tri

| Règle | Ce que l'image montre | Captures |
|---|---|---|
| RL2 | App, accueil : la puce « Membre » (le défaut) paraît sélectionnée et « Toutes les équipes » non — le signal est inversé ; la feuille de portée met des chevrons sur des choix exclusifs. App, calendrier : la puce de portée est coupée (« Toutes m… »). App, Explorer : « Toutes les équipes · Membre » se contredit. Site, Explorer : la portée est un champ isolé au-dessus de « Filtres ». | `accueil-repos`, `accueil-criteres`, `calendrier-repos`, `explorer-repos` |
| RL4 | Site, parcours : le bouton « Filtres » ne dit rien d'un filtre de distance actif, seul « Effacer » apparaît ; le filtre « Route » d'Explorer est invisible panneau fermé. App, parcours : la pastille affiche « 1 » sans aucun filtre (la portée équipe est comptée) et « 3 » avec deux filtres. | `parcours-filtre`, `parcours-repos`, `explorer-filtre` |
| RL6 | App : la recherche des parcours est tronquée (« Rechercher un p… ») à côté de « Ajouter » ; le segment « Je parti… » de l'agenda est tronqué ; la rangée de types des annonces est coupée ; la puce « Tags » et la rangée « Tout / Sorties / Voyages » sont seules et centrées ; le calendrier d'équipe empile deux rangées « Tout ». Site : le tri des parcours est dans le panneau, son sens est un chevron seul, et « Date », le défaut, est en dernier ; le panneau de l'agenda ne contient que la recherche et un champ Tags désactivé ; les annonces n'ont pas de panneau, le prix est toujours affiché. Site à 390 px : en-tête d'équipe, onglets coupés et deux boutons empilés repoussent la liste vers 1 400 px. | `parcours-repos`, `agenda-repos`, `annonces-repos`, `parcours-tri`, `agenda-criteres`, `calendrier-equipe` |
| RL8 | Pas de compteur : site — calendrier, équipes, modèles (total 47), vue carte des parcours ; app — « Mes équipes ». Site, membres : compteur à droite, à gauche ailleurs. « 0 publication » au-dessus de l'état vide, des deux côtés. | `equipes-repos`, `modeles-repos`, `membres-repos`, `publications-vide-filtre`, `accueil-vide` |
| RL10 | Site : le titre « Aucun résultat ne correspond à votre recherche. » répète la description. App : le vide filtré cite « monts » mais pas le tag ; les états vides des équipes sont en haut de l'écran (centrés ailleurs) avec des boutons pleins (en contour ailleurs) ; « en Novembre 2026 » avec une majuscule. | `publications-vide-filtre`, `equipes-vide`, `calendrier-vide` |
| RL11 | Site : « Chargement impossible » **et** une notification « Erreur interne du serveur » — l'erreur est dite deux fois. App : le message d'une erreur serveur est « Erreur », sans détail ; l'agenda et les publications titrent « Fil indisponible. » ; les annonces en panne disent « La rubrique Annonces n'est pas activée sur cette équipe, ou le réseau est indisponible ». Site, calendrier : la grille est seulement voilée pendant le chargement. | `agenda-erreur`, `annonces-erreur`, `inscrits-erreur`, `calendrier-chargement` |
| RL13 | App : `-lecture` est identique à `-repos` sur l'agenda et les publications — aucune action de création, même pour qui organise. | `agenda-repos`, `agenda-lecture`, `publications-repos` |
| RL15 | App : une sortie passée porte à la fois « TERMINÉE » et « J'Y VAIS ». | `publications-repos`, `agenda-passees` (à revoir en dessinant la planche) |

## Ce que le tri n'avait pas

| # | Constat | Support | Nature |
|---|---|---|---|
| C1 | L'en-tête d'équipe affiche le badge « MEMBRE » à une organisatrice, alors que « Mes équipes » dit « Organisateur ». À vérifier : donnée de la galerie ou défaut de l'en-tête. | App | À vérifier, puis défaut |
| C2 | Une personne organisatrice voit « Quitter l'équipe » à côté de « Gérer » sur toutes les pages d'équipe ; dans l'app, « Quitter » occupe l'en-tête de chaque section. | Les deux | Hors listes (en-tête d'équipe) : à noter au ledger |
| C3 | Accueil : le fil est entièrement sous le pli à l'ouverture (app), et sous le pli à 1280 px pendant le chargement (site). | Les deux | Structure de l'accueil, hors règles de liste |
| C4 | Parcours du site : vignettes carrées très hautes, on ne voit que deux images au-dessus du pli à 1280 px. | Site | Carte, pas liste : à rapprocher de KIT §9 |
| C5 | Explorer du site : la page n'a pas de titre. | Site | Défaut faible |
| C6 | Membres du site : le champ de recherche n'a pas de libellé, « Rôle » en a un : les deux champs sont décalés. | Site | Défaut faible |
| C7 | Équipes du site : le badge de rôle n'est pas au même endroit d'une carte à l'autre. | Site | Carte : KIT §9 |
| C8 | Site, équipes sans aucune équipe : la portée affiche « Toutes » (règle `useMembershipDefault`, attendu). | Site | Conforme à RL1 |
| C9 | App : « Rejoignez une équipe pour commencer » sans point final. | App | Défaut faible |
| C10 | App : une publication sans photo a un grand bandeau dégradé. | App | Carte : conforme à R10 (KIT §9) |

## Écarts entre les données des deux galeries

À corriger dans les galeries avant de s'en servir pour vérifier une cible :

- Personnes inscrites du groupe B : 11 dans le cahier des cartes, 8 dans celui des listes. Le site affiche « 11
  personnes » en en-tête et « 1–8 sur 8 » dans la liste.
- « Mes équipes » : deux équipes sur le site, davantage dans l'app (deux équipes ajoutées de chaque côté, pas les
  mêmes : « Cyclos de l'Aulne » sur le site, « Rouleurs du Léon » et « Cyclos de Morlaix » dans l'app).
- Le pied de l'app dit « Vous avez tout vu » sous « 3 sur 47 » : les pages suivantes du faux serveur sont vides.
- Site : la carte et la météo de la page de groupe n'ont pas de donnée ; le fond de carte est vide.
