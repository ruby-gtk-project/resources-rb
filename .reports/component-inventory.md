# Component inventory — resources-rb

Upstream read at `origin/main` (Rust/gtk-rs + GtkBuilder `.ui`), compared
against `lib/` on `ruby`. One row per component unit, in roughly the order a
user meets them: application, window, sidebar, pages, dialogs, widgets, then
backing utilities and non-code resources.

Legend: **kind** — `app` application object, `window` top-level window,
`page` a stack page, `dialog` a modal/presentational dialog, `row`/`cell` a
list-row or cell renderer, `widget` a reusable visual widget, `util` a
non-widget data/model class, `resource` a non-Ruby asset (schema, desktop
file, stylesheet, icon set, po catalogue).

## Application, window, chrome

| Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|
| `src/application.rs`, `src/bin/resources.rs` | `lib/resources/application.rb` | app | Yes |
| `src/application.rs` (`show_about_dialog`) | `lib/resources/about_dialog.rb` | dialog | Yes |
| `src/gui.rs` (clap `Args`) | `lib/resources/cli.rb` | util | Yes |
| `data/resources/ui/window.ui`, `src/ui/window.rs` | `lib/resources/main_window.rb` | window | Yes — wires CPU, Memory and (per-`sysfs_paths`) Battery pages into the sidebar; Applications, Processes, Drive, GPU, Network and NPU pages are still not instantiated here because they do not exist yet (see Pages) |
| `data/resources/ui/widgets/stack_sidebar.ui`, `src/ui/widgets/stack_sidebar.rs` | `lib/resources/stack_sidebar.rb` | widget | Yes |
| `data/resources/ui/widgets/stack_sidebar_item.ui`, `src/ui/widgets/stack_sidebar_item.rs` | `lib/resources/stack_sidebar_item.rb` | widget | Yes |
| `data/resources/ui/shortcuts.ui` | `lib/resources/shortcuts_dialog.rb` | dialog | Yes — its own comment notes the second shortcut section ("Apps/Processes") lists actions for views that do not exist yet in the port |

## Pages (`src/ui/pages/*`, `data/resources/ui/pages/*.ui`)

| Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|
| `src/ui/pages/cpu.rs`, `data/resources/ui/pages/cpu.ui` | `lib/resources/cpu_page.rb` | page | Yes |
| `src/ui/pages/memory.rs`, `data/resources/ui/pages/memory.ui` | `lib/resources/memory_page.rb` | page | Yes |
| `src/ui/pages/applications/mod.rs`, `src/ui/pages/applications/application_entry.rs`, `data/resources/ui/pages/applications.ui` | `lib/resources/applications_page.rb` (+ `lib/resources/application_entry.rb`) | page + row model | **No** |
| `src/ui/pages/processes/mod.rs`, `data/resources/ui/pages/processes.ui` | `lib/resources/processes_page.rb` | page | **No** — `process_entry.rb` (the row model) exists, but the page itself does not |
| `src/ui/pages/battery.rs`, `data/resources/ui/pages/battery.ui` | `lib/resources/battery_page.rb` | page | Yes — one instance per `Battery.sysfs_paths` entry, wired into `main_window.rb` |
| `src/ui/pages/drive.rs`, `data/resources/ui/pages/drive.ui` | `lib/resources/drive_page.rb` | page | **No** |
| `src/ui/pages/gpu.rs`, `data/resources/ui/pages/gpu.ui` | `lib/resources/gpu_page.rb` | page | **No** |
| `src/ui/pages/network.rs`, `data/resources/ui/pages/network.ui` | `lib/resources/network_page.rb` | page | **No** |
| `src/ui/pages/npu.rs`, `data/resources/ui/pages/npu.ui` | `lib/resources/npu_page.rb` | page | **No** |

## Row/cell widgets (`src/ui/pages/*/…`, `data/resources/ui/widgets/*.ui`)

| Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|
| `src/ui/pages/processes/process_entry.rs` | `lib/resources/process_entry.rb` | util (row model) | Yes |
| `src/ui/pages/processes/process_name_cell.rs`, `data/resources/ui/widgets/process_name_cell.ui` | `lib/resources/process_name_cell.rb` | cell | **No** |
| `src/ui/pages/applications/application_entry.rs` | `lib/resources/application_entry.rb` | util (row model) | **No** |
| `src/ui/pages/applications/application_name_cell.rs`, `data/resources/ui/widgets/application_name_cell.ui` | `lib/resources/application_name_cell.rb` | cell | **No** |

## Dialogs (`src/ui/dialogs/*`, `data/resources/ui/dialogs/*.ui`)

| Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|
| `data/resources/ui/dialogs/settings_dialog.ui`, `src/ui/dialogs/settings_dialog.rs` | `lib/resources/settings_dialog.rb` | dialog | Yes |
| `src/ui/pages/processes/mod.rs` + `src/ui/pages/applications/mod.rs` (shared `get_action_name`/`get_action_warning`/`get_action_description`/`connect_response` confirm-action helpers — not a `.ui` file of its own) | `lib/resources/process_action_dialog.rb` | dialog | Yes |
| `data/resources/ui/dialogs/process_dialog.ui`, `src/ui/dialogs/process_dialog.rs` | `lib/resources/process_dialog.rb` | dialog | **No** — distinct from `process_action_dialog.rb` above; this is the process-details dialog (name, CPU/memory/swap/drive/network/GPU usage rows), not the kill/stop/continue confirmation |
| `data/resources/ui/dialogs/process_options_dialog.ui`, `src/ui/dialogs/process_options_dialog.rs` | `lib/resources/process_options_dialog.rb` | dialog | **No** — the niceness/priority editor dialog |
| `data/resources/ui/dialogs/app_dialog.ui`, `src/ui/dialogs/app_dialog.rs` | `lib/resources/app_dialog.rb` | dialog | **No** — the application-details dialog (icon, name, usage rows), analogous to `process_dialog.rb` |

## Other widgets (`src/ui/widgets/*`, `data/resources/ui/widgets/*.ui`)

| Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|
| `src/ui/widgets/graph.rs` | `lib/resources/graph.rb` | widget | Yes |
| `src/ui/widgets/graph_box.rs`, `data/resources/ui/widgets/graph_box.ui` | `lib/resources/graph_box.rb` | widget | Yes |
| `src/ui/widgets/double_graph_box.rs`, `data/resources/ui/widgets/double_graph_box.ui` | `lib/resources/double_graph_box.rb` | widget | Yes |

## Backing utilities (`src/utils/*`) — not widgets, but data classes a page needs before it can be built

| Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|
| `src/utils/cpu.rs` | `lib/resources/cpu.rb` | util | Yes |
| `src/utils/memory.rs` | `lib/resources/memory.rb` | util | Yes |
| `src/utils/process.rs` | `lib/resources/process.rb` | util | Yes |
| `src/utils/os.rs` | `lib/resources/os.rb` | util | Yes |
| `src/utils/pci.rs` | `lib/resources/pci.rb` | util | Yes |
| `src/utils/units.rs` | `lib/resources/units.rb` | util | Yes |
| `src/utils/settings.rs` + `data/net.nokyan.Resources.gschema.xml.in` | `lib/resources/settings.rb` | util + resource | Yes — JSON-backed stand-in for GSettings; all ~50 schema keys are present in `Settings::DEFAULTS` |
| `src/utils/snapd.rs` | `lib/resources/snapd.rb` | util | Yes |
| `src/utils/app.rs` | `lib/resources/app.rb` | util | **No** — backs the Applications page |
| `src/utils/battery.rs` | `lib/resources/battery.rb` | util | Yes |
| `src/utils/drive.rs` | `lib/resources/drive.rb` | util | **No** — backs the Drive page |
| `src/utils/network.rs` | `lib/resources/network.rb` | util | **No** — backs the Network page |
| `src/utils/gpu/mod.rs`, `amd.rs`, `intel.rs`, `nvidia.rs`, `other.rs`, `v3d.rs` | `lib/resources/gpu.rb` (+ per-vendor files or branches) | util | **No** — backs the GPU page |
| `src/utils/npu/mod.rs`, `amd.rs`, `intel.rs`, `other.rs` | `lib/resources/npu.rb` | util | **No** — backs the NPU page |
| `src/utils/link/mod.rs`, `pcie.rs`, `sata.rs`, `usb.rs`, `wifi.rs` | `lib/resources/link.rb` | util | **No** — link-speed/type detection shared by Drive and Network pages |

## Non-Ruby resources

| Upstream file(s) | Kind | Status in port |
|---|---|---|
| `data/net.nokyan.Resources.gschema.xml.in` | resource (schema) | Covered functionally by `Settings::DEFAULTS` (JSON-backed); no `.gschema.xml` is compiled or needed since the port does not use real GSettings |
| `data/resources/style.css` | resource (stylesheet) | Ported to `lib/resources/style.rb` |
| `data/net.nokyan.Resources.desktop.in.in` | resource (desktop entry) | **No equivalent found in `lib/` or elsewhere in the port** |
| `data/net.nokyan.Resources.metainfo.xml.in.in` | resource (AppStream metadata) | **No equivalent found** |
| `data/net.nokyan.Resources.policy.in.in` | resource (polkit policy, used by `resources-adjust`/root helper) | **No equivalent found** — no root-helper binary (`src/bin/resources-adjust.rs`, `resources-kill.rs`, `resources-processes.rs`) has been ported either |
| `data/resources/resources.gresource.xml` | resource (GResource manifest) | Not applicable as a literal file — the Ruby house style never ships `.ui`/GResource bundles, each entry is instead the widget/dialog/page it names (tracked individually above) |
| `data/icons/*.svg`, `data/resources/icons/*.svg` | resource (icon assets) | Not checked for bitmap/SVG parity in this pass; every page/dialog above that is missing also needs its icon(s) carried over when built |
| `po/*.po`, `po/resources.pot`, `po/LINGUAS`, `po/POTFILES.in` | resource (i18n catalogue) | Out of scope for this component survey — see the `translation-parity` skill for a dedicated string-by-string census |

## Summary

- **Ported (13 files have a working lib/ counterpart):** application, about dialog,
  cli, main window, stack sidebar + item, shortcuts dialog, CPU page, memory
  page, battery page, graph / graph box / double graph box, settings dialog,
  settings, process entry, process action (confirm) dialog, os, pci, units,
  snapd, battery (util), process (util), cpu/memory (util).
- **Missing pages (6):** Applications, Processes, Drive, GPU, Network, NPU —
  none of these stack pages exist in `lib/` yet. `main_window.rb` now shows
  CPU, Memory and (per-battery) Battery pages.
- **Missing dialogs (3):** process details (`process_dialog.ui`), process
  niceness/priority editor (`process_options_dialog.ui`), application details
  (`app_dialog.ui`). These are distinct from the already-ported
  `process_action_dialog.rb` (the kill/stop/continue confirmation), which was
  the one dialog done.
- **Missing row/cell widgets (2):** `application_entry`/`application_name_cell`,
  `process_name_cell`.
- **Missing backing utilities (7 upstream modules, several multi-file):**
  `app`, `drive`, `network`, `gpu/*` (5 files), `npu/*` (4 files),
  `link/*` (5 files).
- **Missing non-code resources:** desktop entry, AppStream metainfo, polkit
  policy and the three root-helper binaries it authorizes; icon-asset parity
  unchecked; translation parity unchecked (separate skill).

This is a map of how much is left, not a plan — the next step is to pick one
unit (e.g. the Drive page, the simplest of the still-missing pages) and port
it following `.claude/skills/ruby-gtk`.
