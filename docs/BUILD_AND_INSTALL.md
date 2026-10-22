# Build and install Poma 1.0.0

The release package ID is `com.jyotirmaysingh.poma` on both platforms. Availability
and registration in the owner's store accounts remain unverified. Its sandbox
is separate from `dev.poma.poma`; the older development installation and evidence
can remain intact. There is no automatic cross-package data migration.

## Reproducible Android candidate

Use Flutter 3.44.2 / Dart 3.12.2, Java 17 and the Android toolchain in
ARCHITECTURE.md. Keep `pubspec.lock`; do not upgrade packages for this release.
Install RTK or use the ignored local `.tools/rtk/rtk.exe` on this Windows host.

From the repository root, prepare and check metadata:

```powershell
rtk proxy python scripts/prepare_release.py
rtk proxy python scripts/check_release_scope.py
```

Create the upload key once on Windows:

```powershell
rtk proxy pwsh -NoProfile -File scripts/create_android_upload_key.ps1
```

The helper restricts the signing directory to the current Windows user and stores
`poma-upload.p12` and a Windows DPAPI-encrypted `credentials.xml` under
`%USERPROFILE%/.poma/signing`, outside source control. Preserve the key and put its
password in an owner-controlled password manager through a secure local process.
The DPAPI file alone is not portable to another user/machine. Never post either
file, password or recovery material to GitHub, a chat or a release artifact.

Build using that private credential without printing it:

```powershell
rtk proxy pwsh -NoProfile -File scripts/build_android_release.ps1
```

Other hosts can supply `POMA_ANDROID_KEYSTORE_FILE`, `POMA_ANDROID_KEY_ALIAS`,
`POMA_ANDROID_STORE_PASSWORD` and `POMA_ANDROID_KEY_PASSWORD` through their secure
environment. Then run normal `flutter build apk --release --target-platform
android-arm64` and `flutter build appbundle --release` from `mobile/`, prefixed
with RTK. Normal pub preparation refreshes native plugin registration; avoid
reusing integration-test registration with `--no-pub` for release packaging.

The APK is installable; the AAB is a Play upload artifact. Both use optimized
release mode and the private upload certificate. This is distinct from a Google
Play app-signing certificate that Play may apply after an authorized upload.
`POMA_ALLOW_UNSIGNED_RELEASE=1` is exclusively for clearly labelled inspection
outputs. Unsigned outputs are not installable candidates. Debug signing is never
assigned to a release variant.

Verify the exact artifact hash/certificate against RELEASE_CANDIDATE.md. Install
the named test APK with Android's package installer or `rtk proxy adb install
<exact-apk>`. Do not open it yet. Stop development services, unplug USB, enable
airplane mode, explicitly turn Wi-Fi/data off, then open from the launcher.
Use the candidate-specific walkthrough in that report. Reconnecting for package
inspection is a separate operation and must not interrupt disconnected checks.

## iOS: macOS compilation versus installation

The release-only CI path compiles an iOS simulator app and creates an unsigned
device `.xcarchive` on **macOS**, not Windows. An unsigned archive is inspection
evidence, not an installable IPA, TestFlight build or physical iPhone result.
Existing ten Swift simulator tests remain scoped to the recorded baseline.

For signed distribution, supply a paid Apple Developer team, registered bundle
ID, distribution certificate/private key and matching provisioning profile via
an external secret store or temporary CI keychain. No signing credential belongs
in this repository. Set the real development team in an external Xcode build
configuration and use automatic signing under that team, or explicitly install
the corresponding profiles. Local notifications require no push entitlement,
critical-alert entitlement or continuous-background mode. Inspect final signed
entitlements against the profile before exporting an IPA.

On an authorized Mac with Xcode, resolve the unchanged lockfile, build the release
and archive Runner. Export with an owner-supplied ExportOptions plist using the
correct team and app-store-connect or ad-hoc method. For ad-hoc phone installation,
the iPhone UDID must be included in the profile. An export template is provided at
`release/ios/ExportOptions.template.plist`; its team marker must be replaced outside
source control. No paid account, certificate or profile has been supplied yet.

Present the concrete signed archive/IPA before any TestFlight upload. Uploading,
store submission, publishing policy pages or public download links require the
owner's final authorization. Seven-day personal signing is not this release's
distribution plan. Device and Instruments checks remain open without the Mac,
signing access and physical iPhone installation.

## Branding regeneration

The original mark source is `branding/poma-mark.svg`. Generate its native icons
and splash assets with `rtk proxy python scripts/generate_branding.py` in an
environment with Pillow installed. Pillow is build tooling only. The generated
icons/assets are committed; app installation and builds do not download them.
`scripts/prepare_release.py --check` detects stale version/legal assets. The
ordinary application requires none of these development tools after installation.
