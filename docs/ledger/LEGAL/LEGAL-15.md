---
id: LEGAL-15
title: "Textes légaux élagués du verbiage et des redites"
status: done
done: 2026-09-29
---

## Livré

`LEGAL-15` **Textes légaux élagués du verbiage et des redites** (2026-09-29) — audit par
section de `privacy/*.md` (14 agents, 116 remarques), puis réécriture en parité FR/EN. Chaque
information a désormais **un seul endroit** : le stockage du navigateur est dans le tableau du §8
(le §1 y renvoie), les durées au §6 (le nettoyage nocturne et les 30 jours de sauvegarde n'y
sont dits qu'une fois), la visibilité de la liste des membres au §4, la suppression d'un compte
au §7 (les CGU §9 y renvoient) ; le §9 Sécurité ne redit plus le §1 ni le §6, le §5 ne donne
plus que pays et garantie de chaque transfert. Retirés : les noms de logiciels et d'en-têtes
(HttpOnly, Cache-Control, SameSite, AAGUID, Keystore, imgproxy, Valhalla…), les allusions à
l'historique (« avant ce changement »), la liste des notifications dans les CGU. Corrigé au
passage : la politique disait qu'un contenu signalé « peut être masqué », il l'est à partir de
trois signaleurs (`ReportService.AUTO_HIDE_REPORTERS`), comme le disaient les CGU. À ne pas
défaire : les mentions de l'art. 13 RGPD, les engagements vérifiables (zone d'~1 km des
annonces, clé privée qui ne quitte pas l'appareil, secrets hachés et leurs deux exceptions)
restent. Pas de test (texte).
