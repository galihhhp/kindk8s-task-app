#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

CLUSTER_NAME="app-cluster"
STOP_DOCKER=false
FULL_CLEAN=false

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --stop-docker    Stop Docker Desktop after cleanup"
    echo "  -f, --full           Full cleanup (prune all Docker resources)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0")              # Delete cluster only"
    echo "  $(basename "$0") -f           # Delete cluster + prune Docker"
    echo "  $(basename "$0") -f -d        # Full cleanup + stop Docker Desktop"
    exit 0
fi

for arg in "$@"; do
    if [ "$arg" = "-d" ] || [ "$arg" = "--stop-docker" ]; then
        STOP_DOCKER=true
    fi
    if [ "$arg" = "-f" ] || [ "$arg" = "--full" ]; then
        FULL_CLEAN=true
    fi
done

echo -e "${BOLD}"
echo "╔════════════════════════════════════════╗"
echo "║     Kind Cluster Cleanup Script        ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

if ! docker info &>/dev/null; then
    echo -e "${YELLOW}[WARN]${NC} Docker not running, nothing to clean"
    echo -e "\n${BOLD}=== Cleanup complete! ===${NC}"
    exit 0
fi

echo -e "\n${BOLD}=== Deleting Kind clusters ===${NC}"

if ! command -v kind &>/dev/null; then
    echo -e "${YELLOW}[WARN]${NC} kind not found, skipping cluster deletion"
else
    clusters=$(kind get clusters 2>/dev/null || echo "")
    
    if [ -z "$clusters" ]; then
        echo -e "${GREEN}[INFO]${NC} No Kind clusters found"
    else
        for cluster in $clusters; do
            echo -e "${GREEN}[INFO]${NC} Deleting cluster: $cluster"
            kind delete cluster --name "$cluster"
        done
        echo -e "${GREEN}[INFO]${NC} All Kind clusters deleted"
    fi
fi

echo -e "\n${BOLD}=== Stopping any remaining Kind containers ===${NC}"

containers=$(docker ps -aq --filter "name=kind-" 2>/dev/null || echo "")

if [ -n "$containers" ]; then
    echo -e "${GREEN}[INFO]${NC} Removing Kind containers..."
    docker rm -f $containers 2>/dev/null || true
else
    echo -e "${GREEN}[INFO]${NC} No Kind containers found"
fi

if [ "$FULL_CLEAN" = true ]; then
    echo -e "\n${BOLD}=== Pruning Docker resources ===${NC}"
    
    echo -e "${GREEN}[INFO]${NC} Removing unused containers..."
    docker container prune -f
    
    echo -e "${GREEN}[INFO]${NC} Removing unused images..."
    docker image prune -af
    
    echo -e "${GREEN}[INFO]${NC} Removing unused volumes..."
    docker volume prune -af
    
    echo -e "${GREEN}[INFO]${NC} Removing unused networks..."
    docker network prune -f
    
    echo -e "${GREEN}[INFO]${NC} Removing build cache..."
    docker builder prune -af
    
    echo -e "${GREEN}[INFO]${NC} Docker cleanup complete"
    docker system df
fi

if [ "$STOP_DOCKER" = true ]; then
    echo -e "\n${BOLD}=== Stopping Docker Desktop ===${NC}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        osascript -e 'quit app "Docker Desktop"' 2>/dev/null || true
        echo -e "${GREEN}[INFO]${NC} Docker Desktop stopped"
    elif [[ "$OSTYPE" == "linux"* ]]; then
        sudo systemctl stop docker 2>/dev/null || true
        echo -e "${GREEN}[INFO]${NC} Docker service stopped"
    else
        echo -e "${YELLOW}[WARN]${NC} Cannot stop Docker on this OS automatically"
    fi
fi

echo -e "\n${BOLD}=== Memory status ===${NC}"

if [[ "$OSTYPE" == "darwin"* ]]; then
    top -l 1 | grep PhysMem || true
    echo ""
    memory_pressure 2>/dev/null | grep "free percentage" || true
elif command -v free &>/dev/null; then
    free -h
fi

echo -e "\n${BOLD}=== Cleanup complete! ===${NC}"

if [ "$STOP_DOCKER" = true ]; then
    echo -e "${GREEN}Docker Desktop has been stopped.${NC}"
else
    echo -e "${YELLOW}Tip: Run with -d flag to also stop Docker Desktop${NC}"
fi
