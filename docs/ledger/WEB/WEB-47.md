---
id: WEB-47
title: "Le nom de « Ma prochaine sortie » est un lien"
status: done
group: "Défauts d'interface"
done: 2026-10-04
---

## Livré

`WEB-47` **Le nom de « Ma prochaine sortie » est un lien** (4 octobre 2026, relevé dans
`docs/BUGS.md`) — seul le bouton « Voir la sortie » y menait (`NextRideCard.tsx`). Le titre
`h3` contient désormais un `Anchor` vers la sortie ; la carte elle-même reste non cliquable (les
specs e2e la lisent par le parent du titre « Ma prochaine sortie », et le lien de carte est celui
du fil).
