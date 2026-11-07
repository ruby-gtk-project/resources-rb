# Translation parity — resources-rb

## Upstream

```
$ git show origin/main:po/resources.pot | grep -c '^msgid "'
392          # includes the empty header msgid; 391 real strings
$ git show origin/main:po/LINGUAS | wc -l
42           # translated locales shipped (po/af_ZA.po .. po/zh_TW.po)
```

Sample msgids (`po/resources.pot`): `"Resources"`, `"Keep an eye on system
resources"`, the search-terms string, every page name ("CPU", "Memory",
"GPU", "Network Interfaces", "Storage Devices", "Batteries"), every
screenshot caption, and (by extension of how `gettext!`/`gettext` calls work
in the Rust source) every label, button, row title, tooltip, shortcut
description and error string in the app marked `translatable="yes"` in the
`.ui` files or wrapped in `gettext!()` in `.rs`.

## Port

```
$ find . -iname '*.po' -o -iname '*.pot' | grep -v '^\./\.git'
(nothing)
$ grep -rn 'gettext\|N_(' lib
(nothing)
```

**Zero.** There is no `.po`/`.pot` file anywhere in the port, no `locale/`
directory, no `gettext` gem dependency in `resources-rb.gemspec`, and no
call to a gettext-style translation function (`_()`, `gettext()`, `N_()`)
anywhere in `lib/` or `exe/`. Every user-visible string in the port —
window titles, page names, dialog labels, button text, settings-row
descriptions, the shortcuts window — is a hardcoded English literal.

## Verdict

**0 of 391 upstream msgids survive, in any form, in the port — not as
missing translations with English fallback, but because the port has no
translation mechanism at all.** This is a stronger gap than "translations
are missing for N locales": upstream's own `en`/default strings are already
going through `gettext!`, so even an English-only port that skipped every
`.po` file but still wrapped its strings in a translation call would be
correctly described as "all 42 locale `.po` files not ported, source
strings marked for translation." That weaker claim does not apply here —
the port's strings are not marked for translation at all, so there is
nothing for a future `.po` file to even attach to without a prior pass to
introduce `gettext` calls through the whole of `lib/`.

Nothing in `.reports/component-inventory.md`,
`.reports/component-identification.md`, `.reports/component-parity.md`,
`.reports/drive-verification.md` or `.reports/test-parity.md` overstates
this — the inventory explicitly scopes i18n out as "see the
translation-parity skill," which is accurate deferral, not a false claim of
coverage. This report is the first place in `.reports/` where translation
parity is actually measured, and the number is 0%.
