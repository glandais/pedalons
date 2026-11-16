# AUD — Suivi de l'audit d'infrastructure de février

Contexte des entrées `AUD-n` : la prose qui entourait ces entrées dans les deux anciens fichiers du
ledger. Les entrées elles-mêmes sont à côté, une par fichier ; leur liste est dans
[`LEDGER_NEXT.md`](../../LEDGER_NEXT.md) et [`LEDGER_DONE.md`](../../LEDGER_DONE.md).

## Reste à faire : contexte

[`plans/2026-02-14-project-audit.md`](../../plans/2026-02-14-project-audit.md) fait foi pour le détail et
les statuts ; cette table les suit, revérifiés dans le code le 16 novembre 2026 (en prod le 16 octobre). Quand une
ligne est corrigée : ✅ dans l'audit, ligne déplacée dans `LEDGER_DONE.md` sous son identifiant. La
colonne « Audit » garde l'identifiant de l'audit (section « Problèmes » ; `P…` = plan d'action).
Deux gestes d'exploitation de l'audit sont sous `OPS` : I13 (`OPS-7`) et I20 (`OPS-8`). I3 (pas de
déploiement automatique, `AUD-1`) et K10 (routes Karoo non paginées, `AUD-33`) sont
dans « Délibérément dehors ».


Suivis ailleurs : les lignes de sécurité S2 à S12 ont été versées dans l'audit de sécurité de septembre, donc sous
`SEC` (H5 livré sous `SEC-4`, M7 = `SEC-27`, M8 = `SEC-25`, M9 = `SEC-11`, M10 = `SEC-28`, L12 et L13 livrés sous `SEC-22`, L14 sous `SEC-23` ; S8 et S12 y sont rangées comme
conformes). K12 (= S13, jetons Karoo en clair) est L10, dans `SEC-12` ; P2-44 (en-têtes CSP/HSTS) est
V4, tranché sous `SEC-16` et corrigé sous `SEC-30` ; F12 (sitemap) est livré sous `WEB-31`.

## Livré : contexte

Les lignes corrigées avant l'ouverture du ledger sont cochées dans
[`plans/2026-02-14-project-audit.md`](../../plans/2026-02-14-project-audit.md), qui porte aussi le ✅ de
celles d'ici. Même colonnes que la table de `LEDGER_NEXT.md`, le constat remplacé par ce qui a été
fait.
