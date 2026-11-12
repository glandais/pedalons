# Audit d'homogénéité des listes et de leurs filtres — app mobile ↔ site (2026-11-12)

Suite de l'[audit des cartes](../audit-cartes/README.md), avec la même [méthode](../audit-cartes/METHODE.md). Le
contenu des cartes est réglé (`maquettes/KIT.md` §9) ; cet audit porte sur ce qui les entoure : barre d'outils, filtres,
tri, recherche, bascule de vue, pagination, compteur, états vides, chargement, erreur.

Lecture du code seulement. **Rien n'a été vérifié à l'écran.**

## Périmètre

Treize listes présentes des deux côtés : fil d'accueil, fil d'une équipe, agenda d'une équipe, calendrier, parcours
d'une équipe, tous les parcours et leur carte, annonces, mes équipes et découverte, membres d'une équipe, personnes
inscrites, notifications, modèles de sortie, personnes bloquées. Les commentaires ont été ajoutés par l'axe du tri.

Hors périmètre : l'administration de la plateforme (site seulement). Les listes de gestion propres au site (lieux,
tags, signalements, pages, administration des membres, « Mes aperçus GPX ») ne sont citées que pour les incohérences
internes au site.

Sur le site, `TeamDirectoryPage.tsx` est l'annuaire des membres d'une équipe ; la découverte d'équipes est
`TeamListPage.tsx` ; `TeamMembersPage.tsx` est l'administration des membres.

## Fichiers

| Fichier | Axe | Lignes | Écarts forts |
|---|---|---|---|
| [filtres.md](filtres.md) | Critères, valeurs, défauts, libellés, réinitialisation, persistance | F1–F58 | 9 |
| [tri-recherche.md](tri-recherche.md) | Ordre par défaut, options de tri, recherche, pagination, compteur, sections | T1–T63 | 3 |
| [structure.md](structure.md) | Titre, barre d'outils, bascule de vue, densité, création, navigation | S1–S90 | 7 |
| [etats.md](etats.md) | Vide, vide filtré, hors plage, chargement, erreur, accès refusé, rafraîchissement | E1–E89 | 14 |
| [tri.md](tri.md) | Étape 1 de la méthode : défauts, règles à décider, écarts voulus | — | — |

## Ce qui ressort

- **Ce qu'une liste montre à l'ouverture diffère.** Tous les parcours : sans rôle minimum dans l'app, « Membre » sur le
  site (F20). Découvrir des équipes : par nombre de membres dans l'app, par nom sur le site (T40). Commentaires : le plus
  ancien d'abord dans l'app, le plus récent sur le site (T62).
- **Des critères d'un seul côté**, que l'API permet presque toujours : période du fil d'accueil (site), proximité des
  parcours (app), prix des annonces (site), « Ouvertes à l'adhésion » (app), filtres du calendrier global (app).
- **Le site n'a pas d'état d'erreur sur neuf listes** : une panne s'y lit comme une liste vide (E84, relu au tri : DL11).
- **L'app confond vide et vide filtré** : les parcours n'ont pas d'état vide simple (E35) ; le fil et l'agenda ne comptent
  que la recherche comme filtre (E11, E24).
- **« Mes équipes » de l'app est coupée à 20** sans le dire (T42).
- **Créer depuis une liste** : bouton d'en-tête sur le site, absent de l'app pour l'agenda, les publications, les annonces
  et les équipes (S15, S24, S49, S56).
- **Bascule de vue et place de la recherche** de formes différentes (S19, S20, S37, S38).

## État d'avancement

| Étape | État |
|---|---|
| Audit (quatre axes) | Fait le 12 novembre 2026 |
| 1. Tri | Proposé le 12 novembre 2026 : 22 défauts, 14 règles (9 avec planche), 15 écarts voulus. Cinq règles décidées sans planche le même jour (RL1, RL5, RL7, RL12 ; RL14 reclassée en défauts), RL15 ajoutée sur demande |
| Lot 0, les défauts | Fait le 12 novembre 2026 (`MOB-145`, `WEB-174`, `API-184`, contrat 14.7.0) ; DL23 et DL24 restent (`WEB-175`, `MOB-143`). Rien vu à l'écran |
| 2. Galeries de listes | Cahier écrit ([galerie.md](galerie.md)) ; galeries à construire |
| 3. Planches avant / cible | À faire |
| 4. Décisions | À faire |
| 5. Lots | À faire |
| 6. Vérification contre la cible | À faire |
