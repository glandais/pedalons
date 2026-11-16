---
id: WEB-48
title: "« Cette semaine » devient « Les 7 prochains jours », site et application"
status: done
group: "Défauts d'interface"
---

## Livré

`WEB-48` **« Cette semaine » devient « Les 7 prochains jours », site et application** (4 octobre
2026, relevé dans `docs/BUGS.md` comme « la semaine commence le dimanche ») — le bloc n'a jamais
été une semaine calendaire : c'est une fenêtre glissante de sept jours à partir d'aujourd'hui
(`WeekAgenda.tsx`, `week_events_provider.dart`), qui un dimanche commence donc un dimanche. Le
libellé seul était faux : titre et phrases (`home.week.*`, `home.member.summary.*`) parlent des
« 7 prochains jours », en FR et EN, et le titre mobile (`home.week.title`) suit ; le test
`home_member_sections_test.dart` lit le nouveau titre. **Écarté** : une semaine lundi–dimanche,
qui le dimanche n'aurait montré que la journée en cours.
