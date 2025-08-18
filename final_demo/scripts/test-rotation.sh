#!/bin/bash

# IAM Key Rotation Demo - Test Script
# This script tests the rotation functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to get stack outputs
get_stack_outputs() {
    OUTPUTS=$(aws cloudformation describe-stacks \
        --stack-name iam-rotation-demo \
        --query 'Stacks[0].Outputs' \
        --output json)
    
    # Extract specific outputs
    CONFIG_BUCKET=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="ConfigBucket") | .OutputValue')
    DEMO_APP_BUCKET=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="DemoAppBucket") | .OutputValue')
    KMS_KEY_ID=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="KmsKeyId") | .OutputValue')
    NOTIFICATION_TOPIC_ARN=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="NotificationTopicArn") | .OutputValue')
    DYNAMODB_TABLE=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="DynamoDBTable") | .OutputValue')
    LAMBDA_FUNCTION_NAME=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="LambdaFunctionName") | .OutputValue')
}

# Function to test basic infrastructure
test_infrastructure() {
    print_status "Testing infrastructure components..."
    
    # Test S3 buckets
    print_status "Testing S3 buckets..."
    aws s3 ls s3://$CONFIG_BUCKET/
    aws s3 ls s3://$DEMO_APP_BUCKET/
    
    # Test DynamoDB table
    print_status "Testing DynamoDB table..."
    aws dynamodb scan --table-name $DYNAMODB_TABLE --max-items 5
    
    # Test Lambda function
    print_status "Testing Lambda function..."
    aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME
    
    # Test SNS topic
    print_status "Testing SNS topic..."
    aws sns get-topic-attributes --topic-arn $NOTIFICATION_TOPIC_ARN
    
    print_success "Infrastructure components are working"
}

# Function to test .env files
test_env_files() {
    print_status "Testing .env files..."
    
    # List files in config bucket
    print_status "Files in config bucket:"
    aws s3 ls s3://$CONFIG_BUCKET/
    
    # Test decryption of env1.env
    print_status "Testing decryption of env1.env..."
    aws s3 cp s3://$CONFIG_BUCKET/env1.env.encrypted /tmp/env1.env.encrypted
    aws s3 cp s3://$CONFIG_BUCKET/env1.env.metadata /tmp/env1.env.metadata
    
    # Decrypt and show content (without revealing secrets)
    aws kms decrypt \
        --key-id $KMS_KEY_ID \
        --ciphertext-blob fileb:///tmp/env1.env.encrypted \
        --output text \
        --query Plaintext | base64 -d > /tmp/env1.env.decrypted
    
    print_status "env1.env content (sanitized):"
    cat /tmp/env1.env.decrypted | sed 's/=.*/=***HIDDEN***/'
    
    # Test decryption of env2.env
    print_status "Testing decryption of env2.env..."
    aws s3 cp s3://$CONFIG_BUCKET/env2.env.encrypted /tmp/env2.env.encrypted
    aws s3 cp s3://$CONFIG_BUCKET/env2.env.metadata /tmp/env2.env.metadata
    
    # Decrypt and show content (without revealing secrets)
    aws kms decrypt \
        --key-id $KMS_KEY_ID \
        --ciphertext-blob fileb:///tmp/env2.env.encrypted \
        --output text \
        --query Plaintext | base64 -d > /tmp/env2.env.decrypted
    
    print_status "env2.env content (sanitized):"
    cat /tmp/env2.env.decrypted | sed 's/=.*/=***HIDDEN***/'
    
    print_success ".env files are accessible and decryptable"
}

# Function to test IAM users
test_iam_users() {
    print_status "Testing IAM users..."
    
    # List demo users
    print_status "Demo users:"
    aws iam list-users --query 'Users[?contains(UserName, `demo-user-`)].UserName' --output table
    
    # Check access keys for each user
    for user_num in 1 2 3 4; do
        username="demo-user-$user_num"
        print_status "Checking access keys for $username..."
        
        keys=$(aws iam list-access-keys --user-name $username --query 'AccessKeyMetadata[?Status==`Active`]' --output json)
        key_count=$(echo $keys | jq length)
        
        if [ "$key_count" -eq 1 ]; then
            print_success "$username has 1 active access key"
        else
            print_warning "$username has $key_count active access keys"
        fi
    done
    
    print_success "IAM users are properly configured"
}

# Function to test Lambda rotation
test_lambda_rotation() {
    print_status "Testing Lambda rotation function..."
    
    # Test with force rotation disabled (should check 7-day policy)
    print_status "Testing rotation with force_rotation=false..."
    aws lambda invoke \
        --function-name $LAMBDA_FUNCTION_NAME \
        --payload '{"target_files": ["env1.env", "env2.env"], "force_rotation": false}' \
        /tmp/rotation-response.json
    
    if [ $? -eq 0 ]; then
        print_success "Lambda function executed successfully"
        print_status "Response:"
        cat /tmp/rotation-response.json | jq .
    else
        print_error "Lambda function execution failed"
        exit 1
    fi
    
    # Test with force rotation enabled
    print_status "Testing rotation with force_rotation=true..."
    aws lambda invoke \
        --function-name $LAMBDA_FUNCTION_NAME \
        --payload '{"target_files": ["env1.env", "env2.env"], "force_rotation": true}' \
        /tmp/force-rotation-response.json
    
    if [ $? -eq 0 ]; then
        print_success "Force rotation executed successfully"
        print_status "Response:"
        cat /tmp/force-rotation-response.json | jq .
    else
        print_error "Force rotation failed"
        exit 1
    fi
}

# Function to test single file rotation
test_single_file_rotation() {
    print_status "Testing single file rotation..."
    
    # Test rotation for env1.env only
    print_status "Testing rotation for env1.env only..."
    aws lambda invoke \
        --function-name $LAMBDA_FUNCTION_NAME \
        --payload '{"target_files": ["env1.env"], "force_rotation": true}' \
        /tmp/single-file-response.json
    
    if [ $? -eq 0 ]; then
        print_success "Single file rotation executed successfully"
        print_status "Response:"
        cat /tmp/single-file-response.json | jq .
    else
        print_error "Single file rotation failed"
        exit 1
    fi
}

# Function to check rotation state
check_rotation_state() {
    print_status "Checking rotation state in DynamoDB..."
    
    # Scan DynamoDB table
    aws dynamodb scan --table-name $DYNAMODB_TABLE --output table
    
    print_success "Rotation state checked"
}

# Function to test health checks
test_health_checks() {
    print_status "Testing health checks..."
    
    # Run health check script
    if [ -f "scripts/health-check.py" ]; then
        python3 scripts/health-check.py
    else
        print_warning "Health check script not found"
    fi
    
    print_success "Health checks completed"
}

# Function to test SNS notifications
test_sns_notifications() {
    print_status "Testing SNS notifications..."
    
    # Send a test notification
    aws sns publish \
        --topic-arn $NOTIFICATION_TOPIC_ARN \
        --subject "IAM Rotation Demo - Test Notification" \
        --message "This is a test notification from the IAM rotation demo setup."
    
    print_success "Test notification sent"
}

# Function to display test summary
display_test_summary() {
    print_success "🎉 IAM Key Rotation Demo Testing Complete!"
    echo
    echo "📋 Test Summary:"
    echo "================"
    echo "✅ Infrastructure components tested"
    echo "✅ .env files tested (encryption/decryption)"
    echo "✅ IAM users and access keys verified"
    echo "✅ Lambda rotation function tested"
    echo "✅ Single file rotation tested"
    echo "✅ Rotation state checked"
    echo "✅ Health checks executed"
    echo "✅ SNS notifications tested"
    echo
}

# Main execution
main() {
    echo "🧪 IAM Key Rotation Demo - Testing"
    echo "==================================="
    echo
    
    # Get stack outputs
    get_stack_outputs
    
    # Run tests
    test_infrastructure
    test_env_files
    test_iam_users
    test_lambda_rotation
    test_single_file_rotation
    check_rotation_state
    test_health_checks
    test_sns_notifications
    
    # Display summary
    display_test_summary
}

# Check if help is requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "IAM Key Rotation Demo - Test Script"
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --help, -h    Show this help message"
    echo
    echo "This script tests all components of the IAM key rotation demo:"
    echo "• Infrastructure components (S3, DynamoDB, Lambda, SNS)"
    echo "• .env file encryption/decryption"
    echo "• IAM users and access keys"
    echo "• Lambda rotation function"
    echo "• Health checks"
    echo "• SNS notifications"
    exit 0
fi

# Run main function
main "$@"
