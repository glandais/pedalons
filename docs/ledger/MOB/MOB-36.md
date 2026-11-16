---
id: MOB-36
title: "Écrans périphériques"
status: done
group: "Couverture e2e Patrol"
done: 2026-09-29
---

## Livré

`MOB-36` **Écrans périphériques** (29 septembre 2026) — la page Applications, ouverte depuis le
profil, refuse une adresse mal formée (« Email invalide ») et enregistre l'inscription à la
bêta (« Inscription enregistrée ») ; la même adresse en capitales répond pareil et la liste
d'administration ne la compte qu'une fois. Déconnecté, depuis le formulaire d'inscription,
« Confidentialité » et « Lire les conditions » ouvrent leur texte et le retour ramène au
formulaire. « Signaler un problème » garde « Envoyer » désactivé sous 10 caractères, envoie
une suggestion (`POST /api/feedback`), se ferme et remercie. Sans `PUSH` dans les canaux du
serveur, la boîte de réception ne montre aucun bandeau d'activation —
`apps_beta_signup_test.dart`, `legal_pages_test.dart`, `report_problem_test.dart`,
`push_banner_absent_test.dart`. *Non couvert : le bandeau d'activation du push dans ses états
`notDetermined` → dialogue système → `granted`, et `denied`. Il faudrait une stack e2e qui
pousse (compte de service FCM, `PEDALONS_PUSH_ENABLED=true`) et des APNs sur le simulateur.
Le signalement n'est vérifié que par le 204 et l'interface : aucune API ne relit un
signalement (il part en issue GitHub). Le bouton « Télécharger l'APK » ouvre un lien externe
et n'est pas suivi.*
