# Resources — upstream component inventory

Upstream: `origin/main` (nokyan/resources, Rust + gtk-rs + libadwaita, GtkBuilder
`.ui` templates). Port: the `ruby` branch of this repo.

Method: the `component-identification` skill. Upstream declares almost all of
its widget trees in `data/resources/ui/**.ui`, so those files are the primary
inventory; the matching `src/ui/**.rs` file supplies the callbacks, the
installed actions, the runtime-built widgets (the ColumnView columns, the
per-device pages) and the dynamic CSS. **One component = the `.ui` file plus
its `.rs` file**, and that pair becomes one `lib/resources/*.rb`.

Mapping convention: the port is a gem, so files live under `lib/resources/`
(`lib/resources/application.rb` already corresponds to `src/application.rs`),
one upstream unit per file, `# frozen_string_literal: true` + `require
'adwaita'` + `require_relative` siblings, a comment naming the upstream file,
widgets as memoized accessors assembled in `build` with `.tap`.

## Totals

| | Upstream | `ruby` branch |
|---|---:|---:|
| `.ui` templates / named roots | 20 | 0 (none by design) |
| UI units ported (window, widgets, pages, dialogs) | 25 | 11 |
| GMenu models | 7 | 0 |
| GActions (`app.*`) | 10 | 4 (`quit`, `settings`, `shortcuts`, `about`) |
| GActions (`applications.*` / `processes.*`) | 8 + 10 | 0 |
| Accelerators | 9 bindings over 9 actions | 3 bindings over 2 actions |
| GSettings keys | 53 | 53 (file-backed `Resources::Settings`) |
| Translatable strings (`po/resources.pot`) | 403 | 0 |
| Locales (`po/LINGUAS`) | 40 | 0 |
| Bundled symbolic icons (GResource) | 41 | 0 |
| CSS classes defined in `data/resources/style.css` | 5 | 5 (`lib/resources/style.rb`) |

The `ruby` branch now has the application shell, the main window, the sidebar
and its item, the three graph widgets, the Processor and Memory pages, the
Preferences, Shortcuts and About dialogs, plus the settings, stylesheet, units,
CLI and the CPU and memory data layers. Still missing: both ColumnView pages
(Apps and Processes) with their entry models, name cells, context menus and
confirmation dialog; the five per-device pages (GPU, NPU, drive, network,
battery) and their data layers; the App, Process and Process Options dialogs;
the icon bundle; the gettext catalogue; and the privileged helpers. Each
component section below carries its own status.

## The user's path through the app

Window → sidebar → one of the pages (Apps, Processes, Processor, Memory, and one
page per GPU / NPU / drive / network interface / battery) → selection → bottom
action bar or right-click context menu → confirmation alert → toast; plus the
Information dialog, the Process Options dialog, Preferences, Shortcuts and
About off the primary menu.

---

## data/resources/ui/window.ui + src/ui/window.rs — the main window

→ `lib/resources/main_window.rb` (window). **Exists.**

| Widget | × | CSS | Signals / bindings | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (template `MainWindow`) | 1 | `devel` (dynamic, Devel profile only) | `close-request` → saves window size | 360×240 request; title "Resources" |
| `Adw.Breakpoint` | 1 | — | `max-width: 780sp` → `split_view.collapsed = True` | |
| `Gtk.Box` (vertical) | 1 | — | — | |
| `Adw.OverlaySplitView` `split_view` | 1 | — | source of `collapsed` / `show-sidebar` bindings | |
| `Adw.ToolbarView` (sidebar) | 1 | `undershoot-top` | — | |
| `Adw.HeaderBar` (sidebar) | 1 | — | — | |
| `Gtk.MenuButton` | 1 | — | `menu-model primary_menu` | `open-menu-symbolic`, a11y label "Open menu" |
| `ResStackSidebar` `resources_sidebar` | 1 | — | — | app widget, see below |
| `Gtk.Stack` `content_stack` | 1 | — | `set_visible_child` on sidebar selection | `vhomogeneous=False` |
| `Gtk.StackPage` | 4 static | — | — | Apps, Processes, Processor, Memory |
| `Adw.ToolbarView` (per page) | 4 static + N runtime | — | — | `add_page()` builds the runtime ones |
| `Adw.HeaderBar` (per page) | 4 static + N runtime | `flat` | — | |
| `Adw.WindowTitle` (per page) | 4 static + N runtime | — | — | `processor_window_title` gets a subtitle at runtime |
| `Gtk.ToggleButton` (sidebar reveal) | 4 static + N runtime | — | bound `visible`←`collapsed`, `active`↔`show-sidebar` | `sidebar-show-symbolic` |
| `Gtk.ToggleButton` `apps_search_button`, `processes_search_button` | 2 | — | `toggled` → page search bar | `search-symbolic`, a11y "Toggle search field" |
| `Gtk.EventControllerKey` | 1 | — | Escape closes search | controller, not a widget |
| `Adw.Toast` | repeater | — | — | success/failure of every process action |

Repeaters: one `Adw.ToolbarView` page per GPU (`init_gpu_pages`), per NPU
(`init_npu_pages`), per drive (`refresh_drive_pages`), per network interface
(`refresh_network_pages`), per battery (`refresh_battery_pages`), each added
and removed as hardware appears and disappears.

Menu `primary_menu` (3 items): Preferences → `app.settings`, Keyboard Shortcuts
→ `app.shortcuts`, About Resources → `app.about`.

Window-size persistence via `window-width`, `window-height`, `is-maximized`;
the last page is restored from `last-viewed-page`, and `--open-tab-id` overrides it.

## src/application.rs — the application

→ `lib/resources/application.rb` (application). **Exists.**

Installs 10 `app.*` actions: `quit`, `toggle-search`, `settings`, `about`,
`end-app-process`, `kill-app-process`, `halt-app-process`,
`continue-app-process`, `information-app-process`, `process-options`.
(`app.shortcuts` is referenced by the primary menu and by `shortcuts.ui` but is
not installed in `setup_gactions` — upstream relies on libadwaita's built-in
shortcuts action; the port must install it.)

Accelerators: `app.quit` `<Control>q`/`<Control>w`; `app.settings`
`<Control>comma`; `app.toggle-search` `<Control>f`/`F3`; `app.end-app-process`
`<Control>E`/`Delete`; `app.kill-app-process` `<Control>K`/`<Shift>Delete`;
`app.halt-app-process` `<Control>H`; `app.continue-app-process` `<Control>N`;
`app.information-app-process` `<Control>I`; `app.process-options` `<Control>O`.

Also: loads `style.css` as a display-wide `Gtk.CssProvider`, sets the default
icon name, and guards the Preferences dialog against being opened twice.

## src/application.rs (`show_about_dialog`) — About

→ `lib/resources/about_dialog.rb` (dialog). **Exists.**

`Adw.AboutDialog` ×1: application name "Resources", app icon, issue URL,
developer "nokyan", developers list, artists `["Avhiren"]`, GPL-3.0, version,
website, translator credits.

## data/resources/ui/shortcuts.ui — Keyboard Shortcuts

→ `lib/resources/shortcuts_dialog.rb` (dialog). **Exists.**

`Adw.ShortcutsDialog` ×1, `Adw.ShortcutsSection` ×2, `Adw.ShortcutsItem` ×10.
Section "General": Preferences, Show Shortcuts, Quit. Section "Apps/Processes":
Toggle Search Field, End App/Process, Kill App/Process, Halt App/Process,
Continue App/Process, Show Information for App/Process, Show Process Options.
Each item carries an `action-name`, so the accelerators come from the app.

## data/resources/ui/widgets/stack_sidebar.ui + src/ui/widgets/stack_sidebar.rs

→ `lib/resources/stack_sidebar.rb` (widget). **Exists.**

`Adw.Bin` (template `ResStackSidebar`) → `Gtk.ScrolledWindow` →
`Gtk.Viewport` → `Gtk.ListBox` `list_box` (`navigation-sidebar`,
`selection_mode=single`). Signals: `selected-rows-changed` → switches
`content_stack`; a `set_sort_func` orders rows by the page's primary ord
(Apps 0, Processes 1, CPU 2, Memory 3, GPU 4, NPU 5, Drive 6, Network 7,
Battery 8). Repeater: one `Gtk.ListBoxRow` per `Gtk.StackPage`, rebuilt on
`populate_list` while carrying the previous graph data points across.

## data/resources/ui/widgets/stack_sidebar_item.ui + stack_sidebar_item.rs

→ `lib/resources/stack_sidebar_item.rb` (widget). **Exists.**

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Adw.Bin` (template `ResStackSidebarItem`) | 1 | `sidebar-item` | margins 12/12/8/8 |
| `Gtk.Box` | 2 | — | vertical outer, horizontal header |
| `Gtk.Image` `image` | 1 | — | 16px device icon |
| `Gtk.Label` `label` | 1 | — | device name, ellipsize end |
| `Gtk.Label` `detail_label` | 1 | `caption` | shown when `sidebar-description` |
| `Gtk.Label` `usage_label` | 1 | `subtitle` | shown when `sidebar-details` |
| `Gtk.ProgressBar` `progress_bar` | 1 | `slim` | when `sidebar-meter-type = Bar` |
| `ResGraph` `graph` | 1 | `small-graph` | when `sidebar-meter-type = Graph`, 80px |

## src/ui/widgets/graph.rs — the graph

→ `lib/resources/graph.rb` (widget). **Exists.**

A `Gtk.Widget` subclass (`ResGraph`) that overrides `snapshot`, appends a Cairo
context and plots with the `plotters` crate: a ring of data points, settable
graph colour, optional locked max-Y, optional grid (`show-graph-grids`), and
`graph-data-points` points of history. No `.ui` file. CSS classes come from its
users: `graph`, `small-graph`. In Ruby this is a `Gtk::DrawingArea` with a
`set_draw_func` doing the Cairo work by hand.

## data/resources/ui/widgets/graph_box.ui + graph_box.rs

→ `lib/resources/graph_box.rb` (widget). **Exists.**

`Adw.PreferencesRow` (template `ResGraphBox`, `activatable=false`, 160px) with a
suffix `Gtk.Box` holding `ResGraph` `graph` (`graph`, 120px), `Gtk.Label`
`title_label` (`subtitle`) and `Gtk.Label` `info_label` (selectable). Used 14×
across the pages.

## data/resources/ui/widgets/double_graph_box.ui + double_graph_box.rs

→ `lib/resources/double_graph_box.rb` (widget). **Exists.**

Same shape with two side-by-side columns: `ResGraph` `start_graph` / `end_graph`
(both `graph`), `start_title_label` / `end_title_label` (`subtitle`),
`start_info_label` / `end_info_label` (selectable). Used once, for GPU
encode/decode.

## data/resources/ui/pages/applications.ui + src/ui/pages/applications/mod.rs

→ `lib/resources/applications_page.rb` (page). **Missing.**

| Widget | × | CSS | Signals / actions |
|---|---:|---|---|
| `Adw.Bin` (template `ResApplications`) | 1 | `devel` (dynamic) | — |
| `Gtk.PopoverMenu` `popover_menu` | 1 | — | `app_context_menu`; `set_parent(self)`, popped up by a right-click `Gtk.GestureClick` on every cell |
| `Adw.ToolbarView` | 1 | — | — |
| `Gtk.SearchBar` `search_bar` | 1 | — | toggled by the header button and `app.toggle-search` |
| `Gtk.SearchEntry` `search_entry` | 1 | — | `search-changed` → `FilterChange`; a11y "Search applications" |
| `Adw.ToastOverlay` `toast_overlay` | 1 | — | receives every action toast |
| `Gtk.ScrolledWindow` `applications_scrolled_window` | 1 | — | hosts the ColumnView |
| `Gtk.ColumnView` (runtime) | 1 | `resources-columnview` | `SingleSelection` over `SortListModel`→`FilterListModel`→`Gio.ListStore` of `ApplicationEntry`; sorter persisted to `apps-sort-by` / `apps-sort-by-ascending` |
| `Gtk.ColumnViewColumn` (runtime) | 12 | — | App (name cell) + Memory, Processor, Drive Read, Drive Read Total, Drive Write, Drive Write Total, GPU, Video Memory, Video Encoder, Video Decoder, Swap, Combined Memory — each `visible` bound to its GSetting |
| `Gtk.Inscription` (runtime, per cell) | repeater | — | the cell widget for every non-name column; a11y label "`<column>`: `<value>`" |
| `Gtk.Button` `information_button` | 1 | `circular` | `info-symbolic`, insensitive until a row is selected |
| `Adw.SplitButton` `end_application_button` | 1 | `destructive-action` | label "End App", `end_app_menu`, insensitive until selection |
| `Gtk.EventControllerKey` | 1 | — | Escape closes search |
| `Gtk.GestureClick` | repeater | — | secondary click on a cell → context popover |

Menus: `end_app_menu` (3 items → `applications.kill-app`, `.halt-app`,
`.continue-app`); `app_context_menu` (5 items → `applications.context-end-app`,
`.context-kill-app`, `.context-halt-app`, `.context-continue-app`,
`.context-information`). Actions installed on the class: all 8 of those names.

## src/ui/pages/applications/application_entry.rs

→ `lib/resources/application_entry.rb` (model). **Missing.**

A `GObject` with the properties the columns bind to: name, icon, id, memory,
cpu, drive read/write speed and total, GPU, VRAM, encoder, decoder, swap,
combined memory, running-since, running-processes, containerized. Not a widget,
but the ColumnView cannot exist without it.

## src/ui/pages/applications/application_name_cell.rs + ui/widgets/application_name_cell.ui

→ `lib/resources/application_name_cell.rb` (widget). **Missing.**

`Gtk.Box` (template `ResApplicationNameCell`, spacing 12) with `Gtk.Image`
`image` (32px, `lowres-icon`) and `Gtk.Inscription` `inscription`
(min-chars 12, text-overflow ellipsize-end).

## data/resources/ui/pages/processes.ui + src/ui/pages/processes/mod.rs

→ `lib/resources/processes_page.rb` (page). **Missing.**

Same shape as Apps, with multi-selection:

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Adw.Bin` (template `ResProcesses`) | 1 | `devel` (dynamic) | |
| `Gtk.PopoverMenu` `popover_menu`, `popover_menu_multiple` | 2 | — | single- and multi-selection context menus |
| `Gtk.SearchBar` / `Gtk.SearchEntry` | 1 / 1 | — | a11y "Search processes" |
| `Adw.ToastOverlay` `toast_overlay` | 1 | — | |
| `Gtk.ScrolledWindow` `processes_scrolled_window` | 1 | — | |
| `Gtk.ColumnView` (runtime) | 1 | `resources-columnview` | multi-selection; sorter persisted to `processes-sort-by*` |
| `Gtk.ColumnViewColumn` (runtime) | 19 | — | Process (name cell), Process ID, User, Memory, Processor, Drive Read, Drive Read Total, Drive Write, Drive Write Total, GPU, Video Memory, Video Encoder, Video Decoder, Total CPU Time, User CPU Time, System CPU Time, Priority, Swap, Combined Memory, Commandline |
| `Gtk.Button` `options_button` | 1 | `circular` | `options-symbolic` |
| `Gtk.Button` `information_button` | 1 | `circular` | `info-symbolic` |
| `Adw.SplitButton` `end_process_button` | 1 | `destructive-action` | "End Process"; its menu swaps to `end_process_menu_multiple` on multi-select |

Menus (4): `end_process_menu`, `end_process_menu_multiple`,
`process_context_menu` (6 items incl. Options and Information),
`process_context_menu_multiple` (4 items). Actions installed: 10
(`processes.end-process`, `.kill-process`, `.halt-process`,
`.continue-process`, `.context-end-process`, `.context-kill-process`,
`.context-halt-process`, `.context-continue-process`, `.context-options`,
`.context-information`). The Priority column renders either a niceness number
or one of five labels depending on `detailed-priority` / `processes-niceness`.

## src/ui/pages/processes/process_entry.rs

→ `lib/resources/process_entry.rb` (model). **Missing.** The per-process
GObject behind the 19 columns (pid, user, cgroup, commandline, niceness,
affinity, the usage figures, CPU times).

## src/ui/pages/processes/process_name_cell.rs + ui/widgets/process_name_cell.ui

→ `lib/resources/process_name_cell.rb` (widget). **Missing.**
`Gtk.Box` (template `ResProcessNameCell`) + `Gtk.Image` (16px, `lowres-icon`) +
`Gtk.Inscription` (min-chars 12).

## Shared confirmation dialog (applications/mod.rs + processes/mod.rs)

→ `lib/resources/process_action_dialog.rb` (dialog). **Missing.**

`Adw.AlertDialog` ×1 built identically in both pages: heading "End <name>?" /
"Kill…" / "Halt…", body one of three warnings ("Unsaved work might be lost.",
the halt warning, the kill warning), responses `yes` (destructive, labelled End
App / Halt App / Kill App / …) and `no` ("Cancel", default and close response).
Continue skips the dialog. Worth one file, used by both pages.

## data/resources/ui/pages/cpu.ui + src/ui/pages/cpu.rs — Processor

→ `lib/resources/cpu_page.rb` (page). **Exists.**

`Adw.Bin` (`ResCPU`) → `Gtk.ScrolledWindow` → `Adw.Clamp` (768) → `Gtk.Box`.
Group "Options" with `Adw.SwitchRow` `logical_switch` ("Show Usages of Logical
CPUs", bound to `show-logical-cpus`, insensitive until data arrives); a
`Gtk.Stack` `stack` switching between `total_page` (group "Usage" with
`ResGraphBox` `total_cpu`) and `logical_page` (`Gtk.Label` "Usage"
`heading`+`h4`, `Gtk.FlowBox` `thread_box` homogeneous, selection none, a11y
"CPU usage by logical processors", one `ResGraphBox` per logical CPU —
repeater); group "Sensors" with `ResGraphBox` `temperature`; group "Properties"
with 7 `Adw.ActionRow` (`property`, subtitle-selectable): Max Frequency,
Logical Cores, Physical Cores, Sockets, Uptime, Virtualization, Architecture.
`normalize-cpu-usage` changes the usage figure.

## data/resources/ui/pages/memory.ui + src/ui/pages/memory.rs — Memory

→ `lib/resources/memory_page.rb` (page). **Exists.**

`Adw.Bin` (`ResMemory`) → `Gtk.Box` with `Adw.Banner`
`authentication_banner` ("You need to authenticate to see memory properties",
button "Authenticate", `button-clicked` → `pkexec dmidecode`, revealed only
when the properties are unavailable) above a `Gtk.ScrolledWindow` →
`Adw.Clamp` (768) → `Gtk.Box`: group "Usage" with `ResGraphBox` `memory` and
`swap`; group "Properties" `properties` with 5 `Adw.ActionRow` (`property`):
Slots Used, Speed, Form Factor, Type, Type Detail. This banner is the app's
only error/permission state.

## data/resources/ui/pages/gpu.ui + src/ui/pages/gpu.rs — GPU (per device)

→ `lib/resources/gpu_page.rb` (page). **Missing.**

Group "Usage": `ResGraphBox` `gpu_usage`, `ResDoubleGraphBox`
`encode_decode_usage`, `ResGraphBox` `encode_decode_combined_usage`,
`ResGraphBox` `vram_usage`, plus `Adw.ActionRow` `gpu_clockspeed`,
`vram_clockspeed`, `power_usage`. Group "Sensors": `ResGraphBox` `temperature`.
Group "Properties": `Adw.ActionRow` `manufacturer`, `pci_slot`, `driver_used`,
`max_power_cap`, `link`. All rows `property` + subtitle-selectable. Which of
the encode/decode boxes is shown depends on whether the driver reports them
separately.

## data/resources/ui/pages/npu.ui + src/ui/pages/npu.rs — NPU (per device)

→ `lib/resources/npu_page.rb` (page). **Missing.**

Group "Usage": `ResGraphBox` `npu_usage`, `memory_usage`; `Adw.ActionRow`
`npu_clockspeed`, `tops` ("Performance"), `memory_clockspeed`, `power_usage`.
Group "Sensors": `ResGraphBox` `temperature`. Group "Properties":
`manufacturer`, `pci_slot`, `driver_used`, `max_power_cap`, `link`.

## data/resources/ui/pages/drive.ui + src/ui/pages/drive.rs — Drive (per device)

→ `lib/resources/drive_page.rb` (page). **Missing.**

Group "Usage": `ResGraphBox` `total_usage`, `read_speed`, `write_speed`;
`Adw.ActionRow` `total_read`, `total_written`. Group "Properties" `modules`:
`drive_type`, `device`, `capacity`, `writable`, `removable`, `link`. Pages
appear and disappear with the hardware; virtual drives only when
`show-virtual-drives`.

## data/resources/ui/pages/network.ui + src/ui/pages/network.rs — Network (per interface)

→ `lib/resources/network_page.rb` (page). **Missing.**

Group "Usage": `ResGraphBox` `receiving`, `sending`; `Adw.ActionRow`
`total_received`, `total_sent`. Group "Properties": `manufacturer`, `driver`,
`interface`, `hw_address`, `network_name`, `link`, `link_speed`. Speeds switch
to bits/s with `network-bits`; virtual interfaces only when
`show-virtual-network-interfaces`.

## data/resources/ui/pages/battery.ui + src/ui/pages/battery.rs — Battery (per device)

→ `lib/resources/battery_page.rb` (page). **Missing.**

Group "Usage": `ResGraphBox` `charge`, `power_usage`. Group "Properties"
`modules`: `health`, `design_capacity`, `charge_cycles`, `technology`,
`manufacturer`, `model_name`, `device`.

## data/resources/ui/dialogs/app_dialog.ui + src/ui/dialogs/app_dialog.rs

→ `lib/resources/app_dialog.rb` (dialog). **Missing.**

`Adw.Dialog` (template `ResAppDialog`, title "App Information") →
`Adw.ToolbarView` → `Adw.HeaderBar` + `Adw.WindowTitle` → `Gtk.ScrolledWindow`
→ `Adw.Clamp` → `Gtk.Box`: `Gtk.Image` `icon` (`icon-dropshadow`),
`Gtk.Label` `name` (`title-2`), `Gtk.Label` `description` (`dim-label`);
group "Usage" with 11 `Adw.ActionRow` (Processor, Memory, Swap, Drive Read,
Drive Read Total, Drive Write, Drive Write Total, GPU, Video Memory, Video
Encoder, Video Decoder); group "Properties" with 4 (ID, Running Since, Running
Processes, Containerized). All `property` + subtitle-selectable. A
`Gtk.ShortcutController` with one `Gtk.Shortcut` binding Escape to
`window.close`.

## data/resources/ui/dialogs/process_dialog.ui + process_dialog.rs

→ `lib/resources/process_dialog.rb` (dialog). **Missing.**

`Adw.Dialog` (`ResProcessDialog`, "Process Information"), same frame, no icon:
`Gtk.Label` `name` (`title-2`); group "Usage" with 14 `Adw.ActionRow`
(the eleven above plus Total/User/System CPU Time); group "Properties" with 6
(Process ID, Running Since, Commandline, User, Control Group, Containerized).
Escape → `window.close` via `Gtk.ShortcutController`.

## data/resources/ui/dialogs/process_options_dialog.ui + process_options_dialog.rs

→ `lib/resources/process_options_dialog.rb` (dialog). **Missing.**

`Adw.Dialog` (`ResProcessOptionsDialog`, "Process Options") → `Adw.ToolbarView`
with a bottom `Gtk.Box` holding `Gtk.Button` `apply_button` ("Apply", `pill` +
`suggested-action`); content: `Gtk.Label` `name` (`title-2`); group "Process
Options" with `Adw.SpinRow` `nice_row` (its own `Gtk.Adjustment`, −20…19),
`Adw.ComboRow` `priority_row` over a `Gtk.StringList` of five labels (Very
High, High, Normal, Low, Very Low), and `Adw.ExpanderRow` `affinity_row`
("Processor Affinity") with a suffix `Gtk.Button` `select_all_button`
(`select-all-symbolic`, flat, "Toggle All") and one `Adw.SwitchRow` per logical
CPU added at runtime (repeater). Niceness vs. priority presentation follows
`processes-niceness` / `detailed-priority`. Escape → `window.close`.

## data/resources/ui/dialogs/settings_dialog.ui + settings_dialog.rs — Preferences

→ `lib/resources/settings_dialog.rb` (dialog). **Exists.**

`Adw.PreferencesDialog` (template `ResSettingsDialog`), 4 `Adw.PreferencesPage`:

- **General** (`generic-settings-symbolic`) — group "Units": `Adw.ComboRow`
  `prefix_combo_row` (Decimal/Binary), `Adw.SwitchRow` `network_bits_row`,
  `Adw.ComboRow` `temperature_combo_row` (Celsius/Kelvin/Fahrenheit). Group
  "User Interface": `Adw.ComboRow` `refresh_speed_combo_row` (five speeds),
  `Adw.SwitchRow` `show_graph_grids_row`, `Adw.SpinRow`
  `graph_data_points_row`, `Adw.SwitchRow` `sidebar_details_row`,
  `sidebar_description_row`, `Adw.ComboRow` `sidebar_meter_type_row`
  (Bar/Graph), `Adw.SwitchRow` `normalize_cpu_usage_row`.
- **Apps** (`app-symbolic`) — group "Information Columns": 12 `Adw.SwitchRow`.
- **Processes** (`generic-process-symbolic`) — group "Options": `Adw.SwitchRow`
  `processes_niceness`; group "Information Columns": 18 `Adw.SwitchRow`.
- **Devices** (`device-settings-symbolic`) — groups "Drives" and "Network
  Interfaces": `Adw.SwitchRow` `show_virtual_drives_row`,
  `show_virtual_network_interfaces_row`.

Every row is two-way bound to a GSettings key.

## Non-widget units

| Upstream | → port | Kind |
|---|---|---|
| `data/net.nokyan.Resources.gschema.xml.in` + `src/utils/settings.rs` | `lib/resources/settings.rb` | settings (53 keys, change notification per key) — **exists** |
| `data/resources/style.css` | `lib/resources/style.rb` | stylesheet (`progressbar.slim`, `.resources-columnview`, `.bubble`, `.big-bubble`, `.small-graph`, `.graph`) — **exists** |
| `data/resources/icons/*.svg` (41) + `resources.gresource.xml` | `lib/resources/icons.rb` + `data/icons/` | resources (device/type icons the sidebar and cells name) — **missing** |
| `src/i18n.rs` + `po/` (40 locales, 403 strings) | `lib/resources/i18n.rb` + `po/` | i18n — **missing** |
| `src/utils/units.rs` | `lib/resources/units.rb` | formatting (every label's text) — **exists** |
| `src/utils/{app,process,cpu,memory,drive,network,battery,gpu/*,npu/*,link/*,pci,os,snapd}.rs`, `lib/process_data/` | `lib/resources/*.rb` | data layer (reads `/proc`, `/sys`, sysfs, udev, DMI) — **`cpu.rb` and `memory.rb` exist, the rest missing** |
| `src/bin/resources-{processes,kill,adjust}.rs`, `*.policy.in.in` | `lib/resources/privileged.rb` + polkit policy | privileged helpers (kill/renice/affinity, root process data) — **missing** |
| `src/gui.rs` (clap `Args`) | `lib/resources/cli.rb` + `exe/resources` | CLI (`--disable-*-monitoring`, `--no-suspend-pause`, `--open-tab-id`) — **exists** |

## Blockers and risks

1. ~~**`ResGraph` has no Ruby equivalent.**~~ **Resolved.**
   `lib/resources/graph.rb` is a `Gtk::DrawingArea` with a hand-written Cairo
   `set_draw_func` (grid, fill, line, locked max-Y), and `graph_box.rb` /
   `double_graph_box.rb` wrap it. Everything visual in the app leans on it: 14
   `ResGraphBox`, 1 `ResDoubleGraphBox`, 1 per sidebar row, 1 per logical CPU.
2. **The data layer is the bulk of the work and has no GTK in it.** ~5 500
   lines of Rust under `src/utils/` and `lib/process_data/` read `/proc`,
   `/sys`, sysfs, DMI, NVML, PCI IDs and snapd. None of it is ported, and every
   page is empty without it.
3. **Privileged operations.** Killing, renicing and setting affinity go through
   `resources-kill` / `resources-adjust` and a polkit policy; memory properties
   go through `pkexec dmidecode`. The Ruby port needs its own story here, and
   none of it can be exercised under `xvfb-run` in this sandbox.
4. ~~**No GSettings schema on the `ruby` branch.**~~ **Resolved.**
   `lib/resources/settings.rb` is a file-backed object carrying all 53 keys,
   upstream's defaults and a per-key change callback, so no compiled schema has
   to be installed into the dev shell.
5. **No gettext wiring.** 403 strings across 40 locales, with msgctxt contexts
   ("shortcut window", "process priority", "UI refresh speed") and plural forms
   in the toast messages. `translation-parity` cannot run until the port has a
   catalogue.
6. **Bundled icons.** 41 symbolic SVGs are referenced by name from the sidebar,
   the cells and the Preferences pages; without a GResource or an icon search
   path they all render as missing-image.
7. **Bindings checked and clear.** In the fork's dev shell (GTK 4.22.4) every
   type this port needs resolves: `Gtk::ColumnView`, `ColumnViewColumn`,
   `SignalListItemFactory`, `Inscription`, `NumericSorter`, `StringSorter`,
   `PropertyExpression`, `FilterListModel`, `SortListModel`, `CustomFilter`,
   `CustomSorter`, `PopoverMenu`, `GestureClick`, `FlowBox`, `SearchBar`,
   `Adwaita::{Breakpoint, OverlaySplitView, ToolbarView, ToastOverlay, Toast,
   Banner, SplitButton, AlertDialog, Dialog, PreferencesDialog, SpinRow,
   ComboRow, ExpanderRow, SwitchRow, ShortcutsDialog, ShortcutsSection,
   ShortcutsItem, AboutDialog, PreferencesRow, WindowTitle, Clamp, Bin}`. A
   `GLib::Object` subclass with `type_register` + `install_property` + an
   `attr_accessor` per property works and can be put in a `Gio::ListStore` and
   read by a `Gtk::PropertyExpression`, so the two ColumnViews are feasible —
   note that `install_property` alone is not enough, the accessor must exist.
   Settled: `Adwaita::ApplicationWindow` is unusable, so `main_window.rb` uses
   a `Gtk::ApplicationWindow` holding an `Adwaita::BreakpointBin`, which takes
   the `Adwaita::Breakpoint` upstream puts on its `Adw.ApplicationWindow`.
8. **Scale.** 25 upstream UI source files and 20 templates; 11 UI units are
   ported. The two ColumnView pages (Apps, Processes) with their entry models,
   name cells, menus and action plumbing are the largest remaining items, then
   the five per-device pages and their data layers.
