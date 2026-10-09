#!/usr/bin/env bash
# Собирает веб-версию (транспилятор Luau->JS + эмулятор roblox2web) в каталог демо (рабочая копия ветки gh-pages)
# и кладёт туда README, .nojekyll, исходники и готовые .rbxl/.rbxlx.
# Использование: bash tools/publish_web.sh [/workspace/pawtown-web]
set -e
G=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-/workspace/pawtown-web}
R2W=${R2W_DIR:-/workspace/roblox2web}
TMP=$(mktemp -d)
node "$R2W/roblox2web.js" "$G" -o "$TMP/site" --zip "$TMP/Pawtown_web.zip" >/dev/null
mkdir -p "$OUT"
find "$OUT" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +   # .git сохраняем: конвертор сам очищает свой -o
cp -r "$TMP/site/." "$OUT/"
cp "$TMP/Pawtown_web.zip" "$OUT/"
rm -rf "$TMP"
touch "$OUT/.nojekyll"
cp "$G/docs/DEMO_README.md" "$OUT/README.md"
mkdir -p "$OUT/roblox-source"
(cd "$G" && tar --exclude=.git --exclude=tools_dl --exclude=build --exclude=dist --exclude=node_modules --exclude=sourcemap.json --exclude='*.zip' --exclude=__pycache__ -cf - .) | (cd "$OUT/roblox-source" && tar xf -)
for f in /workspace/Pawtown_v0.1.rbxl /workspace/Pawtown_v0.1.rbxlx; do [ -f "$f" ] && cp "$f" "$OUT/"; done
echo "web build: $OUT"
