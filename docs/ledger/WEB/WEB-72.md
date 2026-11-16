---
id: WEB-72
title: "« Outils GPX » passe dans l'en-tête d'un membre connecté, à la place de « Fonctionnalités »"
status: done
group: "Défauts d'interface"
done: 2026-10-06
---

## Livré

`WEB-72` **« Outils GPX » passe dans l'en-tête d'un membre connecté, à la place de
« Fonctionnalités »** (6 octobre 2026) — les outils n'étaient atteignables que par le menu de
l'avatar (et le tiroir mobile). `useMainNavItems` (`hooks/useNavItems.ts`) les ajoute en dernière
entrée quand la session est ouverte — l'emplacement que `WEB-50` a libéré —, en-tête et tiroir ;
l'entrée s'allume sur toute la section (`gpx-tools` et ses sous-routes). Retirés du menu de
l'avatar et du tiroir (`Layout.tsx`) pour ne pas les lister deux fois. Un visiteur n'a toujours
que « Fonctionnalités » : les outils exigent une session. Test : `MainNav.test.tsx`.
