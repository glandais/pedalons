---
id: WEB-6
title: "Erreur d'hydratation React #418 (texte), intermittente — corrigée le 29 septembre 2026."
status: done
group: "La recette web, automatisée"
---

## Livré

`WEB-6` **Erreur d'hydratation React #418 (texte), intermittente — corrigée le 29 septembre
2026.** Vue d'abord sur `/equipes/{slug}` en membre (point 40 de l'audit), puis sous charge
(`--workers=5`) sur `postEdit` et `gpxToolsEdit`, deux requêtes parties à la même
milliseconde et servies en 2,5 s. Leur HTML serveur n'avait ni le nom du site (« © 2026 . »)
ni la version, sans aucune erreur au journal : le `QueryClient` du SSR avait un `gcTime` de
2 s, et la config et la version, lues avant le prefetch de la route et observées seulement au
rendu, étaient ramassées entre les deux dès que le prefetch dépassait 2 s. Elles manquaient
donc aussi à l'état déshydraté ; le client, qui lit la config avant d'hydrater
(`entry-client.tsx`), rendait le nom, d'où #418 sur n'importe quelle page. Le serveur ne
ramasse plus rien (`gcTime: Infinity`) : son client ne vit qu'une requête et `entry-server`
le vide en fin de rendu. — `src/lib/queryClient.test.tsx` (« a server query nothing observes
yet »). **À ne pas défaire** : aucune fenêtre finie n'est sûre côté serveur, elle ne fait que
déplacer le seuil de charge. L'occurrence d'origine n'a pas été rejouée ; un #418 qui
reviendrait sur une page dont le SSR contient bien nom et version est une autre cause, à
ouvrir sous un nouvel identifiant.
