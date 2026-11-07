# Test parity — resources-rb

## Upstream unit tests (counted directly from `origin/main`, `#[test]` functions)

```
lib/process_data/src/pci_slot.rs : 12
src/utils/battery.rs             : 4
src/utils/cpu.rs                 : 1
src/utils/gpu/intel.rs           : 6
src/utils/link/pcie.rs           : 9
src/utils/link/sata.rs           : 3
src/utils/link/usb.rs            : 3
src/utils/link/wifi.rs           : 7
src/utils/memory.rs              : 3
src/utils/mod.rs                 : 20
src/utils/pci.rs                 : 10
src/utils/units.rs               : 17
----------------------------------------
TOTAL                             : 95 tests across 12 files
```

(Counted with `git show origin/main:<file> | grep -c '#\[test\]'` for every
`.rs` file in the upstream tree; 12 of its ~100 Rust files contain tests.)

## Port side

```
$ find spec test -type f
spec/README.md
spec/spec_helper.rb
test/drive_resources.rb
test/gtk_driver.rb
```

**Zero `*_spec.rb` files exist.** `spec/` contains only a README describing
the `kettle-test` harness and a `spec_helper.rb` that requires it. **Of the
95 upstream unit tests, 0 have been ported**, across every one of the 12
files that has them — including `units.rs` (17 tests) and `pci.rs` (10
tests), whose Ruby equivalents (`lib/resources/units.rb`,
`lib/resources/pci.rb`) already exist in the port and are exactly the kind
of pure-logic file this house's RSpec setup is meant for.

## Does the suite run at all?

No — confirmed by running it directly in this audit, not by trusting the
existing report:

```
$ nix develop --command xvfb-run -a rspec
...
Failure/Error: require "kettle/test/rspec"
LoadError:
  cannot load such file -- kettle/test/rspec
# ./spec/spec_helper.rb:23:in '<top (required)>'
No examples found.
```

`kettle-test` (the gemspec's RSpec harness dependency) is not resolvable in
this fork's Nix-built Ruby environment, so `spec_helper.rb` raises before
RSpec collects a single example. **This is independent of whether any spec
files exist** — even if `kettle/test/rspec` loaded, there is nothing for it
to run, because there are no spec files. Both halves of "a ported test
suite" are missing: the environment to run specs, and the specs themselves.

This matches what `.reports/drive-verification.md` already says (that
report calls out the same `LoadError` and the same "0 examples" outcome) —
so on this specific point the existing report is **not** a false green; it
states the gap plainly rather than omitting it. Re-verifying it here rather
than trusting it is still the right call: a different, less careful report
could have said "spec infrastructure in place" and left it there.

## The "drive" script is not a substitute for unit tests

`test/drive_resources.rb` (confirmed in this audit: 50/50 checks, `DRIVE OK`,
re-run live rather than taken on faith) is an integration/smoke script that
builds real widgets against a real `Xvfb` display and asserts on their
state. It is valuable and it is genuinely running, but it is not what
`test-parity` is asking about:

- It exercises **0 of the 95 upstream unit tests' actual assertions** —
  upstream's `units.rs` tests assert things like
  `convert_speed(1234.0, false) == "1.21 KiB/s"` for dozens of boundary
  values; the drive script never calls `Units` with a boundary value and
  checks the string, because it is driving a live UI, not exercising a pure
  function's edge cases.
- It only covers the **14 built components** (see
  `.reports/component-identification.md`), so it cannot be exercising the
  61 upstream tests that belong to files with no Ruby port at all yet
  (`gpu/intel.rs`, `link/*.rs`, half of `mod.rs`/`pci_slot.rs`'s domain).
- Even for files it does touch indirectly (`cpu.rb`, `memory.rb`,
  `battery.rb`, `pci.rb`, `units.rb` are all `require`d by the drive script
  transitively through the pages it builds), the drive script's checks are
  about widget state (graph received a point, banner visibility), not about
  the pure-function behavior the upstream tests pin down.

## Verdict

**Test parity: 0 of 95 upstream unit tests ported (0%), and the RSpec
harness the project is nominally set up to use cannot load in this fork's
dev shell.** The one test-shaped thing that exists and runs
(`test/drive_resources.rb`) is a real, passing, independently-reverified
integration smoke test over the 14 built UI components — genuinely useful,
genuinely green — but it is not a port of any upstream test and does not
reduce the 95-test gap. A suite that has never been executed (RSpec here)
is a gap in its own right per this audit's brief, and this port has that
gap in its most literal form: not flaky, not slow — it cannot load.
