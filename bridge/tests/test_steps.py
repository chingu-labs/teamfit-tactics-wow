import importlib.util
import errno
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


HERE = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("teamfit_steps", HERE / "steps.py")
steps = importlib.util.module_from_spec(spec)
spec.loader.exec_module(steps)


class StepBridgeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.output = Path(self.temporary.name) / "bridge"
        self.main = steps.prepare(self.output, 11509, slots=4, interval=5)

    def test_generated_manifests_reference_existing_files(self):
        for toc in self.output.glob("*/*.toc"):
            text = toc.read_text()
            self.assertIn("## Interface: 11509", text)
            for line in text.splitlines():
                if line and not line.startswith("#"):
                    self.assertTrue((toc.parent / line).is_file(), line)
            if toc.parent != self.main:
                self.assertIn("## LoadOnDemand: 1", text)
                self.assertIn("## Dependencies: TeamfitTactics", text)

    def test_prepare_never_overwrites(self):
        original = (self.main / "Addon.lua").read_bytes()
        with self.assertRaises(FileExistsError):
            steps.prepare(self.output, 11509)
        self.assertEqual((self.main / "Addon.lua").read_bytes(), original)

    def test_every_unused_slot_gets_latest_measured_steps(self):
        steps.publish_once(self.main, 1, "a" * 32, 1000, 12, True)
        steps.publish_once(self.main, 2, "a" * 32, 1005, 18, True)
        for index in range(1, 5):
            payload = self.output / steps.slot_name(index) / "Payload.lua"
            text = payload.read_text()
            self.assertIn(f"slot = {index}, sequence = 2", text)
            self.assertIn("steps = 18, available = true", text)
            self.assertEqual(list(payload.parent.glob(".teamfit-*")), [])

    def test_payload_executes_with_contract(self):
        steps.publish_once(self.main, 9, "a" * 32, 1000, 321, False)
        payload = self.output / steps.slot_name(1) / "Payload.lua"
        result = subprocess.run(
            [os.environ.get("LUA", "lua"), "-", str(payload)],
            input='''local received
TeamfitTactics = { Receive = function(sample) received = sample end }
assert(loadfile(arg[1]))()
assert(received.schemaVersion == 1 and received.source == "kingsmith-wilink")
assert(received.sequence == 9 and received.slot == 1 and received.steps == 321)
assert(received.available == false and received.observedAt == 1000)
''', text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_invalid_publications_change_nothing(self):
        payload = self.output / steps.slot_name(1) / "Payload.lua"
        before = payload.read_bytes()
        invalid = [
            (0, "a" * 32, 1000, 1, True),
            (1, '"; unsafe()', 1000, 1, True),
            (1, "a" * 32, -1, 1, True),
            (1, "a" * 32, 1000, -1, True),
            (1, "a" * 32, 1000, 1, 1),
        ]
        for values in invalid:
            with self.assertRaises(ValueError):
                steps.publish_once(self.main, *values)
        self.assertEqual(payload.read_bytes(), before)

    def test_symlinked_payload_is_rejected(self):
        payload = self.output / steps.slot_name(1) / "Payload.lua"
        protected = Path(self.temporary.name) / "unrelated.lua"
        protected.write_text("preserve")
        payload.unlink()
        try:
            payload.symlink_to(protected)
        except NotImplementedError as error:
            self.skipTest(str(error))
        except OSError as error:
            if getattr(error, "winerror", None) == 1314 or error.errno in {
                errno.EPERM, errno.EACCES, errno.ENOSYS, errno.ENOTSUP,
            }:
                self.skipTest(str(error))
            raise
        with self.assertRaises(ValueError):
            steps.publish_once(self.main, 1, "a" * 32, 1000, 1, True)
        self.assertEqual(protected.read_text(), "preserve")


if __name__ == "__main__":
    unittest.main()
