#!/usr/bin/env python3
"""Checks localizations against Resources/en.lproj.

Fails when a language misses or adds keys, when a translation changes format placeholders,
or when a plain string literal passed to a localizing SwiftUI/Foundation API in Sources
has no key in en.lproj/Localizable.strings.
"""
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "Resources"
BASE = RESOURCES / "en.lproj"

PLACEHOLDER = re.compile(r"%(?:\d+\$)?(?:ll|l)?[@dDiuUxXoOfeEgGcCsSpaA]")
# A whole first argument that is a string literal, passed to an API that treats it as a key.
SOURCE_KEY = re.compile(
    r'(?:\bString\(localized:|\bText\(|\bButton\(|\bToggle\(|\bLabeledContent\(|\bSection\(|\bPicker\(|'
    r'\btitle:|\bdetail:|\baction: \()\s*"((?:[^"\\]|\\.)*)"(?=\s*[,)])'
)


def load(path: Path) -> dict:
    result = subprocess.run(
        ["plutil", "-convert", "json", "-o", "-", str(path)],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise ValueError(result.stderr.strip() or result.stdout.strip())
    return json.loads(result.stdout)


def placeholders(text: str) -> Counter:
    return Counter(PLACEHOLDER.findall(text.replace("%%", "")))


def main() -> int:
    errors = []
    base = {}
    for file in sorted(BASE.glob("*.strings")):
        try:
            base[file.name] = load(file)
        except ValueError as error:
            errors.append(f"{file.relative_to(ROOT)}: {error}")

    for lproj in sorted(RESOURCES.glob("*.lproj")):
        if lproj == BASE:
            continue
        for name, base_strings in base.items():
            file = lproj / name
            rel = file.relative_to(ROOT)
            if not file.exists():
                errors.append(f"{rel}: missing file")
                continue
            try:
                strings = load(file)
            except ValueError as error:
                errors.append(f"{rel}: {error}")
                continue
            for key in sorted(base_strings.keys() - strings.keys()):
                errors.append(f"{rel}: missing key {key!r}")
            for key in sorted(strings.keys() - base_strings.keys()):
                errors.append(f"{rel}: unknown key {key!r}")
            for key in sorted(base_strings.keys() & strings.keys()):
                if placeholders(base_strings[key]) != placeholders(strings[key]):
                    errors.append(f"{rel}: placeholders differ from en for {key!r}")

    known = base.get("Localizable.strings", {})
    for swift in sorted((ROOT / "Sources").rglob("*.swift")):
        for line_number, line in enumerate(swift.read_text().splitlines(), 1):
            for key in SOURCE_KEY.findall(line):
                # Interpolated keys become %@/%lld at runtime; they are checked by hand.
                if "\\(" in key or not key or key in known:
                    continue
                errors.append(f"{swift.relative_to(ROOT)}:{line_number}: no en key for {key!r}")

    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        return 1
    languages = sorted(p.stem for p in RESOURCES.glob("*.lproj"))
    print(f"Localizations OK: {', '.join(languages)}, {len(known)} keys")
    return 0


if __name__ == "__main__":
    sys.exit(main())
