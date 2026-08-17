#!/usr/bin/env bash
# Capture diagnostics from a frozen Zoom video pipeline.
# Run this WHILE the video is frozen (avatar effect on).

set -u
OUT=~/zoom-freeze-$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT"

PID=$(pgrep -f '/app/extra/zoom/zoom$' | head -1)
if [ -z "${PID:-}" ]; then
    PID=$(pgrep -f 'extra/zoom/zoom' | head -1)
fi

if [ -z "${PID:-}" ]; then
    echo "Could not find the Zoom process. Is Zoom running?"
    exit 1
fi
echo "Zoom PID: $PID  -> capturing into $OUT"

# Three stack samples a few seconds apart. A thread stuck at the same frame
# across all three is blocked; one that moves is merely busy.
for i in 1 2 3; do
    echo "  sample $i/3"
    eu-stack -p "$PID" --verbose > "$OUT/stacks-$i.txt" 2>&1
    [ $i -lt 3 ] && sleep 4
done

# Which threads are in what kernel state, and the CPU burn per thread.
{
    echo "=== per-thread state ==="
    for t in /proc/$PID/task/*; do
        tid=$(basename "$t")
        name=$(cat "$t/comm" 2>/dev/null)
        state=$(awk '/^State:/{print $2,$3}' "$t/status" 2>/dev/null)
        wchan=$(cat "$t/wchan" 2>/dev/null)
        printf "%-8s %-18s %-12s %s\n" "$tid" "$name" "$state" "$wchan"
    done
} > "$OUT/threads.txt" 2>&1

top -b -n 1 -H -p "$PID" > "$OUT/top-threads.txt" 2>&1

# Open FDs: shows whether the camera is still held and being read.
ls -l /proc/$PID/fd 2>/dev/null | grep -E 'video|dri|dev' > "$OUT/fds.txt" 2>&1

cp ~/.var/app/us.zoom.Zoom/.zoom/logs/*.log "$OUT/" 2>/dev/null
cp ~/.var/app/us.zoom.Zoom/config/zoomus.conf "$OUT/" 2>/dev/null

echo
echo "Done. Collected in: $OUT"
ls -la "$OUT"
