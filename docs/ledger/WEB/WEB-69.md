---
id: WEB-69
title: "Un seul sélecteur de vue pour Parcours et Agenda"
status: done
group: "Agenda et Publications"
done: 2026-10-06
---

## Livré

`WEB-69` **Un seul sélecteur de vue pour Parcours et Agenda** (6 octobre 2026, sans changement
de contrat d'API). `ListViewSwitch` (`components/common/`, icônes seules dans un
`SegmentedControl` libellé « Affichage », chaque vue nommée par un texte masqué dans le
`<label>` de sa radio, infobulle) remplace `RouteViewToggle` et `RouteDensityToggle`. Parcours
(`RouteViewSwitch`, les quatre pages) : Vignettes · Lignes · Carte, à droite du nombre de
résultats ; la densité vit dans `?view=card|row`, qui remplace `?d=` ; Carte garde
`routesMap`/`allRoutesMap` et le sélecteur y navigue en gardant les filtres. Agenda :
Vignettes · Lignes · Calendrier ; Calendrier mène à `teamCalendar` en gardant le type et
« Je participe », la page Calendrier (titrée « Agenda », filtres « Tout / Je participe » et type
appliqués aux événements de la fenêtre) ramène aux lignes ou aux vignettes ; un visiteur n'a pas
la vue Calendrier, et `teamCalendar` le renvoie à l'Agenda. Tests : `ListViewSwitch.test.tsx`,
`RouteViewSwitch.test.tsx` ; e2e `list-filters`, `flow-routes`, `routes-render`
(`teamCalendar`), `team-dashboard` (pas de Calendrier pour un visiteur). **À ne pas défaire** :
le composant reste présentationnel — où vit la vue (`?view=`, un chemin) appartient à la page ;
Carte et Calendrier gardent leur chemin pour les liens existants. Le mock `ResizeObserver` de
`src/test/setup.ts` est une classe : Mantine le construit avec `new`.
