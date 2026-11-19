#!/bin/sh
LAUNCHER_DIR="$(dirname "$0")"
REAL_LAUNCHER="$LAUNCHER_DIR/wineskinlauncher.real"
"$REAL_LAUNCHER" "$@"
LAUNCHER_EXIT=$?
WINESERVER_PID=$(pgrep -x wineserver 2>/dev/null | head -1)
if [ -n "$WINESERVER_PID" ]; then
    for i in $(seq 1 7200); do
        if ! kill -0 "$WINESERVER_PID" 2>/dev/null; then
            break
        fi
        sleep 1
    done
fi
exit $LAUNCHER_EXIT
