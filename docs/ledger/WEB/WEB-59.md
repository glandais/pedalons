---
id: WEB-59
title: "« Lien invalide » sur un changement d'adresse pourtant appliqué"
status: done
group: "Défauts d'interface"
done: 2026-10-04
---

## Livré

`WEB-59` **« Lien invalide » sur un changement d'adresse pourtant appliqué** (2026-10-04) —
`VerifyEmailPage` confirmait le changement, puis relisait `/me` avec le jeton d'accès en mémoire.
Ce jeton porte l'ancienne adresse, que le backend ne résout plus (`API-73`) : un 403, que
l'intercepteur ne rafraîchit pas (il ne réagit qu'aux 401), tombait dans le `catch` de la
confirmation et affichait l'erreur. Le changement d'adresse est maintenant affiché dès la
confirmation, puis la session est renouvelée par `refresh` (nouveau jeton et nouvel utilisateur),
dont un échec n'est plus montré. Constaté en prod le 4 octobre 2026. Pas de test : aucun parcours
e2e ne couvre le changement d'adresse. **À ne pas défaire** : rien après `confirmEmailChange`
ne doit pouvoir faire basculer la page en erreur, le lien étant déjà consommé.
