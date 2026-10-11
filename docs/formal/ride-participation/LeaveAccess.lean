/-
  RideService.leaveGroup (RideService.java:534-541) vs RideAccessChecker LEAVE (RideAccessChecker.java:61-68).
  The checker authorises against the ride named by rideSlug (published, caller is a member of its team,
  rides enabled); leaveGroup then deletes the caller's participation found by (userId, groupId) only
  (RideParticipationRepository.findByUserAndGroup, line 19-21) -- the group's ride is never compared
  to the checked ride.
-/
inductive St | draft | published | cancelled deriving DecidableEq, Repr, Inhabited

structure Ride where
  team : Nat
  status : St
  deriving DecidableEq, Repr, Inhabited

structure World where
  rides : List Ride          -- ride index = position
  groupRide : List Nat       -- group index -> ride index
  member : Nat → Bool        -- caller's membership by team
  regGroup : Nat             -- group the caller is registered in

def checkLeave (w : World) (rideIdx : Nat) : Bool :=
  match w.rides[rideIdx]? with
  | some r => w.member r.team && r.status == St.published
  | none => false

/-- what the code does: authorised + participation (user, groupId) exists -/
def leaveDeletes (w : World) (rideIdx g : Nat) : Bool :=
  checkLeave w rideIdx && g == w.regGroup

/-- intended: the deleted participation belongs to a ride the caller was authorised to leave -/
def intended (w : World) (g : Nat) : Bool :=
  match w.groupRide[g]? with
  | some ri => checkLeave w ri
  | none => false

def sts : List St := [St.draft, St.published, St.cancelled]

def worlds : List World := Id.run do
  let mut out := []
  for s0 in sts do
    for s1 in sts do
      for t1 in [0, 1] do
        for m1 in [true, false] do
          out := { rides := [⟨0, s0⟩, ⟨t1, s1⟩], groupRide := [0, 1],
                   member := fun t => t == 0 || m1, regGroup := 1 } :: out
  return out

def counterexamples : List (St × St × Nat) :=
  (worlds.filter fun w => leaveDeletes w 0 1 && !intended w 1).map
    fun w => ((w.rides[0]!).status, (w.rides[1]!).status, (w.rides[1]!).team)

#eval counterexamples.length
#eval counterexamples

theorem leave_check_not_bound_to_group : ∃ w ∈ worlds, leaveDeletes w 0 1 = true ∧ intended w 1 = false := by
  decide
