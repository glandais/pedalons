/-
  Retention (NotificationRetentionService.purgeExpired, 90 days by created_at, any status) vs. the
  longest any piece of work can still be in flight. Mirrors NotificationDispatchService.backoff
  (base * 2^clamp(attempts-1,0,20), capped at 6 h) and the default config.
  Times in seconds.
-/
def maxBackoff : Nat := 6 * 3600
def backoff (base attempts : Nat) : Nat :=
  min maxBackoff (base * 2 ^ (min (attempts - 1) 20))

def stuck : Nat := 15 * 60          -- stuck-after-minutes
def recoverEvery : Nat := 5 * 60    -- recoverStuck cadence
def tickEvery : Nat := 15           -- tick cadence
def digestEvery : Nat := 15 * 60
def updateDelay : Nat := 300        -- update-delay-seconds
def digestWait : Nat := 25 * 3600   -- next 07:00 local, plus a DST hour

/-- Worst case for one attempt: it hangs and is only recovered after stuck + one recovery period. -/
def attemptCost (a base : Nat) : Nat := stuck + recoverEvery + backoff base a + tickEvery

def sumTo (n : Nat) (f : Nat → Nat) : Nat := (List.range n).foldl (fun acc i => acc + f (i+1)) 0

/-- Event: delay, then up to 3 attempts. -/
def eventLife : Nat := updateDelay + sumTo 3 (fun a => attemptCost a 60)
/-- Delivery (incl. digest): digest wait, then up to 5 attempts, each also waiting a digest tick. -/
def deliveryLife : Nat := digestWait + sumTo 5 (fun a => attemptCost a 60 + digestEvery)
/-- Webhook delivery: same ceiling as deliveries. -/
def retention : Nat := 90 * 86400

#eval (eventLife, deliveryLife, eventLife + deliveryLife, retention)

theorem retention_never_hits_live_work : eventLife + deliveryLife < retention := by decide

/-- The backoff never exceeds its cap, for any attempt count up to 64 (the int field is far below). -/
theorem backoff_capped : ∀ a : Fin 64, backoff 60 a.val ≤ maxBackoff := by decide
