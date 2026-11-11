# Third-party notices

## Unicode CLDR 48 timezone mapping

Poma includes the territory-001 Windows-to-IANA mappings from Unicode CLDR 48.
Legacy IANA link names are resolved for the pinned timezone 0.11.2 database.
The pinned source URL and SHA-256 are retained in
`mobile/assets/timezones/SOURCE.json`. The Unicode License v3 terms are bundled
in `mobile/assets/licenses/unicode-cldr.txt`, the Windows license directory, and
the app's About license view.

## Calendar presentation — MIT License

The calendar presentation uses `kalender` 0.33.0. Its package license is also
included by Flutter's generated license registry in About → View licenses.
The existing Flutter 3.44.2 / Dart 3.12.2, intl 0.20.2 and timezone 0.11.2
constraints are retained. Additional packages are linked_pageview,
scrollable_positioned_list and universal_platform; their notices remain in the
generated package license inventory.

MIT License

Copyright (c) 2023 Klarälvdalens Datakonsult AB, a KDAB Group company <info@kdab.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Windows desktop components

Session 9 retains the locked versions below. The verification package must include
the generated package license texts as well as the matching Flutter/SQLite and
Microsoft runtime notices. Native tray, credential and toast adapters remain
app-owned; use of Windows system APIs does not add a redistributed dependency.

Windows Calendar Session 5 adds Dart-team `oauth2` 2.0.5 (BSD-3-Clause) and
directly uses the existing locked `http` 1.6.0 and `crypto` 3.0.7 (BSD-3-Clause).
Their package licenses are included by Flutter's license registry. The native
credential adapter links the operating system's Crypt32 library; it adds no
redistributed storage runtime or ATL requirement. Standard `google_sign_in`
is not used. No Google sample's plaintext credential storage is adopted.

Windows Calendar Session 6 directly uses the existing locked `timezone` 0.11.2
(BSD-2-Clause) for calendar-zone date boundaries. No package version upgrade is
required. Its license is included by Flutter's package license registry.

The private Windows installation kit contains readable Flutter/engine/Dart/package
notices, SQLite public-domain attribution and the matching Microsoft Visual C++
runtime license. `windows-native.txt` is also available in About → View licenses.
SQLite is bundled by locked `sqlite3` 3.5.2 build hooks. The locked Windows
notification dependency is built from a local compatibility copy replacing three
ATL UTF-8 conversions with C++/WinRT equivalents; its original license is retained.
Poma uses its own Windows notification adapter. Runtime file origins/versions and
SHA-256 hashes are recorded in the package inventory. Windows icons derive from
Poma's existing timer mark; bundled fonts are attributed below.

Poma's mobile feature reference is [Pomatez](https://github.com/zidoro/pomatez) at commit `c2727800c6272573590911e9ee81637b89e55d5f`. The mobile Dart implementation is newly written; the original project's notice is retained for attribution and any subsequent reuse.

## Pomatez — MIT License

Copyright (c) 2024 Roldan Montilla Jr

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Flutter and package licenses are available through the app's About → View licenses screen. Resolve the locked package graph and retain its generated license inventory for each distributed build.

## Android native components

The bundled `android-native.txt` license entry preserves the 52 selected native
runtime coordinates, the complete Apache 2.0 terms and license/NOTICE files
found in their cached JAR/AAR archives. This includes AndroidX, Kotlin,
desugaring, Gson and Guava components. Flutter's complete generated mixed
engine notices and Dart/plugin license inventory are preserved separately in
About → View licenses; they are not replaced by a top-level SDK license.

Poma's original timer-ring launcher/splash mark was created for this release.
No Pomatez icon is used. Native archive declarations do not
prove that every declared class survives optimization; full embedded/legal
clearance remains explicitly scoped in the release evidence.


## Source Sans 3 — SIL Open Font License 1.1

Poma bundles the unmodified Regular, Medium and Semibold TrueType fonts
from Adobe Source Sans 3 (adobe-fonts/source-sans, commit
`87b37a2daaed80fcb8e8ccb0085c4d72ddade12e`).
Copyright 2010-2024 Adobe, with Reserved Font Name Source.
The complete upstream notice and license are bundled in
`assets/licenses/source-sans-3.txt` and available in About → View licenses.
The font files are also embedded as process-private Windows resources;
Poma does not install a system font or download fonts at runtime.
Upstream: https://github.com/adobe-fonts/source-sans

## Sora — SIL Open Font License 1.1

Copyright 2019 The Sora Project Authors (https://github.com/sora-xor/sora-font).
Poma bundles static Medium (500) and SemiBold (600) instances of the official
Sora variable font at revision `7f9a9c5d0ccd1c099cfac420aa27133df1c5fdc4`.
fontTools 4.60.1 instanced the weight axis and assigned static family/style names
for Windows GDI; glyph outlines were not edited. Source and output identities
are recorded in `mobile/assets/fonts/SORA_SOURCE.json`.
The complete license is bundled in `assets/licenses/sora.txt` and registered in
About → View licenses. Both families are packaged offline; Windows loads its
font resources privately in the Poma process.
## Focus sound recordings and native audio runtime

The feature branch bundles four prepared CC0 1.0 recording drafts: Tibetan Bowl
Struck #1 by Joseph SARDIN, Small Waterfall #2 by gamin, Beach: Small Waves by
DenisChardonnet, and Forest #3 by Pierre SIBANARCO, acquired from BigSoundBank.
Source URLs, exact license evidence, edits and file hashes are retained in
`docs/focus-sounds/ASSET_PROVENANCE.json`. Listening approval remains pending.
CC0 permits editing and redistribution in apps; creator credits are voluntary.

The selected playback dependency is flutter_soloud **4.1.7** (MIT wrapper), with
the SoLoud engine (zlib/libpng), miniaudio/dr_libs, Signalsmith, PFFFT/FFTPACK and
the package's Ogg/Vorbis/Opus/FLAC native components. Full retained notices are in
`mobile/assets/licenses/focus-audio-native.txt`; recording credits and CC0 legal
code are in `mobile/assets/licenses/focus-sounds.txt`. Both are registered in the
offline About license view. Notice-source identities/hashes are recorded in
`docs/focus-sounds/NATIVE_LICENSE_SOURCES.json`. Resolved Dart package licenses
remain included in Flutter's generated license inventory.

FFmpeg is an external preparation tool, not an application dependency or payload.
No recording, streaming service, microphone access, or provider API is added.
