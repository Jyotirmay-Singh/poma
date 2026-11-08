"""Acquire public CC0 candidates and retain evidence; never use preview audio.

Run from the checkout. Original WAVs and full HTTP bodies remain ignored.
The provider's ordinary public download form is used without login or API keys.
"""
from __future__ import annotations

import hashlib
import json
import time
import http.cookiejar
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlencode, urljoin
from urllib.request import Request, build_opener, HTTPCookieProcessor

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "artifacts/focus-sounds/session-1/raw"
EVIDENCE = ROOT / "docs/focus-sounds/license-evidence"
CANDIDATES = [
    ("bells-1110", "tibetanBells", 1110, "tibetan-bowl-struck-s1110.html", "Joseph SARDIN"),
    ("bells-2553", "tibetanBells", 2553, "tibetan-bowl-struck-2-s2553.html", "Joseph SARDIN"),
    ("waterfall-0219", "waterfall", 219, "small-waterfall-2-s0219.html", "gamin"),
    ("waterfall-0213", "waterfall", 213, "small-stream-1-s0213.html", "gamin"),
    ("ocean-0265", "oceanWaves", 265, "beach-small-waves-s0265.html", "DenisChardonnet"),
    ("ocean-1447", "oceanWaves", 1447, "small-waves-froth-and-beach-s1447.html", "Joseph SARDIN"),
    ("forest-2715", "forestBirds", 2715, "forest-3-s2715.html", "Pierre SIBANARCO"),
    ("forest-2749", "forestBirds", 2749, "forest-4-s2749.html", "Joseph SARDIN"),
]
OPENER = build_opener(HTTPCookieProcessor(http.cookiejar.CookieJar()))


class DownloadForm(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_form = False
        self.action = None
        self.fields = {}

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "form" and attrs.get("id") == "dl-form":
            self.in_form = True
            self.action = attrs["action"]
        if self.in_form and tag == "input" and attrs.get("name"):
            self.fields[attrs["name"]] = attrs.get("value", "")

    def handle_endtag(self, tag):
        if tag == "form":
            self.in_form = False


class PageText(HTMLParser):
    def __init__(self):
        super().__init__()
        self.skip = 0
        self.parts = []

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style", "svg"):
            self.skip += 1

    def handle_endtag(self, tag):
        if tag in ("script", "style", "svg"):
            self.skip -= 1

    def handle_data(self, data):
        if not self.skip and data.strip():
            self.parts.append(" ".join(data.split()))


def sha(data):
    return hashlib.sha256(data).hexdigest()


def fetch(url, data=None):
    req = Request(url, data=data, headers={"User-Agent": "PomaAssetPreparation/1.0"})
    with OPENER.open(req, timeout=120) as response:
        return response.read(), response.url, response.headers.get("Content-Type", "")


def evidence(name, url):
    raw, final_url, content_type = fetch(url)
    (RAW / (name + ".html")).write_bytes(raw)
    parser = PageText()
    parser.feed(raw.decode("utf-8"))
    text = "\n".join(parser.parts)
    path = EVIDENCE / (name + ".txt")
    body = (f"Source: {url}\nRetrieved UTC: {datetime.now(timezone.utc).isoformat()}\n"
            f"Full response SHA-256: {sha(raw)}\nRepresentation: extracted page text (scripts/styles omitted)\n\n{text}\n")
    path.write_text(body, encoding="utf-8")
    return {"source_url": url, "response_url": final_url, "content_type": content_type,
            "original_response_sha256": sha(raw),
            "retained_text": path.relative_to(ROOT).as_posix(),
            "retained_text_sha256": sha(path.read_bytes())}, text


def main():
    RAW.mkdir(parents=True, exist_ok=True)
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    records = []
    terms, terms_text = evidence("bigsoundbank-license", "https://bigsoundbank.com/licenses.html")
    assert "CC0" in terms_text and "commercial" in terms_text
    legal, _, _ = fetch("https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt")
    (EVIDENCE / "CC0-1.0-legalcode.txt").write_bytes(legal)
    for key, category, number, slug, creator in CANDIDATES:
        source = "https://bigsoundbank.com/" + slug
        page, text = evidence(key, source)
        assert "CC0" in text and "redistribute" in text and "apps" in text
        target = RAW / (key + ".wav")
        if not target.exists():
            data, final_url, mime = fetch("https://bigsoundbank.com/download.php", urlencode(
                {"format": "wav", "id": f"{number:04d}", "button": "Download"}).encode())
            if "text/html" in mime:
                # Follow the ordinary public form, including its five-second wait.
                # Do not use preview URLs or bypass a login/challenge.
                form = DownloadForm()
                form.feed(data.decode("utf-8"))
                assert form.action == "/modules/telecharger.php"
                time.sleep(5.2)
                data, final_url, mime = fetch(urljoin(final_url, form.action), urlencode(form.fields).encode())
            assert data[:4] == b"RIFF" and data[8:12] == b"WAVE", (key, mime, final_url, data[:80])
            target.write_bytes(data)
        else:
            final_url = "Previously acquired via provider WAV download form; see acquisition record"
        data = target.read_bytes()
        records.append({"candidate_id": key, "category": category, "creator": creator,
                        "source_url": source, "provider_recording_id": number,
                        "license": "CC0-1.0", "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
                        "acquired_utc": datetime.fromtimestamp(target.stat().st_mtime, timezone.utc).isoformat(),
                        "acquisition_method": "Public provider download.php form POST, format=wav",
                        "download_response_url": final_url,
                        "original_path": target.relative_to(ROOT).as_posix(),
                        "original_bytes": len(data), "original_sha256": sha(data),
                        "license_evidence": page, "provider_terms": terms,
                        "listening_status": "Not auditioned", "selected_as_final": False})
        print(f"{key}: WAV {len(data):,} bytes; CC0 evidence retained", flush=True)
    output = ROOT / "docs/focus-sounds/ASSET_PROVENANCE.json"
    output.write_text(json.dumps({"schema_version": 1, "status": "Candidate acquisition; listening pending",
                                  "candidates": records, "prepared_assets": []}, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
