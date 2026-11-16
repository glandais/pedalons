---
id: BRAND-7
title: "Libellés français épicènes"
status: done
done: 2026-10-24
---

## Livré

`BRAND-7` **Libellés français épicènes** (2026-10-24, contrat inchangé) — le corpus parlait au
masculin générique (« Vous êtes inscrit », « Êtes-vous sûr ? », « Léa s'est inscrit »,
« participants », « Meneur », « Contacter le vendeur ») et mélangeait trois styles, dont un point
médian isolé (`seo.ride.participants_*`, « averti·e »). Environ 170 clés du web
(`frontend/src/locales/fr/common.json`), 100 du mobile (`mobile/assets/l10n/fr.json`), les
notifications (`texts_fr.properties`), l'e-mail `ad-contact` et le README de l'export de données
sont reformulés de façon épicène : « Vous participez », « Voulez-vous vraiment… ? »,
« Léa a rejoint votre sortie », compteurs en « personnes » / « inscriptions », badge « J'y vais »,
« Capitaine » pour le meneur du groupe, « Répondre à l'annonce », « Personnes bloquées », onglet
d'administration « Comptes ». La règle est écrite dans le `CLAUDE.md` racine et détaillée au §8.4
de [`BRANDING.md`](../../BRANDING.md), dont le lexique (§8.2) prend les nouveaux termes. **À ne pas
défaire** : pas de point médian (badges trop longs, mal lu aux lecteurs d'écran) ; les rôles
gardent leur nom (« Administrateur », « Organisateur ») — une phrase qui décrit un droit cite le
rôle (« Le rôle Organisateur peut… ») plutôt que les personnes. Les pages légales françaises
(`privacy/*.fr.md`) suivent la même règle, sans toucher aux termes juridiques consacrés
(« responsable du traitement », « sous-traitant », « destinataire ») ni à leur date de mise à
jour. Hors périmètre : l'anglais. Tests : assertions alignées dans
les e2e Playwright, les tests Vitest, les tests Flutter et Patrol, et `NotificationTextsTest` ;
`pnpm typecheck`, `pnpm lint`, Vitest (hors `PrivacyPolicyPage.test.tsx`, dont l'asset légal
généré manquait au worktree), `flutter analyze` et `flutter test` passent ; tests backend et e2e
non lancés.
