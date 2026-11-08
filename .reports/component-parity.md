# Component parity — resources-rb

Behavioral comparison of the units that **do** exist in `lib/` against their
upstream counterpart on `origin/main`, plus the parity consequence of the
units that don't. See `.reports/component-identification.md` for the unit
list this is built on.

## Parity of built units

| Unit | Parity check | Result |
|---|---|---|
| Application / main window | title, breakpoint-driven sidebar collapse, split-view binding | **matches** — verified live by `test/drive_resources.rb` checks 1–8, 27 |
| Stack sidebar / item | both built rows present, selection drives content stack both ways | **matches** — checks 9–14 |
| CPU page | logical-CPU toggle switches internal stack, one `GraphBox` per `Etc.nprocessors`, live usage string, graph receives real tick data | **matches** — checks (CPU section) |
| Memory page | auth-banner visibility is the exact complement of the properties group, authenticate button doesn't raise | **matches** — checks 16–17 |
| Battery page | builds and refreshes against synthetic sysfs data; **on this dev machine there is no battery, so `MainWindow#battery_pages` is empty and the sidebar never reaches it** — the class is exercised directly, not through the window | **parity unverified in the one place a user would see it** (no battery hardware to prove `main_window.pages` actually includes it when one is present) — this is a gap in verification method, not necessarily in the code, but it means the "battery page is wired into the sidebar" claim rests on reading the `*battery_pages` splat, not on seeing it happen |
| Settings/Preferences dialog | all 53 schema keys present and round-trip (switch/combo/spin rows checked) | **matches** on the 3 sampled row kinds; the dialog has far more than 3 rows (53 keys) and only 3 are driven through a round-trip check — the other ~50 keys are present in `Settings::DEFAULTS` but their *dialog rows* are unverified by any check |
| Shortcuts dialog | opens via action and accelerator | **matches**, but see identification report: it still lists Apps/Processes shortcuts for pages that don't exist — a user who reads the shortcuts window sees commands the app cannot perform. This is a real behavioral mismatch (upstream's shortcuts window only shows shortcuts for pages that exist) |
| About dialog | opens via action/menu/accelerator, app name shown | **matches** |
| Process-action (confirm) dialog | builds, presents, screenshots | **built and exercised standalone only** — not reachable from any page in the running app, because no page that would trigger it (Processes/Applications) exists. A user cannot reach this dialog through the UI today. |
| Process details dialog (`process_dialog.rb`, commit `6eac7de`) | read-only name/CPU/memory/swap/drive/network/GPU rows | **built, matches as far as it goes** — driven directly in `test/drive_resources.rb`; `Resources::Process` only has real CPU/memory data on this machine, so the drive/network/GPU rows are exercised against whatever placeholder/zero values `Process` returns rather than live non-zero telemetry, same limitation as the Battery-page caveat above | **unreachable from any page** — Processes page (row 16) doesn't exist |
| Process options dialog (`process_options_dialog.rb`, commit `6eac7de`) | niceness/priority rows, per-CPU affinity switches, Toggle All, Apply | **matches** on the driven checks (niceness/priority visibility toggle, individual + toggle-all affinity switches, apply-button sensitivity) — `Process#set_affinity` shells out to `taskset`, not independently verified against a real multi-core reniceable process in this audit, only against the dialog's own switch-row state | **unreachable from any page** — same caveat |
| Process name cell (`process_name_cell.rb`, commit `6eac7de`) | icon + elided process name | **built**, driven directly | **has no `GtkColumnView` column to live in** — Processes page (row 16) doesn't exist, so this cell is never actually instantiated by a factory the way upstream's is |

## Parity gaps from missing units (behavioral, not just "file doesn't exist")

Each of these is a place where upstream's user-visible behavior has **no
equivalent at all** in the port, not a lesser version of it:

1. **Six of nine stack pages are simply absent from the sidebar**: Apps,
   Processes, Drive, GPU, Network, NPU. A user who opens the port sees a
   2–3-item sidebar (CPU, Memory, and Battery only if hardware is present)
   where upstream shows up to 9 entries depending on hardware. This is the
   single largest parity gap in the app and it is visible on the very first
   screen.
2. **No process/app management at all.** Upstream's Processes and
   Applications pages are how a user finds and kills/stops/continues a
   process or quits an app. The port has the confirm-dialog and the data
   model (`process.rb`, `process_entry.rb`) but no page to drive them from,
   so **the port cannot kill a process through its UI**, a core function of
   a system monitor.
3. **No Drive/Network/GPU/NPU telemetry.** Upstream reads and displays
   drive read/write speed, network up/down speed, GPU/NPU usage and VRAM.
   None of this exists in the port — not the page, not the backing utility
   (`drive.rb`, `network.rb`, `gpu.rb`, `npu.rb` are all absent), not the
   `link/*` speed-detection helpers they share.
4. **Process-details and process-options dialogs are built but unreachable**
   (the page that would open either, Processes, is missing — see point 2);
   **the app-details dialog is still missing outright**, file and all.
5. ~~Process-options (niceness/priority) dialog is missing~~ — **built as of
   commit `6eac7de`** (`lib/resources/process_options_dialog.rb`), but see
   point 4: there is still no path to it through the running UI, and
   `Process#set_affinity`'s `taskset` call is unverified against a real
   process in this audit.
6. **No root-helper / polkit action.** Upstream's privileged renice/kill
   path goes through `resources-adjust`/`resources-kill`/`resources-processes`
   authorized by `net.nokyan.Resources.policy.in.in`. None of the three
   binaries or the policy file exist in the port. Since the dialogs that
   would need them (process-options) are also missing, this is consistent
   but it means **no privileged action of any kind is possible in the port**.
7. **No desktop entry, no AppStream metainfo.** The port is not installable
   or discoverable as a desktop application the way upstream is (no
   `.desktop` file for a launcher, no metainfo for a software center
   listing).

## Verdict

Of the 17 built units (refreshed from 14, now including the process-details
dialog, process-options dialog and process-name-cell added in commit
`6eac7de`), parity holds for what each one actually does, with caveats worth
flagging on their own: the Battery page's wiring into the sidebar is read,
not observed, on this machine; the Settings dialog's round-trip check covers
3 of 53 keys; and **three of the newly-built units (process details,
process options, process name cell) are built with real internal parity
but remain completely unreachable from the running app's UI**, because the
Processes page that would host all three still does not exist — they are
proven in isolation, not as part of a working feature. Of the 8 still-missing
units, every one is a full behavioral absence — not a partial implementation
— and together with the 15 missing backing-utility files they remove entire
categories of what a "system resource monitor" is for (process *management*
— you still cannot reach a kill/renice flow from the UI even though all
three of its dialogs now exist — GPU/NPU/network/drive telemetry, privileged
actions). Component parity for the **port as a whole** is not close: 17/25
widget units built, but 3 of those 17 are orphaned by a missing parent page,
so the number of units a user can actually *reach and use* is 14/25 (56%),
unchanged from the previous round in user-visible terms even though the
file count went up. The units requiring privilege separation, ColumnViews
or hardware-vendor branching (Processes, Applications, GPU, NPU, Drive,
Network) are all still open, and the Processes page specifically is now the
single highest-leverage gap: building it would retroactively make three
already-built, already-tested dialogs/cells reachable for free.
