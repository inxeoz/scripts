#!/usr/bin/env bash

export PATH="$HOME/.cargo/bin:$PATH"
set -e

# Usage: md <file.md | folder> [port]
TARGET="$1"
PORT="${2:-3000}"  # default port = 3000

if [ -z "$TARGET" ]; then
  echo "Usage: md <file.md | folder> [port]"
  exit 1
fi

# Temporary directory for single-file mode
BOOKDIR=".mdpage_tmp"

# --- CASE 1: Folder provided -----------------------------------------------
if [ -d "$TARGET" ]; then
  echo "📁 Serving mdBook directory: $TARGET"

  cd "$TARGET"

  # If folder lacks mdbook structure → create it
  if [ ! -f "book.toml" ] || [ ! -d "src" ]; then
    echo "⚠️ No mdBook project found — creating one automatically..."

    mkdir -p src

    # Create book.toml if missing
    if [ ! -f book.toml ]; then
      cat > book.toml <<EOF
[book]
title = "Book"

[output.html]
port = $PORT
EOF
    fi

    # Create SUMMARY.md from all markdown files
    echo "# Summary" > src/SUMMARY.md
    for f in *.md; do
      [ "$f" == "*.md" ] && break
      echo "* [${f%.*}]($f)" >> src/SUMMARY.md
      cp "$f" src/
    done
  fi

  mdbook serve --port "$PORT" --open
  exit 0
fi

# --- CASE 2: Single Markdown file ------------------------------------------
if [ -f "$TARGET" ]; then
  echo "📄 Serving single Markdown file: $TARGET"

  rm -rf "$BOOKDIR"
  mkdir -p "$BOOKDIR/src"

  # Create book.toml
  cat > "$BOOKDIR/book.toml" <<EOF
[book]
title = "Preview"

[output.html]
port = $PORT
EOF

  # SUMMARY for single-file mode
  cat > "$BOOKDIR/src/SUMMARY.md" <<EOF
# Summary
* [Page](page.md)
EOF

  cp "$TARGET" "$BOOKDIR/src/page.md"

  cd "$BOOKDIR"
  mdbook serve --port "$PORT" --open
  exit 0
fi

echo "❌ ERROR: '$TARGET' is neither a file nor a directory."
exit 1
