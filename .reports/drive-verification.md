# Drive verification — resources-rb

Ran `nix develop --command xvfb-run -a ruby test/drive_resources.rb` (also
reachable as the dev shell's own `xvfb-run ruby test/drive_*.rb`, now that it
is the only `test/drive_*.rb` file). Result: **50 of 50 checks passed,
`DRIVE OK`**, 9 screenshots written under `tmp/shots/` (gitignored).

This supersedes the previous entry in this file (43/43, before `battery.rb`
and `battery_page.rb` were ported and before this run's dialog-reuse fix).

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
- `Resources::BatteryPage` / `Resources::Battery`: built and refreshed
  against synthetic sysfs data (unwired component on *this* machine — there
  is no battery here, so `MainWindow#battery_pages` is an empty list and the
  sidebar never reaches it — but the class is exercised directly and its
  widget tree screenshotted against the real main window).
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

## Bug this run found and the fix

Opening Preferences, Keyboard Shortcuts or About, closing it, then opening
the *same* dialog kind again — exactly what a user does hitting
`<Control>comma` twice, or using the primary menu's Preferences item after
previously closing it — raised a GTK critical:

```
Gtk-CRITICAL **: gtk_widget_set_parent: assertion '_gtk_widget_get_parent (widget) == NULL' failed
	from .../gobject-introspection/loader.rb:583:in 'Adwaita::Dialog#present'
```

`MainWindow#settings_dialog`/`shortcuts_dialog`/`about_dialog` memoized a
single `Adwaita::Dialog` instance and the `app.settings`/`shortcuts`/`about`
actions called `.build.present(window)` on that same instance every time.
A closed `Adwaita::Dialog` leaves its internal child widget parented, so a
second `present` on the same object hits `gtk_widget_set_parent`'s
"parent is NULL" assertion. The dialog's `visible?` still read `true`
afterwards despite the failed reparent, so the previous drive run's checks
(which only asked `dialog.visible?`) passed while this was silently broken —
confirmed by reproducing it directly against `Adwaita::PreferencesDialog`
*and* `Adwaita::AboutDialog` outside the port, with and without a delay
between `close` and the second `present`.

Upstream's `src/application.rs` (`show_settings_dialog`, `show_about_dialog`)
never reuses a dialog object across opens — it builds a fresh
`ResSettingsDialog`/`adw::AboutDialog` every time the action fires. Fixed the
same way: `MainWindow#actions` now builds a new `SettingsDialog` /
`ShortcutsDialog` / `AboutDialog` instance on every open
(`open_settings_dialog`, `open_shortcuts_dialog`, `open_about_dialog` in
`lib/resources/main_window.rb`), storing it in the same memoized ivar so the
accessor still exposes whichever one is on screen. The `@built` guards in
`lib/resources/settings_dialog.rb` and `lib/resources/shortcuts_dialog.rb`
(added by the previous drive run, for the double-`preferences.add`/duplicated
-section bug on a reused instance) are kept as a defensive guard against a
direct second `build` call, with their comments updated to say so — they are
no longer what prevents dialog reuse, since reuse doesn't happen anymore.

The drive script only caught the surface symptom (`visible?` still read
`true`); the GTK-CRITICAL in stderr is what actually revealed the bug. The
test now runs clean of `Gtk-CRITICAL`/assertion output — checked by grepping
the full run's stderr+stdout after the fix, not just reading the pass count.

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
  GTK port runs, and there is nothing yet for it to run. Unchanged from the
  previous drive-verification run.
- Everything the component inventory (`.reports/component-inventory.md`)
  marks **Missing** — note that inventory predates `battery.rb`/
  `battery_page.rb` and needs a refresh — the Apps/Processes ColumnView
  pages and their name cells, the five remaining per-device pages, the three
  remaining dialogs, icons, i18n, and the privileged helpers — has no drive
  coverage because it does not exist on this branch yet.
- No ruby-gnome binding gap was hit in this run; everything the port
  currently builds ran to completion once the dialog-reuse bug above was
  fixed.
