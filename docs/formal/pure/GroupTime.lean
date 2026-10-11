/-
  Model of EventTimezoneResolver.groupStart / ownTime / sameWallTime
  (backend/src/main/java/fr/pedalons/service/timezone/EventTimezoneResolver.java:162-184)
  and TeamTimezoneChange.rewriteRide / rewrite (TeamTimezoneChange.java:135-161).
  Time unit: minutes since epoch (Int). A zone is an offset function of the instant, with Java's
  ZonedDateTime.ofLocal resolution: in a gap shift forward by the gap, in an overlap take the
  earlier offset.
-/

structure Zone where
  offsetAt : Int → Int     -- offset (minutes) in force at instant i
  cands : List Int         -- every offset the zone ever uses (for resolution)

def fixedZ (o : Int) : Zone := ⟨fun _ => o, [o]⟩
/-- A Paris-like zone: +60, +120 from instant S (spring) until instant F (fall). -/
def dstZ (S F : Int) : Zone := ⟨fun i => if S ≤ i ∧ i < F then 120 else 60, [120, 60]⟩

def toLocal (z : Zone) (i : Int) : Int := i + z.offsetAt i
/-- ZonedDateTime.of(local, zone).toInstant(). -/
def toInstant (z : Zone) (l : Int) : Int :=
  let valid := z.cands.filter (fun o => z.offsetAt (l - o) == o)
  match valid with
  | o :: _ => l - o                       -- cands listed largest first = earlier offset in overlap
  | [] =>                                 -- gap: offset before the gap, i.e. shift forward
    let before := z.cands.filter (fun o => z.offsetAt (l - o) != o)
    match before.reverse with | o :: _ => l - o | [] => l

def day (l : Int) : Int := l / 1440       -- LocalDate (floor)
def tod (l : Int) : Int := l % 1440       -- LocalTime (emod ≥ 0)

/-- EventTimezoneResolver.groupStart (:162-167). -/
def groupStart (r : Int) (t : Option Int) (z : Zone) : Int :=
  match t with
  | none => r
  | some t => toInstant z (day (toLocal z r) * 1440 + t)
/-- EventTimezoneResolver.ownTime (:174-176). -/
def ownTime (r s : Int) (z : Zone) : Option Int := if s == r then none else some (tod (toLocal z s))
/-- EventTimezoneResolver.sameWallTime (:182-184). -/
def sameWallTime (i : Int) (a b : Zone) : Int := toInstant b (toLocal a i)

/-- Re-saving a ride unchanged (RideService.updateRide :389-399 with RideGroupDto.time = ownTime) -/
def resave (r s : Int) (z : Zone) : Int := groupStart r (ownTime r s z) z

-- Paris-like zone over days 0..3: spring gap on day 1 at 01:00 UTC, fall overlap on day 2 at 01:00 UTC.
def paris : Zone := dstZ (1440 + 60) (2*1440 + 60)

/-- P1: in the zone the group was entered in, read-back then re-save is the identity
  (rides every 15 min over 3 days, every group time every 15 min). -/
def p1Failures (z : Zone) : List (Int × Int) := Id.run do
  let mut bad := []
  for ri in [0:288] do
    let r : Int := (ri : Int) * 15
    for ti in [0:96] do
      let s := groupStart r (some ((ti : Int) * 15)) z
      if resave r s z != s then bad := (r, (ti:Int)*15) :: bad
  return bad
#eval s!"P1 same-zone round trip failures, paris: {(p1Failures paris).length}, utc: {(p1Failures (fixedZ 0)).length}"

/-- P2: past ride relabelled from → to at constant instant (rewriteRide :339-341 returns before
  touching the groups; rewrite :360 sets the zone), then re-saved unchanged in `to`. -/
def p2Failures (fromZ toZ : Zone) : List (Int × Int × Int) := Id.run do
  let mut bad := []
  for ri in [0:96] do
    let r : Int := 1440*5 + (ri : Int) * 15
    for ti in [0:96] do
      let s := groupStart r (some ((ti : Int) * 15)) fromZ
      let s' := resave r s toZ
      if s' != s then bad := (r, s, s' - s) :: bad
  return bad
#eval let f := p2Failures (fixedZ 0) (fixedZ 60)
      s!"P2 UTC→UTC+1 past ride re-save shifts: {f.length} of 9216; shift values: {(f.map (·.2.2)).eraseDups}; first: {f.getLast?}"
#eval let f := p2Failures (fixedZ 60) (fixedZ (-240))
      s!"P2 Paris(winter)→Martinique past ride re-save shifts: {f.length}; shifts {(f.map (·.2.2)).eraseDups}"

/-- P3: upcoming ride (rewriteRide :343-345): new ride = sameWallTime, group = own time in from,
  re-anchored in to. Then a re-save in `to` must be the identity. -/
def p3Failures (fromZ toZ : Zone) : Nat := Id.run do
  let mut n := 0
  for ri in [0:288] do
    let r : Int := (ri : Int) * 15
    for ti in [0:96] do
      let s := groupStart r (some ((ti : Int) * 15)) fromZ
      let r' := sameWallTime r fromZ toZ
      let s' := groupStart r' (ownTime r s fromZ) toZ
      if resave r' s' toZ != s' then n := n + 1
  return n
#eval s!"P3 upcoming relabel then re-save failures: utc→paris {p3Failures (fixedZ 0) paris}, paris→+4 {p3Failures paris (fixedZ 240)}"

/-- Fixed variant: ownTime keeping the day offset (a LocalDateTime, or the date delta) round-trips. -/
def ownDelta (r s : Int) (z : Zone) : Option Int :=
  if s == r then none else some (toLocal z s - day (toLocal z r) * 1440)
def p2Fixed : Nat := Id.run do
  let mut n := 0
  for ri in [0:96] do
    let r : Int := 1440*5 + (ri : Int) * 15
    for ti in [0:96] do
      let s := groupStart r (some ((ti : Int) * 15)) (fixedZ 0)
      if groupStart r (ownDelta r s (fixedZ 60)) (fixedZ 60) != s then n := n + 1
  return n
#eval s!"P2 with day-carrying own time: {p2Fixed} failures"
