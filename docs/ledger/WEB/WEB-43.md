---
id: WEB-43
title: "Page publique `/fonctionnalites` (`/features`) et sa navigation"
status: done
group: "Accueil et page Fonctionnalités"
done: 2026-10-03
---

## Livré

`WEB-43` **Page publique `/fonctionnalites` (`/features`) et sa navigation** (3 octobre 2026, sans
changement de contrat). Route `features` dans `contracts/routes.yaml` (web, builder Dart, pas de
deeplink), ajoutée à `scripts/routes-ssr.yml`, au `sitemap.xml` après `/` et à `llms.txt`.
Statique et sûre en SSR : ni prefetch ni appel d'API, méta SEO `featuresMeta`. Héros, puces de
section, 8 fonctionnalités (sorties, parcours, voyages, publications, annonces, calendrier,
compteurs, vie privée), rôles, appel final (variante mono-équipe), barre collante
inscription/connexion pour les visiteurs sur téléphone ; « Retour au fil » une fois connecté ;
« Parcourir les équipes » masqué en mono-équipe ; chaque « Créer un compte » ouvre l'étape
d'inscription. Liens dans l'en-tête, le tiroir mobile et le pied de page. Tests :
`FeaturesPage.test.tsx`, `sitemap.test.ts`, `llmsTxt.test.ts`. **À ne pas défaire** : les
illustrations sont décoratives (`aria-hidden`, rien de focalisable, boutons en `span` via
`DemoButton`) ; l'annonce montre un secteur flouté, jamais une épingle ni d'adresse de contact ;
Karoo, Garmin et Wahoo sont listés à l'identique, sans mention de disponibilité ni description de
l'envoi ; le CSS vit dans `index.css` (classes `features-*`), pas dans un module CSS qui
arriverait après le premier rendu SSR d'une page paresseuse ; les puces défilent par
`scrollIntoView` + `history.replaceState`, pas par une navigation de hash (lue comme un POP).
