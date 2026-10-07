# Qt6 desktop interface

Build `./build.sh gui` and launch `./run_gui.sh`. Qt provides file dialogs and
progress presentation; archive operations run in the canonical Vala engine on a
worker thread. The C++ layer has no independent encryption/compression/job backend.

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
