---
id: NOTIF-11
title: "Rejouer `CoalesceRace` sur le correctif exact de `NOTIF-10`"
status: open
verified: 2026-11-16
---

## Reste à faire

`NOTIF-11` **Rejouer `CoalesceRace` sur le correctif exact de `NOTIF-10`** : dans le modèle
([`formal/notif/`](../../formal/notif/)), la variante la plus proche du correctif livré (`FIX=2`) viole
encore l'invariant ; la relecture du code n'a trouvé aucun entrelacement perdant, mais le modèle
n'a pas été adapté (réinsertion quand la clé a été rendue). L'adapter, et ajouter le test de la
variante « fusion dans la ligne en attente pendant qu'une réservation est tentée ». Taille : S.
