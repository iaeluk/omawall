#!/bin/bash
# omaWall — lista imagens das pastas do slideshow.
# Uso: list-images.sh [-r] <pasta1> [pasta2 ...]
# Saída: uma linha por imagem no formato "mtime|/caminho/completo"
set -uo pipefail

recursive=0
if [[ ${1-} == "-r" ]]; then
  recursive=1
  shift
fi

depth=(-maxdepth 1)
if (( recursive )); then
  depth=()
fi

for dir in "$@"; do
  [[ -d $dir ]] || continue
  find "$dir" "${depth[@]}" \( -type f -o -type l \) \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' \
     -o -iname '*.bmp' -o -iname '*.webp' -o -iname '*.jxl' -o -iname '*.avif' \) \
    -printf '%T@|%p\n' 2>/dev/null
done
