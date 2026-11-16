---
id: OPS-16
title: "imgproxy : copyright retiré, limite de résolution réelle"
status: done
done: 2026-09-30
---

## Livré

`OPS-16` **imgproxy : copyright retiré, limite de résolution réelle** (2026-09-30) —
`docker-compose.yml` passe `IMGPROXY_KEEP_COPYRIGHT: "false"` (le défaut `true` laissait
`Copyright` et `Artist` dans les images servies des originaux pas encore rattrapés) et
`IMGPROXY_MAX_SRC_RESOLUTION` de `"50000000"` à `"50"`. L'unité est bien le **mégapixel** en v4,
vérifié sur `imgproxy:v4.0.14` : `0.01` refuse un PNG de 200 × 200 (422), `1` le sert (200). La
valeur précédente ne bornait donc rien contre une image géante ; 50 Mpx est ce que le
dimensionnement mémoire (`IMGPROXY_WORKERS`, 1536M) supposait déjà. Ne pas remettre une valeur
en pixels. Pas de test automatisé (configuration) ; prend effet au prochain `deploy.sh`.
