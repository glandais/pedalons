---
id: WEB-82
title: "Assets du site compressés une fois au build, plus à chaque requête"
status: done
group: "Outillage"
done: 2026-10-14
---

## Livré

`WEB-82` **Assets du site compressés une fois au build, plus à chaque requête** (2026-10-14, sans
changement de contrat) — `server.js` passait tout le statique par `compression()` : `map-vendor`
(1,08 Mo, dont l'ouverture d'un parcours ou d'un voyage attend le chargement) était regzippé à
chaque requête, au niveau 6, en chunked sans `Content-Length`. Fait : `vite-plugin-compression2`
écrit au build client des voisins `.br` (brotli 11) et `.gz` des fichiers de plus de 1 Ko
(`map-vendor` : 234 Ko en brotli, 286 Ko en gzip), et `express-static-gzip` remplace
`express.static` : il indexe ces variantes au démarrage, sert celle qu'accepte le navigateur
(brotli d'abord) avec `Content-Encoding`, `Vary: Accept-Encoding`, `Content-Length` et le type de
l'original, et les mêmes `Cache-Control` qu'avant. Vérifié à la main (`curl` br/gzip/identité,
contenu décompressé identique, 304 sur ETag). **À ne pas défaire** : `compression()` reste, pour
ce qui est rendu par requête (pages SSR, sitemap, llms.txt) ; ne pas recompresser à la volée les
assets hashés. `index.html` (template SSR) et `sw.js` (route `no-cache`) sont exclus du plugin,
et le bundle SSR n'est pas compressé (aucun navigateur ne le télécharge). Reste, hors de ce
ticket : la page attend toujours la carte pour s'afficher au premier chargement.
