---
id: MOB-59
title: "Les liens vers les pages du site sans écran dans l'app ne mènent plus à sa page d'erreur"
status: done
group: "Tableau de bord d'équipe"
done: 2026-10-11
---

## Livré

`MOB-59` **Les liens vers les pages du site sans écran dans l'app ne mènent plus à sa page
d'erreur** (11 octobre 2026, contrat inchangé), relevé avec `WEB-64`. Les jokers des liens d'app
traversent les `/` : `/equipes/{teamSlug}` donne `/equipes/*` (AASA) et `/equipes/.*`
(manifeste), qui captent tout le sous-arbre de l'équipe — administration, formulaires de
sortie, de voyage, d'article, de parcours, d'annonce, cartes. L'app recevait ces liens et
affichait l'`errorBuilder` (« page introuvable »). Sous iOS, l'AASA les exclut depuis `MOB-58`.
Sous Android, `scripts/generate-routes.mjs` émet la même liste dans `paths.generated.dart`
(`sitePagePathPatterns`, `*` → `[^/]+`) ; `isSitePageLocation` (`link_launcher.dart`) la lit, et
`openDeepLink` (`router.dart`) confie une telle page au navigateur (`openWebPage`) **avant**
tout le reste : sans session requise, sans toucher la pile ni le lien en attente. Elle passe
aussi avant les motifs de l'app dans `internalLocationFor` et `openLink` :
`/equipes/x/sorties/nouvelle` est aussi la sortie de slug `nouvelle`, et un lien du site vers
le formulaire ouvrait l'écran de sortie sur une erreur. Tests : `sign_in_resume_test.dart`
(connecté ou non, la page part au navigateur sans navigation ni lien en attente),
`link_launcher_test.dart` (chaque page du tableau de bord dans les deux langues, aucune route
de l'app prise pour une page du site, un lien markdown vers `sorties/nouvelle`). **À ne pas
défaire** : la liste vient du générateur (même calcul que les `NOT` de l'AASA), jamais écrite
à la main ; le test de page du site précède celui des routes de l'app. L'exclusion côté
manifeste est dans « Délibérément dehors », sous `MOB-74`.
