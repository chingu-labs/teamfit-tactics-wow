import importlib.util
import errno
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


HERE = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("teamfit_probe", HERE / "probe.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


class ProbeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.output = Path(self.temporary.name) / "new-probe"
        self.main = probe.prepare(self.output, 11509, slots=4, interval=5)

    def test_manifests_reference_existing_files_and_slots_are_load_on_demand(self):
        for toc in self.output.glob("*/*.toc"):
            text = toc.read_text()
            self.assertIn("## Interface: 11509", text)
            for line in text.splitlines():
                if line and not line.startswith("#"):
                    self.assertTrue((toc.parent / line).is_file(), line)
            if toc.parent != self.main:
                self.assertIn("## LoadOnDemand: 1", text)
                self.assertIn("## Dependencies: TeamfitLiveProbe", text)

    def test_prepare_never_overwrites_an_existing_directory(self):
        original = (self.main / "Probe.lua").read_bytes()
        with self.assertRaises(FileExistsError):
            probe.prepare(self.output, 11509)
        self.assertEqual((self.main / "Probe.lua").read_bytes(), original)

    def test_every_slot_receives_the_latest_sequence_without_temporary_files(self):
        probe.publish_once(self.main, 1, "a" * 32, 1000)
        probe.publish_once(self.main, 2, "a" * 32, 1005)
        for index in range(1, 5):
            path = self.output / probe.slot_name(index) / "Payload.lua"
            self.assertIn(f"slot = {index}, sequence = 2", path.read_text())
            self.assertIn("fixture = true", path.read_text())
            self.assertNotIn("steps", path.read_text())
            self.assertEqual(list(path.parent.glob(".teamfit-*")), [])

    def test_payload_executes_as_lua_with_the_expected_fixture_contract(self):
        probe.publish_once(self.main, 9, "a" * 32, 1000)
        payload = self.output / probe.slot_name(1) / "Payload.lua"
        result = subprocess.run(
            [os.environ.get("LUA", "lua"), "-", str(payload)],
            input='''local received
TeamfitLiveProbe = { Receive = function(sample) received = sample end }
assert(loadfile(arg[1]))()
assert(received.fixture == true and received.sequence == 9 and received.slot == 1)
assert(received.publishedAt == 1000 and received.run == string.rep("a", 32))
assert(received.steps == nil)
''', text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_invalid_publication_is_rejected_before_any_payload_changes(self):
        path = self.output / probe.slot_name(1) / "Payload.lua"
        before = path.read_bytes()
        invalid = [(0, "a" * 32, 1000), (1, '"; unsafe()', 1000),
                   (1, "a" * 32, -1), (True, "a" * 32, 1000)]
        for sequence, run, timestamp in invalid:
            with self.assertRaises(ValueError):
                probe.publish_once(self.main, sequence, run, timestamp)
        self.assertEqual(path.read_bytes(), before)

    def test_symlinked_payload_is_not_replaced(self):
        path = self.output / probe.slot_name(1) / "Payload.lua"
        protected = Path(self.temporary.name) / "unrelated.lua"
        protected.write_text("preserve")
        path.unlink()
        try:
            path.symlink_to(protected)
        except NotImplementedError as error:
            self.skipTest(f"Symlink creation is unavailable: {error}")
        except OSError as error:
            if getattr(error, "winerror", None) == 1314 or error.errno in {
                errno.EPERM, errno.EACCES, errno.ENOSYS, errno.ENOTSUP,
            }:
                self.skipTest(f"Symlink creation is unavailable: {error}")
            raise
        with self.assertRaises(ValueError):
            probe.publish_once(self.main, 1, "a" * 32, 1000)
        self.assertEqual(protected.read_text(), "preserve")

    def test_symlink_guard_rejects_before_creating_or_replacing_files(self):
        path = self.output / probe.slot_name(1) / "Payload.lua"
        before = path.read_bytes()
        with patch.object(Path, "is_symlink", return_value=True):
            with patch.object(probe.tempfile, "mkstemp") as create:
                with self.assertRaises(ValueError):
                    probe.atomic_write(path, "must not be written")
                create.assert_not_called()
        self.assertEqual(path.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
