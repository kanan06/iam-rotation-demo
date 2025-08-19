#!/bin/bash

# Setup Access Keys for Demo Users
# This script creates access keys for demo users and updates .env files

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

# Get KMS key ID
KMS_KEY_ID=$(aws cloudformation describe-stacks --stack-name iam-rotation-demo --query 'Stacks[0].Outputs[?OutputKey==`KmsKeyId`].OutputValue' --output text)
print_status "KMS Key ID: $KMS_KEY_ID"

# Get config bucket name
CONFIG_BUCKET=$(aws cloudformation describe-stacks --stack-name iam-rotation-demo --query 'Stacks[0].Outputs[?OutputKey==`ConfigBucket`].OutputValue' --output text)
print_status "Config Bucket: $CONFIG_BUCKET"

# Function to create access key for a user
create_access_key() {
    local username=$1
    local user_num=$2
    
    print_status "Creating access key for $username..."
    
    # Create access key
    response=$(aws iam create-access-key --user-name $username)
    access_key_id=$(echo $response | jq -r '.AccessKey.AccessKeyId')
    secret_access_key=$(echo $response | jq -r '.AccessKey.SecretAccessKey')
    
    # Store in variables
    eval "USER${user_num}_ACCESS_KEY_ID=$access_key_id"
    eval "USER${user_num}_SECRET_ACCESS_KEY=$secret_access_key"
    
    print_success "Created access key for $username: $access_key_id"
}

# Create access keys for all demo users
print_status "Creating access keys for demo users..."

create_access_key "demo-user-1" 1
create_access_key "demo-user-2" 2
create_access_key "demo-user-3" 3
create_access_key "demo-user-4" 4

print_success "All access keys created"

# Update .env files with real credentials
print_status "Updating .env files with real credentials..."

# Update env1.env with real credentials
sed -i "s|PLACEHOLDER_ACCESS_KEY_1|$USER1_ACCESS_KEY_ID|g" env1.env
sed -i "s|PLACEHOLDER_SECRET_KEY_1|$USER1_SECRET_ACCESS_KEY|g" env1.env
sed -i "s|PLACEHOLDER_ACCESS_KEY_2|$USER2_ACCESS_KEY_ID|g" env1.env
sed -i "s|PLACEHOLDER_SECRET_KEY_2|$USER2_SECRET_ACCESS_KEY|g" env1.env

# Update env2.env with real credentials
sed -i "s|PLACEHOLDER_ACCESS_KEY_2|$USER2_ACCESS_KEY_ID|g" env2.env
sed -i "s|PLACEHOLDER_SECRET_KEY_2|$USER2_SECRET_ACCESS_KEY|g" env2.env
sed -i "s|PLACEHOLDER_ACCESS_KEY_3|$USER3_ACCESS_KEY_ID|g" env2.env
sed -i "s|PLACEHOLDER_SECRET_KEY_3|$USER3_SECRET_ACCESS_KEY|g" env2.env
sed -i "s|PLACEHOLDER_ACCESS_KEY_4|$USER4_ACCESS_KEY_ID|g" env2.env
sed -i "s|PLACEHOLDER_SECRET_KEY_4|$USER4_SECRET_ACCESS_KEY|g" env2.env

print_success ".env files updated with real credentials"

# Encrypt and upload .env files
print_status "Encrypting and uploading .env files..."

# Encrypt env1.env
print_status "Processing env1.env..."
aws kms encrypt \
    --key-id $KMS_KEY_ID \
    --plaintext fileb://env1.env \
    --output text \
    --query CiphertextBlob > env1.env.encrypted

# Upload env1.env files
aws s3 cp env1.env.encrypted s3://$CONFIG_BUCKET/env1.env.encrypted
aws s3 cp env1.env.metadata s3://$CONFIG_BUCKET/env1.env.metadata

# Encrypt env2.env
print_status "Processing env2.env..."
aws kms encrypt \
    --key-id $KMS_KEY_ID \
    --plaintext fileb://env2.env \
    --output text \
    --query CiphertextBlob > env2.env.encrypted

# Upload env2.env files
aws s3 cp env2.env.encrypted s3://$CONFIG_BUCKET/env2.env.encrypted
aws s3 cp env2.env.metadata s3://$CONFIG_BUCKET/env2.env.metadata

print_success "All .env files encrypted and uploaded to S3"

# Display summary
echo
print_success "🎉 Access Key Setup Complete!"
echo
echo "📋 Summary:"
echo "==========="
echo "✅ Created access keys for all demo users"
echo "✅ Updated .env files with real credentials"
echo "✅ Encrypted and uploaded files to S3"
echo
echo "🔑 Access Keys Created:"
echo "  demo-user-1: $USER1_ACCESS_KEY_ID"
echo "  demo-user-2: $USER2_ACCESS_KEY_ID"
echo "  demo-user-3: $USER3_ACCESS_KEY_ID"
echo "  demo-user-4: $USER4_ACCESS_KEY_ID"
echo
echo "📁 Files in S3:"
echo "  s3://$CONFIG_BUCKET/env1.env.encrypted"
echo "  s3://$CONFIG_BUCKET/env1.env.metadata"
echo "  s3://$CONFIG_BUCKET/env2.env.encrypted"
echo "  s3://$CONFIG_BUCKET/env2.env.metadata"
