#!/usr/bin/env python3
"""Download CC0 Poly Haven textures and an HDRI (1k/2k JPG + HDR)."""

from __future__ import annotations

import json
import os
import ssl
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / "assets" / "textures"
ENV = ROOT / "assets" / "env"
UA = "TheFrontier/0.2 (Godot prototype; CC0 local cache)"
CTX = ssl.create_default_context()

TEXTURES = {
    "metal_plate": ["Diffuse", "nor_gl", "Rough", "Metal", "AO"],
    "rusty_metal_02": ["Diffuse", "nor_gl", "Rough", "Metal", "AO"],
    "concrete_floor_02": ["Diffuse", "nor_gl", "Rough", "AO"],
    "rock_face": ["Diffuse", "nor_gl", "Rough", "AO"],
    "ground_003": ["Diffuse", "nor_gl", "Rough", "AO"],
    "sand_01": ["Diffuse", "nor_gl", "Rough", "AO"],
}

# Prefer 2k for terrain-scale, 1k for metal/detail.
RES = {
    "metal_plate": "1k",
    "rusty_metal_02": "1k",
    "concrete_floor_02": "1k",
    "rock_face": "2k",
    "ground_003": "2k",
    "sand_01": "2k",
}

MAP_FILE = {
    "Diffuse": "diff",
    "nor_gl": "nor_gl",
    "Rough": "rough",
    "Metal": "metal",
    "AO": "ao",
}

HDRI_ID = "qwantani_dusk_2_puresky"
HDRI_RES = "2k"


def get_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, context=CTX, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 1024:
        print(f"skip {dest}")
        return
    tmp = dest.with_suffix(dest.suffix + ".part")
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    print(f"GET {url}")
    with urllib.request.urlopen(req, context=CTX, timeout=120) as resp:
        data = resp.read()
    tmp.write_bytes(data)
    tmp.replace(dest)
    print(f"  wrote {dest} ({len(data)} bytes)")


def pick_url(files: dict, map_name: str, res: str) -> str | None:
    block = files.get(map_name) or files.get(map_name.lower())
    if not block:
        return None
    res_block = block.get(res) or block.get("1k") or block.get("2k")
    if not res_block:
        return None
    jpg = res_block.get("jpg")
    if jpg and "url" in jpg:
        return jpg["url"]
    png = res_block.get("png")
    if png and "url" in png:
        return png["url"]
    return None


def fetch_texture(asset_id: str, maps: list[str]) -> None:
    files = get_json(f"https://api.polyhaven.com/files/{asset_id}")
    res = RES.get(asset_id, "1k")
    out_dir = TEX / asset_id
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "SOURCE.txt").write_text(
        f"{asset_id}\nhttps://polyhaven.com/a/{asset_id}\nLicense: CC0 1.0\n",
        encoding="utf-8",
    )
    for map_name in maps:
        url = pick_url(files, map_name, res)
        if not url:
            print(f"WARN missing {asset_id} {map_name}")
            continue
        dest = out_dir / f"{MAP_FILE[map_name]}.jpg"
        if url.endswith(".png"):
            dest = out_dir / f"{MAP_FILE[map_name]}.png"
        download(url, dest)


def fetch_hdri() -> None:
    files = get_json(f"https://api.polyhaven.com/files/{HDRI_ID}")
    hdr = files.get("hdri", {}).get(HDRI_RES, {}).get("hdr")
    if not hdr:
        # fallback keys used by some assets
        for res in (HDRI_RES, "1k", "2k"):
            block = files.get("hdri", {}).get(res, {})
            hdr = block.get("hdr") or block.get("exr")
            if hdr:
                break
    if not hdr:
        print("HDRI payload:", list(files.keys())[:20])
        raise SystemExit(f"no HDRI url for {HDRI_ID}")
    ext = ".hdr" if "hdr" in hdr.get("url", "") else ".exr"
    dest = ENV / f"{HDRI_ID}{ext}"
    download(hdr["url"], dest)
    (ENV / "SOURCE.txt").write_text(
        f"{HDRI_ID}\nhttps://polyhaven.com/a/{HDRI_ID}\nLicense: CC0 1.0\n",
        encoding="utf-8",
    )


def main() -> int:
    TEX.mkdir(parents=True, exist_ok=True)
    ENV.mkdir(parents=True, exist_ok=True)
    for asset_id, maps in TEXTURES.items():
        try:
            fetch_texture(asset_id, maps)
        except Exception as exc:
            print(f"ERROR {asset_id}: {exc}")
            # try 1k concrete_floor_01 fallback names later
    try:
        fetch_hdri()
    except Exception as exc:
        print(f"ERROR hdri: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
