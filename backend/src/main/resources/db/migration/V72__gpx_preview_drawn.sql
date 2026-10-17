-- docs/LEDGER_*.md WEB-99 (A10) : un aperçu GPX tracé au planificateur ne devient pas un parcours
-- d'une équipe sans planificateur ; il faut donc se souvenir de son origine. Purement additive :
-- colonne avec défaut, que la release précédente ignore (déploiement start-first). Les aperçus
-- existants restent à false (origine inconnue, choix assumé).

alter table gpx_previews
    add column drawn boolean not null default false;
