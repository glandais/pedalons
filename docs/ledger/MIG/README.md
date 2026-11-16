# MIG — Migration biketeam → Pédalons

Contexte des entrées `MIG-n` : la prose qui entourait ces entrées dans les deux anciens fichiers du
ledger. Les entrées elles-mêmes sont à côté, une par fichier ; leur liste est dans
[`LEDGER_NEXT.md`](../../LEDGER_NEXT.md) et [`LEDGER_DONE.md`](../../LEDGER_DONE.md).

## Reste à faire : contexte

Configurée en production des deux côtés ; des migrations sans bascule (alors des « essais »,
`dryRun`) y ont réussi sur `gaby` et `n-peloton` du 11 au 15 octobre 2026. Depuis le 11 novembre
2026 il n'y a plus ni essai ni `reset` : toute migration est incrémentale, et la bascule est un
bouton à part côté biketeam (`MIG-16`). Reste le passage réel
([plan](../../plans/2026-09-22-biketeam-live-migration.md) §10). Source :
[`MIGRATE_BIKETEAM.md`](../../MIGRATE_BIKETEAM.md).


