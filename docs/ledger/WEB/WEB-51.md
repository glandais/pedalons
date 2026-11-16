---
id: WEB-51
title: "La carte « Envoyez vos parcours vers votre compteur » de l'accueil ne s'adresse plus qu'à qui n'a rien branché, et mène au profil"
status: done
group: "Défauts d'interface"
done: 2026-10-04
---

## Livré

`WEB-51` **La carte « Envoyez vos parcours vers votre compteur » de l'accueil ne s'adresse plus
qu'à qui n'a rien branché, et mène au profil** (4 octobre 2026, relevé dans `docs/BUGS.md`) —
`FeaturesPromoCard` s'affichait à tous les membres et menait à la page Fonctionnalités. Elle ne
s'affiche plus que sans service GPS connecté (`UserDto.connectedServices`) **ni** appareil appairé
(`GET /api/users/me/devices`, masquée tant qu'il charge pour ne pas clignoter chez ceux qui en
ont), et mène aux services GPS du profil — d'abord par l'ancre `/profil#gps`, depuis le 4 octobre
2026 à la page `/profil/appareils` (`WEB-55`, l'ancre et `profileAnchors.ts` sont supprimés). Texte (`home.member.promo.text`) réécrit pour dire où se
fait le branchement. Pas d'équivalent mobile à aligner. Non vérifié à l'écran (pas de session
connectée pendant la correction).
