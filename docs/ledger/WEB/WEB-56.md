---
id: WEB-56
title: "Profil refondu (`WEB-55`, `WEB-57`) : recette navigateur"
status: open
size: "S"
verified: 2026-11-16
---

## Reste à faire

`WEB-56` **Profil refondu (`WEB-55`, `WEB-57`) : recette navigateur (S)** — les e2e sont
passés (voir la part livrée sous le même identifiant). Plus rien à trancher : Utilisateurs
bloqués est sous Confidentialité (`/profil/vie-privee/bloques`), la zone de danger suit le
jeton `danger` et les cases des notifications ont leur cible de 44 px sur téléphone
(`WEB-55`). Reste la **recette à l'œil** : mise en page, point de rupture `md`, mode sombre (la
bordure `danger-outline` de la zone de danger y compris) ; sur un téléphone, une touche
n'importe où dans la cellule coche la case des notifications (le `<label>` enveloppe le `div`
racine du `Checkbox` Mantine : HTML pas strictement valide, toléré par les navigateurs). Avec
un fuseau non enregistré, Préférences montre celui du navigateur, que le serveur ne connaît
pas (`WEB-54`). Les mineurs relevés au passage sont sortis dans `WEB-98` ; les renvois
imprécis des textes légaux (« depuis votre profil ») relèvent de la section `LEGAL`.

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
