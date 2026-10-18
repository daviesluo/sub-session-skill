## 6. Multi-sub-session setups

- Each sub-session gets its own name, branch, inbox, outbox, lane and
  poke. There is no sub-session-to-sub-session channel: anything one
  sub-session needs another to know goes through the master (who can
  quote outbox entries into another inbox). Sub-sessions may READ each
  other's branches and outboxes freely.
- The master runs one outbox watcher per sub-session and keeps a short
  roster (name, branch, lane, current assignment) in the ledger.
  **THE WATCHER IS THE PRIMARY SIGNAL AND A SCHEDULED SELF CHECK-IN IS ONLY
  THE FALLBACK.** A master whose tool schedules wakes easily will be tempted
  to run on the timer alone, and it works, badly: the reply is already
  pushed and the master reads it whenever its own clock next fires, so every
  report waits half a cadence on average and a whole one at worst. Arm the
  watchers BEFORE dispatching the first instruction that expects a reply,
  and prove one fires, the same deliberate test the monitor rule demands.
  THE TELL that this was skipped is a gap between a sub-session's outbox
  commit time and the time the master read it: if the master keeps learning
  about pushes from its own timer rather than from an event, the watcher is
  missing or dead. Keep the scheduled check-in anyway, so a dead watcher
  degrades into lateness instead of silence, and set its cadence SHORTER
  than the platform's measured monitor cap rather than long: a watcher that
  expires at thirty minutes under a check-in armed for two hours leaves an
  hour and a half of pure silence, which is the failure the watcher exists
  to prevent. Re-arm the watcher at the top of every wake.
- Partition by independence: give each sub-session work whose outputs and
  inputs do not depend on another sub-session's in-flight work. Where a
  dependency is unavoidable, sequence it through <integration>: sub-session A's
  work merges to <integration> first, sub-session B merges <integration>
  inward, continues.
- A third sub-session is rarely worth its cost unless the work is
  genuinely parallel, since every seat spends usage and coordination
  whether or not it is busy. The master should say so when asked to add
  a session that would idle.

