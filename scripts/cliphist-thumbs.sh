#!/bin/sh
# Clipboard images are untrusted. Decode only raster formats under resource limits.
set -eu
umask 077
MAGICK_CONFIGURE_PATH=$(CDPATH= cd -- "$(dirname -- "$0")/magick-policy" && pwd)
export MAGICK_CONFIGURE_PATH
cache="${XDG_CACHE_HOME:-$HOME/.cache}/cliphist-thumbs"
[ ! -L "$cache" ] || exit 1
mkdir -p -- "$cache"
[ "$(stat -c %u -- "$cache")" = "$(id -u)" ] || exit 1
chmod 700 -- "$cache"
# Separate private work directories prevent concurrent refreshes sharing raw files.
work=$(mktemp -d "$cache/.work.XXXXXXXX")
trap 'rm -rf -- "$work"' EXIT
trap 'exit 1' HUP INT TERM
cliphist list > "$work/list"
cut -f1 "$work/list" > "$work/ids"
for file in "$cache"/*.png; do
    [ -e "$file" ] || [ -L "$file" ] || continue
    id=${file##*/}
    id=${id%.png}
    grep -qxF -- "$id" "$work/ids" || rm -f -- "$file"
done

tab=$(printf '\t')
while IFS= read -r line; do
    case "$line" in *"$tab"*) ;; *) continue ;; esac
    id=${line%%"$tab"*}
    case "$id" in ''|*[!0-9]*) continue ;; esac
    preview=${line#*"$tab"}
    case "$preview" in
        '[[ binary data '*png*' ]]'|'[[ binary data '*jpg*' ]]'|'[[ binary data '*jpeg*' ]]'|'[[ binary data '*gif*' ]]'|'[[ binary data '*bmp*' ]]'|'[[ binary data '*webp*' ]]') ;;
        *) continue ;;
    esac
    thumb="$cache/$id.png"
    [ ! -L "$thumb" ] || continue
    [ ! -s "$thumb" ] || continue
    # Bound disk use even before ImageMagick applies its own limits.
    printf '%s' "$id" | cliphist decode 2>/dev/null | head -c 33554433 > "$work/raw"
    [ "$(wc -c < "$work/raw")" -le 33554432 ] || continue
    if magick "$work/raw[0]" -resize '256x256>' "png:$work/thumb.png" 2>/dev/null; then
        if [ -s "$work/thumb.png" ]; then mv -f -- "$work/thumb.png" "$thumb"; fi
    fi
done < "$work/list"
