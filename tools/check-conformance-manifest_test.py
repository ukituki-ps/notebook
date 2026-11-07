#!/usr/bin/env python3
"""Tests for tools/check-conformance-manifest.py (U02/S2).

Run: python3 -m unittest tools/check-conformance-manifest_test.py
"""

import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHECKER = ROOT / "tools/check-conformance-manifest.py"


class CheckerTest(unittest.TestCase):
    def test_self_test(self) -> None:
        proc = subprocess.run(
            [sys.executable, str(CHECKER), "--self-test"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("SELFTEST:", proc.stdout)

    def test_repository_manifest_release(self) -> None:
        proc = subprocess.run(
            [sys.executable, str(CHECKER), "--release"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("total=29", proc.stdout)

    def test_final_gate_rejects_red_baseline(self) -> None:
        proc = subprocess.run(
            [sys.executable, str(CHECKER), "--final"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 1, proc.stdout + proc.stderr)
        self.assertIn("final release gate forbids red", proc.stderr)


if __name__ == "__main__":
    unittest.main()
