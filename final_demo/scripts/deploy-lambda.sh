#!/bin/bash

# Deploy Lambda Function
# This script deploys the updated Lambda function code

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Get Lambda function name
LAMBDA_FUNCTION_NAME=$(aws cloudformation describe-stacks --stack-name iam-rotation-demo --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionName`].OutputValue' --output text)
print_status "Lambda Function Name: $LAMBDA_FUNCTION_NAME"

# Deploy Lambda function
print_status "Deploying Lambda function..."

# Create deployment package
print_status "Creating Lambda deployment package..."

# Create temporary directory for package
mkdir -p /tmp/lambda-package

# Copy Lambda function
cp lambda/lambda_function.py /tmp/lambda-package/

# Install dependencies
print_status "Installing dependencies..."
pip3 install boto3 requests -t /tmp/lambda-package/

# Create ZIP file
print_status "Creating deployment package..."
cd /tmp/lambda-package
zip -r lambda-package.zip .
cd - > /dev/null

# Update Lambda function code
print_status "Updating Lambda function code..."
aws lambda update-function-code \
    --function-name $LAMBDA_FUNCTION_NAME \
    --zip-file fileb:///tmp/lambda-package/lambda-package.zip

# Wait for update to complete
print_status "Waiting for function update to complete..."
aws lambda wait function-updated --function-name $LAMBDA_FUNCTION_NAME

print_success "Lambda function deployed successfully"

# Clean up
rm -rf /tmp/lambda-package

print_status "Deployment package cleaned up"
