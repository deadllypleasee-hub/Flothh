#!/usr/bin/env python3
"""Godot editor can return 0 on parse failure: explicitly reject engine errors."""
import pathlib
import re
import sys

failed = False
for path in sys.argv[1:]:
    text = pathlib.Path(path).read_text(encoding="utf-8", errors="replace")
    for line in text.splitlines():
        if re.search(r"SCRIPT ERROR:|ERROR:|FAIL  |Parse Error|Compile Error", line):
            print(f"{path}: {line}")
            failed = True
sys.exit(1 if failed else 0)
