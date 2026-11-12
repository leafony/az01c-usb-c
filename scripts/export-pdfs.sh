#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

kicad_cli="${KICAD_CLI:-kicad-cli}"
kicad_version="$("$kicad_cli" version)"
case "$kicad_version" in
  10.*) ;;
  *) printf 'KiCad 10 is required (found %s).\n' "$kicad_version" >&2; exit 1 ;;
esac

# Stage both PDFs so a failed export does not replace the previous output.
mkdir -p output
staging_dir="$(mktemp -d "$repo_dir/output/.pdf.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
project="kicad/leafony-az01c"
layers="F.Cu,In1.Cu,In2.Cu,B.Cu,F.Silkscreen,B.Silkscreen"

"$kicad_cli" sch export pdf \
  --black-and-white --no-background-color \
  --output "$staging_dir/schematic.pdf" \
  "$project.kicad_sch"

# Plot the single board, with each layer viewed from the front (no mirroring).
"$kicad_cli" pcb export pdf \
  --mode-multipage --layers "$layers" --common-layers Edge.Cuts \
  --black-and-white --include-border-title --scale 4 --check-zones \
  --output "$staging_dir/layout.pdf" \
  "$project.kicad_pcb"

python3 - "$staging_dir" <<'PYTHON'
from pathlib import Path
import re
import sys

for filename in ("schematic.pdf", "layout.pdf"):
    data = (Path(sys.argv[1]) / filename).read_bytes()
    if not data.startswith(b"%PDF-") or b"%%EOF" not in data[-1024:]:
        raise SystemExit(f"Invalid or incomplete PDF: {filename}")
    previous = Path("output") / filename
    if previous.exists():
        # KiCad embeds the export time even when the design is unchanged.
        # Compare without that metadata and keep the original PDF if identical.
        def without_export_time(pdf):
            return re.sub(rb"/CreationDate \(D:[0-9:]+\)", b"/CreationDate ()", pdf)

        old_data = previous.read_bytes()
        if without_export_time(data) == without_export_time(old_data):
            (Path(sys.argv[1]) / filename).write_bytes(old_data)
PYTHON

cp "$staging_dir/schematic.pdf" output/schematic.pdf
cp "$staging_dir/layout.pdf" output/layout.pdf
printf 'Generated output/schematic.pdf and output/layout.pdf\n'
