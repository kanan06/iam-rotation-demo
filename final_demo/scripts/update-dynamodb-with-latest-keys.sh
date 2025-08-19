#!/bin/bash

# Update DynamoDB with Latest Access Keys
# This script updates the DynamoDB table with the latest access keys

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

print_status "🔄 Updating DynamoDB with Latest Access Keys"
print_status "============================================="

# Function to update DynamoDB for a user
update_user_in_dynamodb() {
    local username=$1
    local access_key=$2
    
    print_status "Updating $username with access key: $access_key"
    
    # Get current timestamp
    current_time=$(date -u +"%Y-%m-%dT%H:%M:%S.%6N")
    
    # Calculate TTL (7 days from now)
    ttl=$(date -d "+7 days" +%s)
    
    # Update DynamoDB
    aws dynamodb put-item \
        --table-name iam-rotation-state \
        --item "{
            \"UserId\": {\"S\": \"$username\"},
            \"CurrentAccessKeyId\": {\"S\": \"$access_key\"},
            \"KeyCreatedAt\": {\"S\": \"$current_time\"},
            \"LastRotation\": {\"S\": \"$current_time\"},
            \"RotationCount\": {\"N\": \"1\"},
            \"TTL\": {\"N\": \"$ttl\"}
        }"
    
    print_success "✅ Updated $username in DynamoDB"
}

# Get latest access keys for each user (the newest ones)
print_status "Fetching latest access keys..."

# Get the newest access key for each user (last in the list)
USER1_KEY=$(aws iam list-access-keys --user-name demo-user-1 --query 'AccessKeyMetadata[-1].AccessKeyId' --output text)
USER2_KEY=$(aws iam list-access-keys --user-name demo-user-2 --query 'AccessKeyMetadata[-1].AccessKeyId' --output text)
USER3_KEY=$(aws iam list-access-keys --user-name demo-user-3 --query 'AccessKeyMetadata[-1].AccessKeyId' --output text)
USER4_KEY=$(aws iam list-access-keys --user-name demo-user-4 --query 'AccessKeyMetadata[-1].AccessKeyId' --output text)

print_status "Latest access keys:"
print_status "  demo-user-1: $USER1_KEY"
print_status "  demo-user-2: $USER2_KEY"
print_status "  demo-user-3: $USER3_KEY"
print_status "  demo-user-4: $USER4_KEY"

# Update DynamoDB for each user
print_status "Updating DynamoDB entries..."

update_user_in_dynamodb "demo-user-1" "$USER1_KEY"
update_user_in_dynamodb "demo-user-2" "$USER2_KEY"
update_user_in_dynamodb "demo-user-3" "$USER3_KEY"
update_user_in_dynamodb "demo-user-4" "$USER4_KEY"

print_success "🎉 DynamoDB updated successfully!"
print_status "All users now have their latest access keys in the rotation state table."
