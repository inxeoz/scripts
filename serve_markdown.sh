#!/usr/bin/env bash
export PATH="$HOME/.cargo/bin:$PATH"
set -euo pipefail

# Usage: md <file.md | folder> [port]
TARGET="${1:-}"
PORT="${2:-3000}"

if [ -z "$TARGET" ]; then
  echo "Usage: md <file.md | folder> [port]"
  exit 1
fi

BASE="$HOME/.mdpage"
SINGLE="$BASE/single"
FOLDER="$BASE/folder"

mkdir -p "$BASE"

# Helper: create book.toml with port
create_book_toml() {
  local dest="$1"
  cat > "$dest/book.toml" <<EOF
[book]
title = "Book"

[output.html]
port = $PORT
EOF
}

# Helper: create SUMMARY.md from files in src
create_summary_from_src() {
  local srcdir="$1"
  local summary="$srcdir/SUMMARY.md"
  echo "# Summary" > "$summary"
  # list markdown files (sorted), skip SUMMARY.md itself
  find "$srcdir" -maxdepth 1 -type f -name '*.md' -printf '%f\n' | sort | while read -r fn; do
    [ "$fn" = "SUMMARY.md" ] && continue
    echo "* [${fn%.*}]($fn)" >> "$summary"
  done
}

# ------------------------------
# CASE: target is directory
# ------------------------------
if [ -d "$TARGET" ]; then
  echo "📁 Serving folder as mdBook project: $TARGET"

  # clear destination folder
  rm -rf "$FOLDER"
  mkdir -p "$FOLDER"

  # If target already looks like an mdBook project (book.toml or src/)
  if [ -f "$TARGET/book.toml" ] || [ -d "$TARGET/src" ]; then
    echo "Detected mdBook structure in target — copying project..."
    # copy entire project (preserve structure)
    rsync -a --delete --exclude='.mdpage' "$TARGET"/ "$FOLDER"/
    cd "$FOLDER"
    # ensure book.toml exists (it should), but create if missing
    if [ ! -f book.toml ]; then
      create_book_toml "$FOLDER"
    fi
    # if src/SUMMARY.md missing, try to generate it from src/*.md
    if [ ! -f src/SUMMARY.md ]; then
      mkdir -p src
      create_summary_from_src "$FOLDER/src"
    fi

    mdbook serve --port "$PORT" --open
    exit 0
  fi

  # Otherwise: treat as a plain folder of markdown files.
  # Create a fresh mdBook structure in $FOLDER and copy top-level *.md files into src/
  mkdir -p "$FOLDER/src"

  # Copy top-level markdown files (non-recursive) from TARGET into $FOLDER/src
  shopt -s nullglob
  has_md=false
  for f in "$TARGET"/*.md; do
    has_md=true
    cp "$f" "$FOLDER/src/"
  done
  shopt -u nullglob

  if [ "$has_md" = false ]; then
    echo "⚠️ No top-level .md files found in $TARGET. If you intended to serve an mdBook project, make sure it contains book.toml or src/."
  fi

  # create book.toml and SUMMARY.md
  create_book_toml "$FOLDER"
  create_summary_from_src "$FOLDER/src"

  cd "$FOLDER"
  mdbook serve --port "$PORT" --open
  exit 0
fi

# ------------------------------
# CASE: target is single file
# ------------------------------
if [ -f "$TARGET" ]; then
  echo "📄 Serving single Markdown file: $TARGET"

  rm -rf "$SINGLE"
  mkdir -p "$SINGLE/src"

  cat > "$SINGLE/book.toml" <<EOF
[book]
title = "Preview"

[output.html]
port = $PORT
EOF

  cat > "$SINGLE/src/SUMMARY.md" <<EOF
# Summary
* [Page](page.md)
EOF

  cp "$TARGET" "$SINGLE/src/page.md"

  cd "$SINGLE"
  mdbook serve --port "$PORT" --open
  exit 0
fi

echo "❌ ERROR: '$TARGET' is neither a file nor a directory."
exit 1
