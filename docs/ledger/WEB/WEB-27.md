---
id: WEB-27
title: "Le SSR de `/calendrier` ne croît plus en carré des sorties d'une semaine"
status: done
group: "Défauts d'interface"
done: 2026-10-12
---

## Livré

`WEB-27` **Le SSR de `/calendrier` ne croît plus en carré des sorties d'une semaine** (mesuré le
12 octobre 2026 sur la pile e2e, sans changement de code ici) — `@mantine/schedule` 9.6.2 plaçait
chaque événement du mois en le comparant à tous ceux déjà posés dans sa semaine
(`findAvailableRow`) : 1 000 sorties sur une semaine, 2,7 s de rendu ; 2 400, 10 s, pendant
lesquelles le même processus Node ne servait plus `/assets`. Corrigé en amont (issue
[mantinedev/mantine#9231](https://github.com/mantinedev/mantine/issues/9231), PR
[#9232](https://github.com/mantinedev/mantine/pull/9232) : un index d'occupation de 7 jours,
`reserveRow`), publié en 9.7.1, où `frontend/` est passé le 7 octobre 2026 (`8fa64c44`). Mesure
sur les images de `c556fe32` : un compte neuf, une équipe, 1 000 puis 2 400 sorties publiées
du 12 au 18 octobre, `/calendrier` rendu en connecté, quatre fois par palier, un chunk `/assets`
demandé 150 ms après le document :

| Sorties | `GET /api/calendar/events` | Document `/calendrier` | Chunk pendant le rendu |
|---|---|---|---|
| 0 | 11–29 ms | 96–132 ms | 12–23 ms |
| 1 000 | 54–121 ms (303 Kio) | 659–747 ms (413 Kio) | 500–588 ms |
| 2 400 | 118–150 ms (729 Kio) | 1,44–1,83 s (839 Kio) | 1,27–1,66 s |

Le rendu Node (document moins API) tombe de 2,7 s à ~0,6 s et de 10 s à ~1,4 s, et croît
désormais **linéairement** (×2,3 pour ×2,4 sorties, contre ×3,7 avant). Il reste synchrone : à
2 400 sorties sur une semaine, un chunk attend encore ~1,4 s — le coût se partage entre le
placement par jour (`get-renderable-month-event-segments`, linéaire) et la sérialisation d'un
état de 729 Kio. À l'échelle d'un vrai compte (quelques dizaines de sorties par semaine), c'est
négligeable. **Repli non retenu** : un seuil au rendu serveur (grille vide au-delà de N
événements, remplie après montage) — à rouvrir seulement si un compte réel approche le millier
de sorties sur une semaine. Pas de test permanent : la mesure (une spec Playwright jetable)
n'a pas sa place dans la suite nocturne.
