---
id: MOB-49
title: "Tests Patrol du profil refondu lancés"
status: done
group: "Profil"
done: 2026-10-06
---

## Livré

`MOB-49` **Tests Patrol du profil refondu lancés** (6 octobre 2026) — les dix-sept tests que
`MOB-48` et `WEB-57` touchent (`notification_settings_test`, `profile_timezone_test`,
`profile_preferences_test`, `profile_data_export_test`, `profile_logout_all_test`,
`profile_paired_devices_test`, `profile_participations_count_test`,
`profile_participations_list_test`, `account_deletion_test`, `expired_access_token_test`,
`notification_mute_test`, `block_user_test`, `report_problem_test`, `apps_beta_signup_test`,
`login_with_password_test`, `sign_up_verify_test`, `password_reset_test`) sont verts dans la
suite Patrol iOS complète (63/63 à `c3532d63`, pile e2e remise à zéro, iPhone 17 Pro Max), et
de nouveau le 7 octobre à `86788c92` (les deux échecs de ce run, `calendar_test` et
`user_timezone_test`, sont hors du profil).
`profile_paired_devices_test` attendait la ligne d'un appareil par `scrolledTo`, qui touche son
centre : seule la croix « délier » y prend les touchers, il passe par `scrolledIntoView`
(`7efc822c`) — l'app n'était pas en cause. La recette sur appareil et les finitions restent en
`MOB-62`. **À ne pas défaire** : une ligne sans centre touchable s'attend par `scrolledIntoView`,
pas par `scrolledTo`.
