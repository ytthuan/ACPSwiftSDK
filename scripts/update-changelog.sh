#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <version> <date>" >&2
  exit 1
fi

version="$1"
date="$2"
changelog_file="CHANGELOG.md"

if [[ ! -f "$changelog_file" ]]; then
  echo "Error: $changelog_file not found in current directory." >&2
  exit 1
fi

python3 - "$version" "$date" "$changelog_file" <<'PY'
import pathlib
import re
import sys

version, date, path_str = sys.argv[1], sys.argv[2], sys.argv[3]
path = pathlib.Path(path_str)
text = path.read_text(encoding="utf-8")

unreleased_match = re.search(r"^## \[Unreleased\]\n", text, re.MULTILINE)
if not unreleased_match:
    print("Error: Could not find '## [Unreleased]' section.", file=sys.stderr)
    sys.exit(1)

start = unreleased_match.start()
body_start = unreleased_match.end()
next_heading = re.search(r"^## \[[^\]]+\]", text[body_start:], re.MULTILINE)
if next_heading:
    body_end = body_start + next_heading.start()
    tail = text[body_end:]
else:
    body_end = len(text)
    tail = ""

prefix = text[:start]
unreleased_body = text[body_start:body_end].strip("\n")

new_unreleased = "## [Unreleased]\n\n### Added\n- _None yet._\n\n"
new_version_heading = f"## [{version}] - {date}\n\n"

if unreleased_body.strip():
    promoted_body = unreleased_body.rstrip() + "\n\n"
else:
    promoted_body = "### Added\n- _None yet._\n\n"

new_text = prefix + new_unreleased + new_version_heading + promoted_body + tail.lstrip("\n")
path.write_text(new_text, encoding="utf-8")
PY
