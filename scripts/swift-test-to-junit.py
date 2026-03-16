#!/usr/bin/env python3
"""Convert `swift test` (swift-testing) console output into a minimal JUnit XML.

This is intentionally simple: it parses lines like:
  ◇ Test <name>() started.
  ✔ Test <name>() passed after ...
  ✘ Test <name>() ...

Usage:
  scripts/swift-test-to-junit.py <input_log> <output_xml>
"""

from __future__ import annotations

import re
import sys
import time
import xml.etree.ElementTree as ET


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: swift-test-to-junit.py <input_log> <output_xml>", file=sys.stderr)
        return 2

    inp, outp = sys.argv[1], sys.argv[2]

    started_re = re.compile(r"^◇ Test (.+) started\.")
    passed_re = re.compile(r"^✔ Test (.+) passed")
    failed_re = re.compile(r"^✘ Test (.+) (failed|recorded an issue)")

    # Map: testName -> {status: passed|failed|unknown, message: str}
    tests: dict[str, dict[str, str]] = {}

    with open(inp, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")

            m = started_re.match(line)
            if m:
                name = m.group(1).strip()
                # Ignore run-level bookkeeping lines like "run" / "run with N tests".
                if name.startswith("run"):
                    continue
                tests.setdefault(name, {"status": "unknown", "message": ""})
                continue

            m = passed_re.match(line)
            if m:
                name = m.group(1).strip()
                if name.startswith("run"):
                    continue
                tests.setdefault(name, {"status": "unknown", "message": ""})
                tests[name]["status"] = "passed"
                continue

            m = failed_re.match(line)
            if m:
                name = m.group(1).strip()
                if name.startswith("run"):
                    continue
                tests.setdefault(name, {"status": "unknown", "message": ""})
                tests[name]["status"] = "failed"
                # Next lines might include details; keep first failure line for context
                if not tests[name]["message"]:
                    tests[name]["message"] = line
                continue

            # Attach issue detail lines to the last failed test (best-effort)
            if line.startswith("✘") or line.startswith("/") or line.startswith("Expectation failed"):
                # Find last failed test inserted
                for k in reversed(list(tests.keys())):
                    if tests[k]["status"] == "failed":
                        msg = tests[k]["message"]
                        if msg:
                            msg += "\n" + line
                        else:
                            msg = line
                        tests[k]["message"] = msg
                        break

    suite = ET.Element("testsuite")
    suite.set("name", "swift test")
    suite.set("timestamp", time.strftime("%Y-%m-%dT%H:%M:%S"))

    total = len(tests)
    failures = sum(1 for t in tests.values() if t["status"] == "failed")

    suite.set("tests", str(total))
    suite.set("failures", str(failures))

    for name, info in tests.items():
        tc = ET.SubElement(suite, "testcase")
        tc.set("name", name)
        tc.set("classname", "ghw")
        # no reliable duration available from log parsing
        tc.set("time", "0")
        if info["status"] == "failed":
            failure = ET.SubElement(tc, "failure")
            failure.set("message", "test failed")
            failure.text = info.get("message", "")

    tree = ET.ElementTree(suite)
    ET.indent(tree, space="  ")
    with open(outp, "wb") as f:
        tree.write(f, encoding="utf-8", xml_declaration=True)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
