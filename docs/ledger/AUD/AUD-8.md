---
id: AUD-8
title: "VCL Varnish réduite à un `backend default` et une règle de contournement du cache (`API-43`) : ni purge, ni…"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `AUD-8` | **VCL Varnish minimale** (audit de février 2026, I15) : `services/varnish/varnish.vcl` n'a qu'un `backend default` (imgproxy) et le `pass` du réencodage (`API-43`) — ni purge, ni grace, ni ban | Gardée telle quelle (décidé le 17 novembre 2026 avec le propriétaire) | **Purge et ban sont sans objet** : une image remplacée prend une nouvelle clé (`team` + `fileId`, `API-128`), donc une nouvelle URL, et une image supprimée n'est plus atteignable — le backend vérifie l'asset et les droits avant d'appeler Varnish (`ImgProxyService`). **Grace** ne servirait qu'en cas de panne d'imgproxy, jamais vue. Mesuré en prod le 17 novembre 2026 sur 7 jours : 3 358 requêtes, 61 % servies par le cache, 106 Mo sur 1 Go, aucune éviction, aucun échec d'imgproxy. Accepté aussi : imgproxy répond `Vary: Accept` (`IMGPROXY_AUTO_WEBP/AVIF/JXL`), si bien qu'une vignette est gardée une fois par chaîne `Accept` brute (7 variantes relevées) au lieu d'une par format ; à ce volume le surcoût est négligeable. À rouvrir si le taux de hit ou la mémoire deviennent un sujet : normaliser `Accept` dans `vcl_recv` (jxl, avif, webp ou rien) est alors la première mesure |
