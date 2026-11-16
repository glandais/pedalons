---
id: MOB-34
title: "Listes : pagination et filtres"
status: done
group: "Couverture e2e Patrol"
done: 2026-09-29
---

## Livré

`MOB-34` **Listes : pagination et filtres** (29 septembre 2026) — sous une équipe dédiée, le défilement atteint l'entrée que l'API place en page 2 (demandée à l'API, pas déduite du tri) : fil d'équipe et fil d'accueil (21 articles et une sortie), annonces (22), membres (22), commentaires d'un article (21) ; les puces de type du fil (« Sorties », « Articles ») et des annonces (« Recherche ») filtrent, une recherche sans résultat mène à l'état vide filtré (fil, annonces), la recherche des membres réduit la liste à un nom — `feed_pagination_test.dart`, `ads_members_pagination_test.dart`, `comments_pagination_test.dart`. Le test des commentaires a mis au jour un défaut, corrigé le même jour (231c2188) : le fil ne chargeait jamais sa deuxième page, les commentaires au-delà du 20ᵉ étaient inaccessibles. Sur Android, ce correctif ne tenait pas : le pied du fil se mesurait dans l'écouteur de défilement, avant la mise en page de la frame, donc en retard d'un cran, et au dernier cran (sans rebond comme sur iOS) il se croyait encore loin. Il se mesure depuis le 29 septembre après la frame (`_NearViewportTrigger._onScroll`), testé sur une liste à slivers comme les pages (« un seul cran jusqu'en bas, sans rebond ») ; **ne pas remesurer dans l'écouteur**. *Non couvert : la portée « rôle minimum » du fil d'accueil, les filtres de prix et de proximité des annonces, les puces de rôle des membres, le bouton « Voir plus de commentaires » (défiler suffit), les listes de découverte des équipes et de mes participations.*
