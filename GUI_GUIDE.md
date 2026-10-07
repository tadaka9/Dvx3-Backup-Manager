# Qt6 desktop interface

Build `./build.sh gui` and launch `./run_gui.sh`. Qt provides file dialogs and
progress presentation; archive operations run in the canonical Vala engine on a
worker thread. The C++ layer has no independent encryption/compression/job backend.
The window and taskbar use an embedded app icon. Its editable vector source is
`gui/qt/qtdesktop/icons/logo.svg`; the matching PNG is included as a Qt resource.
Windows builds also embed an ICO in the executable for Explorer.

The monochrome desktop shell provides an overview, dedicated create/restore flows,
a live codec matrix, session activity and an about view. Use the sidebar, the
File/View/Tools menus, keyboard shortcuts, drag and drop, or the `Ctrl+K` command
palette. Page fades and the compact-sidebar transition can be disabled with
View → Reduce motion.

The interaction model applies cognitive and ethical UX principles: progressive
disclosure, one dominant action per task, validation before submission, status
feedback in plain language, security cues beside sensitive inputs and no urgency,
hidden consent or other dark patterns. Password guidance reports observable length
without pretending to calculate cryptographic strength.

Choose Create or Restore, source, destination and password. Creation offers the
codecs whose local tools/profile dependencies are detected; zstd is the default.
Restore reads the codec from the archive and requires an empty directory. Progress
and failures come from actual operations, with no simulated success. Passwords
are not saved. Closing is blocked until the active operation finishes.

There is no cancellation, scheduler, configuration dashboard or automatic password
recovery. Job management is available through the Vala manager CLI.

Automated smoke test:

```sh
QT_QPA_PLATFORM=offscreen build/bin/dvx3-backup-manager --smoke-test
```

This constructs/renders the real window; it does not substitute for manual desktop
interaction testing. Local Linux compilation and offscreen startup were verified;
other platform GUI support depends on the native CI results listed in BUILD.md.
Set `DVX3_SMOKE_IMAGE=/path/to/preview.png` with the smoke test to save its
rendered window for visual inspection. `DVX3_SMOKE_PAGE` accepts `archive`,
`restore`, `codecs`, `activity` or `about` to render another view.
