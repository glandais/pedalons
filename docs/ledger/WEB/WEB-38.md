---
id: WEB-38
title: "Une réponse de `/me` arrivée après la déconnexion ne rouvre plus la session"
status: done
group: "Défauts d'interface"
done: 2026-09-30
---

## Livré

`WEB-38` **Une réponse de `/me` arrivée après la déconnexion ne rouvre plus la session**
(2026-09-30, contrat inchangé) — `useAuth` recopiait l'utilisateur de `/me` dans le store dès sa
réponse ; un `/me` parti juste avant `logout()` et revenu après remettait
`isAuthenticated: true` sans jeton. Les requêtes de la page partaient alors en 401, le
rafraîchissement échouait (403) et l'intercepteur renvoyait le visiteur, déjà déconnecté, vers
`/login?next=/connexion`. Relevé par `flow-account.e2e.ts` « a deleted passkey… » (mobile,
instable). L'effet ne recopie `/me` que si le store est **encore** authentifié au moment où la
réponse arrive (`useAuthStore.getState()`, pas la valeur du rendu). Pas de test unitaire : le
hook tire `useGetMe`, Mantine et i18n ; la course reste couverte, sans garantie, par ce e2e.
