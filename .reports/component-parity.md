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
4. **Process-details and app-details dialogs are unreachable** (both the
   dialog file and the page that would open it are missing).
5. **Process-options (niceness/priority) dialog is missing** — upstream lets
   a user renice a process; the port has no path to this at all.
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

Of the 14 built units, parity holds for what each one actually does, with
two caveats worth flagging on their own: the Battery page's wiring into the
sidebar is read, not observed, on this machine, and the Settings dialog's
round-trip check covers 3 of 53 keys. Of the 11 missing units, every one is
a full behavioral absence — not a partial implementation — and together
with the 15 missing backing-utility files they remove entire categories of
what a "system resource monitor" is for (process management, GPU/NPU/
network/drive telemetry, privileged actions). Component parity for the
**port as a whole** is not close: 14/25 widget units, and the 14 that exist
skew toward the simplest pages (CPU, Memory, Battery) while the ones
requiring privilege separation, ColumnViews or hardware-vendor branching
(Processes, Applications, GPU, NPU, Drive, Network) are all still open.
