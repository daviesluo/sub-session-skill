# A worked example

One instruction, its answers, and the ruling: the whole loop on one
page. The project is invented, a data pipeline, and the shapes are the
contract. `compute` is the sub-session's name, `main` the
integration branch.

**Inbox** (`collab/INBOX_compute.md` on `main`, written by the master):

```
## Open instructions

- COMPUTE-7 (ack [done: COMPUTE-7]): rebuild the March segment of
  the features cache with the new normaliser. Gates, pre-registered:
  row count equals the manifest's 1,244,000 exactly, no column mean
  moves by more than 0.1 standard deviations against February except
  the two the normaliser targets, runtime under two hours.
  Interpretation: all three hold = pass. Row count holds but one
  non-target column moves = conditional pass, name the column.
  Anything else = fail, stop before writing. Report the numbers.
```

**Outbox** (`collab/OUTBOX_compute.md` on the sub-session's branch):

```
- 2026-03-14 14:02 UTC COMPUTE-7 started. Pre-flight on 10,000 real
  rows: the new normaliser runs, output schema unchanged.
- 2026-03-14 15:41 UTC COMPUTE-7 done, 1 h 32 m, watermark 4f2a9c1.
  Rows 1,244,000 exact. Target columns moved as designed. Non-target
  columns all within 0.02 standard deviations. PASS on the
  pre-registered reading.
- 2026-03-14 15:49 UTC watermark 4f2a9c1. FINDING-1, severity MEDIUM:
  the manifest counts 1,244,000 rows but the upstream export writes
  1,244,106, and the loader silently drops 106 malformed lines. The
  cache is right, the manifest's number comes from the loader where it
  should come from the export, and nothing records the drop. Proposed:
  log the dropped count in the loader and state the derivation rule in
  the manifest.
```

The checkpoint that pushed those entries carries the acknowledgement
where the gate reads it, in the commit subject:

```
rebuild the March features cache [done: COMPUTE-7]
```

**Ruling** (the next inbox entry, and the fix is the master's to make):

```
- COMPUTE-8 (ruling on FINDING-1, ack [done: COMPUTE-8]):
  ACCEPTED. The loader now logs the dropped count and the manifest
  states that its counts are post-drop. Verify both in the merged
  file. FINDING-1 CLOSES on this ruling: drop it from the open list
  in your check-in prompt, and this instruction moves to
  `## Closed instructions`.
```

That is the protocol in miniature: a numbered instruction with its
gates and their interpretation fixed before the run, terse
timestamped answers carrying the numbers and the watermark that says
how far the sub-session had read, a finding with a severity and a
proposed fix, a ruling that closes it explicitly, and acknowledgements
travelling in commit subjects.

---

Copyright 2026 Zheng Luo (Davies Luo). Licensed under the Apache
License 2.0, whose text is the `LICENSE` file beside this one.
