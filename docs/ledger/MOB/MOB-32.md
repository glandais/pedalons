---
id: MOB-32
title: "Réglages du profil"
status: done
group: "Couverture e2e Patrol"
done: 2026-09-29
---

## Livré

`MOB-32` **Réglages du profil** (29 septembre 2026) — le nom affiché s'enregistre ; unités
impériales (l'exemple chiffré passe en milles), thème sombre (l'app se redessine en sombre),
« Être contacté par les membres » coupé et langue anglaise (la ligne dit « English »), puis
retour au français : tout arrive sur `/api/users/me`, et l'interrupteur coupé fait refuser le
relais d'annonce `AD_CONTACT_OPTED_OUT`. L'export de données : « Jamais demandé », « Demander
un export » → « En préparation… », le mail du scheduler porte le lien de téléchargement, et le
profil rouvert dit « Prêt » (l'API `READY`) — `profile_preferences_test.dart`, `profile_data_export_test.dart`.
« Déconnecter tous les appareils » ramène à la connexion, refuse le refresh token de cet
appareil et celui d'un autre, et le mot de passe connecte toujours —
`profile_logout_all_test.dart`. Trois défauts trouvés en chemin et corrigés le même jour : un export `READY` restait « En préparation… » (le
code attendait un statut `COMPLETED` absent du contrat, 8ef911d0) ; `logout-all` partait sans jeton et
ne révoquait rien (1dab921c) ; les appels authentifiés sous `/api/auth/` (`getMe`,
gestion des clés d'accès, `logout-all`) ne rafraîchissaient pas un jeton expiré (08aa46ef). *Non couvert : l'avatar (sélecteur de photos natif du
système) ; les services GPS connectés (OAuth Strava/Garmin hors stack) ; le téléchargement de
l'archive (lien du mail, pas de bouton dans l'app).*
