# Compression backends and reversible pipelines

Compression is selected in the canonical Vala engine, before encryption.
Restore selects the codec recorded in the archive. Backups remain `.dvx3`;
this is not a universal extractor for standalone ZIP/RAR/7z or game installers.

```sh
build/bin/dvx3 --codecs
build/bin/dvx3 encrypt ./data -p 'password' -o ./data.dvx3 --codec zpaq
build/bin/dvx3 decrypt ./data.dvx3 -p 'password' -o ./empty-directory
```

| Codec | Executable | Local Linux round trip |
| --- | --- | --- |
| none | no compressor (tar still required) | verified |
| zstd | zstd | verified |
| gzip / DEFLATE | gzip | verified |
| bzip2 | bzip2 | verified |
| xz / LZMA2 | xz | verified |
| lzma | xz --format=lzma | verified |
| lz4 | lz4 | verified |
| brotli | brotli | verified |
| 7z (default LZMA2) | 7zz or 7z | verified |
| zpaq | zpaq, method 1 | verified with ZPAQ 7.15 |
| razor | a local profile for rz.exe | integration example; executable unavailable, unverified |
| custom pipeline | locally configured ordered codecs | xz -> zstd verified |

ZPAQ's API uses `add`/`extract` on a staged `payload.tar`; its native incremental
journal semantics are not exposed as incremental encrypted backups.
[ZPAQ source/manual](https://github.com/zpaq/zpaq/blob/master/zpaq.pod).

## Adding codecs without a second architecture

There is no finite implementation that can claim tested support for *every*
existing compressor, proprietary release or game-specific preprocessor.
The core instead supports locally installed extensions and reversible pipelines.
A profile is considered available only if its encode/decode tools and all pipeline
steps resolve. Availability is not proof of compatibility: run a round trip with
your exact version and representative bytes before depending on it.

Store profiles in `dvx3/codecs.ini` under GLib's native user configuration directory,
or set `DVX3_CODECS=/absolute/path/codecs.ini`. See `config/codecs.example.ini`.
Custom names use lowercase ASCII letters, digits, `_` and `-`, maximum 64 characters.
Built-in codec names cannot be overridden. Keep profile IDs/versioned commands
stable for as long as an archive needs restoration; profiles are not bundled into
archives and must also be installed on the restoring machine.

Two extension contracts:

```ini
[my-codec-v1]
adapter=/absolute/path/to/native-adapter

[my-direct-codec-v1]
compress=encoder;{input};{output};
decompress=decoder;{input};{output};

[my-pipeline-v1]
pipeline=my-codec-v1;xz;
```

An adapter receives `compress|decompress INPUT OUTPUT`, creates the output file,
and exits zero only after success. A direct command is a semicolon-separated
argv list: each element is one argument, so paths with spaces need no shell quoting.
`{input}`/`{output}` are absolute native paths. All commands run in a private working
directory and must produce the requested file. No shell interpolation occurs.
Pipelines stage each step independently; restore runs inverses in reverse order.
Cycles/excessive nesting are rejected. External tools must preserve every input byte.

## Razor and repacking requests

`config/codecs.example.ini` contains an explicit Razor command profile based on
its `rz a` / `rz x` interface. It needs the vendor executable and validation on the
actual target OS; it is **not** a claim of native Linux/macOS Razor support.
No Wine dependency or proprietary binaries are downloaded automatically.

The request for “FitGirl compression” is handled as a request for configurable
repacking chains, not an invented `fitgirl` algorithm or a claim to reproduce a
specific repacker's methods. Precompression, deduplication and final compression
can be represented as `xtool-v1;srep-v1;lolz-v1` or another reversible chain.
These sample adapter names need real executables and version-specific wrappers;
they are not shipped or verified here. XTool's own source separates precompression
and decoding: [XTool source](https://github.com/Razor12911/xtool/blob/main/xtool.dpr).
This refactor does not claim compatibility with FitGirl installers or their archives.
