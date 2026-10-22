"""Freeze and verify a signed APK/AAB; preserve command output and package inventories."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile
from release_evidence import archive

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java", type=Path, required=True)
    parser.add_argument("--build-tools", type=Path, required=True)
    parser.add_argument("--rtk", required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    env["JAVA_HOME"] = str(args.java.parent.parent)
    env["PATH"] = str(args.java.parent) + os.pathsep + env["PATH"]

    def run(label, *command):
        result = subprocess.run([args.rtk, "proxy", *map(str, command)], cwd=ROOT, env=env,
                                capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
        text = result.stdout + result.stderr
        (out / (label + ".log")).write_text(text, encoding="utf-8")
        if result.returncode:
            raise RuntimeError(f"{label} failed; inspect {out / (label + '.log')}")
        return text

    if subprocess.check_output([args.rtk, "proxy", "git", "diff", "--name-only", args.source_commit,
                                "--", "mobile", ":(exclude)mobile/android/.gitignore"], cwd=ROOT).strip():
        raise SystemExit("Application source differs from the claimed built commit")
    sources = [ROOT / "mobile/build/app/outputs/flutter-apk/app-release.apk",
               ROOT / "mobile/build/app/outputs/bundle/release/app-release.aab"]
    targets = [out / "poma-1.0.0-2007-android-arm64-release-test.apk", out / "poma-1.0.0-2007-upload.aab"]
    for source, target in zip(sources, targets):
        if target.exists() and sha(target) != sha(source):
            raise SystemExit("Refusing to overwrite an existing candidate with different bytes: " + str(target))
        if not target.exists():
            shutil.copy2(source, target)
    apk, aab = targets
    signature = run("apk-signature", args.java, "-jar", args.build_tools / "lib/apksigner.jar",
                    "verify", "--verbose", "--print-certs", apk)
    if "CN=Android Debug" in signature or "CN=Jyotirmay Singh" not in signature:
        raise SystemExit("Unexpected certificate; candidate must use the owner's upload key")
    certificate = re.search(r"certificate SHA-256 digest: ([a-f0-9]+)", signature).group(1)
    run("apk-16k-alignment", args.build_tools / "zipalign.exe", "-c", "-P", "16", "-v", "4", apk)
    badging = run("apk-badging", args.build_tools / "aapt2.exe", "dump", "badging", apk)
    if not all(value in badging for value in ("name='com.jyotirmaysingh.poma'", "versionCode='2007'", "versionName='1.0.0'")):
        raise SystemExit("Unexpected package/version metadata")
    if "application-debuggable" in badging or "android.permission.INTERNET" in badging:
        raise SystemExit("Debuggable/network-enabled APK is not the offline release candidate")
    manifest = run("apk-manifest", args.build_tools / "aapt2.exe", "dump", "xmltree", "--file", "AndroidManifest.xml", apk)
    for receiver in ("PomaAlarmReceiver", "PomaDismissReceiver", "PomaRestoreReceiver"):
        if receiver not in manifest:
            raise SystemExit("Native alert receiver missing: " + receiver)
    if "android:allowBackup" not in manifest:
        raise SystemExit("Backup configuration missing")
    verified = run("aab-signature", args.java.parent / "jarsigner.exe", "-verify", "-verbose", "-certs", aab)
    if "jar verified." not in verified or "jar is unsigned" in verified:
        raise SystemExit("AAB signature not verified")
    aab_certificate = run("aab-certificate", args.java.parent / "keytool.exe", "-printcert", "-jarfile", aab)
    match = re.search(r"SHA256:\s*([A-Fa-f0-9:]+)", aab_certificate)
    if not match or match.group(1).replace(":", "").lower() != certificate:
        raise SystemExit("APK and AAB signer mismatch")
    with zipfile.ZipFile(apk) as apk_zip, zipfile.ZipFile(aab) as aab_zip:
        for asset in ("assets/legal/privacy.txt", "assets/legal/notices.txt", "assets/licenses/android-native.txt", "assets/licenses/pomatez.txt"):
            packaged = "assets/flutter_assets/" + asset
            if apk_zip.read(packaged) != (ROOT / "mobile" / asset).read_bytes():
                raise SystemExit("Stale bundled legal text: " + asset)
        comparable = [name for name in apk_zip.namelist() if name.startswith(("assets/flutter_assets/", "lib/arm64-v8a/"))]
        differences = [name for name in comparable if "base/" + name not in aab_zip.namelist()
                       or apk_zip.read(name) != aab_zip.read("base/" + name)]
        if differences:
            raise SystemExit("APK/AAB payloads differ: " + ", ".join(differences))
        if "assets/flutter_assets/NOTICES.Z" not in apk_zip.namelist():
            raise SystemExit("Generated Flutter notices missing")
    if apk.stat().st_size > 20 * 1024 * 1024:
        raise SystemExit("ARM64 APK exceeds the provisional 20 MiB artifact budget")
    records = [archive(path) for path in targets]
    for record in records:
        record["path"] = str(Path(record["path"]).relative_to(ROOT))
    receipt = {
        "recordedUtc": datetime.now(timezone.utc).isoformat(), "sourceCommit": args.source_commit,
        "lockfileSha256": sha(ROOT / "mobile/pubspec.lock"), "applicationId": "com.jyotirmaysingh.poma",
        "versionName": "1.0.0", "versionCode": 2007, "buildMode": "optimized release",
        "signing": "Owner RSA-3072 upload certificate; not Android Debug or Play app-signing certificate",
        "certificateSha256": certificate, "artifacts": records, "payloadsCompared": len(comparable),
        "checks": {"apkSignature": "passed", "aabSignature": "passed", "matchingCertificate": "passed",
                   "16KiBAlignment": "passed", "packageVersion": "passed", "noDebugOrInternet": "passed",
                   "nativeReceivers": "passed", "bundledLegalAndFlutterNotices": "passed",
                   "apkAabSharedPayloadParity": "passed", "arm64ArtifactBudget20MiB": "passed"},
        "limitations": ["No phone installed or exercised by this collector.", "Artifact size is not store download size or startup/energy evidence."]
    }
    (out / "android-receipt.json").write_text(json.dumps(receipt, indent=2)+"\n", encoding="utf-8")
    (out / "SHA256SUMS.txt").write_text("".join(sha(path)+"  "+path.name+"\n" for path in targets), encoding="utf-8")
    print(json.dumps({"sourceCommit": args.source_commit, "certificateSha256": certificate,
                      "artifacts": [{"name": p.name, "bytes": p.stat().st_size, "sha256": sha(p)} for p in targets],
                      "checks": receipt["checks"]}, indent=2))


if __name__ == "__main__":
    main()
