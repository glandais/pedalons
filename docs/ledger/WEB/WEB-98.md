---
id: WEB-98
title: "Deux clés i18n mortes et un e-mail qui nomme un réglage sans lien"
status: open
size: "XS"
verified: 2026-11-16
---

## Reste à faire

`WEB-98` **Deux clés i18n mortes et un e-mail qui nomme un réglage sans lien (XS)** —
`auth.login.tabs.passkey` et `auth.passkey.login` ne servent plus nulle part dans
`frontend/src` (`frontend/src/locales/{fr,en}/common.json` ;
le mobile a son propre catalogue) : les supprimer des deux langues. L'e-mail de contact d'une
annonce (`backend/src/main/resources/templates/mail/ad-contact.{fr,en}.{txt,html}`) dit
« désactivez « Accepter les messages des membres » dans Profil › Confidentialité » sans lien, le
gabarit ne recevant que `params.adUrl` : passer l'URL absolue de `/profile/privacy` (sur le
domaine de l'équipe, comme `adUrl`) et en faire un lien dans la version HTML.
