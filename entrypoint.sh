#!/usr/bin/env bash
#shellcheck disable=SC2086

# Default port value or specified
DEFAULT_PORT="${P2P_PORT:-8621}"
HTTP_PORT="${HTTP_PORT:-6878}"

# Wait for 60 seconds for port file to exist and have content (if specified)
timeout=60
elapsed=0

if [ -n "$PORT_FILE" ]; then
    while [ ! -s "$PORT_FILE" ] && [ "$elapsed" -lt "$timeout" ]; do
		echo "[STARTUP] Waiting for $PORT_FILE to exist and have content... ($elapsed/$timeout)"
        sleep 1
        elapsed=$((elapsed + 1))
    done
fi

# Assign port from file or use default
if [ -n "$PORT_FILE" ] && [ -s "$PORT_FILE" ]; then
    PORT=$(cat "$PORT_FILE")
    echo "[STARTUP] Port file found. Using port: $PORT"
else
    PORT=$DEFAULT_PORT
    echo "[STARTUP] Port file not found or empty. Using default port: $PORT"
fi

# If allow remote access is enabled, set the extra flags
if [[ $ALLOW_REMOTE_ACCESS == "yes" ]]; then
    EXTRA_FLAGS="$EXTRA_FLAGS --bind-all"
fi

# Build final flags
EXTRA_FLAGS="$EXTRA_FLAGS --port $PORT --http-port $HTTP_PORT"

# Start the engine with the specified flags
echo "[STARTUP] Starting engine with flags: $EXTRA_FLAGS"

if [ -n "$PORT_FILE" ] && [ -s "$PORT_FILE" ]; then
    initial_port=$(cat "$PORT_FILE")
    (
        while true; do
            sleep 10
            current_port=$(cat "$PORT_FILE" 2>/dev/null)
            if [ "$current_port" != "$initial_port" ] && [ -n "$current_port" ]; then
                echo "[WATCHER] Port in $PORT_FILE changed from $initial_port to $current_port. Restarting container..."
                kill 1
            fi
        done
    ) &
fi

if [[ "${FILTER_LOGS:-false}" == "true" ]]; then
    exec su appuser -c "/app/start-engine --client-console $EXTRA_FLAGS \"$@\" 2>&1 \
        | grep -v \"zc|run: got socket error\""
else
    exec su appuser -c "/app/start-engine --client-console $EXTRA_FLAGS \"$@\""
fi