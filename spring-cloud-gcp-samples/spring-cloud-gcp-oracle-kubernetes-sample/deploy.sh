#!/bin/bash

# Oracle Database Deployment Script for Kubernetes (AKS/GKE)
# This script helps deploy Oracle Database to a Kubernetes cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if kubectl is installed
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    print_info "kubectl is installed"
}

# Function to check if connected to a cluster
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Not connected to a Kubernetes cluster. Please configure kubectl."
        exit 1
    fi
    print_info "Connected to Kubernetes cluster"
    kubectl cluster-info
}

# Function to create namespace
create_namespace() {
    local namespace=$1
    if kubectl get namespace "$namespace" &> /dev/null; then
        print_warn "Namespace $namespace already exists"
    else
        kubectl create namespace "$namespace"
        print_info "Created namespace: $namespace"
    fi
}

# Function to create Oracle Container Registry secret
create_registry_secret() {
    local namespace=$1
    read -p "Enter Oracle Container Registry username: " oracle_username
    read -s -p "Enter Oracle Container Registry password: " oracle_password
    echo
    read -p "Enter your email: " oracle_email
    
    kubectl create secret docker-registry oracle-registry \
        --docker-server=container-registry.oracle.com \
        --docker-username="$oracle_username" \
        --docker-password="$oracle_password" \
        --docker-email="$oracle_email" \
        --namespace="$namespace" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    print_info "Created Oracle Container Registry secret"
}

# Function to create Oracle password secret
create_password_secret() {
    local namespace=$1
    read -s -p "Enter Oracle Database password (min 8 characters): " oracle_pwd
    echo
    read -s -p "Confirm Oracle Database password: " oracle_pwd_confirm
    echo
    
    if [ "$oracle_pwd" != "$oracle_pwd_confirm" ]; then
        print_error "Passwords do not match"
        exit 1
    fi
    
    if [ ${#oracle_pwd} -lt 8 ]; then
        print_error "Password must be at least 8 characters"
        exit 1
    fi
    
    kubectl create secret generic oracle-secrets \
        --from-literal=oracle-password="$oracle_pwd" \
        --namespace="$namespace" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    print_info "Created Oracle password secret"
}

# Function to deploy Oracle Database
deploy_oracle() {
    local namespace=$1
    local edition=$2
    
    print_info "Deploying Oracle Database ($edition edition)..."
    
    # Deploy PVC
    kubectl apply -f oracle-pvc.yaml -n "$namespace"
    print_info "Created PersistentVolumeClaim"
    
    # Deploy Service
    kubectl apply -f oracle-service.yaml -n "$namespace"
    print_info "Created Service"
    
    # Deploy Oracle Database
    if [ "$edition" == "xe" ]; then
        kubectl apply -f oracle-xe-deployment.yaml -n "$namespace"
        print_info "Deployed Oracle XE"
    else
        kubectl apply -f oracle-enterprise-statefulset.yaml -n "$namespace"
        print_info "Deployed Oracle Enterprise Edition"
    fi
}

# Function to wait for pod to be ready
wait_for_pod() {
    local namespace=$1
    local label=$2
    
    print_info "Waiting for Oracle Database pod to be ready..."
    kubectl wait --for=condition=ready pod -l "$label" -n "$namespace" --timeout=600s
    print_info "Oracle Database is ready!"
}

# Function to show connection info
show_connection_info() {
    local namespace=$1
    
    print_info "Oracle Database Connection Information:"
    echo "  Service Name: oracle-db-service"
    echo "  Port: 1521"
    echo "  Namespace: $namespace"
    echo ""
    echo "Connection string from within cluster:"
    echo "  jdbc:oracle:thin:@oracle-db-service:1521/XE"
    echo ""
    echo "To connect with sqlplus:"
    echo "  kubectl exec -it -n $namespace \$(kubectl get pod -n $namespace -l app=oracle -o jsonpath='{.items[0].metadata.name}') -- sqlplus system/<password>@localhost:1521/XE"
}

# Main script
main() {
    echo "================================================"
    echo "Oracle Database Kubernetes Deployment Script"
    echo "================================================"
    echo ""
    
    # Check prerequisites
    check_kubectl
    check_cluster
    
    # Get deployment options
    read -p "Enter namespace (default: oracle-db): " namespace
    namespace=${namespace:-oracle-db}
    
    echo ""
    echo "Select Oracle Database Edition:"
    echo "1) Oracle XE (Express Edition) - For development/testing"
    echo "2) Oracle Enterprise Edition - For production"
    read -p "Enter choice (1 or 2): " edition_choice
    
    case $edition_choice in
        1)
            edition="xe"
            ;;
        2)
            edition="enterprise"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    
    # Create namespace
    create_namespace "$namespace"
    
    # Check if secrets already exist
    if kubectl get secret oracle-registry -n "$namespace" &> /dev/null; then
        print_warn "Oracle registry secret already exists, skipping creation"
    else
        read -p "Do you want to create Oracle Container Registry secret? (y/n): " create_reg
        if [ "$create_reg" == "y" ]; then
            create_registry_secret "$namespace"
        else
            print_warn "Skipping Oracle Container Registry secret creation"
        fi
    fi
    
    if kubectl get secret oracle-secrets -n "$namespace" &> /dev/null; then
        print_warn "Oracle password secret already exists, skipping creation"
    else
        read -p "Do you want to create Oracle password secret? (y/n): " create_pwd
        if [ "$create_pwd" == "y" ]; then
            create_password_secret "$namespace"
        else
            print_warn "Skipping Oracle password secret creation"
        fi
    fi
    
    # Deploy Oracle
    read -p "Proceed with deployment? (y/n): " proceed
    if [ "$proceed" != "y" ]; then
        print_info "Deployment cancelled"
        exit 0
    fi
    
    deploy_oracle "$namespace" "$edition"
    
    # Wait for pod to be ready
    wait_for_pod "$namespace" "app=oracle"
    
    # Show connection info
    show_connection_info "$namespace"
    
    print_info "Deployment completed successfully!"
}

# Run main function
main
