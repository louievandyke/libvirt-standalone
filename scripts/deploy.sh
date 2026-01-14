#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"

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
    echo "Deploy the Nomad cluster with Terraform and Ansible"
    echo ""
    echo "Options:"
    echo "  -t, --terraform-only   Only run Terraform (skip Ansible)"
    echo "  -a, --ansible-only     Only run Ansible (skip Terraform)"
    echo "  -y, --auto-approve     Auto-approve Terraform changes"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                     # Full deployment"
    echo "  $0 -y                  # Full deployment with auto-approve"
    echo "  $0 -t                  # Terraform only"
    echo "  $0 -a                  # Ansible only (requires existing infrastructure)"
}

TERRAFORM_ONLY=false
ANSIBLE_ONLY=false
AUTO_APPROVE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--terraform-only)
            TERRAFORM_ONLY=true
            shift
            ;;
        -a|--ansible-only)
            ANSIBLE_ONLY=true
            shift
            ;;
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

# Check for required tools
check_requirements() {
    log_info "Checking requirements..."

    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed"
        exit 1
    fi

    if ! command -v ansible-playbook &> /dev/null; then
        log_error "Ansible is not installed"
        exit 1
    fi

    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi

    log_info "All requirements satisfied"
}

# Run Terraform
run_terraform() {
    log_info "Running Terraform..."

    cd "$TERRAFORM_DIR"

    # Check for tfvars file
    if [[ ! -f "terraform.tfvars" ]]; then
        log_warn "terraform.tfvars not found"
        log_info "Copy terraform.tfvars.example to terraform.tfvars and configure it"
        exit 1
    fi

    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init

    # Plan
    log_info "Planning Terraform changes..."
    terraform plan -out=tfplan

    # Apply
    log_info "Applying Terraform changes..."
    terraform apply $AUTO_APPROVE tfplan

    # Show outputs
    log_info "Terraform outputs:"
    terraform output

    cd "$PROJECT_ROOT"
}

# Wait for instances to be ready
wait_for_instances() {
    log_info "Waiting for instances to be ready..."

    cd "$TERRAFORM_DIR"

    # Get server IPs
    SERVER_IPS=$(terraform output -json server_public_ips | jq -r '.[]')

    for ip in $SERVER_IPS; do
        log_info "Waiting for server $ip..."
        until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$ip "echo ready" &> /dev/null; do
            sleep 5
        done
        log_info "Server $ip is ready"
    done

    cd "$PROJECT_ROOT"
}

# Install Ansible requirements
install_ansible_requirements() {
    log_info "Installing Ansible requirements..."

    cd "$ANSIBLE_DIR"

    if [[ -f "requirements.yaml" ]]; then
        ansible-galaxy collection install -r requirements.yaml
    fi

    cd "$PROJECT_ROOT"
}

# Run Ansible
run_ansible() {
    log_info "Running Ansible..."

    cd "$ANSIBLE_DIR"

    # Run playbook
    log_info "Running site playbook..."
    ansible-playbook playbooks/site.yaml

    cd "$PROJECT_ROOT"
}

# Main
main() {
    log_info "Starting deployment..."

    check_requirements

    if [[ "$ANSIBLE_ONLY" != "true" ]]; then
        run_terraform
        wait_for_instances
    fi

    if [[ "$TERRAFORM_ONLY" != "true" ]]; then
        install_ansible_requirements
        run_ansible
    fi

    log_info "Deployment complete!"

    # Print access info
    cd "$TERRAFORM_DIR"
    echo ""
    echo "=========================================="
    echo "Access Information:"
    echo "=========================================="
    terraform output ssh_info
    echo ""
    echo "Nomad UI: $(terraform output -raw nomad_ui)"
    echo "Consul UI: $(terraform output -raw consul_ui)"
    echo "Vault UI: $(terraform output -raw vault_ui)"
    echo "=========================================="
}

main
