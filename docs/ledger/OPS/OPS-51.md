---
id: OPS-51
title: "Styles de vignettes v7 déployés, alias retirés du dépôt"
status: done
done: 2026-10-20
---

## Livré

`OPS-51` **Styles de vignettes v7 déployés, alias retirés du dépôt** (2026-10-20) — stack
partagée (`deploy.sh --shared` puis `docker service update --force pedalons-shared_tileserver`),
staging et prod déployés dans cet ordre, vignettes vérifiées par l'utilisateur. Plus aucun backend
n'appelant plus `colorful` ni `eclipse`, ces deux alias sont retirés sous `OPS-52`.
