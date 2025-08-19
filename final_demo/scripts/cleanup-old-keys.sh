#!/bin/bash

# Cleanup Old Access Keys
# This script deletes old access keys to allow testing rotation

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

# Function to delete old access keys for a user
delete_old_access_keys() {
    local username=$1
    
    print_status "Cleaning up old access keys for $username..."
    
    # List all access keys for the user
    response=$(aws iam list-access-keys --user-name $username)
    access_keys=$(echo $response | jq -r '.AccessKeyMetadata[].AccessKeyId')
    
    if [ -n "$access_keys" ]; then
        for key_id in $access_keys; do
            print_status "Deleting access key: $key_id"
            aws iam delete-access-key --user-name $username --access-key-id $key_id
        done
        print_success "Deleted all access keys for $username"
    else
        print_warning "No access keys found for $username"
    fi
}

# Clean up old access keys for all demo users
print_status "Cleaning up old access keys for demo users..."

delete_old_access_keys "demo-user-1"
delete_old_access_keys "demo-user-2"
delete_old_access_keys "demo-user-3"
delete_old_access_keys "demo-user-4"

print_success "🎉 Old access keys cleanup completed!"
print_status "Now you can test rotation by creating new access keys."
