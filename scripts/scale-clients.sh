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
    echo "Usage: $0 <desired_count>"
    echo ""
    echo "Scale the Nomad client ASG to the specified count"
    echo ""
    echo "Arguments:"
    echo "  desired_count   Number of client instances (must be between min and max)"
    echo ""
    echo "Examples:"
    echo "  $0 3    # Scale to 3 clients"
    echo "  $0 1    # Scale down to 1 client"
}

if [[ $# -ne 1 ]]; then
    log_error "Missing required argument: desired_count"
    usage
    exit 1
fi

DESIRED_COUNT=$1

# Validate it's a number
if ! [[ "$DESIRED_COUNT" =~ ^[0-9]+$ ]]; then
    log_error "desired_count must be a number"
    exit 1
fi

# Get ASG name from Terraform output
cd "$TERRAFORM_DIR"

ASG_NAME=$(terraform output -raw client_asg_name 2>/dev/null)

if [[ -z "$ASG_NAME" ]]; then
    log_error "Could not get ASG name from Terraform state"
    log_info "Make sure Terraform has been applied"
    exit 1
fi

log_info "Scaling ASG $ASG_NAME to $DESIRED_COUNT instances..."

# Scale ASG
aws autoscaling set-desired-capacity \
    --auto-scaling-group-name "$ASG_NAME" \
    --desired-capacity "$DESIRED_COUNT"

log_info "Scale request submitted"

# Wait for scaling to complete
log_info "Waiting for scaling to complete..."

while true; do
    CURRENT=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$ASG_NAME" \
        --query 'AutoScalingGroups[0].Instances | length(@)' \
        --output text)

    IN_SERVICE=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$ASG_NAME" \
        --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`] | length(@)' \
        --output text)

    log_info "Current: $CURRENT, In Service: $IN_SERVICE, Desired: $DESIRED_COUNT"

    if [[ "$IN_SERVICE" -eq "$DESIRED_COUNT" ]]; then
        break
    fi

    sleep 10
done

log_info "Scaling complete!"

# Show instance IPs
log_info "Client instance IPs:"
aws ec2 describe-instances \
    --filters "Name=tag:AnsibleGroup,Values=clients" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].[InstanceId, PublicIpAddress, PrivateIpAddress]' \
    --output table
