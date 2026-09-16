#!/bin/sh
# CPU/MEM/NET/TMP records. Alternate roots allow hardware-independent fixtures.
set -eu
export LC_ALL=C
proc=${PILL_PROC_ROOT:-/proc}
read -r _ user nice system idle iowait irq softirq steal _ < "$proc/stat"
printf 'CPU %s %s\n' "$((user+nice+system+idle+iowait+irq+softirq+steal))" "$((idle+iowait))"
awk '
    /^MemTotal:/ { total=$2 }
    /^MemAvailable:/ { available=$2 }
    /^SwapTotal:/ { swap=$2 }
    /^SwapFree:/ { free=$2 }
    END { print "MEM", total, available, swap, free }
' "$proc/meminfo"
awk '
    NR>2 { gsub(":", " "); if ($1!="lo") { rx+=$2; tx+=$10 } }
    END { print "NET", rx+0, tx+0 }
' "$proc/net/dev"
if [ -n "${1:-}" ] && [ -r "$1" ]; then
    printf 'TMP %s\n' "$(cat -- "$1")"
else
    printf 'TMP -\n'
fi
