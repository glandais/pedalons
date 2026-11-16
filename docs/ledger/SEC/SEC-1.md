---
id: SEC-1
title: "Un fichier téléversé ne s'exécute plus dans l'origine de l'application : H2"
status: done
done: 2026-09-30
---

## Livré

`SEC-1` **Un fichier téléversé ne s'exécute plus dans l'origine de l'application : H2**
(2026-09-30, contrat inchangé, pas de migration) — la route de téléchargement des assets servait
tout fichier `inline`, sous son type d'origine, sans `nosniff` ni CSP, et un SVG ou un XML s'y
rendait en page. Décisions de l'utilisateur : **seuls les images matricielles (PNG, JPEG, GIF,
WebP, AVIF) et le PDF s'ouvrent dans le navigateur**, tout le reste part en
`Content-Disposition: attachment` (avec `filename*` RFC 5987) ; et **le SVG est refusé à
l'envoi**, pas rastérisé. Au service (`UploadedContentHeaders`, appelé par
`AbstractDownloadAssetResource`) : `X-Content-Type-Options: nosniff` partout, CSP
`default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; sandbox` partout sauf sur le PDF
— elle empêche la visionneuse des navigateurs de démarrer, et les scripts d'un PDF tournent dans
cette visionneuse, pas dans l'origine. Les images d'imgproxy (`/images/…`) portent le même
`nosniff` et la même CSP : un SVG stocké avant le correctif y sort nettoyé par imgproxy, et
sandboxé en plus. **Ce volet couvre les fichiers déjà stockés** ; ne pas le retirer au motif que
l'envoi refuse désormais les SVG. À l'envoi : `svg` quitte la liste blanche `IMAGE`, `svg` et
`xml` entrent dans la liste noire `ATTACHMENT`, et `FileTypeDetector` refuse en plus, pour une
image ou une pièce jointe, tout type résolu `image/svg+xml`, `application/xml`, `text/xml`,
`text/html` ou `application/xhtml+xml` — un petit SVG que Magika étiquette `txt` prenait sinon
son type du seul nom de fichier. Seule exception : un **GPX joint** (étiquette `xml`, nom en
`.gpx`), accepté parce que `TrackAttachmentSanitizer` le réécrit intégralement depuis sa trace
(`API-49`) ; ne pas élargir l'exception à d'autres extensions. La moitié SVG d'`API-48` s'en
trouve réglée pour l'avenir, le reste y demeure. Couvert par `UploadedContentHeadersTest`,
`AssetResourceTest.downloadAsset_aGpxIsSavedSandboxed_neverRenderedInPlace` et
`downloadAsset_anSvgStoredBeforeTheFix_isSavedSandboxed`, `FileTypeDetectorTest.ActiveDocuments`
et `FileTypeCategoryTest`.
