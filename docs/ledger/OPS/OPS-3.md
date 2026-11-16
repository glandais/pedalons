---
id: OPS-3
title: "Le relais de contact en production : regarder un message reçu"
status: open
group: "Recette du backend en conditions réelles"
verified: 2026-11-16
---

## Reste à faire

`OPS-3` **Le relais de contact en production : regarder un message reçu** — les gabarits
`ad-contact.{fr,en}` sont rendus par le backend (`templates/mail/`) et partent par le relais
SMTP de Scaleway TEM comme tout le reste. L'envoi par TEM est constaté le 16 octobre 2026 :
11 contacts d'annonce en base depuis la bascule du 22 septembre, tous du 4 octobre,
aucune erreur du mailer dans les journaux de prod sur sept jours. Relu le 16 novembre 2026 :
toujours ces 11 lignes dans `ad_contacts`, aucune depuis, et toujours aucune erreur du mailer
sur sept jours. **Reste** : un envoi réel
vers une boîte du propriétaire, pour lire les en-têtes et le corps — le `Reply-To` doit porter
l'adresse de l'auteur et le corps ne doit jamais l'imprimer. Se fait dans la même séance
qu'`OPS-4`. Taille : XS.
