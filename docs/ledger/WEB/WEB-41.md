---
id: WEB-41
title: "Services connectés et appareils appairés, deux sections distinctes"
status: done
group: "Profil"
done: 2026-10-03
---

## Livré

`WEB-41` **Services connectés et appareils appairés, deux sections distinctes** (3 octobre 2026,
site et app mobile, sans changement de contrat). Le profil titrait « Appareils GPS » la liste des
*services* OAuth (Hammerhead, Garmin Connect, Wahoo), et le site y glissait « Appareils appairés »
en simple sous-titre : on lisait une seule section, avec les mêmes logos des deux côtés. Les deux
clients disent désormais **« Services connectés »** (des comptes où « Envoyer vers l'appareil »
dépose le parcours) et **« Appareils appairés »** (les Karoo et Garmin où l'app Pédalons est liée
par un code), chacun avec sa phrase d'explication ; sur le site, deux titres de même niveau
séparés par un `Divider` (`UserProfilePage`, `PairedDevicesManager`), sur mobile la phrase
`profile.devices.hint` dans `PairedDevicesCard`. Tests : `PairedDevicesManager.test.tsx` (titre et
description) et `paired_devices_card_test.dart` (la phrase). **À ne pas défaire** : un service
OAuth n'est jamais appelé « appareil » (titre, confirmation de déconnexion, aide).
