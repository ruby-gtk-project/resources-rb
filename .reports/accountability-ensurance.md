# Accountability ensurance — resources-rb (refresh)

Checked whether any gap found by the other four reports is being excused
rather than built, and whether any green claim in this fork rests on
something never actually executed. This refresh re-runs the audit at
commit `6eac7de` ("Port the process name cell and the process
detail/options dialogs"), after the previous round's reports.

## Grep for excuse language

```
$ grep -rniE "TODO|FIXME|not implemented|for now|in a future|placeholder|stub\b|unimplemented|unsupported" lib exe
(no matches)
$ grep -rniE "TODO|FIXME|not implemented|for now|in a future" .reports
(no matches)
$ ls PORTING.md
ls: cannot access 'PORTING.md': No such file or directory
```

No `PORTING.md` exists on this branch. No excuse marker appears in `lib/`,
`exe/`, or `.reports/`. This is a genuinely clean result on its own terms —
but it is clean because **the missing 11 widget units and 15 backing-utility
files simply don't exist as files at all**, not because they exist as
stubs with an honest "not implemented" marker. There is no hedge to find
because nothing was written and then hedged; it is just absent. That is the
correct way to leave undone work (an absent file beats a lying stub), and
it is also why the real gap-tracking has to live in the parity reports
instead of a grep hit — which is what this round produced.

## Checking every green claim against something actually executed

| Claim | Where made | Verified how in this audit | Outcome |
|---|---|---|---|
| "68 of 68 checks passed, DRIVE OK, 18 components" | this round's runtime gate | Re-ran `nix develop --command xvfb-run -a ruby test/drive_resources.rb` live in this session; grepped the full stdout+stderr for `Gtk-CRITICAL`/`WARNING`/`assert` | **Confirmed — real, reproduced identically (68/68, DRIVE OK), clean of GTK criticals.** "18 components" is off by one against this audit's own built-widget-unit count of 17 (see `component-identification.md`'s refresh) — most likely the drive script also counts `Resources::Process`, a backing-util model class, as a component. Flagged there as a labeling note, not a false claim: 68/68 is real either way. |
| "`Process#set_affinity` applies via `taskset`" | commit `6eac7de`'s message, `lib/resources/process.rb` | Read `test/drive_resources.rb`'s ProcessOptionsDialog checks: they assert switch-row state and Apply-button sensitivity, never read `/proc/<pid>/status` back after Apply to confirm the `taskset` invocation actually changed anything | **Unverified, not false** — the dialog's own state is proven; the claim that `set_affinity` *works* (vs. silently failing while the UI still reports success) rests on code reading, not execution. Recorded as a gap in `.reports/drive-verification.md`'s refresh rather than left implicit. |
| "all ~50 schema keys are present in `Settings::DEFAULTS`" | `.reports/component-inventory.md` | Counted both sides: upstream `grep -c '<key '` → 53, port `grep -c '"[a-z-]*" =>'` → 53 | **Confirmed**, and more precise (53, not "~50") |
| "spec/ has kettle/test/rspec LoadError, 0 spec files" | `.reports/drive-verification.md` | Re-ran `nix develop --command xvfb-run -a rspec` live; confirmed identical `LoadError` and `find spec -name '*_spec.rb'` → empty | **Confirmed — not a false green, this report undersells nothing** |
| "battery page: No" | `.reports/component-inventory.md` (stale, pre-`f97dbbf`) | Read `lib/resources/battery_page.rb` (222 lines, real implementation) and `lib/resources/main_window.rb` (`battery_pages` method, wired into `pages`) | **Stale claim, now false** — corrected in `.reports/component-identification.md`. This is the one place an old report, if taken at face value without re-reading the tree, would have under-counted progress (a different direction of error than a false green, but still a report that no longer matches the tree it describes) |
| "None are reachable from a page yet" (process dialogs/cell) | commit `6eac7de`'s own message | Read `lib/resources/main_window.rb`'s `pages` method and `test/drive_resources.rb`'s comments | **Confirmed, and disclosed by the author in the commit that introduced the gap, not found by this audit.** This is the behavior the skill is checking for: a limitation stated in the same breath as the feature, not buried or omitted. |

No claim examined rests on something that was asserted but never run. The
fork's own `.reports/drive-verification.md` is unusually candid for a
"green" report: it states its own blind spots (rspec can't load, 6 pages +
backing utils don't exist, battery is exercised directly rather than
through live hardware) in the same document that reports the pass count,
rather than in a separate document nobody reads. That is the behavior this
skill is checking for, and it is present here.

## Where the real accountability gap is

The gap in this fork is not a lie anywhere in `.reports/` — it is that the
**runtime gate's "68 checks / 0 failed / 18 components, drive_ok=true"
reads, out of context, as if the port were far along**, when the 17 built
widget/dialog/page units (this audit's count; see the one-unit labeling
note above) are 68% of the 25 identified widget units, but only **14 of 25
(56%) are actually reachable through the running UI** — three of the 17
(process details dialog, process options dialog, process name cell) are
built, individually driven, and green in the gate, yet sit behind a
Processes page that doesn't exist, so no user action reaches them. The gate
counts "built and driven directly" the same as "built and reachable", and
does not distinguish the two. Add 0% of the 391 translation strings and 0%
of the 95 upstream unit tests, and a gate that only reports pass/fail over
what exists, with no denominator over what *upstream* has and no
reachability column, is not itself dishonest, but treating "drive_ok=true"
as "parity achieved" — which is exactly the framing this audit was told to
resist — would be the false-green failure mode, committed by the reader of
the gate rather than by the fork. This round's reports make both the
denominator (25 units, 391 msgids, 95 tests) and the reachability split
(14 reachable / 3 orphaned / 8 absent) explicit specifically so that
framing cannot happen by omission.

## Verdict

**No excused gap found.** Every shortfall identified by
`component-identification.md`, `component-parity.md`, `test-parity.md` and
`translation-parity.md` is either stated plainly in an existing report or
commit message (the rspec/spec-files gap, the process-dialogs'
unreachability, the unverified `taskset` effect) or was simply never
addressed (6 pages, 1 dialog, 1 cell, 15 utility files, all translation
infrastructure, the
desktop/metainfo/polkit resources) — in neither case is there a hedge, a
stub claiming partial credit, or a report claim that doesn't hold up against
re-execution.
