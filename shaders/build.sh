#!/bin/sh
set -eu
cd "$(dirname "$0")"
shader_baker=${QSB:-/usr/lib64/qt6/bin/qsb}
if [ ! -x "$shader_baker" ]; then
    shader_baker=qsb
fi
for name in interaction-glitch bloom; do
    "$shader_baker" --glsl '300 es,330' --hlsl 50 --msl 12 -o "$name.frag.qsb" "$name.frag"
done
