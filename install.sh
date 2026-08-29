#!/usr/bin/env bash
# ==============================================================================
# Oracle Cloud Always Free ARM (2 OCPU / 4GB RAM) - One-Click LLM Deploy Script
# Optimized for Ampere A1 ARM64 & Debian/Ubuntu/Oracle Linux
# ==============================================================================

set -euo pipefail

# Text styling
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${CYAN}${BOLD}"
echo "=============================================================================="
echo "    Oracle Cloud Always Free ARM - One-Click LLM Server Setup"
echo "=============================================================================="
echo -e "${NC}"

# 1. Root / Sudo Check
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run this script with sudo: sudo ./install.sh${NC}"
    exit 1
fi

# 2. Architecture & Resource Check
ARCH=$(uname -m)
echo -e "${BLUE}[1/8] Checking system hardware & architecture...${NC}"
echo -e "  Architecture: ${BOLD}${ARCH}${NC}"

TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
TOTAL_SWAP_MB=$(free -m | awk '/^Swap:/{print $2}')
echo -e "  Physical RAM: ${BOLD}${TOTAL_RAM_MB} MB${NC}"
echo -e "  Current Swap: ${BOLD}${TOTAL_SWAP_MB} MB${NC}"

# 3. Automatic Swap Allocation (Essential for 4GB RAM to prevent OOM)
echo -e "\n${BLUE}[2/8] Checking swap memory space...${NC}"
if [ "$TOTAL_SWAP_MB" -lt 2000 ]; then
    echo -e "${YELLOW}  Swap is less than 2GB. Creating 4GB Swap file to prevent OOM killer...${NC}"
    if [ ! -f /swapfile ]; then
        fallocate -l 4G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        if ! grep -q '/swapfile' /etc/fstab; then
            echo '/swapfile none swap sw 0 0' >> /etc/fstab
        fi
        echo -e "${GREEN}  ✓ 4GB Swap successfully created and activated!${NC}"
    else
        swapon /swapfile 2>/dev/null || true
        echo -e "${GREEN}  ✓ Existing /swapfile activated.${NC}"
    fi
else
    echo -e "${GREEN}  ✓ Swap space is sufficient (${TOTAL_SWAP_MB} MB).${NC}"
fi

# 4. Install Base Dependencies & Docker
echo -e "\n${BLUE}[3/8] Checking and installing dependencies (Docker & Compose)...${NC}"
if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq curl wget jq iptables iptables-persistent >/dev/null 2>&1 || apt-get install -y -qq curl wget jq iptables >/dev/null 2>&1
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y curl wget jq iptables >/dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y curl wget jq iptables >/dev/null 2>&1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo -e "${YELLOW}  Docker not found. Installing official Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
    echo -e "${GREEN}  ✓ Docker installed successfully.${NC}"
else
    systemctl enable --now docker >/dev/null 2>&1 || true
    echo -e "${GREEN}  ✓ Docker is already installed.${NC}"
fi

DOCKER_BIN="$(command -v docker || echo "/usr/bin/docker")"

# Check Docker Compose (plugin or standalone)
if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
    SERVICE_EXEC_START="${DOCKER_BIN} compose -f ${SCRIPT_DIR}/docker-compose.yml up -d"
    SERVICE_EXEC_STOP="${DOCKER_BIN} compose -f ${SCRIPT_DIR}/docker-compose.yml down"
elif command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
    DOCKER_COMPOSE_BIN="$(command -v docker-compose)"
    SERVICE_EXEC_START="${DOCKER_COMPOSE_BIN} -f ${SCRIPT_DIR}/docker-compose.yml up -d"
    SERVICE_EXEC_STOP="${DOCKER_COMPOSE_BIN} -f ${SCRIPT_DIR}/docker-compose.yml down"
else
    echo -e "${YELLOW}  Installing docker-compose plugin...${NC}"
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y docker-compose-plugin >/dev/null 2>&1 || true
    fi
    DOCKER_COMPOSE="docker compose"
    SERVICE_EXEC_START="${DOCKER_BIN} compose -f ${SCRIPT_DIR}/docker-compose.yml up -d"
    SERVICE_EXEC_STOP="${DOCKER_BIN} compose -f ${SCRIPT_DIR}/docker-compose.yml down"
fi

# 5. Configure Host OS Firewall (Oracle Cloud iptables trap fix)
PORT=8080
echo -e "\n${BLUE}[4/8] Configuring host firewall for port ${PORT}...${NC}"

# Open iptables
if command -v iptables >/dev/null 2>&1; then
    if ! iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null; then
        iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT
        echo -e "  ✓ Added iptables rule for port ${PORT}"
    fi
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save >/dev/null 2>&1 || true
    fi
fi

# Open UFW if active
if command -v ufw >/dev/null 2>&1 && ufw status | grep -qw "active"; then
    ufw allow "$PORT"/tcp >/dev/null 2>&1
    echo -e "  ✓ UFW rule added for port ${PORT}"
fi

# Open Firewalld if active
if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-port="${PORT}/tcp" >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
    echo -e "  ✓ Firewalld rule added for port ${PORT}"
fi

# 6. Model Selection
echo -e "\n${BLUE}[5/8] Select the LLM Model to deploy:${NC}"
echo -e "  ${BOLD}[1] Qwen2.5-3B-Instruct (Recommended balance, ~1.9GB RAM, ~8-12 tok/s)${NC} [Default]"
echo -e "  [2] Qwen2.5-1.5B-Instruct (Ultra fast, ~1.0GB RAM, ~18-25 tok/s)"
echo -e "  [3] Qwen3-4B-Instruct-2507 (Financial & General Reasoning, ~2.5GB RAM, ~6-10 tok/s)"
echo -e "  [4] DeepSeek-R1-Distill-Qwen-1.5B (Reasoning/Chain-of-Thought, ~1.1GB RAM)"
echo -e "  [5] Custom HuggingFace GGUF URL"

if [ -t 0 ]; then
    read -r -p "Enter choice [1-5] (default: 1): " MODEL_CHOICE
else
    MODEL_CHOICE=""
fi
MODEL_CHOICE="${MODEL_CHOICE:-1}"

case "$MODEL_CHOICE" in
    2)
        MODEL_NAME="qwen2.5-1.5b-instruct-q4_k_m.gguf"
        MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
        CTX_SIZE=2048
        ;;
    3)
        MODEL_NAME="Qwen3-4B-Instruct-2507-Q4_K_M.gguf"
        MODEL_URL="https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q4_K_M.gguf"
        CTX_SIZE=2048
        ;;
    4)
        MODEL_NAME="DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf"
        MODEL_URL="https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf"
        CTX_SIZE=2048
        ;;
    5)
        read -r -p "Enter direct GGUF download URL: " MODEL_URL
        MODEL_NAME=$(basename "$MODEL_URL")
        CTX_SIZE=2048
        ;;
    *)
        MODEL_NAME="qwen2.5-3b-instruct-q4_k_m.gguf"
        MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"
        CTX_SIZE=2048
        ;;
esac

# 7. Download Model
mkdir -p "$SCRIPT_DIR/models"
TARGET_MODEL_PATH="$SCRIPT_DIR/models/$MODEL_NAME"

echo -e "\n${BLUE}[6/8] Preparing model file...${NC}"
echo -e "  Model: ${BOLD}${MODEL_NAME}${NC}"

if [ -f "$TARGET_MODEL_PATH" ] && [ "$(stat -c%s "$TARGET_MODEL_PATH" 2>/dev/null || stat -f%z "$TARGET_MODEL_PATH" 2>/dev/null || echo 0)" -gt 100000000 ]; then
    echo -e "${GREEN}  ✓ Model already exists in ./models/ (${MODEL_NAME}), skipping download.${NC}"
else
    echo -e "${YELLOW}  Downloading model from Hugging Face (supports resume)...${NC}"
    curl -L -C - --retry 5 --retry-delay 3 --progress-bar -o "$TARGET_MODEL_PATH" "$MODEL_URL"
    echo -e "${GREEN}  ✓ Model download finished.${NC}"
fi

# 8. Write Environment Configuration (.env)
cat > "$SCRIPT_DIR/.env" <<EOF
PORT=${PORT}
MODEL_FILENAME=${MODEL_NAME}
MODEL_URL=${MODEL_URL}
CTX_SIZE=${CTX_SIZE}
THREADS=2
N_PARALLEL=1
API_KEY=
MAX_MEMORY=3500M
FLASH_ATTN=0
EOF

# 9. Register Systemd Auto-start Service
echo -e "\n${BLUE}[7/8] Configuring systemd auto-start service (oracle-llm.service)...${NC}"
cat > /etc/systemd/system/oracle-llm.service <<EOF
[Unit]
Description=Oracle ARM LLM Server (llama.cpp)
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${SCRIPT_DIR}
ExecStart=${SERVICE_EXEC_START}
ExecStop=${SERVICE_EXEC_STOP}
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable oracle-llm.service >/dev/null 2>&1

# 10. Start Docker Container
echo -e "\n${BLUE}[8/8] Starting LLM container...${NC}"
$DOCKER_COMPOSE -f "$SCRIPT_DIR/docker-compose.yml" pull
$DOCKER_COMPOSE -f "$SCRIPT_DIR/docker-compose.yml" up -d

# 11. Healthcheck & Wait for Model Load
echo -e "\n${YELLOW}Waiting for model to load into memory...${NC}"
for i in {1..30}; do
    if curl -s -f "http://localhost:${PORT}/health" >/dev/null 2>&1 || curl -s -f "http://localhost:${PORT}/v1/models" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ LLM Server is ONLINE and READY!${NC}"
        break
    fi
    echo -n "."
    sleep 2
    if [ "$i" -eq 30 ]; then
        echo -e "\n${YELLOW}Note: Server is still starting or initializing. You can check logs with: ./manage.sh logs${NC}"
    fi
done

# 12. Retrieve Server Public IP
PUBLIC_IP=$(curl -s --max-time 3 https://ifconfig.me || curl -s --max-time 3 https://icanhazip.com || echo "<YOUR_SERVER_PUBLIC_IP>")

echo -e "\n${GREEN}${BOLD}==============================================================================${NC}"
echo -e "${GREEN}${BOLD}             🎉 Deployment Completed Successfully! 🎉${NC}"
echo -e "${GREEN}${BOLD}==============================================================================${NC}"
echo -e "  ${BOLD}OpenAI Base URL:${NC}  http://${PUBLIC_IP}:${PORT}/v1"
echo -e "  ${BOLD}Health Endpoint:${NC}  http://${PUBLIC_IP}:${PORT}/health"
echo -e "  ${BOLD}Model Loaded:${NC}     ${MODEL_NAME}"
echo -e "  ${BOLD}Context Window:${NC}   ${CTX_SIZE} tokens"
echo -e "  ${BOLD}Threads:${NC}          2 vCPU"
echo -e ""
echo -e "${CYAN}${BOLD}📋 Management Commands:${NC}"
echo -e "  View Live Logs:     ${BOLD}./manage.sh logs${NC}"
echo -e "  Check Status:       ${BOLD}./manage.sh status${NC}"
echo -e "  Run Test Query:     ${BOLD}./manage.sh test${NC}"
echo -e "  Restart Service:    ${BOLD}./manage.sh restart${NC}"
echo -e "  Stop Service:       ${BOLD}./manage.sh stop${NC}"
echo -e ""
echo -e "${YELLOW}${BOLD}⚠️ IMPORTANT (Oracle Cloud Security List Reminder):${NC}"
echo -e "  In the Oracle Cloud Console:"
echo -e "  1. Go to ${BOLD}Networking -> Virtual Cloud Networks (VCN) -> Security Lists${NC}"
echo -e "  2. Add an ${BOLD}Ingress Rule${NC}:"
echo -e "     - Source CIDR: ${BOLD}0.0.0.0/0${NC}"
echo -e "     - IP Protocol: ${BOLD}TCP${NC}"
echo -e "     - Destination Port Range: ${BOLD}${PORT}${NC}"
echo -e "=============================================================================="
