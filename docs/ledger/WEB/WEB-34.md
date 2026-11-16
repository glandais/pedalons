---
id: WEB-34
title: "Un `llms.txt` par site"
status: done
group: "Référencement"
done: 2026-09-30
---

## Livré

`WEB-34` **Un `llms.txt` par site** (2026-09-30, sans changement de contrat) — le résumé
(https://llmstxt.org) qu'un modèle de langage lit avant le site. Servi par `server.js` comme
`/sitemap.xml`, **par hôte** et non en fichier statique (décision du 30 septembre 2026) : le nom du
site, des liens absolus sur l'hôte de la requête, et sur un hôte épinglé sa seule équipe, à la
racine. `renderLlmsTxt` (`entry-server.tsx`) interroge l'API en anonyme (seuls les en-têtes d'hôte
passent, réponse en cache public une heure) : `GET /api/config` pour le nom, `GET /api/teams`
pour les équipes `PUBLIC` (la liste anonyme), les 200 plus grandes, avec leur extrait et leur
chemin anglais ; au-delà, un renvoi au plan du site. Le texte (`lib/llmsTxt.ts`) dit les deux
locales et ce qui n'est listé nulle part — annonces, parcours et cartes, espaces personnels — puis
pointe `/sitemap.xml`. Il n'expose rien que `robots.txt` et le sitemap (`WEB-31`) n'exposent déjà.
Couvert par `lib/llmsTxt.test.ts` (titre et résumé, liens et extrait, équipes au-delà de la page,
hôte épinglé, ni annonce ni parcours). Ne pas y lister de contenu que le sitemap ne liste pas.
