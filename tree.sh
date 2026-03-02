#!/bin/bash

# bash <(curl -s https://raw.githubusercontent.com/abikesa/directory-tree/refs/heads/main/summarize.sh) ./
# === Config === ./summarize.sh ukubona-llc.github.io --raw
TARGET_DIR=""
DEPTH=3
OUTPUT_MD=false
FILTER_EXCLUDES=true
OUTPUT_JSON=false
OUTPUT_XML=false
OUTPUT_HAIKU=false
DEFAULT_EXCLUDES=".git|node_modules|__pycache__|env|.venv|myenv|_build"

# === Parse flags ===
for arg in "$@"; do
    case $arg in
        --deep) DEPTH=10 ;;
        --md) OUTPUT_MD=true ;;
        --raw) FILTER_EXCLUDES=false ;;
        --json) OUTPUT_JSON=true ;;
        --xml) OUTPUT_XML=true ;;
        --haiku) OUTPUT_HAIKU=true ;;
        *) TARGET_DIR=$arg ;;
    esac
done

# === Validate target ===
if [ -z "$TARGET_DIR" ]; then
    echo "❗ Please specify a target directory."
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ Directory not found: $TARGET_DIR"
    exit 1
fi

# === Markdown output safe redirect ===
if $OUTPUT_MD; then
    mkdir -p "$TARGET_DIR"
    exec > "${TARGET_DIR}/summary.md"
fi

# === Count stuff ===
TOTAL_FILES=$(find "$TARGET_DIR" -type f | wc -l)
TOTAL_DIRS=$(find "$TARGET_DIR" -type d | wc -l)

HTML_COUNT=$(find "$TARGET_DIR" -type f -iname "*.html" | wc -l)
MD_COUNT=$(find "$TARGET_DIR" -type f -iname "*.md" | wc -l)
PY_COUNT=$(find "$TARGET_DIR" -type f -iname "*.py" | wc -l)
JS_COUNT=$(find "$TARGET_DIR" -type f -iname "*.js" | wc -l)
CSS_COUNT=$(find "$TARGET_DIR" -type f -iname "*.css" | wc -l)
IMG_COUNT=$(find "$TARGET_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.svg" -o -iname "*.gif" \) | wc -l)
CFF_COUNT=$(find "$TARGET_DIR" -type f -iname "*.cff" | wc -l)
ZIP_COUNT=$(find "$TARGET_DIR" -type f \( -iname "*.zip" -o -iname "*.tar" -o -iname "*.gz" -o -iname "*.bz2" -o -iname "*.xz" \) | wc -l)

# === JSON/XML/Haiku output ===
if $OUTPUT_JSON; then
  cat <<EOF
{
  "directory": "$TARGET_DIR",
  "files": $TOTAL_FILES,
  "folders": $TOTAL_DIRS,
  "html": $HTML_COUNT,
  "markdown": $MD_COUNT,
  "python": $PY_COUNT,
  "javascript": $JS_COUNT,
  "css": $CSS_COUNT,
  "images": $IMG_COUNT,
  "citation": $CFF_COUNT,
  "compressed": $ZIP_COUNT
}
EOF
  exit 0
fi

if $OUTPUT_XML; then
  cat <<EOF
<summary>
  <directory>$TARGET_DIR</directory>
  <files>$TOTAL_FILES</files>
  <folders>$TOTAL_DIRS</folders>
  <html>$HTML_COUNT</html>
  <markdown>$MD_COUNT</markdown>
  <python>$PY_COUNT</python>
  <javascript>$JS_COUNT</javascript>
  <css>$CSS_COUNT</css>
  <images>$IMG_COUNT</images>
  <citation>$CFF_COUNT</citation>
  <compressed>$ZIP_COUNT</compressed>
</summary>
EOF
  exit 0
fi

if $OUTPUT_HAIKU; then
  echo "Folders like forests,"
  echo "Code and silence intertwined—"
  echo "$TOTAL_FILES seeds bloom."
  exit 0
fi

# === Header ===
echo "📁 Scanning directory: $TARGET_DIR"
echo
echo "🗂️  Total files:      $TOTAL_FILES"
echo "📂 Total folders:     $TOTAL_DIRS"
echo
echo "🧾 File breakdown:"
printf "  📄 HTML files       : %5d\n" $HTML_COUNT
printf "  📓 Markdown files   : %5d\n" $MD_COUNT
printf "  🐍 Python files     : %5d\n" $PY_COUNT
printf "  📜 JavaScript files : %5d\n" $JS_COUNT
printf "  🎨 CSS files        : %5d\n" $CSS_COUNT
printf "  🖼️  Image files      : %5d\n" $IMG_COUNT
printf "  🧾 Citation (.cff)  : %5d\n" $CFF_COUNT
printf "  📦 Compressed files : %5d\n" $ZIP_COUNT
echo

# === Folder structure ===
echo "📚 Folder structure (first $DEPTH levels):"
echo "$TARGET_DIR"

TREE_OUTPUT=$(find "$TARGET_DIR" -mindepth 1 -maxdepth $DEPTH \
  | { $FILTER_EXCLUDES && grep -Ev "$DEFAULT_EXCLUDES" || cat; } \
  | sed "s|$TARGET_DIR/||" \
  | sort \
  | awk -F/ '
{
    indent = ""
    for (i = 1; i < NF; i++) indent = indent "│   "
    fname = $NF
    emoji = ""

    if (fname ~ /^\./) {
        hidden = " (hidden)"
    } else {
        hidden = ""
    }

    if (fname ~ /\.md$/) {
        emoji = "📓 "
    } else if (fname ~ /\.cff$/) {
        emoji = "🧾 "
    } else if (fname ~ /\.html$/) {
        emoji = "📄 "
    } else if (fname ~ /\.py$/) {
        emoji = "🐍 "
    } else if (fname ~ /\.js$/) {
        emoji = "📜 "
    } else if (fname ~ /\.css$/) {
        emoji = "🎨 "
    } else if (fname ~ /\.(png|jpg|jpeg|svg|gif)$/) {
        emoji = "🖼️  "
    } else if (fname ~ /\.(zip|tar|gz|bz2|xz)$/) {
        emoji = "📦 "
    } else if ($0 ~ /\/$/ || $0 !~ /\./) {
        emoji = "📁 "
    }

    print indent "├── " emoji fname hidden
}')

if [ -z "$TREE_OUTPUT" ]; then
    echo "  (no visible structure within $DEPTH levels)"
else
    echo "$TREE_OUTPUT"
fi

echo
echo "✅ Done scanning."