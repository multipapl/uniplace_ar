#!/usr/bin/env python3
"""
optimize_assets.py — ASTC + downscale asset pipeline for UP_AR.

Takes raw USDZ layers dropped into the Resilio sync folder and, per layer:
  * textured layers  -> downscale textures to MAX_TEXTURE_SIZE, then `realitytool
    compile` to a GPU-ASTC `.reality` in Content/TestLevel (stays compressed in
    VRAM; the texture downscale is the real AR memory lever — `realitytool
    compile` always re-encodes ASTC itself and ignores any block-size flag);
  * geometry-only layers (no textures) -> copied through as plain `.usdz`.

The manifest only ever names `.usdz`; the loader auto-prefers the `.reality`
sibling when one exists, so the manifest is never touched.

Incremental: a layer is rebuilt only when its source `.usdz` hash changes (or
--force). Run on demand (or via optimize.command) after Resilio finishes syncing.

Usage:
    Tools/optimize_assets.py                  # process everything new
    Tools/optimize_assets.py --force          # rebuild all layers
    Tools/optimize_assets.py --only UP_Scene  # one layer
    Tools/optimize_assets.py --staging /path  # override the sync folder
    Tools/optimize_assets.py --max-size 1024  # harsher texture downscale
"""

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

# ─── EDIT THIS ONE LINE: where Resilio syncs the raw USDZ layers ────────────────
SYNC_DIR = Path.home() / "Projects" / "UP_AR_Sync"
# ────────────────────────────────────────────────────────────────────────────────

REPO = Path(__file__).resolve().parent.parent
DEST = REPO / "UP_AR" / "Content" / "TestLevel"
CACHE_FILE = DEST / ".optimize_cache.json"

PLATFORM = "iphoneos"            # realitytool platform for on-device iOS builds
DEPLOYMENT_TARGET = "18.0"
MAX_TEXTURE_SIZE = None           # None = compile at source resolution (prep textures by hand).
                                  # Set a cap (e.g. via --max-size 2048) for an optional global downscale.
IMAGE_EXTS = {".png", ".jpg", ".jpeg"}


def sh(cmd):
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError("command failed: %s\n%s\n%s" % (" ".join(cmd), res.stdout, res.stderr))
    return res.stdout


def realitytool(*args):
    return sh(["xcrun", "realitytool", *args])


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def human(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024:
            return "%.1f%s" % (n, unit)
        n /= 1024
    return "%.1fTB" % n


def load_cache():
    if CACHE_FILE.exists():
        try:
            return json.loads(CACHE_FILE.read_text())
        except json.JSONDecodeError:
            pass
    return {}


def save_cache(cache):
    CACHE_FILE.write_text(json.dumps(cache, indent=2, sort_keys=True))


# ─── texture downscale (sips ships with macOS — no extra deps) ──────────────────
def image_max_dimension(img):
    out = sh(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(img)])
    dims = [int(tok) for tok in out.split() if tok.isdigit()]
    return max(dims) if dims else 0


def downscale_images(images, max_size):
    """Resize any texture whose longest edge exceeds max_size, in place. Never upscales."""
    scaled = 0
    for img in sorted(images):
        if image_max_dimension(img) > max_size:
            sh(["sips", "-Z", str(max_size), str(img)])
            scaled += 1
    return scaled


# ─── per-layer processing ───────────────────────────────────────────────────────
def compile_layer(usdz, work, max_size):
    """Downscale + compile one textured layer to `.reality`; return None if geometry-only."""
    stem = usdz.stem
    rkassets = work / (stem + ".rkassets")
    rkassets.mkdir()
    with zipfile.ZipFile(usdz) as z:
        z.extractall(rkassets)

    images = [p for p in rkassets.rglob("*")
              if p.is_file() and p.suffix.lower() in IMAGE_EXTS]
    if not images:
        return None  # geometry-only — caller ships the plain usdz

    if max_size:
        scaled = downscale_images(images, max_size)
        print("    %d textures (%d downscaled to <=%dpx)" % (len(images), scaled, max_size))
    else:
        print("    %d textures (compiled at source resolution)" % len(images))

    reality = work / (stem + ".reality")
    realitytool("compile", "--platform", PLATFORM,
                "--deployment-target", DEPLOYMENT_TARGET,
                "-o", str(reality), str(rkassets))
    return reality


def process_usdz(usdz, cache, force, max_size):
    stem = usdz.stem
    digest = sha256(usdz)
    dest_usdz = DEST / usdz.name
    dest_reality = DEST / (stem + ".reality")
    no_textures = cache.get(stem + ".no_textures")

    up_to_date = (
        not force
        and cache.get(usdz.name) == digest
        and cache.get(stem + ".max_size") == max_size
        and ((no_textures and dest_usdz.exists())
             or (no_textures is False and dest_reality.exists()))
    )
    if up_to_date:
        print("  = %-22s unchanged, skip" % stem)
        return False

    print("  * %s" % stem)
    with tempfile.TemporaryDirectory() as tmp:
        reality = compile_layer(usdz, Path(tmp), max_size)
        if reality is None:
            shutil.copy2(usdz, dest_usdz)
            if dest_reality.exists():
                dest_reality.unlink()
            cache[stem + ".no_textures"] = True
            print("    geometry-only — shipped %s (%s)" % (dest_usdz.name, human(dest_usdz.stat().st_size)))
        else:
            shutil.move(str(reality), str(dest_reality))
            if dest_usdz.exists():
                dest_usdz.unlink()
            cache[stem + ".no_textures"] = False
            print("    -> %s  (raw usdz %s, shipped reality %s)"
                  % (dest_reality.name, human(usdz.stat().st_size), human(dest_reality.stat().st_size)))

    cache[usdz.name] = digest
    cache[stem + ".max_size"] = max_size
    save_cache(cache)
    return True


def main():
    global MAX_TEXTURE_SIZE
    ap = argparse.ArgumentParser(description="ASTC + downscale asset pipeline for UP_AR")
    ap.add_argument("--staging", type=Path, default=SYNC_DIR, help="folder Resilio syncs raw USDZ into")
    ap.add_argument("--force", action="store_true", help="rebuild even if the source hash is unchanged")
    ap.add_argument("--only", metavar="LAYER", help="process a single layer by stem, e.g. UP_Scene")
    ap.add_argument("--max-size", type=int, default=MAX_TEXTURE_SIZE,
                    help="optional: downscale texture longest edge to this many px (default: source res)")
    args = ap.parse_args()

    MAX_TEXTURE_SIZE = args.max_size
    staging = args.staging.expanduser().resolve()
    if not staging.is_dir():
        sys.exit("sync folder not found: %s\nCreate it / point Resilio there, or pass --staging." % staging)
    DEST.mkdir(parents=True, exist_ok=True)

    usdz_files = sorted(staging.glob("*.usdz"))
    if args.only:
        usdz_files = [p for p in usdz_files if p.stem == args.only]
        if not usdz_files:
            sys.exit("no staged layer named %s.usdz in %s" % (args.only, staging))

    print("sync   : %s" % staging)
    print("dest   : %s" % DEST)
    print("layers : %d usdz found" % len(usdz_files))
    print("max tex: %s\n" % ("%dpx" % MAX_TEXTURE_SIZE if MAX_TEXTURE_SIZE else "source (no downscale)"))

    cache = load_cache()
    changed = 0
    for usdz in usdz_files:
        try:
            if process_usdz(usdz, cache, args.force, MAX_TEXTURE_SIZE):
                changed += 1
        except Exception as e:  # noqa: BLE001 — report and continue other layers
            print("  ! %s FAILED: %s" % (usdz.stem, e))

    print("\ndone: %d layer(s) updated." % changed)


if __name__ == "__main__":
    main()
