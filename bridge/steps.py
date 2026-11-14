"""Generate and update the bounded Teamfit Tactics step-ingress addon pool."""

import argparse
import json
import os
from pathlib import Path
import re
import tempfile


ROOT = Path(__file__).resolve().parent.parent


def bounded_integer(value, minimum, maximum):
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValueError(f"Expected an integer from {minimum} to {maximum}")
    return value


def slot_name(index):
    return f"TeamfitTacticsSlot{index:04d}"


def atomic_write(path, content):
    if path.is_symlink() or path.parent.is_symlink():
        raise ValueError("Refusing a symlinked step destination")
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
    output.mkdir(parents=True, exist_ok=False)
    main = output / "TeamfitTactics"
    main.mkdir()
    manifest = {
        "schemaVersion": 1,
        "slots": slots,
        "intervalSeconds": interval,
        "staleSeconds": max(15, interval * 3),
        "interface": interface,
    }
    (main / "step-bridge-manifest.json").write_text(
        json.dumps(manifest), encoding="utf-8"
    )
    (main / "TeamfitTactics.toc").write_text(
        f"## Interface: {interface}\n## Title: Teamfit Tactics\n"
        "## Notes: Bounded live KingSmith WalkingPad step counter.\n"
        "## Author: Chingu Labs\n## Version: 0.3.0-dev\n"
        "## SavedVariablesPerCharacter: TeamfitTacticsDB\n## X-License: MIT\n\n"
        "Config.lua\nAddon.lua\n",
        encoding="utf-8",
    )
    (main / "Config.lua").write_text(
        "TeamfitTacticsConfig = { slots = %d, intervalSeconds = %d, staleSeconds = %d }\n"
        % (slots, interval, manifest["staleSeconds"]),
        encoding="utf-8",
    )
    (main / "Addon.lua").write_bytes((ROOT / "TeamfitTactics/Addon.lua").read_bytes())
    for index in range(1, slots + 1):
        slot = output / slot_name(index)
        slot.mkdir()
        (slot / f"{slot.name}.toc").write_text(
            f"## Interface: {interface}\n## Title: Teamfit Tactics Step Slot {index}\n"
            "## Dependencies: TeamfitTactics\n## LoadOnDemand: 1\nPayload.lua\n",
            encoding="utf-8",
        )
        (slot / "Payload.lua").write_text("-- Awaiting a desktop reading.\n", encoding="utf-8")
    return main


def read_manifest(main):
    manifest = json.loads((main / "step-bridge-manifest.json").read_text(encoding="utf-8"))
    if manifest.get("schemaVersion") != 1 or main.name != "TeamfitTactics":
        raise ValueError("Not a generated Teamfit Tactics step bridge")
    bounded_integer(manifest["slots"], 1, 3600)
    bounded_integer(manifest["intervalSeconds"], 1, 30)
    return manifest


def publish_once(main, sequence, run, observed_at, steps, available):
    manifest = read_manifest(main)
    bounded_integer(sequence, 1, 1000000000)
    bounded_integer(observed_at, 0, 9007199254740991)
    bounded_integer(steps, 0, 9007199254740991)
    if type(available) is not bool:
        raise ValueError("Availability must be boolean")
    if not isinstance(run, str) or re.fullmatch(r"[a-f0-9]{32}", run) is None:
        raise ValueError("Invalid source session identifier")
    literal = "true" if available else "false"
    for index in range(1, manifest["slots"] + 1):
        destination = main.parent / slot_name(index) / "Payload.lua"
        content = (
            "TeamfitTactics.Receive({ schemaVersion = 1, source = \"kingsmith-wilink\", "
            "slot = %d, sequence = %d, observedAt = %d, steps = %d, "
            "available = %s, run = \"%s\" })\n"
        ) % (index, sequence, observed_at, steps, literal, run)
        atomic_write(destination, content)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    create = commands.add_parser("prepare")
    create.add_argument("--interface", required=True, type=int)
    create.add_argument("--slots", default=64, type=int)
    create.add_argument("--interval", default=5, type=int)
    create.add_argument("--output", type=Path, default=ROOT / "dist/steps-ingress")
    args = parser.parse_args()
    result = prepare(args.output, args.interface, args.slots, args.interval)
    print(result)
    print("Generated only. Not installed; no sensor was accessed.")


if __name__ == "__main__":
    main()
