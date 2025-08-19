#!/bin/bash

# IAM Key Rotation Demo - Complete Cleanup Script
# This script removes all AWS infrastructure created for the demo

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

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install it first."
        exit 1
    fi
    
    print_success "All prerequisites are satisfied"
}

# Function to get AWS account ID
get_account_id() {
    print_status "Getting AWS account ID..."
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    print_success "AWS Account ID: $ACCOUNT_ID"
}

# Function to delete IAM users
delete_iam_users() {
    print_status "Deleting IAM users..."
    
    for user_num in 1 2 3 4; do
        username="demo-user-$user_num"
        print_status "Deleting IAM user: $username"
        
        # List and delete access keys
        access_keys=$(aws iam list-access-keys --user-name $username --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null || echo "")
        if [ -n "$access_keys" ]; then
            for key_id in $access_keys; do
                print_status "Deleting access key: $key_id"
                aws iam delete-access-key --user-name $username --access-key-id $key_id 2>/dev/null || true
            done
        fi
        
        # Delete the user
        aws iam delete-user --user-name $username 2>/dev/null || print_warning "User $username not found or already deleted"
    done
    
    print_success "IAM users cleanup completed"
}

# Function to delete IAM roles and policies
delete_iam_roles_and_policies() {
    print_status "Deleting IAM roles and policies..."
    
    # Delete GitHub Actions role
    print_status "Deleting GitHub Actions OIDC role..."
    aws iam delete-role-policy --role-name github-actions-oidc-role --policy-name GitHubActionsPolicy 2>/dev/null || print_warning "GitHubActionsPolicy not found"
    aws iam delete-role --role-name github-actions-oidc-role 2>/dev/null || print_warning "github-actions-oidc-role not found"
    
    # Delete GitHub Actions policy
    print_status "Deleting GitHub Actions policy..."
    aws iam delete-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/GitHubActionsPolicy 2>/dev/null || print_warning "GitHubActionsPolicy not found"
    
    # Delete Lambda role
    print_status "Deleting Lambda role..."
    aws iam delete-role-policy --role-name iam-rotation-lambda-role --policy-name IAMRotationPolicy 2>/dev/null || print_warning "IAMRotationPolicy not found"
    aws iam delete-role --role-name iam-rotation-lambda-role 2>/dev/null || print_warning "iam-rotation-lambda-role not found"
    
    print_success "IAM roles and policies cleanup completed"
}

# Function to delete OIDC provider
delete_oidc_provider() {
    print_status "Deleting OIDC provider..."
    aws iam delete-open-id-connect-provider --open-id-connect-provider-arn arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com 2>/dev/null || print_warning "OIDC provider not found"
    print_success "OIDC provider cleanup completed"
}

# Function to delete KMS key
delete_kms_key() {
    print_status "Deleting KMS key..."
    
    # Get KMS key ID from CloudFormation if available
    KMS_KEY_ID=$(aws cloudformation describe-stacks --stack-name iam-rotation-demo --query 'Stacks[0].Outputs[?OutputKey==`KmsKeyId`].OutputValue' --output text 2>/dev/null || echo "")
    
    if [ -n "$KMS_KEY_ID" ] && [ "$KMS_KEY_ID" != "None" ]; then
        print_status "Found KMS key: $KMS_KEY_ID"
        
        # Schedule key deletion (7-30 days)
        aws kms schedule-key-deletion --key-id $KMS_KEY_ID --pending-window-in-days 7 2>/dev/null || print_warning "KMS key deletion failed"
        print_success "KMS key scheduled for deletion"
    else
        print_warning "KMS key not found"
    fi
}

# Function to delete S3 buckets
delete_s3_buckets() {
    print_status "Deleting S3 buckets..."
    
    # Get bucket names from CloudFormation if available
    CONFIG_BUCKET=$(aws cloudformation describe-stacks --stack-name iam-rotation-demo --query 'Stacks[0].Outputs[?OutputKey==`ConfigBucket`].OutputValue' --output text 2>/dev/null || echo "")
    DEMO_APP_BUCKET=$(aws cloudformation describe-stacks --stack-name iam-rotation-demo --query 'Stacks[0].Outputs[?OutputKey==`DemoAppBucket`].OutputValue' --output text 2>/dev/null || echo "")
    
    # Delete config bucket
    if [ -n "$CONFIG_BUCKET" ] && [ "$CONFIG_BUCKET" != "None" ]; then
        print_status "Deleting config bucket: $CONFIG_BUCKET"
        aws s3 rb s3://$CONFIG_BUCKET --force 2>/dev/null || print_warning "Config bucket deletion failed"
    fi
    
    # Delete demo app bucket
    if [ -n "$DEMO_APP_BUCKET" ] && [ "$DEMO_APP_BUCKET" != "None" ]; then
        print_status "Deleting demo app bucket: $DEMO_APP_BUCKET"
        aws s3 rb s3://$DEMO_APP_BUCKET --force 2>/dev/null || print_warning "Demo app bucket deletion failed"
    fi
    
    print_success "S3 buckets cleanup completed"
}

# Function to delete Lambda function
delete_lambda_function() {
    print_status "Deleting Lambda function..."
    aws lambda delete-function --function-name iam-rotation-function 2>/dev/null || print_warning "Lambda function not found"
    print_success "Lambda function cleanup completed"
}

# Function to delete CloudWatch log group
delete_cloudwatch_logs() {
    print_status "Deleting CloudWatch log group..."
    aws logs delete-log-group --log-group-name "/aws/lambda/iam-rotation-function" 2>/dev/null || print_warning "Log group not found"
    print_success "CloudWatch logs cleanup completed"
}

# Function to delete DynamoDB table
delete_dynamodb_table() {
    print_status "Deleting DynamoDB table..."
    aws dynamodb delete-table --table-name iam-rotation-state 2>/dev/null || print_warning "DynamoDB table not found"
    print_success "DynamoDB table cleanup completed"
}

# Function to delete SNS topic
delete_sns_topic() {
    print_status "Deleting SNS topic..."
    
    # Get SNS topic ARN from CloudFormation if available
    SNS_TOPIC_ARN=$(aws cloudformation describe-stacks --stack-name iam-rotation-demo --query 'Stacks[0].Outputs[?OutputKey==`NotificationTopicArn`].OutputValue' --output text 2>/dev/null || echo "")
    
    if [ -n "$SNS_TOPIC_ARN" ] && [ "$SNS_TOPIC_ARN" != "None" ]; then
        aws sns delete-topic --topic-arn $SNS_TOPIC_ARN 2>/dev/null || print_warning "SNS topic deletion failed"
    fi
    
    print_success "SNS topic cleanup completed"
}

# Function to delete CloudFormation stack
delete_cloudformation_stack() {
    print_status "Deleting CloudFormation stack..."
    
    # Check if stack exists
    if aws cloudformation describe-stacks --stack-name iam-rotation-demo &> /dev/null; then
        print_status "Deleting stack: iam-rotation-demo"
        aws cloudformation delete-stack --stack-name iam-rotation-demo
        
        print_status "Waiting for stack deletion to complete..."
        aws cloudformation wait stack-delete-complete --stack-name iam-rotation-demo
        
        print_success "CloudFormation stack deleted successfully"
    else
        print_warning "CloudFormation stack not found"
    fi
}

# Function to clean up local files
cleanup_local_files() {
    print_status "Cleaning up local files..."
    
    # Remove local .env files
    rm -f env1.env env2.env env1.env.encrypted env2.env.encrypted env1.env.metadata env2.env.metadata 2>/dev/null || true
    
    # Remove local policy files
    rm -f github-actions-policy.json kms-key-policy.json 2>/dev/null || true
    
    # Remove test files
    rm -f test.txt test.encrypted test.encrypted.bin 2>/dev/null || true
    
    print_success "Local files cleanup completed"
}

# Function to display cleanup summary
display_cleanup_summary() {
    print_success "🎉 IAM Key Rotation Demo Cleanup Complete!"
    echo
    echo "📋 Cleanup Summary:"
    echo "==================="
    echo "✅ CloudFormation Stack: iam-rotation-demo"
    echo "✅ IAM Users: demo-user-1, demo-user-2, demo-user-3, demo-user-4"
    echo "✅ IAM Roles: github-actions-oidc-role, iam-rotation-lambda-role"
    echo "✅ IAM Policies: GitHubActionsPolicy, IAMRotationPolicy"
    echo "✅ OIDC Provider: token.actions.githubusercontent.com"
    echo "✅ KMS Key: Scheduled for deletion (7 days)"
    echo "✅ S3 Buckets: Config and Demo App buckets"
    echo "✅ Lambda Function: iam-rotation-function"
    echo "✅ CloudWatch Logs: /aws/lambda/iam-rotation-function"
    echo "✅ DynamoDB Table: iam-rotation-state"
    echo "✅ SNS Topic: iam-rotation-notifications"
    echo "✅ Local Files: All demo files removed"
    echo
    echo "🚀 Ready for fresh deployment tomorrow!"
    echo
}

# Main execution
main() {
    echo "🧹 IAM Key Rotation Demo - Complete Cleanup"
    echo "==========================================="
    echo
    
    # Check prerequisites
    check_prerequisites
    
    # Get AWS account ID
    get_account_id
    
    # Delete resources in reverse order of dependencies
    print_status "Starting cleanup process..."
    
    # Delete IAM users first (they depend on roles)
    delete_iam_users
    
    # Delete IAM roles and policies
    delete_iam_roles_and_policies
    
    # Delete OIDC provider
    delete_oidc_provider
    
    # Delete Lambda function
    delete_lambda_function
    
    # Delete CloudWatch log group
    delete_cloudwatch_logs
    
    # Delete DynamoDB table
    delete_dynamodb_table
    
    # Delete SNS topic
    delete_sns_topic
    
    # Delete S3 buckets
    delete_s3_buckets
    
    # Delete KMS key
    delete_kms_key
    
    # Delete CloudFormation stack last
    delete_cloudformation_stack
    
    # Clean up local files
    cleanup_local_files
    
    # Display summary
    display_cleanup_summary
}

# Run main function
main "$@"
