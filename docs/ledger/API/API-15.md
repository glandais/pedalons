---
id: API-15
title: "Fuseau des dates : celui de l'utilisateur, sinon l'appareil, sur le mobile aussi"
status: done
group: "Petites évolutions d'API"
done: 2026-10-02
---

## Livré

| ID | Livré | Écrans |
|---|---|---|
| `API-15` | **Fuseau des dates : celui de l'utilisateur, sinon l'appareil, sur le mobile aussi** (2026-10-02) — sans changement de contrat. **Tranché avec le propriétaire : pas de `Team.timezone` ni de dates zonées au contrat** (`API-60`). **Décision revue le 6 octobre 2026** : `API-60` est rouvert pour les heures de rendez-vous (départs de sortie, de groupe, d'étape), lues dans le fuseau de l'événement ; la préférence et `toDisplayTime` restent la règle pour tout le reste, et la règle « pas de `.toLocal()` » tient toujours. Le mobile applique désormais `UserDto.timezone` comme le web (`useEffectiveTimezone`) : `app.dart` le passe à `AppFormatters.setDisplayTimezone`, et tout instant du contrat est ramené par `AppFormatters.toDisplayTime` / `tryParseDisplayTime` — les 23 `.toLocal()` des écrans y passent. La valeur rendue est une **heure murale** (un `DateTime` local portant les champs du fuseau choisi) : les regroupements par jour et `DateFormat` restent justes sans connaître `package:timezone`, mais elle ne se compare pas à un instant — « passé » vient du serveur (`API-16`). « Maintenant » se prend par `displayNow()` (le calendrier), et les bornes de mois envoyées à l'API repassent par `displayWallClockToUtc`. `package:timezone` redevient une dépendance directe, sans coût de taille : `flutter_local_notifications` l'embarquait déjà ; la base n'est chargée qu'au premier fuseau posé. Un nom inconnu de la base embarquée retombe sur l'appareil. À ne pas défaire : pas de `.toLocal()` ni de `DateTime.now()` comparé à une date convertie (règle dans `mobile/CLAUDE.md`). Tests : `display_timezone_test.dart` (l'étape du lundi à Auckland reste un lundi, dimanche à Los Angeles ; pas de double conversion ; bornes de mois ; repli sur l'appareil), Patrol `user_timezone_test` (**écrit, non lancé** : une étape à 08:00 d'Auckland lue « 08:00 » par un membre réglé sur `Pacific/Auckland`) | 22, 24, 25 |
