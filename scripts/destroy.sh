#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Destroy the Nomad cluster infrastructure"
    echo ""
    echo "Options:"
    echo "  -y, --auto-approve     Auto-approve destruction"
    echo "  -h, --help             Show this help message"
}

AUTO_APPROVE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--auto-approve)
            AUTO_APPROVE="-auto-approve"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Confirmation
if [[ -z "$AUTO_APPROVE" ]]; then
    echo ""
    log_warn "This will destroy ALL infrastructure!"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_info "Destruction cancelled"
        exit 0
    fi
fi

# Run Terraform destroy
log_info "Destroying infrastructure..."

cd "$TERRAFORM_DIR"

terraform destroy $AUTO_APPROVE

log_info "Infrastructure destroyed"
