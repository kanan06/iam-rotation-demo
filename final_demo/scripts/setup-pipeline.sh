#!/bin/bash

# IAM Key Rotation Demo - Complete Setup Script
# This script deploys the entire infrastructure and sets up the demo

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
    
    # Check Python3
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 is not installed. Please install it first."
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

# Function to deploy CloudFormation stack
deploy_infrastructure() {
    print_status "Deploying CloudFormation infrastructure..."
    
    # Check if stack already exists
    if aws cloudformation describe-stacks --stack-name iam-rotation-demo &> /dev/null; then
        print_warning "Stack 'iam-rotation-demo' already exists. Updating..."
        aws cloudformation update-stack \
            --stack-name iam-rotation-demo \
            --template-body file://cloudformation/infrastructure.yaml \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameters \
                ParameterKey=DemoUserName1,ParameterValue=demo-user-1 \
                ParameterKey=DemoUserName2,ParameterValue=demo-user-2 \
                ParameterKey=DemoUserName3,ParameterValue=demo-user-3 \
                ParameterKey=DemoUserName4,ParameterValue=demo-user-4
        
        print_status "Waiting for stack update to complete..."
        aws cloudformation wait stack-update-complete --stack-name iam-rotation-demo
    else
        print_status "Creating new stack 'iam-rotation-demo'..."
        aws cloudformation create-stack \
            --stack-name iam-rotation-demo \
            --template-body file://cloudformation/infrastructure.yaml \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameters \
                ParameterKey=DemoUserName1,ParameterValue=demo-user-1 \
                ParameterKey=DemoUserName2,ParameterValue=demo-user-2 \
                ParameterKey=DemoUserName3,ParameterValue=demo-user-3 \
                ParameterKey=DemoUserName4,ParameterValue=demo-user-4
        
        print_status "Waiting for stack creation to complete..."
        aws cloudformation wait stack-create-complete --stack-name iam-rotation-demo
    fi
    
    print_success "Infrastructure deployed successfully"
}

# Function to get stack outputs
get_stack_outputs() {
    print_status "Getting stack outputs..."
    
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
    GITHUB_ACTIONS_ROLE_ARN=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="GitHubActionsRoleArn") | .OutputValue')
    
    print_success "Stack outputs retrieved"
}

# Function to create initial .env files
create_initial_env_files() {
    print_status "Creating initial .env files..."
    
    # Create env1.env with demo-user-1 and demo-user-2
    cat > /tmp/env1.env << EOF
# Environment 1 Configuration
# Contains demo-user-1 and demo-user-2

# Demo User 1 Credentials (will be populated after key creation)
AWS_ACCESS_KEY_ID_USER1=PLACEHOLDER_ACCESS_KEY_1
AWS_SECRET_ACCESS_KEY_USER1=PLACEHOLDER_SECRET_KEY_1

# Demo User 2 Credentials (will be populated after key creation)
AWS_ACCESS_KEY_ID_USER2=PLACEHOLDER_ACCESS_KEY_2
AWS_SECRET_ACCESS_KEY_USER2=PLACEHOLDER_SECRET_KEY_2

# Environment Configuration
ENVIRONMENT=env1
AWS_REGION=us-east-1
EOF

    # Create env2.env with demo-user-2, demo-user-3, and demo-user-4
    cat > /tmp/env2.env << EOF
# Environment 2 Configuration
# Contains demo-user-2, demo-user-3, and demo-user-4

# Demo User 2 Credentials (common user - will be populated after key creation)
AWS_ACCESS_KEY_ID_USER2=PLACEHOLDER_ACCESS_KEY_2
AWS_SECRET_ACCESS_KEY_USER2=PLACEHOLDER_SECRET_KEY_2

# Demo User 3 Credentials (will be populated after key creation)
AWS_ACCESS_KEY_ID_USER3=PLACEHOLDER_ACCESS_KEY_3
AWS_SECRET_ACCESS_KEY_USER3=PLACEHOLDER_SECRET_KEY_3

# Demo User 4 Credentials (will be populated after key creation)
AWS_ACCESS_KEY_ID_USER4=PLACEHOLDER_ACCESS_KEY_4
AWS_SECRET_ACCESS_KEY_USER4=PLACEHOLDER_SECRET_KEY_4

# Environment Configuration
ENVIRONMENT=env2
AWS_REGION=us-east-1
EOF

    print_success "Initial .env files created"
}

# Function to create access keys for demo users
create_access_keys() {
    print_status "Creating access keys for demo users..."
    
    # Create keys for each demo user
    for user_num in 1 2 3 4; do
        username="demo-user-$user_num"
        print_status "Creating access key for $username..."
        
        # Create access key
        response=$(aws iam create-access-key --user-name $username)
        access_key_id=$(echo $response | jq -r '.AccessKey.AccessKeyId')
        secret_access_key=$(echo $response | jq -r '.AccessKey.SecretAccessKey')
        
        print_success "Created access key for $username: $access_key_id"
        
        # Store keys for later use
        eval "USER${user_num}_ACCESS_KEY_ID=$access_key_id"
        eval "USER${user_num}_SECRET_ACCESS_KEY=$secret_access_key"
    done
    
    print_success "All access keys created"
}

# Function to encrypt and upload .env files
encrypt_and_upload_env_files() {
    print_status "Encrypting and uploading .env files..."
    
    # Update env1.env with real credentials
    sed -i "s|PLACEHOLDER_ACCESS_KEY_1|$USER1_ACCESS_KEY_ID|g" /tmp/env1.env
    sed -i "s|PLACEHOLDER_SECRET_KEY_1|$USER1_SECRET_ACCESS_KEY|g" /tmp/env1.env
    sed -i "s|PLACEHOLDER_ACCESS_KEY_2|$USER2_ACCESS_KEY_ID|g" /tmp/env1.env
    sed -i "s|PLACEHOLDER_SECRET_KEY_2|$USER2_SECRET_ACCESS_KEY|g" /tmp/env1.env
    
    # Update env2.env with real credentials
    sed -i "s|PLACEHOLDER_ACCESS_KEY_2|$USER2_ACCESS_KEY_ID|g" /tmp/env2.env
    sed -i "s|PLACEHOLDER_SECRET_KEY_2|$USER2_SECRET_ACCESS_KEY|g" /tmp/env2.env
    sed -i "s|PLACEHOLDER_ACCESS_KEY_3|$USER3_ACCESS_KEY_ID|g" /tmp/env2.env
    sed -i "s|PLACEHOLDER_SECRET_KEY_3|$USER3_SECRET_ACCESS_KEY|g" /tmp/env2.env
    sed -i "s|PLACEHOLDER_ACCESS_KEY_4|$USER4_ACCESS_KEY_ID|g" /tmp/env2.env
    sed -i "s|PLACEHOLDER_SECRET_KEY_4|$USER4_SECRET_ACCESS_KEY|g" /tmp/env2.env
    
    # Encrypt and upload env1.env
    print_status "Processing env1.env..."
    aws kms encrypt \
        --key-id $KMS_KEY_ID \
        --plaintext fileb:///tmp/env1.env \
        --output text \
        --query CiphertextBlob > /tmp/env1.env.encrypted
    
    # Create metadata for env1.env
    cat > /tmp/env1.env.metadata << EOF
{
  "file_name": "env1.env",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "encryption_key_id": "$KMS_KEY_ID",
  "users": ["demo-user-1", "demo-user-2"],
  "environment": "env1"
}
EOF
    
    # Upload env1.env files
    aws s3 cp /tmp/env1.env.encrypted s3://$CONFIG_BUCKET/env1.env.encrypted
    aws s3 cp /tmp/env1.env.metadata s3://$CONFIG_BUCKET/env1.env.metadata
    
    # Encrypt and upload env2.env
    print_status "Processing env2.env..."
    aws kms encrypt \
        --key-id $KMS_KEY_ID \
        --plaintext fileb:///tmp/env2.env \
        --output text \
        --query CiphertextBlob > /tmp/env2.env.encrypted
    
    # Create metadata for env2.env
    cat > /tmp/env2.env.metadata << EOF
{
  "file_name": "env2.env",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "encryption_key_id": "$KMS_KEY_ID",
  "users": ["demo-user-2", "demo-user-3", "demo-user-4"],
  "environment": "env2"
}
EOF
    
    # Upload env2.env files
    aws s3 cp /tmp/env2.env.encrypted s3://$CONFIG_BUCKET/env2.env.encrypted
    aws s3 cp /tmp/env2.env.metadata s3://$CONFIG_BUCKET/env2.env.metadata
    
    print_success "All .env files encrypted and uploaded"
}

# Function to deploy Lambda function
deploy_lambda_function() {
    print_status "Deploying Lambda function..."
    
    # Create deployment package
    print_status "Creating Lambda deployment package..."
    
    # Create temporary directory for package
    mkdir -p /tmp/lambda-package
    
    # Copy Lambda function
    cp lambda/lambda_function.py /tmp/lambda-package/
    
    # Install dependencies
    pip3 install boto3 requests -t /tmp/lambda-package/
    
    # Create ZIP file
    cd /tmp/lambda-package
    zip -r lambda-package.zip .
    cd - > /dev/null
    
    # Update Lambda function code
    aws lambda update-function-code \
        --function-name $LAMBDA_FUNCTION_NAME \
        --zip-file fileb:///tmp/lambda-package/lambda-package.zip
    
    print_success "Lambda function deployed"
}

# Function to test the setup
test_setup() {
    print_status "Testing the setup..."
    
    # Test Lambda function
    print_status "Testing Lambda function..."
    aws lambda invoke \
        --function-name $LAMBDA_FUNCTION_NAME \
        --payload '{"target_files": ["env1.env", "env2.env"], "force_rotation": false}' \
        /tmp/lambda-response.json
    
    if [ $? -eq 0 ]; then
        print_success "Lambda function test successful"
        cat /tmp/lambda-response.json | jq .
    else
        print_error "Lambda function test failed"
    fi
    
    # Test S3 access
    print_status "Testing S3 access..."
    aws s3 ls s3://$CONFIG_BUCKET/
    
    # Test DynamoDB access
    print_status "Testing DynamoDB access..."
    aws dynamodb scan --table-name $DYNAMODB_TABLE --max-items 5
    
    print_success "Setup testing completed"
}

# Function to display summary
display_summary() {
    print_success "🎉 IAM Key Rotation Demo Setup Complete!"
    echo
    echo "📋 Setup Summary:"
    echo "=================="
    echo "✅ CloudFormation Stack: iam-rotation-demo"
    echo "✅ Config Bucket: $CONFIG_BUCKET"
    echo "✅ Demo App Bucket: $DEMO_APP_BUCKET"
    echo "✅ KMS Key: $KMS_KEY_ID"
    echo "✅ DynamoDB Table: $DYNAMODB_TABLE"
    echo "✅ Lambda Function: $LAMBDA_FUNCTION_NAME"
    echo "✅ SNS Topic: $NOTIFICATION_TOPIC_ARN"
    echo "✅ GitHub Actions Role: $GITHUB_ACTIONS_ROLE_ARN"
    echo
    echo "👥 Demo Users Created:"
    echo "======================"
    echo "• demo-user-1 (env1.env)"
    echo "• demo-user-2 (env1.env, env2.env) - Common user"
    echo "• demo-user-3 (env2.env)"
    echo "• demo-user-4 (env2.env)"
    echo
    echo "📁 Environment Files:"
    echo "====================="
    echo "• env1.env: 2 users (demo-user-1, demo-user-2)"
    echo "• env2.env: 3 users (demo-user-2, demo-user-3, demo-user-4)"
    echo
    echo "🚀 Next Steps:"
    echo "=============="
    echo "1. Set up GitHub repository with the provided workflow"
    echo "2. Add AWS_ACCOUNT_ID secret to GitHub repository"
    echo "3. Test the rotation by running: ./scripts/test-rotation.sh"
    echo "4. Monitor the pipeline in GitHub Actions"
    echo
    echo "📚 Documentation:"
    echo "================="
    echo "• README.md - Complete setup and usage guide"
    echo "• scripts/ - Additional scripts for testing and management"
    echo
}

# Main execution
main() {
    echo "🚀 IAM Key Rotation Demo - Complete Setup"
    echo "=========================================="
    echo
    
    # Check prerequisites
    check_prerequisites
    
    # Get AWS account ID
    get_account_id
    
    # Deploy infrastructure
    deploy_infrastructure
    
    # Get stack outputs
    get_stack_outputs
    
    # Create initial .env files
    create_initial_env_files
    
    # Create access keys
    create_access_keys
    
    # Encrypt and upload .env files
    encrypt_and_upload_env_files
    
    # Deploy Lambda function
    deploy_lambda_function
    
    # Test the setup
    test_setup
    
    # Display summary
    display_summary
}

# Run main function
main "$@"
