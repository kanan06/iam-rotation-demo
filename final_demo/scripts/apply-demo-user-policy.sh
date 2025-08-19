#!/bin/bash

# Apply Demo User Policy
# This script applies the demo user policy to all demo users

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_status "AWS Account ID: $ACCOUNT_ID"

# Create the policy
print_status "Creating demo user policy..."
aws iam create-policy \
    --policy-name DemoUsersPolicy \
    --policy-document file://demo-users-policy.json \
    --description "Policy for demo users to access demo resources" \
    2>/dev/null || print_warning "Policy already exists"

# Get policy ARN
POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`DemoUsersPolicy`].Arn' --output text)
print_status "Policy ARN: $POLICY_ARN"

# Function to attach policy to a user
attach_policy_to_user() {
    local username=$1
    
    print_status "Attaching policy to $username..."
    
    # Check if policy is already attached
    if aws iam list-attached-user-policies --user-name $username --query 'AttachedPolicies[?PolicyName==`DemoUsersPolicy`].PolicyName' --output text | grep -q "DemoUsersPolicy"; then
        print_warning "Policy already attached to $username"
    else
        aws iam attach-user-policy \
            --user-name $username \
            --policy-arn $POLICY_ARN
        print_success "Policy attached to $username"
    fi
}

# Attach policy to all demo users
print_status "Attaching policy to all demo users..."

attach_policy_to_user "demo-user-1"
attach_policy_to_user "demo-user-2"
attach_policy_to_user "demo-user-3"
attach_policy_to_user "demo-user-4"

print_success "🎉 Demo user policy applied successfully!"
print_status "All demo users now have the necessary permissions to pass health checks."
