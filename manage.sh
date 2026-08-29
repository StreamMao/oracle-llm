#!/usr/bin/env bash
# ==============================================================================
# Oracle ARM LLM Management CLI
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f "$SCRIPT_DIR/.env" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/.env"
fi

PORT="${PORT:-8080}"
CONTAINER_NAME="oracle-llm-server"

# Determine compose command
if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

usage() {
    echo "Usage: ./manage.sh [command]"
    echo ""
    echo "Commands:"
    echo "  status      Check container, memory, swap, and health status"
    echo "  logs        Stream real-time inference server logs"
    echo "  start       Start the LLM server container"
    echo "  stop        Stop the LLM server container"
    echo "  restart     Restart the LLM server container"
    echo "  test        Send a quick test query to the running model"
    echo "  update      Pull the latest llama.cpp image and restart"
    echo ""
}

case "${1:-}" in
    status)
        echo "=== Container Status ==="
        docker ps -a --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "=== Resource Usage ==="
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" "${CONTAINER_NAME}" 2>/dev/null || echo "Container is not currently running."
        echo ""
        echo "=== Host Memory & Swap ==="
        free -h
        echo ""
        echo "=== API Healthcheck ==="
        if curl -s -f "http://localhost:${PORT}/health" >/dev/null 2>&1; then
            echo "Status: ONLINE (HTTP 200 OK)"
        else
            echo "Status: OFFLINE or Starting"
        fi
        ;;

    logs)
        echo "Streaming logs from ${CONTAINER_NAME} (Ctrl+C to exit)..."
        docker logs -f --tail 100 "${CONTAINER_NAME}"
        ;;

    start)
        echo "Starting LLM Server..."
        $DOCKER_COMPOSE up -d
        echo "Started."
        ;;

    stop)
        echo "Stopping LLM Server..."
        $DOCKER_COMPOSE down
        echo "Stopped."
        ;;

    restart)
        echo "Restarting LLM Server..."
        $DOCKER_COMPOSE restart
        echo "Restarted."
        ;;

    update)
        echo "Pulling latest llama.cpp server image..."
        $DOCKER_COMPOSE pull
        $DOCKER_COMPOSE up -d
        echo "Updated."
        ;;

    test)
        echo "Sending test request to http://localhost:${PORT}/v1/chat/completions..."
        curl -s -X POST "http://localhost:${PORT}/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -d '{
                "messages": [
                    {"role": "system", "content": "You are a concise AI assistant."},
                    {"role": "user", "content": "Hello! Please reply in one short sentence introducing yourself."}
                ],
                "temperature": 0.7,
                "max_tokens": 100,
                "stream": false
            }' | jq . 2>/dev/null || curl -s -X POST "http://localhost:${PORT}/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -d '{
                "messages": [
                    {"role": "system", "content": "You are a concise AI assistant."},
                    {"role": "user", "content": "Hello! Please reply in one short sentence introducing yourself."}
                ],
                "temperature": 0.7,
                "max_tokens": 100,
                "stream": false
            }'
        echo ""
        ;;

    *)
        usage
        exit 1
        ;;
esac
