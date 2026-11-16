---
id: MOB-41
title: "Les données du compte des relecteurs des stores ne se périment plus"
status: done
---

## Livré

`MOB-41` **Les données du compte des relecteurs des stores ne se périment plus** (3 octobre
2026, contrat inchangé) — le seed prod de `mobile/screenshots/seed.py` était un passage unique :
trois semaines plus tard, `marketplace-tester@pedalons.fr` n'était plus inscrit à rien, la sortie
commentée que citent les notes App Review était passée, et la reconstruction elle-même ne passait
plus, l'API refusant depuis `80670273` l'inscription à une sortie passée. `--refresh` remet les
deux clubs à jour sans rien supprimer, par l'API seule : le compte de test inscrit à sa prochaine
sortie (plus deux sur cinq dans les trois semaines), un fil de commentaires d'autres membres sur
celle-ci tel que lui le voit, ses blocages levés, les sorties proches complétées, un voyage
toujours à venir, la publication du mois, la fin du calendrier qui avance (quinze mois glissants
au lieu du 31 décembre 2027). La reconstruction part désormais de demain ; l'historique est ce que
les rafraîchissements laissent derrière eux. Pas de test automatisé : `--dry-run` et une
vérification hors ligne du calendrier et des inscriptions. **À ne pas défaire** : une sortie tire
ses membres et son calendrier **d'une graine par date** (`calendar-{fr}-{jour}`,
`{locale}-{AAAAMMJJ}`), et les lève-tôt sont un préfixe des inscrits finaux — c'est ce qui rend
`--refresh` idempotent et ne fait qu'ajouter. L'installation sur l'hôte est `OPS-28`.
