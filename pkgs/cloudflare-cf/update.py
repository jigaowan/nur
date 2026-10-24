#!/usr/bin/env python3
"""Refresh runtime dependencies after nvfetcher updates cloudflare-cf."""

import base64
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
import urllib.request


def main():
    package_dir = Path(__file__).resolve().parent
    repo = package_dir.parents[1]
    source = json.loads((repo / "_sources/generated.json").read_text())["cloudflare-cf"]
    lock_path = package_dir / "package-lock.json"
    lock = json.loads(lock_path.read_text()) if lock_path.exists() else {}
    if lock.get("version") == source["version"]:
        print(f"cloudflare-cf {source['version']}: dependencies already current")
        return

    with urllib.request.urlopen(source["src"]["url"]) as response:
        archive = response.read()
    digest = "sha256-" + base64.b64encode(hashlib.sha256(archive).digest()).decode()
    if digest != source["src"]["sha256"]:
        raise RuntimeError("npm release hash does not match nvfetcher metadata")
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as tar:
        package = json.load(tar.extractfile("package/package.json"))
    if package["name"] != "cf" or package["version"] != source["version"]:
        raise RuntimeError("unexpected npm package name or version")
    package.pop("devDependencies", None)

    with tempfile.TemporaryDirectory(prefix="cloudflare-cf-") as directory:
        work = Path(directory)
        (work / "package.json").write_text(json.dumps(package, indent=2) + "\n")
        subprocess.run(
            ["npm", "install", "--package-lock-only", "--ignore-scripts",
             "--omit=dev", "--no-audit", "--no-fund"],
            cwd=work, check=True,
        )
        lock = work / "package-lock.json"
        lock_path.write_bytes(lock.read_bytes())


if __name__ == "__main__":
    main()
