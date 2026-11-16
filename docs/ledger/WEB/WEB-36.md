---
id: WEB-36
title: "Un tap juste après l'affichage d'une page, sous charge, est ignoré"
status: open
size: "M"
verified: 2026-11-16
---

## Reste à faire

`WEB-36` **Un tap juste après l'affichage d'une page, sous charge, est ignoré (M)** — le HTML
du SSR est à l'écran et cliquable avant que React l'ait adopté ; avec l'hydratation
concurrente de React 19, un clic qui tombe pendant le rendu d'hydratation, avant son commit,
n'atteint pas son gestionnaire et **n'est pas rejoué** (mesuré par la sonde de `WEB-35` : 3 clics
sur 40 dans les premières centaines de millisecondes, pile e2e chargée, sur le burger de
`Layout.tsx`). Rien ne se passe, sans message : l'utilisateur retape. `WEB-35` ne corrige que
les tests (ils attendent le commit). Pistes : capturer les clics sur `document` entre
l'affichage et `HydrationMarker` puis les rejouer sur leur cible au commit (attention aux
doubles déclenchements et aux liens, que le navigateur suit déjà sans JS), ou raccourcir la
fenêtre (hydratation par îlots, moins de travail au premier rendu). Mesurer d'abord sur un
vrai téléphone moyen de gamme, hors pile e2e. La mesure est à refaire après `WEB-95`
(chargement initial de 836 à 406 Ko gzip, sans gain sur le TBT) et `WEB-96` (carte montée en
différé), qui raccourcit justement cette fenêtre. Un rejeu doit rester compatible avec la CSP
(`SEC-31`, `SEC-40`) : nonce, aucun script inline libre.
