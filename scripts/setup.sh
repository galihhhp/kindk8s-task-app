#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

CLUSTER_NAME="app-cluster"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KIND_CONFIG="$PROJECT_DIR/app/kind-config.yaml"

echo -e "${BOLD}"
echo "╔════════════════════════════════════════╗"
echo "║     Kind Cluster Setup Script          ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "\n${BOLD}=== Checking requirements ===${NC}"

if ! command -v docker &>/dev/null; then
    echo -e "${RED}[ERROR]${NC} docker is not installed"
    exit 1
fi

if ! command -v kind &>/dev/null; then
    echo -e "${RED}[ERROR]${NC} kind is not installed"
    exit 1
fi

if ! command -v kubectl &>/dev/null; then
    echo -e "${RED}[ERROR]${NC} kubectl is not installed"
    exit 1
fi

if ! docker info &>/dev/null; then
    echo -e "${YELLOW}[WARN]${NC} Docker is not running. Starting Docker Desktop..."
    open -a "Docker Desktop"
    echo -e "${GREEN}[INFO]${NC} Waiting for Docker to start..."
    while ! docker info &>/dev/null; do
        sleep 2
    done
    echo -e "${GREEN}[INFO]${NC} Docker is ready"
else
    echo -e "${GREEN}[INFO]${NC} Docker is running"
fi

echo -e "\n${BOLD}=== Creating Kind cluster ===${NC}"

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${YELLOW}[WARN]${NC} Cluster '$CLUSTER_NAME' already exists"
    read -p "Delete and recreate? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        kind delete cluster --name "$CLUSTER_NAME"
    else
        echo -e "${GREEN}[INFO]${NC} Using existing cluster"
    fi
fi

if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    if [ -f "$KIND_CONFIG" ]; then
        kind create cluster --config "$KIND_CONFIG"
    else
        kind create cluster --name "$CLUSTER_NAME"
    fi
    echo -e "${GREEN}[INFO]${NC} Cluster created successfully"
fi

echo -e "\n${BOLD}=== Waiting for nodes to be ready ===${NC}"

kubectl wait --for=condition=Ready nodes --all --timeout=120s
echo -e "${GREEN}[INFO]${NC} All nodes are ready"
kubectl get nodes

echo -e "\n${BOLD}=== Deploying application (dev environment) ===${NC}"

cd "$PROJECT_DIR/app/env/dev"

if [ -f kustomization.yaml ]; then
    kubectl apply -k .
    echo -e "${GREEN}[INFO]${NC} App deployed via Kustomize"
else
    echo -e "${RED}[ERROR]${NC} kustomization.yaml not found in app/env/dev"
    exit 1
fi

echo -e "\n${BOLD}=== Deploying observability stack ===${NC}"

cd "$PROJECT_DIR/observability/env/dev"

if [ -f kustomization.yaml ]; then
    kubectl apply -k .
    echo -e "${GREEN}[INFO]${NC} Observability stack deployed"
else
    echo -e "${YELLOW}[WARN]${NC} observability/env/dev/kustomization.yaml not found, skipping"
fi

echo -e "\n${BOLD}=== Waiting for pods to be ready ===${NC}"

if kubectl get namespace development &>/dev/null; then
    echo -e "${GREEN}[INFO]${NC} Waiting for pods in namespace: development"
    kubectl wait --for=condition=Ready pods --all -n development --timeout=180s 2>/dev/null || true
fi

if kubectl get namespace observability &>/dev/null; then
    echo -e "${GREEN}[INFO]${NC} Waiting for pods in namespace: observability"
    kubectl wait --for=condition=Ready pods --all -n observability --timeout=180s 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}[INFO]${NC} Pods in development:"
kubectl get pods -n development 2>/dev/null || echo "  (none)"

echo ""
echo -e "${GREEN}[INFO]${NC} Pods in observability:"
kubectl get pods -n observability 2>/dev/null || echo "  (none)"

echo -e "\n${BOLD}=== Services available ===${NC}"

echo ""
echo -e "${GREEN}[INFO]${NC} Development services:"
kubectl get svc -n development 2>/dev/null || echo "  (none)"

echo ""
echo -e "${GREEN}[INFO]${NC} Observability services:"
kubectl get svc -n observability 2>/dev/null || echo "  (none)"

echo -e "\n${BOLD}=== Port forwarding commands ===${NC}"

echo -e "${BOLD}Copy and run these commands in separate terminals:${NC}"
echo ""

if kubectl get svc frontend-service -n development &>/dev/null; then
    echo "# Frontend"
    echo "kubectl port-forward svc/frontend-service 80:80 -n development"
    echo ""
fi

if kubectl get svc backend-service -n development &>/dev/null; then
    echo "# Backend"
    echo "kubectl port-forward svc/backend-service 3000:3000 -n development"
    echo ""
fi

if kubectl get svc postgres-service -n development &>/dev/null; then
    echo "# PostgreSQL"
    echo "kubectl port-forward svc/postgres-service 5432:5432 -n development"
    echo ""
fi

if kubectl get svc prometheus -n observability &>/dev/null; then
    echo "# Prometheus"
    echo "kubectl port-forward svc/prometheus 9090:9090 -n observability"
    echo ""
fi

if kubectl get svc grafana -n observability &>/dev/null; then
    echo "# Grafana"
    echo "kubectl port-forward svc/grafana 3333:3333 -n observability"
    echo ""
fi

echo -e "\n${BOLD}=== Setup complete! ===${NC}"
echo -e "${GREEN}Cluster '$CLUSTER_NAME' is ready for use.${NC}"
