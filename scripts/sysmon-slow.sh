#!/bin/sh
export LC_ALL=C
df -P / | awk 'NR==2 { gsub("%", "", $5); print "DISK", $5 }'
awk '{ print "UP", int($1) }' "${PILL_PROC_ROOT:-/proc}/uptime"
