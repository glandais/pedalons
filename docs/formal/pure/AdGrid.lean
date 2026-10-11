/-
  Model of backend/src/main/java/fr/pedalons/common/CoarseLocation.java (blur, snap, snapRadiusUp,
  SQL_PATTERN) and of the proximity filter in repository/ad/AdRepository.java:107-118.
  Part 1: integer (micro-degree) model, proved for all inputs with omega.
  Part 2: IEEE-double (Lean Float) transcription of the Java and SQL arithmetic, exhaustive #eval checks.
-/

/-! ## Part 1 — integer model of the latitude grid (cell = 0.01° = 10000 µdeg). -/

def cellLat (x : Int) : Int := x / 10000            -- Math.floor(value/step): Int `/` is floor for d>0
def centreLat (x : Int) : Int := cellLat x * 10000 + 5000  -- (floor + 0.5) * step, in µdeg*… (×1)

/-- The published centre is within half a cell of the exact point (CoarseLocation.java:96). -/
theorem centre_within_half_cell (x : Int) : centreLat x - 5000 ≤ x ∧ x < centreLat x + 5000 := by
  unfold centreLat cellLat; omega

/-- Two points in the same cell publish the same centre: the output is a function of the cell. -/
theorem centre_function_of_cell (x y : Int) (h : cellLat x = cellLat y) : centreLat x = centreLat y := by
  unfold centreLat; rw [h]

/-- Every cell is exactly one cell wide, negative coordinates included (floor, not truncation). -/
theorem cell_width (x y : Int) (h : cellLat x = cellLat y) : (x - y) < 10000 ∧ (y - x) < 10000 := by
  unfold cellLat at h; omega

/-- Control: had the code truncated toward zero ((long) cast), the cell around 0 would be 2 cells wide. -/
def cellTrunc (x : Int) : Int := Int.tdiv x 10000
example : cellTrunc (-9999) = cellTrunc 9999 := by decide

/-- Proximity filter (AdRepository.java:116): st_distancesphere(coarse(ad), blur(probe)) ≤ snap(r).
  Abstracted as any decision `d` over (ad centre, probe centre, quantised radius). -/
def answer (d : Int → Int → Nat → Bool) (ad probe : Int) (rq : Nat) : Bool :=
  d (centreLat ad) (centreLat probe) rq

/-- Non-interference: whatever the probes and radii, ads in the same cell are indistinguishable. -/
theorem probe_no_leak (d : Int → Int → Nat → Bool) (a a' : Int) (h : cellLat a = cellLat a') :
    ∀ p rq, answer d a p rq = answer d a' p rq := by
  intro p rq; unfold answer; rw [centre_function_of_cell a a' h]

/-! ## Part 2 — IEEE double transcription. -/

def CELL : Float := 0.01
def MINCOS : Float := 0.05
def DEG2RAD : Float := 0.017453292519943295   -- Math.toRadians and Postgres radians()
def javaRound (x : Float) : Float := Float.floor (x + 0.5) -- Math.round (long) for the magnitudes here
def snap (v step : Float) : Float :=
  let c := (Float.floor (v / step) + 0.5) * step
  javaRound (c * 1000000.0) / 1000000.0
def maxF (a b : Float) : Float := if a < b then b else a
/-- CoarseLocation.blur, lines 77-79. -/
def blurJava (lat lon : Float) : Float × Float :=
  let la := snap lat CELL
  let cosLat := maxF (Float.cos (la * DEG2RAD)) MINCOS
  (snap lon (CELL / cosLat), la)
/-- Cell indices as Java decides them. -/
def idxJava (lat lon : Float) : Float × Float :=
  let la := snap lat CELL
  let step := CELL / maxF (Float.cos (la * DEG2RAD)) MINCOS
  (Float.floor (lat / CELL), Float.floor (lon / step))
/-- Cell indices as SQL_PATTERN decides them (lines 58-60): unrounded lat centre in cos. -/
def idxSql (lat lon : Float) : Float × Float :=
  let la := (Float.floor (lat / CELL) + 0.5) * CELL
  let step := CELL / maxF (Float.cos (la * DEG2RAD)) MINCOS
  (Float.floor (lat / CELL), Float.floor (lon / step))

/-- Exhaustive grid: lat −89.5..89.5 every 0.37°, lon −179.9..179.9 every 1.13°, and for each the
  points ±1e-9° around the nearest lon cell boundary. Counts Java/SQL cell disagreements. -/
def mismatches : Nat := Id.run do
  let mut n := 0
  for i in [0:485] do
    let lat := -89.5 + (Float.ofNat i) * 0.37
    for j in [0:319] do
      let lon0 := -179.9 + (Float.ofNat j) * 1.13
      let la := snap lat CELL
      let step := CELL / maxF (Float.cos (la * DEG2RAD)) MINCOS
      let b := Float.floor (lon0 / step) * step
      for lon in [lon0, b + 1e-9, b - 1e-9, b + 1e-12, b - 1e-12] do
        if idxJava lat lon != idxSql lat lon then n := n + 1
  return n
#eval s!"Java vs SQL cell mismatches (incl. ±1e-12° of boundaries): {mismatches}"

/-- Max distance (in cell units) between the exact point and the published one; must be ≤ 0.5+ε. -/
def worstOffset : Float := Id.run do
  let mut w := 0.0
  for i in [0:900] do
    let lat := -89.0 + (Float.ofNat i) * 0.1977
    for j in [0:300] do
      let lon := -179.0 + (Float.ofNat j) * 1.193
      let (bl, ba) := blurJava lat lon
      let step := CELL / maxF (Float.cos (ba * DEG2RAD)) MINCOS
      let dLat := Float.abs (ba - lat) / CELL
      let dLon := Float.abs (bl - lon) / step
      w := maxF w (maxF dLat dLon)
  return w
#eval s!"worst |published - exact| in cell units: {worstOffset}"

-- Edge cases: poles and antimeridian.
#eval blurJava 90.0 0.0            -- lat 90.005: outside [-90,90]
#eval blurJava (-90.0) 0.0
#eval blurJava 45.0 180.0          -- lon > 180
#eval blurJava 45.0 (-180.0)
-- Width of the partial cell east of the last full cell at lat 45 (fraction of a cell).
#eval let la := snap 45.0 CELL; let step := CELL / maxF (Float.cos (la * DEG2RAD)) MINCOS;
      (180.0 - Float.floor (180.0 / step) * step) / step

-- Over all latitude cells: how many publish a longitude > 180 for a point at lon 179.9999?
def lonOver180 : Nat := Id.run do
  let mut n := 0
  for i in [0:17999] do
    let lat := -89.995 + (Float.ofNat i) * 0.01
    if (blurJava lat 179.9999).1 > 180.0 then n := n + 1
  return n
#eval s!"lat cells whose eastmost published lon exceeds 180: {lonOver180} / 17999"
