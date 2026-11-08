# Component identification — resources-rb (refresh 2)

This supersedes `.reports/component-inventory.md` and the previous version of
this file where they disagree. Both predate commit `6eac7de` ("Port the
process name cell and the process detail/options dialogs"), which built three
more units that the previous pass of this report listed as missing (rows 9,
10, 24 below). This pass re-reads `lib/` as it stands at `6eac7de` against
`origin/main` and corrects those three rows, then restates the rest with
fresh counts.

Method: `git ls-tree -r --name-only origin/main`, read every `src/ui/**`,
`src/utils/**` and `data/resources/ui/**/*.ui` file against the corresponding
`lib/resources/*.rb`, applying the unit boundary from the
`component-identification` skill (one window/page/dialog/widget class = one
unit, upstream source file(s) + its `.ui` joined before comparing).

## Units found upstream (one row per top-level widget/app class or standalone `.ui`)

| # | Unit | Upstream file(s) | Port file | Status |
|---|---|---|---|---|
| 1 | Application | `src/application.rs`, `src/bin/resources.rs` | `lib/resources/application.rb` | **built** |
| 2 | Main window | `src/ui/window.rs`, `data/resources/ui/window.ui` | `lib/resources/main_window.rb` | **built, partial** — only wires Apps-slot-equivalent CPU, Memory, Battery(×N) pages into the stack; 6 of 9 upstream stack pages never get a `content_stack.add_named` call |
| 3 | Stack sidebar | `src/ui/widgets/stack_sidebar.rs` + `.ui` | `lib/resources/stack_sidebar.rb` | built |
| 4 | Stack sidebar item | `src/ui/widgets/stack_sidebar_item.rs` + `.ui` | `lib/resources/stack_sidebar_item.rb` | built |
| 5 | Shortcuts window | `data/resources/ui/shortcuts.ui` (no `.rs`, standalone) | `lib/resources/shortcuts_dialog.rb` | built, **but lists shortcuts for the Apps/Processes pages that don't exist in the port**, so some rows describe behavior the app cannot perform |
| 6 | About dialog | `src/application.rs` (`show_about_dialog`) | `lib/resources/about_dialog.rb` | built |
| 7 | Settings/Preferences dialog | `src/ui/dialogs/settings_dialog.rs` + `.ui` | `lib/resources/settings_dialog.rb` | built — all 53 schema keys present in `Settings::DEFAULTS` (verified: `grep -c '"[a-z-]*" =>' lib/resources/settings.rb` → 53, upstream `grep -c '<key ' data/net.nokyan.Resources.gschema.xml.in` → 53) |
| 8 | Process action (confirm kill/stop/continue) dialog | `src/ui/pages/processes/mod.rs` + `applications/mod.rs` shared helpers (no standalone `.ui`) | `lib/resources/process_action_dialog.rb` | built |
| 9 | Process details dialog | `src/ui/dialogs/process_dialog.rs`, `data/resources/ui/dialogs/process_dialog.ui` | `lib/resources/process_dialog.rb` | **built** (commit `6eac7de`) — not reachable from any page yet (see row 16), driven directly in `test/drive_resources.rb` |
| 10 | Process options (niceness/affinity) dialog | `src/ui/dialogs/process_options_dialog.rs`, `.ui` | `lib/resources/process_options_dialog.rb` | **built** (commit `6eac7de`), backed by new `Process#affinity`/`#set_affinity` reading `/proc`'s `Cpus_allowed` mask and shelling out to `taskset` — same reachability caveat as row 9 |
| 11 | **App details dialog** | `src/ui/dialogs/app_dialog.rs`, `data/resources/ui/dialogs/app_dialog.ui` | — | **missing** |
| 12 | CPU page | `src/ui/pages/cpu.rs` + `.ui` | `lib/resources/cpu_page.rb` | built |
| 13 | Memory page | `src/ui/pages/memory.rs` + `.ui` | `lib/resources/memory_page.rb` | built |
| 14 | Battery page | `src/ui/pages/battery.rs` + `.ui` | `lib/resources/battery_page.rb` | **built** (this is the correction — the stale inventory says "No") |
| 15 | **Applications page** | `src/ui/pages/applications/mod.rs` + `.ui` | — | **missing** (no `applications_page.rb`) |
| 16 | **Processes page** | `src/ui/pages/processes/mod.rs` + `.ui` | — | **missing** (`process.rb`/`process_entry.rb`/`process_action_dialog.rb` exist as backing pieces, but no page assembles them into a ColumnView) |
| 17 | **Drive page** | `src/ui/pages/drive.rs` + `.ui` | — | **missing** |
| 18 | **GPU page** | `src/ui/pages/gpu.rs` + `.ui` | — | **missing** |
| 19 | **Network page** | `src/ui/pages/network.rs` + `.ui` | — | **missing** |
| 20 | **NPU page** | `src/ui/pages/npu.rs` + `.ui` | — | **missing** |
| 21 | Graph | `src/ui/widgets/graph.rs` | `lib/resources/graph.rb` | built |
| 22 | Graph box | `src/ui/widgets/graph_box.rs` + `.ui` | `lib/resources/graph_box.rb` | built |
| 23 | Double graph box | `src/ui/widgets/double_graph_box.rs` + `.ui` | `lib/resources/double_graph_box.rb` | built |
| 24 | Process name cell | `src/ui/pages/processes/process_name_cell.rs` + `.ui` | `lib/resources/process_name_cell.rb` | **built** (commit `6eac7de`) — icon + elided name; has no `GtkColumnView` column to be installed into, since row 16 (Processes page) is still missing, so it is driven directly rather than through a live column |
| 25 | **Application name cell** | `src/ui/pages/applications/application_name_cell.rs` + `.ui` | — | **missing** |

### Backing (non-widget) utility classes

| Upstream | Port | Status |
|---|---|---|
| `src/utils/cpu.rs` | `cpu.rb` | built |
| `src/utils/memory.rs` | `memory.rb` | built |
| `src/utils/battery.rs` | `battery.rb` | **built** (correction from stale inventory) |
| `src/utils/process.rs` | `process.rb` | built |
| `src/utils/os.rs`, `pci.rs`, `units.rs`, `settings.rs`, `snapd.rs` | `os.rb`, `pci.rb`, `units.rb`, `settings.rb`, `snapd.rb` | built |
| `src/utils/app.rs` | — | **missing** |
| `src/utils/drive.rs` | — | **missing** |
| `src/utils/network.rs` | — | **missing** |
| `src/utils/gpu/{mod,amd,intel,nvidia,other,v3d}.rs` (6 files) | — | **missing**, all 6 |
| `src/utils/npu/{mod,amd,intel,other}.rs` (4 files) | — | **missing**, all 4 |
| `src/utils/link/{mod,pcie,sata,usb,wifi}.rs` (5 files) | — | **missing**, all 5 — shared by Drive and Network pages |

### Non-code resources

| Upstream | Port | Status |
|---|---|---|
| `data/net.nokyan.Resources.desktop.in.in` | — | **missing** |
| `data/net.nokyan.Resources.metainfo.xml.in.in` | — | **missing** |
| `data/net.nokyan.Resources.policy.in.in` + `src/bin/resources-{adjust,kill,processes}.rs` (polkit-authorized root helpers) | — | **missing**, all 4 |
| `data/resources/style.css` | `lib/resources/style.rb` | built |
| `po/*.po` (42 locales), `po/resources.pot` (391 msgids) | — | **missing entirely** — see `.reports/translation-parity.md` |

## Totals

- **25 widget/dialog/page units identified upstream** (app, window, 2 sidebar
  widgets, shortcuts window, 3 dialogs built + 3 missing dialogs [now 1
  missing], 9 pages (3 built + 6 missing), 3 widgets built, 2 cells [now 1
  built + 1 missing]).
- **Built: 17** (app, window, sidebar×2, shortcuts, about, settings,
  process-action dialog, process-details dialog, process-options dialog,
  cpu/memory/battery pages, graph/graph_box/double_graph_box,
  process-name-cell).
- **Missing: 8** (app-details dialog, applications page, processes page,
  drive page, gpu page, network page, npu page, application-name-cell).
- **Backing utils missing: 15 upstream `.rs` files** (app, drive, network,
  6×gpu, 4×npu, 5×link — gpu and npu count their mod.rs) — unchanged by this
  commit; `process.rb` gained `#affinity`/`#set_affinity` but that is an
  addition to an already-built file, not a new backing-util unit.
- **Non-code resources missing: desktop entry, metainfo, polkit policy, 3
  root-helper binaries, and the entire po/ catalogue.** Unchanged.

The runtime gate for this round reports **68 checks passed, 0 failed,
covering 18 components** (re-run live in this audit: `nix develop --command
xvfb-run -a ruby test/drive_resources.rb` → `68 of 68 checks passed, DRIVE
OK`, confirmed byte-for-byte against the gate's numbers). That is **off by
one against this report's own built-unit count of 17**: the drive script's
"18 components" most likely counts `Resources::Process` (the backing-util
model class, exercised directly for the affinity round-trip) as a component
alongside the 17 widget/dialog/page units above, which this report's unit
boundary (per the `component-identification` skill: top-level widget
classes and the app class, not backing data classes) does not. This is a
counting-convention difference, not a hidden extra widget — re-reading
`test/drive_resources.rb` finds no 18th widget unit, built or driven, beyond
the 17 listed here. Either way, **17 or 18, the gate is exhaustive only over
what exists, and what exists is 17 of 25 identified widget/dialog/page units
(68%)** — the remaining 32% (8 units, plus all 15 backing-utility files and
all non-code resources) has no component to check yet, let alone a check
that runs. A component the gate never reaches is unverified, not done.
