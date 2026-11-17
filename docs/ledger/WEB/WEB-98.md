---
id: WEB-98
title: "Deux clés i18n mortes et un e-mail qui nomme un réglage sans lien"
status: done
size: "XS"
done: 2026-11-17
---

## Livré

`WEB-98` **Deux clés i18n mortes et un e-mail qui nomme un réglage sans lien (XS)** — les clés
`auth.login.tabs.passkey` et `auth.passkey.login`, que plus rien n'utilisait dans `frontend/src`, ont
été retirées de `frontend/src/locales/{fr,en}/common.json`. L'e-mail de contact d'une annonce
(`ad-contact.{fr,en}.{txt,html}`) reçoit désormais `params.privacyUrl`, l'URL absolue de
`/profile/privacy` sur le domaine de l'équipe, construite par `AdContactEmailService` comme `adUrl`
(chemin anglais canonique, que les deux routeurs résolvent dans les deux langues) : la version HTML
fait de « Profil › Confidentialité » un lien, la version texte donne l'URL à sa suite. Pas de
changement de contrat. Couvert par `AdContactResourceTest#contact_asAnotherMember_relaysToAuthorWithReplyToSender`
(l'URL dans le texte, le lien dans le HTML) et `EmailServiceTest` (rendu de tous les gabarits).
