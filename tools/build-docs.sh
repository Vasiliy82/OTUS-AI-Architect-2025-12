#!/usr/bin/env bash
#
# Builds homework deliverables:
#   1) downloads tools/plantuml.jar if missing
#   2) renders HW-XX/diagrams/*.puml -> *.svg (for GitHub)
#   3) builds HW-XX/HW-XX-решение.pdf via pandoc + typst PDF engine
#      (a Lua filter renders inline ```plantuml blocks to PNG inside the PDF)
#
# Requirements: java (PlantUML), pandoc, typst. Graphviz is auto-detected by
# PlantUML if installed; otherwise PlantUML still renders sequence diagrams.
#
# Usage:
#   tools/build-docs.sh            # build all HW-* folders
#   tools/build-docs.sh HW-04      # build a single homework
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

JAR="tools/plantuml.jar"
PLANTUML_URL="https://sourceforge.net/projects/plantuml/files/plantuml.jar/download"
PDF_FONT="${PDF_FONT:-Arial}"

# Make sure typst (installed via winget user scope) is reachable.
if ! command -v typst >/dev/null 2>&1; then
  LAD="$(cygpath -u "${LOCALAPPDATA:-}" 2>/dev/null || true)"
  [ -n "$LAD" ] || LAD="$HOME/AppData/Local"
  for p in \
    "$LAD/Microsoft/WinGet/Links" \
    "$LAD"/Microsoft/WinGet/Packages/Typst.Typst_*/typst-*; do
    if [ -e "$p/typst.exe" ] || [ -e "$p/typst" ]; then
      PATH="$PATH:$p"
      break
    fi
  done
fi

if [ ! -f "$JAR" ]; then
  echo ">> Downloading plantuml.jar ..."
  curl -L -o "$JAR" "$PLANTUML_URL"
fi

export PLANTUML_JAR="$ROOT/$JAR"

if [ "$#" -gt 0 ]; then
  TARGETS=("$@")
else
  TARGETS=(HW-*/)
fi

for d in "${TARGETS[@]}"; do
  d="${d%/}"
  [ -d "$d" ] || continue
  echo "=== $d ==="

  if compgen -G "$d/diagrams/*.puml" > /dev/null; then
    echo ">> Rendering SVG diagrams ..."
    java -jar "$JAR" -charset UTF-8 -tsvg "$d"/diagrams/*.puml
  fi

  md="$(ls "$d"/*-решение.md 2>/dev/null | head -1 || true)"
  if [ -n "${md:-}" ]; then
    pdf="${md%.md}.pdf"
    echo ">> Building PDF: $pdf"
    pandoc "$md" -o "$pdf" \
      --pdf-engine=typst \
      --lua-filter=tools/plantuml-image.lua \
      -V mainfont="$PDF_FONT" \
      --metadata title="$(basename "$d")"
  fi
done

echo ">> Done."
