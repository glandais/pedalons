import json, os, sys
# page -> rows -> [(file, w, h, title)]  (colonnes : mobile, web étroit, web desktop)
PAGES = [
 ("sortie", "Sortie", [
  [("Main.dc.html",390,3480,"Sortie solo — mobile"),("sortie-solo-mobile-cible.dc.html",390,3100,"Sortie solo — mobile, CIBLE"),("sortie-solo-web-etroit.dc.html",390,3900,"Sortie solo — web étroit"),("sortie-solo-web-desktop.dc.html",1280,2760,"Sortie solo — web desktop")],
  [("sortie-sans-groupe-mobile.dc.html",390,3080,"Sortie sans groupe — mobile"),("sortie-sans-groupe-mobile-cible.dc.html",390,2560,"Sortie sans groupe — mobile, CIBLE"),("sortie-sans-groupe-web-etroit.dc.html",390,2400,"Sortie sans groupe — web étroit"),("sortie-sans-groupe-web-desktop.dc.html",1280,1820,"Sortie sans groupe — web desktop")],
 ]),
]
extra = json.load(open("extra.json")) if os.path.exists("extra.json") else {}
for pid, name, rows in PAGES:
    rows.extend(extra.get(pid, []))
for pid, name, rows in extra.get("_pages", []):
    PAGES.append((pid, name, rows))
# page « Cibles mobiles » : copies synchronisées des 9 cibles, côte à côte (un fichier = un seul board)
import shutil as _sh
CIBLES=[("sortie-solo","Sortie solo"),("sortie-sans-groupe","Sortie sans groupe"),("sortie-groupes-meme-heure","Sortie, groupes à la même heure"),("sortie-groupes-heures-differentes","Sortie, heures différentes"),("groupe","Groupe"),("groupe-inscrit","Groupe, inscrit"),("voyage-etapes","Voyage de 3 étapes"),("voyage-une-etape","Voyage d'une étape"),("etape","Étape"),("parcours","Parcours")]
_row=[]
for _n,_t in CIBLES:
    _sh.copyfile("project/%s-mobile-cible.dc.html"%_n,"project/tous-%s.dc.html"%_n)
    _row.append(("tous-%s.dc.html"%_n,390,3000,_t+" — mobile, CIBLE"))
_row.append(("feuille-gps.dc.html",390,844,"Feuille GPS — appareil connecté"))
_row.append(("feuille-gps-sans-appareil.dc.html",390,844,"Feuille GPS — aucun appareil connecté"))
PAGES.append(("cibles","Cibles mobiles",[_row]))
import re as _re
def _h(f,h):
    m=_re.search(r'"height":(\d+)',open("project/"+f).read()); return int(m.group(1)) if m else h
boards, order, notes = {}, [], {}
for pid, name, rows in PAGES:
    y = 0
    for row in rows:
        row = [(r[0],r[1],_h(r[0],r[2]),r[3]) for r in row if os.path.exists("project/" + r[0])]
        if not row: continue
        x = 0
        for f, w, h, t in row:
            b = {"x": x, "y": y, "w": w, "h": h, "title": t, "page": pid}
            if w >= 1000: b["expand"] = "fill"
            boards[f] = b; order.append(f); x += w + 80
        y += max(r[2] for r in row) + 160
    notes["t-" + pid] = {"x": 0, "y": -300, "text": name + ("" if pid in ("cibles","cartes-cibles","listes-cibles") else " — existant"), "kind": "title1", "maxW": 2220, "page": pid}
idx = {"v": 3, "createdOnFiles": {"v": 1, "at": "2026-11-10T02:00:00Z"},
       "title": "Pédalons — maquettes de l'existant (web et mobile)",
       "launch": {"view": "canvas", "page": "sortie"},
       "pages": [{"id": p, "name": n} for p, n, _ in PAGES],
       "boards": boards, "order": order, "notes": notes, "designSystems": []}
json.dump(idx, open("project/canvas.json", "w"), ensure_ascii=False, indent=1)
print(len(boards), "boards;", [f for f in os.listdir("project") if f.endswith(".dc.html") and f not in boards])
