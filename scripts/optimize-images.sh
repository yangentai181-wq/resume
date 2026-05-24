#!/usr/bin/env bash
# 画像を最大辺1920px・WebP(q90)へ一括最適化。原本は images_original/ に保全。
# リサイズ=magick / エンコード=cwebp。
set -euo pipefail
cd "$(dirname "$0")/.."
SRC_DIR="images"; ORIG_DIR="images_original"; QUALITY=90; MAXDIM=1920
mkdir -p "$ORIG_DIR"

# 1) 原本退避（未退避のみ・属性保持）
for f in "$SRC_DIR"/*; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  [ -e "$ORIG_DIR/$base" ] || cp -p "$f" "$ORIG_DIR/$base"
done

# 2) 原本から webp 生成（同名 .webp が複数ソースに割れる場合は後勝ち＝webp原本優先）
tmp="$(mktemp -d)"
for f in "$ORIG_DIR"/*; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"; name="${base%.*}"
  png="$tmp/${name}.png"
  magick "$f" -resize "${MAXDIM}x${MAXDIM}>" "$png"
  cwebp -quiet -q "$QUALITY" "$png" -o "$SRC_DIR/${name}.webp"
  echo "  $base -> ${name}.webp"
done
rm -rf "$tmp"

# 3) images/ から非webpを削除（images_original に保全済みのもののみ）
for f in "$SRC_DIR"/*; do
  [ -f "$f" ] || continue
  case "$f" in *.webp) continue ;; esac
  base="$(basename "$f")"
  [ -e "$ORIG_DIR/$base" ] && rm "$f"
done

echo "done. images/ size:"; du -sh "$SRC_DIR"
