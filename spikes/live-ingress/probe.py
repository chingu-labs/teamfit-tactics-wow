"""Generate and publish bounded WoW LOD transport fixtures, never step data."""

import argparse
import json
import os
from pathlib import Path
import re
import tempfile
import time
import uuid


HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent


def bounded_integer(value, minimum, maximum):
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValueError(f"Expected an integer from {minimum} to {maximum}")
    return value


def slot_name(index):
    return f"TeamfitLiveProbeSlot{index:04d}"


def atomic_write(path, content):
    if path.is_symlink() or path.parent.is_symlink():
        raise ValueError("Refusing a symlinked fixture destination")
    descriptor, temporary = tempfile.mkstemp(prefix=".teamfit-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as output:
            output.write(content)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def prepare(output, interface, slots=64, interval=5):
    bounded_integer(interface, 10000, 999999)
    bounded_integer(slots, 1, 3600)
    bounded_integer(interval, 1, 30)
    # A new output only: never overwrite an installed addon or an earlier run.
    output.mkdir(parents=True, exist_ok=False)
    main = output / "TeamfitLiveProbe"
    main.mkdir()
    manifest = {"schemaVersion": 1, "slots": slots, "intervalSeconds": interval,
                "staleSeconds": max(15, interval * 3), "interface": interface}
    (main / "probe-manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    (main / "TeamfitLiveProbe.toc").write_text(
        f"## Interface: {interface}\n## Title: Teamfit Tactics Transport Test\n"
        "## Notes: Synthetic transport fixtures only. No step tracking.\n"
        "Config.lua\nProbe.lua\n", encoding="utf-8")
    (main / "Config.lua").write_text(
        "TeamfitLiveProbeConfig = { slots = %d, intervalSeconds = %d, staleSeconds = %d }\n"
        % (slots, interval, manifest["staleSeconds"]), encoding="utf-8")
    (main / "Probe.lua").write_bytes((HERE / "Probe.lua").read_bytes())
    for index in range(1, slots + 1):
        slot = output / slot_name(index)
        slot.mkdir()
        (slot / f"{slot.name}.toc").write_text(
            f"## Interface: {interface}\n## Title: Teamfit Transport Slot {index}\n"
            "## Dependencies: TeamfitLiveProbe\n## LoadOnDemand: 1\nPayload.lua\n",
            encoding="utf-8")
        (slot / "Payload.lua").write_text("-- No publisher payload yet.\n", encoding="utf-8")
    return main


def read_manifest(main):
    manifest = json.loads((main / "probe-manifest.json").read_text(encoding="utf-8"))
    if manifest.get("schemaVersion") != 1 or main.name != "TeamfitLiveProbe":
        raise ValueError("Not a generated Teamfit transport test")
    bounded_integer(manifest["slots"], 1, 3600)
    bounded_integer(manifest["intervalSeconds"], 1, 30)
    return manifest


def publish_once(main, sequence, run, published_at):
    manifest = read_manifest(main)
    bounded_integer(sequence, 1, 1000000000)
    bounded_integer(published_at, 0, 9007199254740991)
    if not isinstance(run, str) or re.fullmatch(r"[a-f0-9]{32}", run) is None:
        raise ValueError("Invalid publisher run identifier")
    # No outbound channel is assumed. Every unused slot must see the latest fixture.
    # This O(pool size) write cost is deliberately part of the diagnostic.
    for index in range(1, manifest["slots"] + 1):
        destination = main.parent / slot_name(index) / "Payload.lua"
        content = ("TeamfitLiveProbe.Receive({ fixture = true, slot = %d, sequence = %d, "
                   "publishedAt = %d, run = \"%s\" })\n") % (index, sequence, published_at, run)
        atomic_write(destination, content)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    create = commands.add_parser("prepare")
    create.add_argument("--interface", required=True, type=int)
    create.add_argument("--slots", default=64, type=int)
    create.add_argument("--interval", default=5, type=int)
    create.add_argument("--output", type=Path, default=ROOT / "dist/live-ingress-probe")
    publish = commands.add_parser("publish")
    publish.add_argument("--addon", type=Path, required=True,
                         help="Generated TeamfitLiveProbe directory, not the slot directory")
    publish.add_argument("--ticks", type=int, default=12)
    args = parser.parse_args()
    if args.command == "prepare":
        result = prepare(args.output, args.interface, args.slots, args.interval)
        print(result)
        print("Transport fixtures only. Not installed. No steps measured.")
        return
    bounded_integer(args.ticks, 1, 7200)
    manifest = read_manifest(args.addon)
    run = uuid.uuid4().hex
    for sequence in range(1, args.ticks + 1):
        started = time.monotonic()
        publish_once(args.addon, sequence, run, int(time.time()))
        duration = time.monotonic() - started
        print(f"Fixture {sequence}: {manifest['slots']} files, {duration:.3f}s", flush=True)
        if sequence < args.ticks:
            time.sleep(max(0, manifest["intervalSeconds"] - duration))
    print("Publisher stopped. The in-game display must become stale or exhausted.")


if __name__ == "__main__":
    main()
