#!/usr/bin/env python3
"""Tell openipc.org which stock-to-OpenIPC images this release holds.

openipc.org's board catalogue offers each image under the XM device ID it is
for (the asset <device ID>_OpenIPC_<board>.bin), shows it on the boards that
run that device ID, and counts those boards as supported by OpenIPC. It
never polls GitHub: this step pushes the release's whole list after the
upload, and the push replaces what the site had
(https://github.com/OpenIPC/website/blob/master/service/internal/vendorfw/PUSH.md).

The list is read from the release itself, not from the build: a build that
failed for one board leaves that board's previous image on the release, and
the site should keep offering it.

  python3 _push_openipc_org.py <release tag> [manifest.tsv] [--dry-run]

Needs `permissions: id-token: write` (a GitHub Actions OIDC token, audience
https://openipc.org, from xm.yml on main) and GH_TOKEN to read the release.
"""

import gzip
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

URL = os.environ.get("OPENIPC_ORG_URL", "https://openipc.org/api/v1/vendor-firmware")
AUDIENCE = "https://openipc.org"
REPO = os.environ.get("GITHUB_REPOSITORY", "OpenIPC/coupler")
IMAGE = re.compile(r"^([0-9A-Za-z]{8})_OpenIPC_(.+)\.bin$")


def get(url, token=None):
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json", **({"Authorization": "Bearer " + token} if token else {})})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def items(assets, socs):
    out = []
    for a in assets:
        m = IMAGE.match(a["name"])
        if not m:
            continue
        it = {"key": a["name"], "device_id": m.group(1).upper(), "version": a["updated_at"][:10],
              "build": m.group(2), "asset_url": a["browser_download_url"], "size": a["size"], "published_at": a["updated_at"]}
        if (a.get("digest") or "").startswith("sha256:"):
            it["sha256"] = a["digest"][7:]
        if socs.get(a["name"]):
            it["soc"] = socs[a["name"]]
        out.append(it)
    return out


def oidc_token():
    url, bearer = os.environ.get("ACTIONS_ID_TOKEN_REQUEST_URL"), os.environ.get("ACTIONS_ID_TOKEN_REQUEST_TOKEN")
    if not url or not bearer:
        sys.exit("no OIDC token: the job needs `permissions: id-token: write`")
    return get(url + "&audience=" + AUDIENCE, bearer)["value"]


def main():
    args = [a for a in sys.argv[1:] if a != "--dry-run"]
    tag = args[0] if args else "latest"
    socs = {}
    if len(args) > 1 and os.path.exists(args[1]):
        for line in open(args[1]):
            name, soc, *_ = line.rstrip("\n").split("\t") + [""]
            socs[name] = soc
    rel = get(f"https://api.github.com/repos/{REPO}/releases/tags/{tag}", os.environ.get("GH_TOKEN"))
    body = {"schema": 1, "source": "coupler", "items": items(rel["assets"], socs)}
    if not body["items"]:
        # The release holds no image now: say so, and the site withdraws them.
        body["empty"] = True
    data = gzip.compress(json.dumps(body).encode())
    print(f"{len(body['items'])} images, {len(data)} bytes gzipped")
    if "--dry-run" in sys.argv:
        return
    token = oidc_token()
    for attempt in range(5):
        req = urllib.request.Request(URL, data=data, method="POST", headers={
            "Authorization": "Bearer " + token, "Content-Type": "application/json", "Content-Encoding": "gzip"})
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                print(r.status, r.read().decode())
                return
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")
            if e.code < 500:
                sys.exit(f"refused: {e.code} {msg}")
            print(f"attempt {attempt + 1}: {e.code} {msg}")
        except urllib.error.URLError as e:
            print(f"attempt {attempt + 1}: {e.reason}")
        time.sleep(30 * (attempt + 1))
    sys.exit("openipc.org did not take the push")


if __name__ == "__main__":
    main()
