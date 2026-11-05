"""Exercise navigation with real jq and a fake yabai; never move real windows."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "window_focus_or_swap.sh"

MOCK_YABAI = r'''#!/bin/bash
printf '%s\n' "$*" >> "$FIXTURE/calls"
case "$*" in
  '-m query --windows')
    [[ "$QUERY_FAIL" != 1 ]] || exit 1
    cat "$FIXTURE/windows.json" ;;
  '-m query --windows --window')
    if [[ -f "$FIXTURE/focused" ]]; then
      cat "$FIXTURE/neighbor.json"
    else
      cat "$FIXTURE/origin.json"
    fi ;;
  '-m query --windows --window '* )
    [[ -f "$FIXTURE/neighbor.json" ]] || exit 1
    cat "$FIXTURE/neighbor.json" ;;
  '-m query --displays --display')
    printf '{"frame":{"x":0,"y":0,"w":1000,"h":800}}\n' ;;
  '-m window --focus east'|'-m window --focus west')
    [[ -f "$FIXTURE/neighbor.json" ]] || exit 1
    touch "$FIXTURE/focused" ;;
  '-m window --focus '*|'-m window --swap '*) exit 0 ;;
  *) exit 1 ;;
esac
'''


def window(id, x, y=0, display=1, **flags):
    return {"id": id, "display": display,
            "frame": {"x": x, "y": y, "w": 100, "h": 100},
            "has-focus": id == 1, "is-visible": True,
            "is-minimized": False, "is-floating": False, **flags}


class NavigationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = dict(os.environ, DYLD_INSERT_LIBRARIES="",
                        FIXTURE=str(self.root), QUERY_FAIL="0",
                        REAL_JQ=shutil.which("jq"),
                        PATH=str(self.root) + os.pathsep + os.environ["PATH"])
        for name, code in {
            "yabai": MOCK_YABAI,
            "jq": '#!/bin/bash\nprintf "jq\\n" >> "$FIXTURE/calls"\nexec "$REAL_JQ" "$@"\n',
        }.items():
            path = self.root / name
            path.write_text(code)
            path.chmod(0o755)

    def run_navigation(self, windows, neighbor=None, direction="east", swap=False, script=SCRIPT):
        for filename in ("neighbor.json", "focused", "calls"):
            (self.root / filename).unlink(missing_ok=True)
        (self.root / "windows.json").write_text(json.dumps(windows))
        (self.root / "origin.json").write_text(json.dumps(windows[0] if windows else None))
        if neighbor is not None:
            (self.root / "neighbor.json").write_text(json.dumps(neighbor))
        result = subprocess.run(["/bin/bash", str(script), direction, str(swap).lower()],
                                env=self.env, capture_output=True, text=True, timeout=5)
        calls = (self.root / "calls").read_text().splitlines()
        return result, calls

    def test_horizontal_destinations_and_single_focus(self):
        origin = window(1, 500)
        left, right = window(2, 0), window(3, 1000, display=2)
        vertical = window(4, 500, 500)
        cases = [
            ("native right", [origin, right], right, "east", 3),
            ("native left", [origin, left], left, "west", 2),
            ("cross display fallback", [origin, right], None, "east", 3),
            ("native cross display at same x", [origin, window(5, 500, display=2)], window(5, 500, display=2), "east", 5),
            ("east wrap", [origin, left], None, "east", 2),
            ("west wrap", [origin, right], None, "west", 3),
            ("reject vertical native", [origin, vertical, right], vertical, "east", 3),
            ("within horizontal tolerance", [origin, window(6, 514), right], window(6, 514), "east", 3),
            ("vertical-only cycle", [origin, vertical], vertical, "east", 4),
            ("self candidate", [origin, right], origin, "east", 3),
            ("nearest x then y", [origin, window(6, 800, 500), window(7, 800, 0), right], None, "east", 7),
            ("negative coordinates", [origin, window(8, -1500, display=2), left], None, "west", 2),
            ("exclude unavailable windows", [origin, right, window(8, 650, **{"is-visible": False}), window(9, 700, **{"is-minimized": True}), window(10, 750, **{"is-floating": True})], None, "east", 3),
            ("one window", [origin], None, "east", None),
            ("no focused window", [window(2, 0), right], None, "east", None),
            ("empty snapshot", [], None, "east", None),
        ]
        for name, windows, neighbor, direction, target in cases:
            with self.subTest(name=name):
                result, calls = self.run_navigation(windows, neighbor, direction)
                self.assertEqual(result.stderr, "")
                focuses = [c for c in calls if c.startswith("-m window --focus")]
                self.assertEqual(focuses, [] if target is None else [f"-m window --focus {target}"])
                self.assertEqual(result.returncode, 1 if target is None else 0)
                self.assertEqual(calls.count("jq"), 1)
                self.assertEqual(sum(c.startswith("-m query") for c in calls), 2)

    def test_failed_snapshot_does_not_focus(self):
        self.env["QUERY_FAIL"] = "1"
        result, calls = self.run_navigation([window(1, 0)])
        self.assertEqual(result.returncode, 1)
        self.assertEqual(calls, ["-m query --windows"])

    def test_plain_vertical_focus_needs_no_queries(self):
        for direction in ("north", "south"):
            result, calls = self.run_navigation([window(1, 0)], direction=direction)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(calls, [f"-m window --focus {direction}"])

    def test_vertical_edge_swaps(self):
        for direction, y, partner in (("north", 0, "south"), ("south", 700, "north")):
            result, calls = self.run_navigation([window(1, 0, y)], direction=direction, swap=True)
            self.assertEqual(result.returncode, 0)
            self.assertEqual([c for c in calls if c.startswith("-m window")],
                             [f"-m window --swap {partner}", f"-m window --focus {direction}"])

    def test_horizontal_swap_returns_focus_to_original_window(self):
        for direction, partner in (("east", "west"), ("west", "east")):
            result, calls = self.run_navigation([window(1, 500), window(2, 0)],
                                                direction=direction, swap=True)
            self.assertEqual(result.returncode, 0)
            self.assertEqual([c for c in calls if c.startswith("-m window")],
                             [f"-m window --swap {direction}", f"-m window --focus {partner}",
                              "-m window --focus 1"])


if __name__ == "__main__":
    unittest.main()
