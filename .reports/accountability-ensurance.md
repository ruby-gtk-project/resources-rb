# Accountability ensurance — resources-rb

Checked whether any gap found by the other four reports is being excused
rather than built, and whether any green claim in this fork rests on
something never actually executed.

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
| "50 of 50 checks passed, DRIVE OK" | `.reports/drive-verification.md`, runtime gate | Re-ran `nix develop --command xvfb-run -a ruby test/drive_resources.rb` live in this session | **Confirmed — real, reproduced identically (50/50, DRIVE OK)** |
| "all ~50 schema keys are present in `Settings::DEFAULTS`" | `.reports/component-inventory.md` | Counted both sides: upstream `grep -c '<key '` → 53, port `grep -c '"[a-z-]*" =>'` → 53 | **Confirmed**, and more precise (53, not "~50") |
| "spec/ has kettle/test/rspec LoadError, 0 spec files" | `.reports/drive-verification.md` | Re-ran `nix develop --command xvfb-run -a rspec` live; confirmed identical `LoadError` and `find spec -name '*_spec.rb'` → empty | **Confirmed — not a false green, this report undersells nothing** |
| "battery page: No" | `.reports/component-inventory.md` (stale, pre-`f97dbbf`) | Read `lib/resources/battery_page.rb` (222 lines, real implementation) and `lib/resources/main_window.rb` (`battery_pages` method, wired into `pages`) | **Stale claim, now false** — corrected in `.reports/component-identification.md`. This is the one place an old report, if taken at face value without re-reading the tree, would have under-counted progress (a different direction of error than a false green, but still a report that no longer matches the tree it describes) |
| "14 components" covered by the runtime gate | task's stated runtime gate | Cross-checked against the unit count in `.reports/component-identification.md` (14 built units) | **Consistent** — the gate's "14 components" is not inflated; it is exactly the set of units that exist |

No claim examined rests on something that was asserted but never run. The
fork's own `.reports/drive-verification.md` is unusually candid for a
"green" report: it states its own blind spots (rspec can't load, 6 pages +
backing utils don't exist, battery is exercised directly rather than
through live hardware) in the same document that reports the pass count,
rather than in a separate document nobody reads. That is the behavior this
skill is checking for, and it is present here.

## Where the real accountability gap is

The gap in this fork is not a lie anywhere in `.reports/` — it is that the
**runtime gate's "50 checks / 0 failed / 14 components, drive_ok=true"
reads, out of context, as if the port were far along**, when the 14
components are 56% of the 25 identified widget units, 0% of the 391
translation strings, and 0% of the 95 upstream unit tests. A gate that only
reports pass/fail over what exists, with no denominator over what
*upstream* has, is not itself dishonest, but treating "drive_ok=true" as
"parity achieved" — which is exactly the framing this audit was told to
resist — would be the false-green failure mode, committed by the reader of
the gate rather than by the fork. This round's reports make the denominator
explicit (25 units, 391 msgids, 95 tests) specifically so that framing
cannot happen by omission.

## Verdict

**No excused gap found.** Every shortfall identified by
`component-identification.md`, `component-parity.md`, `test-parity.md` and
`translation-parity.md` is either stated plainly in an existing report
(the rspec/spec-files gap) or was simply never addressed (6 pages, 3
dialogs, 2 cells, 15 utility files, all translation infrastructure, the
desktop/metainfo/polkit resources) — in neither case is there a hedge, a
stub claiming partial credit, or a report claim that doesn't hold up against
re-execution.
