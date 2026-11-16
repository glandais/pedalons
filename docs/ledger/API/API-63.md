---
id: API-63
title: "Onboarding d'un Karoo refait de bout en bout (M, backend + web + mobile + Karoo)"
status: open
size: "M"
group: "Extension Karoo : ce que le découpage de novembre 2026 a figé sans le corriger"
verified: 2026-11-16
---

## Reste à faire

### `API-63` Onboarding d'un Karoo refait de bout en bout (M, backend + web + mobile + Karoo)

Associer un Karoo laisse l'utilisateur sans Hammerhead sans qu'il le sache : l'app mobile ne le
propose jamais, le web le propose trop tard (le Karoo a déjà affiché son second QR), et ce QR mène
au profil sans rien expliquer. Le plan [`2026-10-02-karoo-onboarding.md`](../../plans/2026-10-02-karoo-onboarding.md)
refait le parcours : un seul QR, l'étape Hammerhead enchaînée sur le téléphone après l'autorisation,
un retour d'OAuth paramétré (`returnTo`, contrat `10.4.0`) et un Karoo qui suit `/api/device/me`
au lieu de redemander. Hammerhead y est **obligatoire** (décision du 2 octobre 2026).

**Code livré et en prod, tous les tests automatisés verts : reste la recette manuelle.** Backend
(`GpsResourceTest`), e2e web (`flow-device.e2e.ts`) et Patrol (`device_link_test`,
`device_hammerhead_test`, `device_link_signed_out_test`, `device_manual_code_test`) sont verts.
Reste la recette sur Karoo et téléphone du §4 du plan (six scénarios), à faire sur la version courante (`karoo.1.0.15` au 16 novembre 2026),
qui embarque aussi « Prochaines sorties » (`API-118`) et l'état de synchro GPS (`API-121`). Les
connexions Hammerhead créées en prod (trois au 16 octobre 2026) montrent un usage réel, pas que la
recette a été faite ; l'entrée passe dans `LEDGER_DONE.md` une fois celle-ci faite.
