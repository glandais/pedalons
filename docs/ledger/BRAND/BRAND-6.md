---
id: BRAND-6
title: "Les icônes des sections d'équipe suivent la charte, les mêmes sur les deux clients"
status: done
done: 2026-10-06
---

## Livré

`BRAND-6` **Les icônes des sections d'équipe suivent la charte, les mêmes sur les deux clients**
(6 octobre 2026, avec `WEB-68` et `MOB-60`, contrat inchangé). Au web, `useTeamNavItems` prend
les icônes de la table du [`BRANDING.md`](../../BRANDING.md) §6 (`useTeamNavItems.test.tsx`) ; au
mobile, `buildTeamSections` prend l'équivalent `PdlIcons` de chacune — `dashboard`, `agenda`
(nouveau, `event_outlined` pour `IconCalendarEvent`), `post`, `route`, `ad`, `people`, `info` —
au lieu des `Icons.*` choisis à part (`dynamic_feed`, `sell`, `calendar_today`…) ; la table du
§6 porte désormais la colonne mobile (`team_dashboard_test.dart`, « les puces suivent l'ordre du
site »). « Agenda » et « En cours » sont au lexique (§8). **À ne pas défaire** : une icône de
section vient de `PdlIcons`, jamais d'un `Icons.*` posé dans l'écran ; changer une icône de
section se fait dans la table du §6 et sur les deux clients à la fois.
