# Drive verification — resources-rb

Ran `nix develop --command xvfb-run -a ruby test/drive_resources.rb` (also
reachable as the dev shell's own `xvfb-run ruby test/drive_*.rb`, now that it
is the only `test/drive_*.rb` file). Result: **43 of 43 checks passed,
`DRIVE OK`**, 8 screenshots written under `tmp/shots/` (gitignored).

## What it covers

Every component the `ruby` branch currently builds:

- `Resources::Application` / `Resources::MainWindow`: window title, the
  breakpoint bin, the split view's `collapsed` ↔ sidebar-toggle binding.
- `Resources::StackSidebar` / `StackSidebarItem`: both rows present, tab
  selection switches the content stack both ways.
- `Resources::CpuPage`: the logical-CPU switch flips the internal stack, one
  thread `GraphBox` per `Etc.nprocessors`, a live usage string and at least
  one pushed graph point after a real refresh tick.
- `Resources::MemoryPage`: the authentication banner's revealed state is the
  logical complement of the properties group's visibility, and its
  `button-clicked` handler can be fired without raising.
- `Resources::SettingsDialog`, `ShortcutsDialog`, `AboutDialog`: built
  directly, screenshotted, and opened a second time through the installed
  `app.settings` / `app.shortcuts` / `app.about` actions — the same actions
  the primary menu and the `<Control>comma` accelerator invoke.
- A switch row, a combo row and a spin row in Preferences all round-trip
  through `Resources::Settings`.
- `app.quit` (bound to `<Control>q` / `<Control>w`) closes the window and
  records `window-width`/`window-height` via the `close-request` handler.
- `Resources::Cli.parse`, `Resources::Process.all` (reads real `/proc`),
  `Resources::ProcessEntry`, and `Resources::ProcessActionDialog` — all three
  ported but **not yet wired into any page** (the Apps/Processes ColumnView
  pages that would reach them don't exist on this branch) — are required
  directly by the test and exercised standalone: `ProcessActionDialog` is
  built and presented against the real main window and screenshotted.

## Bug the drive found and the fix

`SettingsDialog#build` and `ShortcutsDialog#build` were not idempotent.
Every open of Preferences or Keyboard Shortcuts — via the primary menu, the
installed `app.settings`/`app.shortcuts` action, or the `<Control>comma`
accelerator — called `build` again on the same memoized dialog. For
Preferences this tried to `Adw.PreferencesGroup#add` already-parented rows a
second time (`adw_preferences_group_add: assertion
'gtk_widget_get_parent (child) == NULL' failed`, a GTK critical); for
Shortcuts it silently duplicated every section on each reopen, since
`section(...)` builds a fresh widget each call. Both `build` methods now
guard with an `@built` flag, matching the rest of the house style's
build-once widgets. Fixed in `lib/resources/settings_dialog.rb` and
`lib/resources/shortcuts_dialog.rb`.

## What this run did not cover

- **`rspec`**, per the dev shell's own banner command, loads
  `spec/spec_helper.rb`, which `require`s `kettle/test/rspec`. That gem
  (`kettle-test`, a `resources-rb.gemspec` development dependency) is not
  present in this fork's Nix-built Ruby environment —
  `cannot load such file -- kettle/test/rspec` — so the spec run errors
  before collecting any examples. This is a gemset gap, not a GTK binding
  gap: `spec/` currently holds no `*_spec.rb` files at all (only `README.md`
  and `spec_helper.rb`), so even a working `kettle-test` would report
  "0 examples". Not fixed here — bringing in `kettle-test` (a heavyweight
  Kettle/jem test-harness gem) is a separate piece of work from proving the
  GTK port runs, and there is nothing yet for it to run.
- Everything the component inventory (`.reports/component-inventory.md`)
  marks **Missing** — the Apps/Processes ColumnView pages and their name
  cells, the five per-device pages, the three remaining dialogs, icons,
  i18n, and the privileged helpers — has no drive coverage because it does
  not exist on this branch yet.
- No ruby-gnome binding gap was hit in this run; everything the port
  currently builds ran to completion once the two `build`-idempotency bugs
  above were fixed.
