#!/usr/bin/env python3
"""Render fixture comparisons with Studio, encode MP4s, and save generated comparison artifacts."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "tests/fixtures/videos"


def run(args, *, capture=False):
    return subprocess.run(args, cwd=ROOT, check=True, text=True,
                          stdout=subprocess.PIPE if capture else None).stdout


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", action="append", default=[], help="Fixture stem; repeat to select several")
    parser.add_argument("--fps", type=int, default=24)
    parser.add_argument("--seconds", type=float, default=6, help="Minimum video duration")
    parser.add_argument("--cycles", type=int, default=2, help="Minimum number of source cycles")
    parser.add_argument("--counter-waist", action="store_true")
    parser.add_argument("--port", type=int, default=44895, help="Dedicated rodeo port for this capture")
    parser.add_argument("--keep-frames", action="store_true", help="Keep full-resolution raw frames under out/videos")
    args = parser.parse_args()
    if not 1 <= args.fps <= 60 or not 0 < args.seconds <= 120 or not 1 <= args.cycles <= 20:
        parser.error("Use fps 1–60, seconds 0–120, and cycles 1–20")
    if not 1024 <= args.port <= 65534:
        parser.error("Use a port from 1024 through 65534; rodeo also uses the next port")
    for tool in ("rodeo", "ffmpeg", "ffprobe"):
        if not shutil.which(tool):
            parser.error(f"Required tool is not on PATH: {tool}")
    available = {p.stem: p for p in sorted((ROOT / "tests/fixtures").glob("*.rbxm"))}
    names = list(dict.fromkeys(args.fixture)) or list(available)
    unknown = set(names) - available.keys()
    if unknown:
        parser.error("Unknown fixtures: " + ", ".join(sorted(unknown)))
    if any(not re.fullmatch(r"[A-Za-z0-9_.-]+", name) for name in names):
        parser.error("Fixture names must use letters, digits, dots, hyphens, and underscores")
    work_root = ROOT / "out/videos"
    work_root.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="capture-", dir=work_root))
    frames = work / "frames"
    frames.mkdir()
    config = {"fps": args.fps, "seconds": args.seconds, "cycles": args.cycles,
              "counterWaist": args.counter_waist, "frames": str(frames),
              "fixtures": [{"name": name, "path": str(available[name])} for name in names]}
    config_path = work / "config.json"
    config_path.write_text(json.dumps(config))
    result_path = work / "capture.json"
    print(f"Capturing {len(names)} fixtures in an isolated Studio; raw frames: {frames}", flush=True)
    run(["rodeo", "run", "--port", str(args.port), "--place", "--focus", "--show-widgets", "none",
         "tools/render-fixtures.luau", "--return", str(result_path), "--", str(config_path)])
    results = json.loads(result_path.read_text())
    records, skipped = [], []
    OUTPUT.mkdir(parents=True, exist_ok=True)
    generated_at = datetime.now(timezone.utc).isoformat()
    converter_hash = sha256(ROOT / "package/src/init.luau")
    renderer_hash = sha256(ROOT / "tools/render-fixtures.luau")
    for result in results:
        if "skipped" in result:
            skipped.append(result)
            continue
        name = result["name"]
        frame_dir = frames / name
        images = sorted(frame_dir.glob("*.png"))
        if len(images) != result["frames"]:
            raise RuntimeError(f"Missing frames for {name}")
        unique = len({sha256(image) for image in images})
        if unique < 2:
            raise RuntimeError(f"No visible motion was captured for {name}")
        staged = work / f"{name}.mp4"
        title = name.replace("rbx_animate_", "").replace("_", " ").upper()
        filters = ",".join([
            "scale=1280:720:force_original_aspect_ratio=decrease:flags=lanczos",
            "pad=1280:720:(ow-iw)/2:(oh-ih)/2:color=0x11151c", "setsar=1",
            "drawbox=x=0:y=0:w=iw:h=56:color=0x11151c:t=fill",
            f"drawtext=font=Arial:text='{title}  /  R15 TO R6':fontcolor=white:fontsize=26:x=28:y=15",
            "drawtext=font=Arial:text='R15  ORIGINAL':fontcolor=0x9cc9ff:fontsize=20:x=w/4-tw/2:y=76",
            "drawtext=font=Arial:text='R6  CONVERTED':fontcolor=0xffd292:fontsize=20:x=3*w/4-tw/2:y=76",
            "drawbox=x=639:y=110:w=2:h=560:color=0x8795aa@0.25:t=fill",
            "drawbox=x=0:y=684:w=iw:h=36:color=0x11151c:t=fill",
            f"drawtext=font=Arial:text='{result['fps']} FPS  /  waist compensation {'ON' if args.counter_waist else 'OFF'}':fontcolor=0xaab7cb:fontsize=16:x=28:y=694",
            "drawtext=font=Arial:text='frame %{n}':fontcolor=0xaab7cb:fontsize=16:x=w-tw-28:y=694",
        ])
        run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-framerate", str(args.fps),
             "-i", str(frame_dir / "%05d.png"), "-vf", filters, "-frames:v", str(result["frames"]),
             "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an", str(staged)])
        probe = json.loads(run(["ffprobe", "-v", "error", "-count_frames", "-select_streams", "v:0",
                               "-show_entries", "stream=codec_name,pix_fmt,width,height,nb_read_frames,avg_frame_rate,duration",
                               "-of", "json", str(staged)], capture=True))["streams"][0]
        assert probe["codec_name"] == "h264" and probe["pix_fmt"] == "yuv420p", probe
        assert (probe["width"], probe["height"]) == (1280, 720), probe
        assert int(probe["nb_read_frames"]) == result["frames"], probe
        assert Fraction(probe["avg_frame_rate"]) == args.fps, probe
        assert abs(float(probe["duration"]) - result["seconds"]) < 1 / args.fps, probe
        poster = work / f"{name}.png"
        run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", str(min(0.3, result["seconds"] / 2)),
             "-i", str(staged), "-frames:v", "1", "-update", "1", str(poster)])
        # Only replace each artifact after its encoded video passes validation.
        for suffix in (".mp4", ".png"):
            previous = OUTPUT / f"{name}{suffix}"
            shutil.copy2(work / f"{name}{suffix}", previous)
        result.update({"sourceSha256": sha256(available[name]), "uniqueCaptureFrames": unique,
                       "counterWaist": args.counter_waist, "encoding": probe,
                       "generatedAt": generated_at, "converterSha256": converter_hash, "rendererSha256": renderer_hash})
        records.append(result)
        print(f"VIDEO {name}: {result['frames']} frames, {result['seconds']:.2f}s, {(OUTPUT / (name + '.mp4')).stat().st_size // 1024} KiB", flush=True)
    manifest_path = OUTPUT / "generation.json"
    prior = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"fixtures": [], "skipped": []}
    # Targeted runs update selected fixtures without dropping metadata for other generated videos.
    merged = {r["name"]: r for r in prior["fixtures"] if r["name"] not in names}
    merged.update({r["name"]: r for r in records})
    merged_skipped = {r["name"]: r for r in prior["skipped"] if r["name"] not in names}
    merged_skipped.update({r["name"]: r for r in skipped})
    manifest = {"generatedAt": datetime.now(timezone.utc).isoformat(),
                "converterSha256": sha256(ROOT / "package/src/init.luau"),
                "rendererSha256": sha256(ROOT / "tools/render-fixtures.luau"),
                "fixtures": sorted(merged.values(), key=lambda r: r["name"]),
                "skipped": sorted(merged_skipped.values(), key=lambda r: r["name"])}
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    if not args.keep_frames:
        shutil.rmtree(frames)
    print(f"Videos: {OUTPUT}", flush=True)


if __name__ == "__main__":
    main()
