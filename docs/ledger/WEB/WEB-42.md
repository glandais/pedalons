---
id: WEB-42
title: "Accueil visiteur, accueil membre, formulaire de connexion partagé"
status: done
group: "Accueil et page Fonctionnalités"
done: 2026-10-03
---

## Livré

`WEB-42` **Accueil visiteur, accueil membre, formulaire de connexion partagé** (3 octobre 2026,
**API 10.6.0**, revue du 4 octobre intégrée). `HomePage` rend une version visiteur ou membre selon
l'authentification ; le SSR anonyme rend la version visiteur. Visiteur : héros (pitch et
formulaire, puis « Découvrir les fonctionnalités » sur téléphone), tuiles vers `/fonctionnalites`,
fil public, bandeau des compteurs (Karoo, Garmin, Wahoo, téléphone), bandeau « créer une équipe »
masqué en mono-équipe. Membre : salutation datée et résumé de la semaine, actions rapides pour
organisateurs et admins seulement (sélecteur d'équipe s'il y en a plusieurs), `NextRideCard`
refaite (section titrée, `registeredGroup`, menu « Envoyer vers l'appareil », états chargement,
erreur et vide sous le même h2), `WeekAgenda` (`GET /api/calendar/events`, maintenant aligné sur
l'heure → +7 jours, sans la prochaine sortie dans ses lignes), `MyTeamsCard`
(`GET /api/teams?minRole=MEMBER&size=20`, ligne d'activité depuis `upcomingRideCount`,
`upcomingTripCount`, `recentPostCount` — `API-66`), puis le fil (`HomeFeedSection`, région titrée,
filtre de type en puces `radiogroup` « Type ») et une carte promo des fonctionnalités. Le
formulaire est extrait dans `components/auth/LoginForm.tsx` (avec `OtpLogin`) : `afterSignIn`
`'redirect'` (LoginPage, `?next=` et `from`) ou `'stay'` (héros), étape pilotable par
`mode`/`onModeChange`, `initialMode` (LoginPage lit `mode: 'register'` ou `?mode=register`). Le
prefetch SSR de `homeFeedData.ts` ajoute événements, équipes et services GPS pour une requête
connectée. Tests : `LoginForm.test.tsx`, `HomePage.test.tsx`, `memberHome.test.tsx`, e2e
`rides.e2e.ts` (« Aucune sortie à venir »). **À ne pas défaire** : la logique de connexion est
partagée, jamais dupliquée ; le titre de `NextRideCard` reste enfant direct du corps de carte (les
e2e lisent la carte par son parent) ; le lien de l'agenda s'appelle « Voir le calendrier » (pas de
collision avec l'onglet « Calendrier ») ; les locators e2e du fil passent par `homeFeed(page)` ; la
fenêtre de semaine part de `hourAlignedNowIso` pour que les clés de requête SSR et client
coïncident ; les parcours prennent la couleur neutre `primary`, pas de couleur métier locale.
