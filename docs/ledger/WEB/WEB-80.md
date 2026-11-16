---
id: WEB-80
title: "Zoom du profil et de la carte plein écran synchronisés dans les deux sens"
status: done
group: "Défauts d'interface"
---

## Livré

`WEB-80` **Zoom du profil et de la carte plein écran synchronisés dans les deux sens** (13 octobre
2026, contrat inchangé) — constaté en production sur `/carte` d'un parcours : la molette, le
pincement et le glisser du profil ne faisaient rien, donc le profil ne pilotait jamais la carte.
Depuis le SSR (`e8a50db6`), `chartjs-plugin-zoom` se charge après le montage (`useZoomPlugin`),
or `react-chartjs-2` ne transmet `plugins` à Chart.js qu'à la création du graphique : l'instance
ne portait que `crosshair`. `<Line>` prend maintenant une `key` qui change quand le plugin arrive
(`ElevationChart.tsx`), et le remontage garde la plage, tenue dans l'état du composant. Dans le
même passage, `useMapChartZoomSync` :
- **Verrou** : le `fitBounds` induit par le profil porte `{ chartSync: <id> }` en `eventData`
  (MapLibre le recopie sur `moveend`, react-map-gl transmet l'événement). Ce `moveend` n'est
  jamais renvoyé au profil, et seul le dernier mouvement induit lève le verrou. Avant, un minuteur
  de 400 ms pour une animation de 300 ms renvoyait le `moveend` au profil dès qu'une image lente
  (relief 3D) le retardait : le zoom sautait vers l'extérieur. Un mouvement de l'utilisateur pendant
  l'animation pilote désormais le profil ; un minuteur de 1,5 s ne reste qu'en secours.
- **Bords** (`components/route/trackDistanceRange.ts`) : carte → profil coupe les segments aux
  bords de la vue (Liang–Barsky) au lieu de s'arrêter au dernier sommet visible ; profil → carte
  interpole un point au début et à la fin de la fenêtre. La trace étant simplifiée
  (Douglas-Peucker), deux sommets peuvent être distants de près d'un kilomètre.

Couvert par `ElevationChart.test.tsx` (le graphique est créé avec `zoom` ; échoue sans la `key`),
`useMapChartZoomSync.test.ts` (moveend induit tardif, mouvement interrompu, mouvement de
l'utilisateur, minuteur de secours) et `trackDistanceRange.test.ts`. Vérifié dans Chrome sur
NP#676 GRVL. **À ne pas défaire** : un plugin Chart.js chargé après le montage impose de recréer
le graphique ; un mouvement induit se reconnaît à son `eventData`, jamais à un délai.
