---
id: LEGAL-21
title: "L'envoi automatique des parcours aux services GPS dans la politique"
status: done
done: 2026-10-16
---

## Livré

`LEGAL-21` **L'envoi automatique des parcours aux services GPS dans la politique** (2026-10-16,
contrat inchangé) — `API-120` envoyait déjà, en prod, le tracé et le nom des sorties où un membre
est inscrit à Hammerhead, Wahoo ou Garmin, alors que la politique disait « uniquement lorsque vous
choisissez d'envoyer un itinéraire ». En parité FR/EN : la section des services GPS distingue
l'envoi à la demande (qui reste chez le service) de l'envoi automatique — désactivé par défaut,
réglé service par service, sorties inscrites partant dans les 7 jours, nom « date · groupe ·
itinéraire », mis à jour si l'itinéraire change, retiré 24 h après le départ, à la désinscription
ou à l'annulation, à la désactivation, à la déconnexion et à l'effacement du compte — et déclare
le suivi des envois (identifiant chez le service, empreinte, dates) ; la base légale (consentement :
l'activation, retirable), la ligne Hammerhead / Garmin / Wahoo des destinataires, les transferts
hors UE (article 49.1.b) et une ligne de conservation du suivi suivent. Datée du 16 octobre 2026.
Pas de test automatisé (texte) ; l'app mobile embarque le texte comme asset, il n'y paraît qu'à la
build suivante. Les formulaires des stores ne changent pas : l'envoi part du serveur, aucun
fichier ne quitte l'appareil (`mobile/store-metadata/data-safety.md`, point 8). Pas d'e-mail aux
membres : l'envoi automatique est un opt-in, rien ne change pour qui ne l'active pas. **À ne pas
défaire** : toute évolution de ce qui part chez un service GPS (fenêtre, nom, données Wahoo,
nouveau service) se relit d'abord contre cette section.
