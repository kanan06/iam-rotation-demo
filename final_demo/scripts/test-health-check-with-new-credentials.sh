#!/bin/bash

# Test Health Check with New Credentials
# This script tests health checks using the new credentials from rotated keys

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "🧪 Testing Health Checks with New Credentials"
print_status "=============================================="

# Get the latest access keys from DynamoDB
print_status "Fetching latest access keys from DynamoDB..."

# Get current access keys for each user
USER1_KEY=$(aws dynamodb get-item \
    --table-name iam-rotation-state \
    --key '{"UserId": {"S": "demo-user-1"}}' \
    --query 'Item.CurrentAccessKeyId.S' \
    --output text)

USER2_KEY=$(aws dynamodb get-item \
    --table-name iam-rotation-state \
    --key '{"UserId": {"S": "demo-user-2"}}' \
    --query 'Item.CurrentAccessKeyId.S' \
    --output text)

USER3_KEY=$(aws dynamodb get-item \
    --table-name iam-rotation-state \
    --key '{"UserId": {"S": "demo-user-3"}}' \
    --query 'Item.CurrentAccessKeyId.S' \
    --output text)

USER4_KEY=$(aws dynamodb get-item \
    --table-name iam-rotation-state \
    --key '{"UserId": {"S": "demo-user-4"}}' \
    --query 'Item.CurrentAccessKeyId.S' \
    --output text)

print_status "Current access keys:"
print_status "  demo-user-1: $USER1_KEY"
print_status "  demo-user-2: $USER2_KEY"
print_status "  demo-user-3: $USER3_KEY"
print_status "  demo-user-4: $USER4_KEY"

# Function to test credentials
test_credentials() {
    local username=$1
    local access_key=$2
    local secret_key=$3
    
    print_status "Testing credentials for $username..."
    
    # Test S3 access
    if AWS_ACCESS_KEY_ID=$access_key AWS_SECRET_ACCESS_KEY=$secret_key aws s3 ls s3://iam-rotation-demo-config-160885290762/ >/dev/null 2>&1; then
        print_success "✅ $username can access S3"
    else
        print_error "❌ $username cannot access S3"
        return 1
    fi
    
    # Test DynamoDB access
    if AWS_ACCESS_KEY_ID=$access_key AWS_SECRET_ACCESS_KEY=$secret_key aws dynamodb describe-table --table-name iam-rotation-state >/dev/null 2>&1; then
        print_success "✅ $username can access DynamoDB"
    else
        print_error "❌ $username cannot access DynamoDB"
        return 1
    fi
    
    # Test SNS access
    if AWS_ACCESS_KEY_ID=$access_key AWS_SECRET_ACCESS_KEY=$secret_key aws sns get-topic-attributes --topic-arn arn:aws:sns:us-east-1:160885290762:iam-rotation-notifications >/dev/null 2>&1; then
        print_success "✅ $username can access SNS"
    else
        print_error "❌ $username cannot access SNS"
        return 1
    fi
    
    # Test Lambda access
    if AWS_ACCESS_KEY_ID=$access_key AWS_SECRET_ACCESS_KEY=$secret_key aws lambda get-function --function-name iam-rotation-function >/dev/null 2>&1; then
        print_success "✅ $username can access Lambda"
    else
        print_error "❌ $username cannot access Lambda"
        return 1
    fi
    
    # Test IAM access (limited to demo users)
    if AWS_ACCESS_KEY_ID=$access_key AWS_SECRET_ACCESS_KEY=$secret_key aws iam list-users --query 'Users[?contains(UserName, `demo-user`)].UserName' --output text >/dev/null 2>&1; then
        print_success "✅ $username can access IAM (demo users)"
    else
        print_error "❌ $username cannot access IAM"
        return 1
    fi
    
    print_success "🎉 All health checks passed for $username"
    return 0
}

# Get secret keys from the encrypted .env files
print_status "Decrypting .env files to get secret keys..."

# Download and decrypt env1.env
aws s3 cp s3://iam-rotation-demo-config-160885290762/env1.env.encrypted /tmp/env1.env.encrypted
aws s3 cp s3://iam-rotation-demo-config-160885290762/env1.env.metadata /tmp/env1.env.metadata

# Decrypt env1.env
aws kms decrypt \
    --ciphertext-blob fileb:///tmp/env1.env.encrypted \
    --key-id d006c181-c7b5-4f03-b2f0-20374ac95e9e \
    --query Plaintext \
    --output text | base64 -d > /tmp/env1.env

# Download and decrypt env2.env
aws s3 cp s3://iam-rotation-demo-config-160885290762/env2.env.encrypted /tmp/env2.env.encrypted
aws s3 cp s3://iam-rotation-demo-config-160885290762/env2.env.metadata /tmp/env2.env.metadata

# Decrypt env2.env
aws kms decrypt \
    --ciphertext-blob fileb:///tmp/env2.env.encrypted \
    --key-id d006c181-c7b5-4f03-b2f0-20374ac95e9e \
    --query Plaintext \
    --output text | base64 -d > /tmp/env2.env

# Extract secret keys
USER1_SECRET=$(grep "AWS_SECRET_ACCESS_KEY_USER1=" /tmp/env1.env | cut -d'=' -f2)
USER2_SECRET=$(grep "AWS_SECRET_ACCESS_KEY_USER2=" /tmp/env1.env | cut -d'=' -f2)
USER3_SECRET=$(grep "AWS_SECRET_ACCESS_KEY_USER3=" /tmp/env2.env | cut -d'=' -f2)
USER4_SECRET=$(grep "AWS_SECRET_ACCESS_KEY_USER4=" /tmp/env2.env | cut -d'=' -f2)

print_status "Testing all users with their new credentials..."

# Test each user
test_credentials "demo-user-1" "$USER1_KEY" "$USER1_SECRET"
USER1_RESULT=$?

test_credentials "demo-user-2" "$USER2_KEY" "$USER2_SECRET"
USER2_RESULT=$?

test_credentials "demo-user-3" "$USER3_KEY" "$USER3_SECRET"
USER3_RESULT=$?

test_credentials "demo-user-4" "$USER4_KEY" "$USER4_SECRET"
USER4_RESULT=$?

# Summary
print_status "=============================================="
print_status "Health Check Summary:"
print_status "  demo-user-1: $([ $USER1_RESULT -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
print_status "  demo-user-2: $([ $USER2_RESULT -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
print_status "  demo-user-3: $([ $USER3_RESULT -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
print_status "  demo-user-4: $([ $USER4_RESULT -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"

# Clean up
rm -f /tmp/env1.env.encrypted /tmp/env1.env.metadata /tmp/env1.env
rm -f /tmp/env2.env.encrypted /tmp/env2.env.metadata /tmp/env2.env

if [ $USER1_RESULT -eq 0 ] && [ $USER2_RESULT -eq 0 ] && [ $USER3_RESULT -eq 0 ] && [ $USER4_RESULT -eq 0 ]; then
    print_success "🎉 All health checks passed! The new credentials are working correctly."
    print_status "The GitHub Actions pipeline should now be able to run successfully with these credentials."
else
    print_error "❌ Some health checks failed. Please check the permissions."
    exit 1
fi
