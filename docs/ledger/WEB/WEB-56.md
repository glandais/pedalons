---
id: WEB-56
title: "Profil refondu (`WEB-55`, `WEB-57`) : recette navigateur"
status: open
size: "S"
verified: 2026-11-16
---

## Reste à faire

`WEB-56` **Profil refondu (`WEB-55`, `WEB-57`) : ce qui reste de la recette navigateur (S)** — vus le 16 novembre
2026 sur staging (`3b8a0b80`, Chrome, compte administrateur) et conformes : la mise en page des dix écrans, la bascule
liste puis détail sous le point de rupture `md` (980 px et 606 px), le mode sombre, la bordure `danger-outline` de la
zone de danger en sombre (`1px solid rgb(255, 135, 135)`), Personnes bloquées sous Confidentialité. **Restent deux
points que staging ne permet pas de voir** : la cible de 44 px des cases de notifications au téléphone (staging
n'annonce aucun canal, la matrice type × canal n'y est pas rendue : à voir sur une pile qui liste `EMAIL` ou `PUSH`,
au doigt) ; et Préférences avec un fuseau non enregistré, qui montre celui du navigateur (`WEB-54`) — il faut un
compte neuf. Les mineurs relevés au passage sont dans `WEB-98` ; les renvois imprécis des textes légaux relèvent de
la section `LEGAL`.

## Livré

### `WEB-56` Profil refondu : les e2e passés (constaté le 16 octobre 2026, contrat inchangé)

`WEB-56` **Les e2e du profil refondu (`WEB-55`) et du lexique commun (`WEB-57`), écrits le
4 octobre 2026 sans être lancés, sont passés** — constaté à la relecture du ledger du 16 octobre
2026 : toute la suite Playwright est verte, sur les deux projets, et la prod tourne sur
`ac130fc5`. Specs concernées : `profile-navigation` (bascule bureau / téléphone en CSS,
`aria-current`, fil d'Ariane masqué sous `sm`, nouvelle URL des bloqués
`/profil/vie-privee/bloques`), `flow-account` (libellés « Adresse e-mail », « Nom affiché »,
« Clé d'accès »), `routes-render` (les dix routes du profil et l'audit de préchargement),
`ssr-session`, `auth`, `flow-moderation`, `flow-device`, `flow-notifications`, `pwa`,
`invitations`, `flow-platform-admin`, `ad-contact`. **À ne pas défaire** : « Adresse e-mail »
reste unique sur la connexion, l'inscription et l'inscription bêta (Playwright compare `name` en
sous-chaîne insensible à la casse) ; les états d'un compte neuf que suppose `profile-navigation`
(« Métrique », « Aucun service ni appareil », « Aucune clé d'accès ») sont à ajuster avec la spec
si le backend change ses défauts. La recette à l'œil (mise en page, `md`, mode sombre, cible des
cases sur téléphone, fuseau non enregistré) reste ouverte sous le même identifiant.
