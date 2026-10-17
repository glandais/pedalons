# Plans archivés

Ces plans ont été exécutés. Ils sont conservés parce qu'ils portent le **pourquoi** de décisions
qui contraignent encore le code — pas comme feuille de route. Ce qui reste à faire a été extrait
dans [`docs/LEDGER_NEXT.md`](../../LEDGER_NEXT.md) : c'est là qu'il faut chercher la suite, pas ici.

Ne pas rouvrir un arbitrage listé ici sans lire sa justification. Plusieurs sont des invariants que
des tests gardent (`groupLeader_isNotTheRideCreator`, `…QueryCountTest`, les deux `grep` de revue de
`core/pdl`).

| Plan | Objet | État vérifié |
|---|---|---|
| [`2026-07-26-mobile-v2-implementation.md`](2026-07-26-mobile-v2-implementation.md) | Refonte de l'app Flutter : thème, bibliothèque `core/pdl`, coquille à 5 onglets, 12 écrans | **Terminé** (27 juillet 2026) — 116 tâches ☑, aucune ☐. `flutter analyze` propre, 480 tests verts, les 5 invariants de revue tiennent (§ci-dessous) |
| [`2026-07-26-web-portage-mobile-v2.md`](2026-07-26-web-portage-mobile-v2.md) | Portage vers React des seules idées de la v2 mobile qui corrigent une faiblesse du site | **Terminé sauf 3 tâches** (27 juillet 2026) — T3.5 abandonnée (prémisse fausse, argumentée sur place), T5.4 partielle (trombinoscope public bloqué par une décision de sécurité), T5.5 optionnelle. Les trois sont reportées dans `LEDGER_NEXT.md`, qui donne depuis T5.5 livrée (juillet 2026) et T5.4 débloquée en `3.0.0`, sauf la page web publique |
| [`2026-07-26-api-v2-livraison-et-suites.md`](2026-07-26-api-v2-livraison-et-suites.md) | Ce que les contrats 1.3.0 → 1.5.0 ont apporté, et les 4 chantiers d'infrastructure non livrés | **Document de référence** — la partie « livré » fait toujours foi ; son §4 (push, curseur, cache/images, carte multi-entités) est repris dans `LEDGER_NEXT.md`. **S'arrête volontairement à 1.5.0** (note en tête du document) : le contrat est en **5.6.0** au 29 septembre 2026, la suite est dans `LEDGER_NEXT.md` et l'historique git |
| [`2026-07-31-navbuttons.md`](2026-07-31-navbuttons.md) | Instruction et livraison de la refonte sémantique de `NavButtons` (web) : liens et non `tablist`, mesures prises dans le navigateur | **Livré** le 31 juillet 2026 (lots A, B, C). L'anneau de focus (lot D) reste ouvert dans `LEDGER_NEXT.md` (`WEB-2`) ; les deux autres restes du §7 (`/equipes/{slug}/admin/parametres` en SSR direct, préférence de langue) ont été corrigés le 25 septembre 2026 et sont gardés par `frontend/e2e/team-misc.e2e.ts` |
| [`2026-09-24-signalement.md`](2026-09-24-signalement.md) | Signalement, blocage et filtre de publication exigés par la directive App Store 1.2 | **Livré** le 24 septembre 2026 (V41). Les quatre défauts mineurs restants sont dans `LEDGER_NEXT.md` (`MOD-1` à `MOD-4`) |
| [`2026-09-27-e2e-coverage-audit.md`](2026-09-27-e2e-coverage-audit.md) | Audit de couverture e2e Playwright, plan P0/P1/P2, suivi des 54 défauts trouvés (était `frontend/E2E_COVERAGE_AUDIT.md`) | **Exécuté** le 28 septembre 2026 : P0, P1 et P2 écrits, sauf le canal e-mail. Le point 40 (hydratation #418) est le ledger `WEB-6`, les idées P2 non écrites `WEB-7` |
| [`2026-09-security-audit.md`](2026-09-security-audit.md) | Audit de sécurité de septembre 2026 (était `docs/SECURITY_AUDIT.md`), version expurgée : constats H1–H5, M1–M10, L1–L14, faits hors dépôt V1–V8, contrôles vérifiés et conformes | **Archivé** le 9 octobre 2026, statuts figés à cette date. Ouverts suivis sous `SEC` dans `LEDGER_NEXT.md` (`SEC-12`, `SEC-13`, `SEC-14`, `SEC-31`), qui fait seul foi. Les identifiants H/M/L/V restent cités par le code (`UploadedContentHeaders`) et par l'audit de février |
| [`2026-09-30-fixes-branch.md`](2026-09-30-fixes-branch.md) | Note de livraison de la branche `fixes` (était `docs/FIXES-2026-09-30.md`) : ce qu'elle apportait au-dessus de `develop` (API 6.1.0 → 9.1.2, V49 à V53), les vérifications avant déploiement, les résultats de la passe de tests du 30 septembre | **Fusionnée et déployée** — `d9428ecc` est dans `develop`. Ses ouverts sont livrés (`API-56`, `API-57`, `OPS-24`, `SEC-26`) ou suivis dans `LEDGER_NEXT.md` (`WEB-27`, `WEB-36`) ; sa mention « correctif en cours côté Mantine » pour `WEB-27` est dépassée |
| [`2026-10-01-tags.md`](2026-10-01-tags.md) | Tags d'équipe sur les sorties, posts, voyages, parcours et annonces : vocabulaire par équipe et par type, couleur, filtre en OU, import des tags biketeam (décisions D1 à D23) | **Exécuté** le 1er octobre 2026, API 10.1.0 — `API-59`, `WEB-40`, `MOB-39` et `MIG-14` (l'import, détaché de `MIG-6`, qui garde la ville et le pays) dans `LEDGER_DONE.md`. Écart : la copie modèle → sortie (D14) est faite par le formulaire web, pas par l'API |
| [`2026-07-25-privacy-policy-audit.md`](2026-07-25-privacy-policy-audit.md) | Audit de la politique de confidentialité et des CGU contre le code (juillet 2026), constats et preuves | **Exécuté** — politique et CGU réécrites, puis rebasées le 29 septembre 2026 ; les suites sont sous `LEGAL` |
| [`2026-09-21-privacy-policy-refresh.md`](2026-09-21-privacy-policy-refresh.md) | Mise à jour de la politique après ~400 commits (notifications, export, Wahoo…), registre des preuves, points ouverts sortis du texte publié | **Exécuté** le 29 septembre 2026 — les points ouverts sont `LEGAL-9` à `LEGAL-13`, `WEB-28` (jetons Karoo : `SEC-12`) |
| [`2026-09-29-privacy-policy-open-points.md`](2026-09-29-privacy-policy-open-points.md) | Ce que la politique ne disait pas, ou mal, et qui demandait une décision juridique (import biketeam, relais d'annonces, app Garmin, contenu public, Web Push, points mineurs) | **Exécuté** le 29 septembre 2026 — ses six points sont clos (`LEGAL-1` à `LEGAL-8`), comme les suites `LEGAL-9` à `LEGAL-15` ; la section `LEGAL` de `LEDGER_NEXT.md` est vide |
| [`2026-09-18-notifications.md`](2026-09-18-notifications.md) | Notifications évènementielles : pipeline évènement → notification → livraison, canaux in-app, e-mail, push mobile et Web Push, webhook d'équipe, résumé quotidien | **Livré** — phases 1 à 5 en production le 21 septembre 2026, Web Push le 29 ; archivé le 29 septembre 2026. Le livré (et son ledger rapatrié) est dans `LEDGER_DONE.md` (`NOTIF-9`), les restes dans `LEDGER_NEXT.md` (`NOTIF-1` à `NOTIF-4`). Les migrations V37, V39 et V40 citent encore l'ancien chemin `docs/plans/…` : une migration appliquée ne se modifie pas |
| [`2026-10-05-weather.md`](2026-10-05-weather.md) | Météo Open-Meteo des sorties puis des voyages : cache global en Postgres, calculs côté backend, résumé de liste, détail, écran « Météo du parcours » mobile | **Exécuté** le 6 octobre 2026 — sorties en `10.9.0` (`API-74`, `WEB-60`, `MOB-51`, `BRAND-4`), étapes de voyage en `10.11.0` (`API-76`, `WEB-67`, `MOB-57`), cartes de voyage en `10.13.0` (`API-82`). Restent dans `LEDGER_NEXT.md` : Karoo/Garmin (`API-77`), `computeRideStartInstant` (`API-78`), recettes et production des sorties (`WEB-61`, `MOB-52`, `OPS-29`). `V61__weather_cache.sql` cite encore l'ancien chemin `docs/plans/…` : une migration appliquée ne se modifie pas |
| [`2026-10-06-team-agenda.md`](2026-10-06-team-agenda.md) | La page d'équipe découpée par temporalité : fin stockée d'une sortie et filtre `when`, tableau de bord ouvert aux visiteurs, Agenda (sorties et voyages, « À venir / Je participe / Passées », vue Calendrier aux membres) et Publications à la place du fil, un seul sélecteur de vue, icônes de section de la charte | **Exécuté** le 6 octobre 2026 — `API-85` (`10.15.0`), `API-86` (`10.16.0`, relecture sécurité passée), `WEB-69`, `WEB-68`, `MOB-60` et `BRAND-6` dans `LEDGER_DONE.md`. Restes dans `LEDGER_NEXT.md` : `API-87` (suppression d'un parcours), `API-88` (fenêtre du calendrier sur la fin), `MOB-61` (recherche et tags des anciennes adresses dans l'app) ; le déploiement à chaud est accepté (`API-89`, « Délibérément dehors »). Aucun test backend ni e2e n'avait tourné à l'archivage |
| [`2026-10-06-event-timezones.md`](2026-10-06-event-timezones.md) | Fuseau horaire des événements : fuseau d'équipe obligatoire, fuseau de saisie résolu par le backend (lieu → parcours → étape précédente → équipe), saisie en heure murale, rendez-vous lus dans le fuseau de l'entité avec la mention « chez vous », départ d'un groupe en instant (`start_at`) | **Exécuté** du 6 au 7 octobre 2026, lots 0 à 7, contrats `10.17.0` → `11.0.0` — `API-60` dans `LEDGER_DONE.md`. Écart : la suppression de `ride_groups.time` prévue en N+1 a pris deux versions de plus (lot 6 : plus mappée ; lot 7 : supprimée), une version qui mappe une colonne cassant si elle disparaît pendant qu'elle tourne. `V64__event_timezones.sql` cite encore l'ancien chemin `docs/plans/…` : une migration appliquée ne se modifie pas |
| [`2026-10-17-altitude-hd-asynchrone.md`](2026-10-17-altitude-hd-asynchrone.md) | Altitude rapide (Mapterhorn) à l'enregistrement et dans le planificateur, rattrapage HD (IGN LiDAR) en arrière-plan avec debounce, parcours et aperçus de l'outil GPX ; tests backend hors réseau | **Livré** le 17 octobre 2026, API 11.8.0, `V74` — `API-131` et `WEB-102` dans `LEDGER_DONE.md` ; reste `MOB-76` dans `LEDGER_NEXT.md` |

## Les invariants vérifiés du plan mobile

Ce sont les `grep` que le plan lui-même impose en revue. Ils passaient tous le 27 juillet 2026 ;
les relancer avant de conclure qu'un écran a le droit de faire autrement.

```bash
cd mobile
grep -rn --include='*.dart' "api/generated" lib/core/pdl   # vide — la bibliothèque ignore les DTO
grep -rn --include='*.dart' '\bIcons\.'     lib/core/pdl   # vide — tout passe par PdlIcons
grep -rln "showModalBottomSheet" lib                       # seul pdl_sheet.dart (le reste = commentaires)
grep -rn "TODO\|FIXME" --include='*.dart' lib | grep -v generated   # vide
grep -rnE '0xFF[0-9A-Fa-f]{6}' lib/features                # vide — aucun littéral de couleur
grep -rn "TeamShell" lib                                   # seuls des commentaires historiques
```

## Ce qui n'est *pas* archivé

[`../2026-02-14-project-audit.md`](../2026-02-14-project-audit.md) reste dans `docs/plans/` : son
plan d'action a encore des lignes ouvertes, suivies sous le préfixe `AUD` de `LEDGER_NEXT.md`. Ses statuts ont été rafraîchis en partie le 29
septembre 2026 ; les backups, notamment, existent. La sécurité applicative est suivie à part, sous le préfixe `SEC`
du ledger ; l'audit de septembre 2026 qui l'a ouverte est archivé ici.

Le plan de [migration biketeam en direct](../2026-09-22-biketeam-live-migration.md) reste aussi dans
`docs/plans/` : c'est le contrat en vigueur avec biketeam, jusqu'à la mise en production et l'arrêt
de biketeam (`LEDGER_NEXT.md`, préfixe `MIG`).

[`audit-ux/`](audit-ux/) est l'**entrant** de design (brief, analyse page par page, descriptifs
des captures) et documente l'état d'avant la v2 ; il ne décrit pas le code actuel. Sa charte et sa
feuille de style, toujours de référence, vivent dans [`../../BRANDING.md`](../../BRANDING.md) et
[`../../pedalons.css`](../../pedalons.css).
